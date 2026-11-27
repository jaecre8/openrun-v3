import { DocumentData, FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { assignGroup, shopPriceKey } from "./group";
import { inQuietHours, matchDeals, Notification, notificationText } from "./match";
import { normalize } from "./normalize";
import { crawlAll, CrawlResult } from "./sources";
import { AlertRule, Category, Deal, UserSettings } from "./types";

/** Posts older than this when first seen never trigger alerts (backlog, re-crawls). */
const ALERT_WINDOW_MS = 6 * 60 * 60 * 1000;
/** How far back a new post looks for the same deal on other boards. */
const GROUP_WINDOW_MS = 48 * 60 * 60 * 1000;

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
  notified: number;
  pushed: number;
}

export async function runCrawl(db: Firestore, messaging: Messaging, now = new Date()): Promise<CrawlStats> {
  const results: CrawlResult[] = await crawlAll();
  const perSource: Record<string, number | string> = {};
  for (const r of results) perSource[r.source] = r.error ?? r.posts.length;

  // A board can list the same post twice (pinned + regular row).
  const byId = new Map(results.flatMap((r) => r.posts).map((p) => normalize(p, now)).map((d) => [d.id, d]));
  const deals = [...byId.values()];
  if (deals.length === 0) return { perSource, fresh: 0, updated: 0, notified: 0, pushed: 0 };

  const col = db.collection("deals");
  const snaps = await db.getAll(...deals.map((d) => col.doc(d.id)));
  const existing = new Map(snaps.filter((s) => s.exists).map((s) => [s.id, s.data()!]));
  const bootstrap = existing.size === 0 && (await col.limit(1).get()).empty;

  // Group new posts with the same deal seen on other boards.
  const fresh = deals.filter((d) => !existing.has(d.id));
  const groupedThisRun: Deal[] = [];
  for (const d of fresh) {
    const key = shopPriceKey(d);
    if (!key) continue;
    const q = await col.where("shopPriceKey", "==", key).limit(20).get();
    const earlier = q.docs
      .map((doc) => docToDeal(doc.data()))
      .filter((c) => now.getTime() - c.postedAt.getTime() < GROUP_WINDOW_MS);
    const sameRun = groupedThisRun.filter((c) => shopPriceKey(c) === key);
    d.groupKey = assignGroup(d, [...earlier, ...sameRun]);
    groupedThisRun.push(d);
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
  for (const d of deals) {
    const prev = existing.get(d.id);
    if (!prev) {
      writer.set(col.doc(d.id), dealToDoc(d, now));
    } else {
      const changes: DocumentData = {};
      for (const k of ["upvotes", "comments", "views", "isEnded", "thumbnail"] as const) {
        if (d[k] !== null && d[k] !== prev[k]) changes[k] = d[k];
      }
      if (Object.keys(changes).length === 0) continue;
      changes.updatedAt = Timestamp.fromDate(now);
      writer.update(col.doc(d.id), changes);
      updated++;
    }
    if (++ops >= 450) await flush();
  }
  await flush();

  const notifiable = bootstrap
    ? []
    : fresh.filter((d) => !d.isEnded && now.getTime() - d.postedAt.getTime() < ALERT_WINDOW_MS);
  const { notified, pushed } = notifiable.length ? await sendAlerts(db, messaging, notifiable, now) : { notified: 0, pushed: 0 };

  return { perSource, fresh: fresh.length, updated, notified, pushed };
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
    quietStart: typeof data?.quietStart === "number" ? data.quietStart : null,
    quietEnd: typeof data?.quietEnd === "number" ? data.quietEnd : null,
  };
}

async function sendAlerts(db: Firestore, messaging: Messaging, deals: Deal[], now: Date) {
  // All rules are read only when there are new deals; fine for the MVP scale.
  const ruleSnap = await db.collectionGroup("alerts").get();
  const rules = ruleSnap.docs
    .filter((d) => d.ref.parent.parent !== null)
    .map((d) => docToRule(d.id, d.ref.parent.parent!.id, d.data()))
    .filter((r) => r.enabled && r.keyword.trim());

  const matches = matchDeals(deals, rules);
  if (matches.length === 0) return { notified: 0, pushed: 0 };

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
