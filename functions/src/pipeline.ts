import { DocumentData, FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { dealChanges, DealState, stateOf } from "./changes";
import { assignGroup, shopPriceKey } from "./group";
import { addPrice, hotScore, priceInsight, ProductDoc } from "./insight";
import { inQuietHours, matchDeals, Notification, notificationText } from "./match";
import { normalize } from "./normalize";
import { crawlAll, CrawlResult } from "./sources";
import { AlertRule, Category, Deal, UserSettings } from "./types";

/** Posts older than this when first seen never trigger alerts (backlog, re-crawls). */
const ALERT_WINDOW_MS = 6 * 60 * 60 * 1000;
/** How far back a new post looks for the same deal on other boards. */
const GROUP_WINDOW_MS = 48 * 60 * 60 * 1000;
/** "지금 뜨는 딜": hot score, engagement and age a deal needs (calibrated on live boards: ~top 5%). */
const HOT_SCORE = 3.5;
const HOT_MIN_ENGAGEMENT = 8;
const HOT_MAX_AGE_MS = 6 * 60 * 60 * 1000;

function isHot(d: Deal, score: number, now: Date): boolean {
  return !d.isEnded && score >= HOT_SCORE && d.upvotes + d.comments >= HOT_MIN_ENGAGEMENT &&
    now.getTime() - d.postedAt.getTime() < HOT_MAX_AGE_MS;
}

export function dealToDoc(deal: Deal, now: Date): DocumentData {
  return {
    ...deal,
    postedAt: Timestamp.fromDate(deal.postedAt),
    shopPriceKey: shopPriceKey(deal),
    firstSeenAt: Timestamp.fromDate(now),
    updatedAt: Timestamp.fromDate(now),
  };
}

function docToDeal(data: DocumentData): Deal {
  return { ...(data as Deal), postedAt: (data.postedAt as Timestamp).toDate() };
}

export interface CrawlStats {
  perSource: Record<string, number | string>;
  fresh: number;
  updated: number;
  reads: number;
  notified: number;
  pushed: number;
  hot?: number;
  products?: number;
}

/** How long alert rules read from Firestore are reused by a long-running process. */
const RULES_TTL_MS = 3 * 60 * 1000;

/**
 * State kept between runs by a long-running process (the standalone runner),
 * so each 2-minute cycle reads only posts it has not seen yet.
 * A fresh cache per run (Cloud Functions) behaves exactly like no cache.
 */
export class CrawlCache {
  deals = new Map<string, DealState>();
  rules: { at: number; rules: AlertRule[] } | null = null;
  hotUsers: { at: number; uids: string[] } | null = null;
  /** products/{key} docs read or written by this process (null = no doc yet). */
  products = new Map<string, ProductDoc | null>();
  hasAnyDeal = false;
}

export async function runCrawl(
  db: Firestore,
  messaging: Messaging,
  now = new Date(),
  cache = new CrawlCache(),
): Promise<CrawlStats> {
  const results: CrawlResult[] = await crawlAll();
  const perSource: Record<string, number | string> = {};
  for (const r of results) {
    perSource[r.source] = r.error ?? (r.via ? `${r.posts.length} ${r.via === "preferred" ? "html" : "rss"}` : r.posts.length);
  }

  // A board can list the same post twice (pinned + regular row).
  const byId = new Map(results.flatMap((r) => r.posts).map((p) => normalize(p, now)).map((d) => [d.id, d]));
  const deals = [...byId.values()];
  if (deals.length === 0) return { perSource, fresh: 0, updated: 0, reads: 0, notified: 0, pushed: 0 };

  const col = db.collection("deals");
  const existing = new Map<string, DealState>();
  const unknown = deals.filter((d) => {
    const cached = cache.deals.get(d.id);
    if (cached) existing.set(d.id, cached);
    return !cached;
  });
  let reads = 0;
  if (unknown.length > 0) {
    const snaps = await db.getAll(...unknown.map((d) => col.doc(d.id)));
    reads += snaps.length;
    for (const s of snaps) if (s.exists) existing.set(s.id, stateOf(s.data() as DealState));
  }
  if (existing.size > 0) cache.hasAnyDeal = true;
  if (!cache.hasAnyDeal) {
    reads++;
    cache.hasAnyDeal = !(await col.limit(1).get()).empty;
  }
  // First run against an empty database: store the backlog without alerting on it.
  const bootstrap = !cache.hasAnyDeal;

  // Group new posts with the same deal seen on other boards.
  const fresh = deals.filter((d) => !existing.has(d.id));
  const groupedThisRun: Deal[] = [];
  for (const d of fresh) {
    const key = shopPriceKey(d);
    if (!key) continue;
    const q = await col.where("shopPriceKey", "==", key).limit(20).get();
    reads += Math.max(q.size, 1);
    const earlier = q.docs
      .map((doc) => docToDeal(doc.data()))
      .filter((c) => now.getTime() - c.postedAt.getTime() < GROUP_WINDOW_MS);
    const sameRun = groupedThisRun.filter((c) => shopPriceKey(c) === key);
    d.groupKey = assignGroup(d, [...earlier, ...sameRun]);
    groupedThisRun.push(d);
  }

  // Price history per product: badge each new deal against earlier prices of the same product.
  const priced = fresh
    .filter((d) => d.productKey && d.currency === "KRW" && d.price !== null && d.price > 0)
    .sort((a, b) => a.postedAt.getTime() - b.postedAt.getTime());
  if (cache.products.size > 5000) cache.products.clear();
  const missing = [...new Set(priced.map((d) => d.productKey!))].filter((k) => !cache.products.has(k));
  if (missing.length > 0) {
    const snaps = await db.getAll(...missing.map((k) => db.collection("products").doc(k)));
    reads += snaps.length;
    snaps.forEach((snap, i) => cache.products.set(missing[i], snap.exists ? (snap.data() as ProductDoc) : null));
  }
  const dirtyProducts = new Set<string>();
  for (const d of priced) {
    const key = d.productKey!;
    const doc = cache.products.get(key) ?? null;
    const ins = priceInsight(d.price!, doc?.history ?? [], d.groupKey);
    d.insightKind = ins.kind;
    d.insight = ins.samples > 0 ? { prevLowest: ins.prevLowest, avg: ins.avg, pct: ins.pct, samples: ins.samples } : null;
    const next = addPrice(doc, key, d.productName, {
      price: d.price!, at: d.postedAt.toISOString(), dealId: d.id, groupKey: d.groupKey, shop: d.shop,
    });
    if (next !== doc) {
      cache.products.set(key, next);
      dirtyProducts.add(key);
    }
  }

  // Write new deals, and counters/status of deals that changed.
  let writer = db.batch();
  let ops = 0;
  let updated = 0;
  const flush = async () => {
    if (ops > 0) await writer.commit();
    writer = db.batch();
    ops = 0;
  };
  const nextCache = new Map<string, DealState>();
  const hotDeals: Deal[] = [];
  for (const d of deals) {
    const prev = existing.get(d.id);
    const score = Math.round(hotScore(d, now) * 100) / 100;
    const becameHot = !bootstrap && !prev?.hot && isHot(d, score, now);
    if (becameHot) hotDeals.push(d);
    const hotFields = becameHot ? { hotAt: Timestamp.fromDate(now) } : {};
    if (!prev) {
      d.hotScore = score;
      writer.set(col.doc(d.id), { ...dealToDoc(d, now), ...hotFields });
      nextCache.set(d.id, { ...stateOf(d), hot: becameHot });
    } else {
      const changes = dealChanges(prev, stateOf(d), now);
      nextCache.set(d.id, { ...prev, ...changes, hot: prev.hot || becameHot });
      if (!changes && !becameHot) continue;
      writer.update(col.doc(d.id), { ...changes, hotScore: score, ...hotFields, updatedAt: Timestamp.fromDate(now) });
      updated++;
    }
    if (++ops >= 450) await flush();
  }
  for (const key of dirtyProducts) {
    writer.set(db.collection("products").doc(key), { ...cache.products.get(key), updatedAt: Timestamp.fromDate(now) });
    if (++ops >= 450) await flush();
  }
  await flush();
  // Keep only what is still on the boards' first pages.
  cache.deals = nextCache;
  if (deals.length > 0) cache.hasAnyDeal = true;

  const notifiable = bootstrap
    ? []
    : fresh.filter((d) => !d.isEnded && now.getTime() - d.postedAt.getTime() < ALERT_WINDOW_MS);
  const notes: Notification[] = [];
  if (notifiable.length > 0) {
    if (!cache.rules || now.getTime() - cache.rules.at > RULES_TTL_MS) {
      const rules = await loadRules(db);
      reads += Math.max(rules.length, 1);
      cache.rules = { at: now.getTime(), rules };
    }
    notes.push(...matchDeals(notifiable, cache.rules.rules).map((n) => ({ ...n, kind: "keyword" as const })));
    const tracked = await trackedMatches(db, notifiable);
    reads += tracked.reads;
    notes.push(...tracked.notes);
  }
  if (hotDeals.length > 0) {
    if (!cache.hotUsers || now.getTime() - cache.hotUsers.at > RULES_TTL_MS) {
      const snap = await db.collection("users").where("hotPush", "==", true).get();
      reads += Math.max(snap.size, 1);
      cache.hotUsers = { at: now.getTime(), uids: snap.docs.map((doc) => doc.id) };
    }
    for (const d of hotDeals) {
      for (const uid of cache.hotUsers.uids) notes.push({ uid, deal: d, rule: pseudoRule(uid, "hot", "지금 뜨는 딜"), kind: "hot" });
    }
  }
  const { notified, pushed } = notes.length > 0 ? await sendAlerts(db, messaging, notes, now) : { notified: 0, pushed: 0 };

  return { perSource, fresh: fresh.length, updated, reads, notified, pushed, hot: hotDeals.length, products: dirtyProducts.size };
}

function pseudoRule(uid: string, id: string, keyword: string): AlertRule {
  return { id, uid, keyword, maxPrice: null, excludeWords: [], shops: [], categories: [], enabled: true };
}

/** Users tracking the product of a new deal, at or under their target price (users/{uid}/tracked/{productKey}). */
async function trackedMatches(db: Firestore, deals: Deal[]): Promise<{ notes: Notification[]; reads: number }> {
  const byKey = new Map<string, Deal[]>();
  for (const d of deals) {
    if (!d.productKey) continue;
    byKey.set(d.productKey, [...(byKey.get(d.productKey) ?? []), d]);
  }
  const keys = [...byKey.keys()];
  const notes: Notification[] = [];
  let reads = 0;
  for (let i = 0; i < keys.length; i += 30) {
    const snap = await db.collectionGroup("tracked").where("key", "in", keys.slice(i, i + 30)).get();
    reads += Math.max(snap.size, 1);
    for (const doc of snap.docs) {
      const uid = doc.ref.parent.parent?.id;
      const t = doc.data();
      if (!uid) continue;
      const target = typeof t.targetPrice === "number" ? t.targetPrice : null;
      for (const d of byKey.get(String(t.key)) ?? []) {
        const ok = target === null || (d.currency === "KRW" && d.price !== null && d.price <= target);
        if (ok) notes.push({ uid, deal: d, rule: pseudoRule(uid, `tracked:${t.key}`, String(t.name ?? d.productName)), kind: "tracked" });
      }
    }
  }
  return { notes, reads };
}

function docToRule(id: string, uid: string, data: DocumentData): AlertRule {
  return {
    id,
    uid,
    keyword: String(data.keyword ?? ""),
    maxPrice: typeof data.maxPrice === "number" ? data.maxPrice : null,
    excludeWords: Array.isArray(data.excludeWords) ? data.excludeWords.map(String) : [],
    shops: Array.isArray(data.shops) ? data.shops.map(String) : [],
    categories: Array.isArray(data.categories) ? (data.categories as Category[]) : [],
    enabled: data.enabled !== false,
  };
}

function docToUser(uid: string, data: DocumentData | undefined): UserSettings {
  return {
    uid,
    fcmTokens: Array.isArray(data?.fcmTokens) ? data!.fcmTokens.map(String) : [],
    pushEnabled: data?.pushEnabled !== false,
    hotPush: data?.hotPush === true,
    quietStart: typeof data?.quietStart === "number" ? data.quietStart : null,
    quietEnd: typeof data?.quietEnd === "number" ? data.quietEnd : null,
  };
}

/** All enabled alert rules. Read only when there are new deals, and cached by long-running runners. */
async function loadRules(db: Firestore): Promise<AlertRule[]> {
  const ruleSnap = await db.collectionGroup("alerts").get();
  return ruleSnap.docs
    .filter((d) => d.ref.parent.parent !== null)
    .map((d) => docToRule(d.id, d.ref.parent.parent!.id, d.data()))
    .filter((r) => r.enabled && r.keyword.trim());
}

/** Records and pushes notifications; one per user per deal group, across kinds and runs. */
async function sendAlerts(db: Firestore, messaging: Messaging, notes: Notification[], now: Date) {
  const seen = new Set<string>();
  const matches = notes.filter((n) => {
    const k = `${n.uid}|${n.deal.groupKey}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });

  const uids = [...new Set(matches.map((m) => m.uid))];
  const userSnaps = await db.getAll(...uids.map((u) => db.collection("users").doc(u)));
  const users = new Map(userSnaps.map((s) => [s.id, docToUser(s.id, s.data())]));

  let notified = 0;
  let pushed = 0;
  for (const n of matches) {
    const user = users.get(n.uid)!;
    const deliver = user.pushEnabled && user.fcmTokens.length > 0 && !inQuietHours(user, now);
    if (!(await recordSent(db, n, deliver, now))) continue; // already notified for this deal group
    notified++;
    if (deliver) pushed += await push(db, messaging, user, n);
  }
  return { notified, pushed };
}

/** Writes the alert history entry. Returns false if this user was already notified for the group. */
async function recordSent(db: Firestore, n: Notification, delivered: boolean, now: Date): Promise<boolean> {
  const ref = db.collection("users").doc(n.uid).collection("sent").doc(n.deal.groupKey.replace(/\//g, "_"));
  try {
    await ref.create({
      dealId: n.deal.id,
      groupKey: n.deal.groupKey,
      ruleId: n.rule.id,
      kind: n.kind ?? "keyword",
      keyword: n.rule.keyword,
      title: n.deal.title,
      productName: n.deal.productName,
      shop: n.deal.shop,
      price: n.deal.price,
      currency: n.deal.currency,
      sourceName: n.deal.sourceName,
      url: n.deal.url,
      thumbnail: n.deal.thumbnail,
      delivered,
      sentAt: Timestamp.fromDate(now),
    });
    return true;
  } catch (e: unknown) {
    if ((e as { code?: number }).code === 6) return false; // ALREADY_EXISTS
    throw e;
  }
}

const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

async function push(db: Firestore, messaging: Messaging, user: UserSettings, n: Notification): Promise<number> {
  const { title, body } = notificationText(n);
  const res = await messaging.sendEachForMulticast({
    tokens: user.fcmTokens,
    notification: { title, body },
    data: { dealId: n.deal.id, url: n.deal.url },
    android: { priority: "high", notification: { channelId: "openrun_deals" } },
    apns: { payload: { aps: { sound: "default" } } },
  });
  const dead = res.responses
    .map((r, i) => (r.error && DEAD_TOKEN_CODES.has(r.error.code) ? user.fcmTokens[i] : null))
    .filter((t): t is string => t !== null);
  if (dead.length) {
    await db.collection("users").doc(user.uid).update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  }
  return res.successCount;
}

/** Sends a test notification to one user's devices (used from the app's settings screen). */
export async function sendTestPush(db: Firestore, messaging: Messaging, uid: string): Promise<number> {
  const user = docToUser(uid, (await db.collection("users").doc(uid).get()).data());
  if (user.fcmTokens.length === 0) return 0;
  const res = await messaging.sendEachForMulticast({
    tokens: user.fcmTokens,
    notification: { title: "오픈런 알림 테스트", body: "알림이 정상적으로 도착했어요." },
    android: { priority: "high", notification: { channelId: "openrun_deals" } },
    apns: { payload: { aps: { sound: "default" } } },
  });
  return res.successCount;
}

/**
 * One-time backfill: replays every stored deal oldest first to build products/{key}
 * histories and set productKey/insight on the deals. Safe to re-run (it rebuilds).
 */
export async function backfillProducts(db: Firestore): Promise<{ deals: number; products: number; badged: number }> {
  const { productKey } = await import("./insight");
  const snap = await db.collection("deals").orderBy("postedAt", "asc").get();
  const products = new Map<string, ProductDoc>();
  let writer = db.batch();
  let ops = 0;
  let badged = 0;
  const flush = async () => {
    if (ops > 0) await writer.commit();
    writer = db.batch();
    ops = 0;
  };
  for (const doc of snap.docs) {
    const d = docToDeal(doc.data());
    const key = productKey(d.productName ?? d.title);
    const update: DocumentData = { productKey: key, insightKind: null, insight: null };
    if (key && d.currency === "KRW" && d.price !== null && d.price > 0) {
      const prev = products.get(key) ?? null;
      const ins = priceInsight(d.price, prev?.history ?? [], d.groupKey);
      update.insightKind = ins.kind;
      update.insight = ins.samples > 0 ? { prevLowest: ins.prevLowest, avg: ins.avg, pct: ins.pct, samples: ins.samples } : null;
      if (ins.kind) badged++;
      products.set(key, addPrice(prev, key, d.productName, {
        price: d.price, at: d.postedAt.toISOString(), dealId: d.id, groupKey: d.groupKey, shop: d.shop,
      }));
    }
    writer.update(doc.ref, update);
    if (++ops >= 450) await flush();
  }
  for (const [key, p] of products) {
    writer.set(db.collection("products").doc(key), { ...p, updatedAt: Timestamp.now() });
    if (++ops >= 450) await flush();
  }
  await flush();
  return { deals: snap.size, products: products.size, badged };
}
