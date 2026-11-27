import { Deal } from "./types";

/**
 * Cross-site grouping. Two posts are the same deal when they share shop and
 * price and their product names overlap strongly. Deals without a price or
 * shop are never grouped: a wrong merge hides a deal, a missed merge only
 * shows a duplicate.
 */

const STOPWORDS = new Set(["무료", "무배", "무료배송", "할인", "특가", "최저가", "역대가", "개", "x", "외", "and", "the", "with"]);

export function tokens(name: string): Set<string> {
  return new Set(
    name
      .toLowerCase()
      .replace(/[^0-9a-z가-힣\s]/g, " ")
      .split(/\s+/)
      .filter((t) => t.length >= 2 && !STOPWORDS.has(t)),
  );
}

export function similarity(a: string, b: string): number {
  const ta = tokens(a);
  const tb = tokens(b);
  if (ta.size === 0 || tb.size === 0) return 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter++;
  return inter / Math.min(ta.size, tb.size);
}

export const SIMILARITY_THRESHOLD = 0.6;

/** Equality key used to find grouping candidates, or null when the deal can't be grouped. */
export function shopPriceKey(deal: Pick<Deal, "shop" | "price" | "currency">): string | null {
  if (!deal.shop || deal.price === null || deal.price <= 0 || !deal.currency) return null;
  return `${deal.shop.toLowerCase()}|${deal.price}${deal.currency}`;
}

/**
 * Picks the groupKey for a deal from earlier deals that share its shop and price.
 * Never groups two posts from the same source (a board re-post is a separate post).
 */
export function assignGroup(
  deal: Pick<Deal, "id" | "source" | "productName">,
  candidates: Pick<Deal, "id" | "source" | "productName" | "groupKey">[],
): string {
  let best: { key: string; score: number } | null = null;
  for (const c of candidates) {
    if (c.id === deal.id || c.source === deal.source) continue;
    const score = similarity(deal.productName, c.productName);
    if (score >= SIMILARITY_THRESHOLD && (!best || score > best.score)) best = { key: c.groupKey, score };
  }
  return best?.key ?? deal.id;
}
