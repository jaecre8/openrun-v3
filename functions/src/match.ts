import { AlertRule, Deal, UserSettings } from "./types";

const squash = (s: string) => s.toLowerCase().replace(/\s+/g, "");

/** Every space-separated word of the keyword must appear in the title (case and spacing ignored). */
export function keywordMatches(keyword: string, title: string): boolean {
  const words = keyword.trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return false;
  const t = squash(title);
  return words.every((w) => t.includes(squash(w)));
}

/**
 * Whether a deal satisfies an alert rule.
 * A deal whose price is unknown, or not in KRW, still passes a maxPrice
 * condition: for hot deals a missed alert costs more than an extra one.
 */
export function ruleMatches(rule: AlertRule, deal: Deal): boolean {
  if (!rule.enabled || deal.isEnded) return false;
  const text = `${deal.title} ${deal.shop ?? ""}`;
  if (!keywordMatches(rule.keyword, text)) return false;
  if (rule.excludeWords.some((w) => w.trim() && squash(text).includes(squash(w)))) return false;
  if (rule.maxPrice !== null && deal.price !== null && deal.currency === "KRW" && deal.price > rule.maxPrice) return false;
  if (rule.shops.length > 0 && !rule.shops.some((s) => deal.shop !== null && squash(deal.shop) === squash(s))) return false;
  if (rule.categories.length > 0 && !rule.categories.includes(deal.category)) return false;
  return true;
}

/** Hour of day in Korea (UTC+9, no DST). */
export function kstHour(now: Date): number {
  return (now.getUTCHours() + 9) % 24;
}

export function inQuietHours(user: Pick<UserSettings, "quietStart" | "quietEnd">, now: Date): boolean {
  const { quietStart: s, quietEnd: e } = user;
  if (s === null || e === null || s === e) return false;
  const h = kstHour(now);
  return s < e ? h >= s && h < e : h >= s || h < e;
}

export interface Notification {
  uid: string;
  deal: Deal;
  rule: AlertRule;
}

/**
 * For each user, the first matching rule per deal group. A deal posted on
 * several boards notifies once (dedupe across runs is done with sent/ docs).
 */
export function matchDeals(deals: Deal[], rules: AlertRule[]): Notification[] {
  const out: Notification[] = [];
  const seen = new Set<string>();
  for (const deal of deals) {
    for (const rule of rules) {
      const key = `${rule.uid}|${deal.groupKey}`;
      if (seen.has(key)) continue;
      if (ruleMatches(rule, deal)) {
        seen.add(key);
        out.push({ uid: rule.uid, deal, rule });
      }
    }
  }
  return out;
}

export function formatPrice(deal: Pick<Deal, "price" | "currency">): string | null {
  if (deal.price === null || !deal.currency) return null;
  if (deal.price === 0) return "무료";
  switch (deal.currency) {
    case "KRW":
      return `${deal.price.toLocaleString("ko-KR")}원`;
    case "USD":
      return `$${deal.price}`;
    case "JPY":
      return `¥${deal.price.toLocaleString("ko-KR")}`;
    case "EUR":
      return `€${deal.price}`;
    case "CNY":
      return `${deal.price}위안`;
  }
}

export function notificationText(n: Notification): { title: string; body: string } {
  const price = formatPrice(n.deal);
  const shop = n.deal.shop ? `[${n.deal.shop}] ` : "";
  return {
    title: `🔥 '${n.rule.keyword}' 핫딜${price ? ` · ${price}` : ""}`,
    body: `${shop}${n.deal.productName} · ${n.deal.sourceName}`,
  };
}
