/**
 * Price history per product, built from the community deals themselves, and the
 * "역대 최저가 / 평소보다 N% 저렴" badges derived from it.
 *
 * Products are identified by a key made from the product name. Precision matters more
 * than recall: a wrong match puts a misleading badge on a deal, a missed match only
 * leaves the badge off.
 */

/** Words that say nothing about which product it is. */
const STOPWORDS = new Set([
  "무료", "무배", "무료배송", "배송", "특가", "할인", "최저가", "역대가", "역대급", "핫딜", "행사", "쿠폰", "적용", "적용시",
  "카드", "결제", "결제시", "선착순", "한정", "증정", "사은품", "추가", "정품", "공식", "새상품", "재입고", "타임딜", "오늘만",
  "블랙프라이데이", "블프", "the", "and", "with", "for", "new",
]);

/** Posts that are not one product (sales, collections, events) get no key. */
const NOT_ONE_PRODUCT = /모음|다양|기획전|세일|할인전|이벤트|전품목|프로모션|골라담기|택\s*1|외\s*\d*\s*종|쿠폰팩|브랜드\s*위크/;

export function productKey(productName: string): string | null {
  if (NOT_ONE_PRODUCT.test(productName)) return null;
  const tokens = productName
    .toLowerCase()
    .replace(/\([^)]*\)|\[[^\]]*\]/g, " ") // option notes like "(색상랜덤)"
    .replace(/[^0-9a-z가-힣.]+/g, " ")
    .split(/\s+/)
    .map((t) => t.replace(/^\.+|\.+$/g, ""))
    .filter((t) => t.length >= 2 && !STOPWORDS.has(t));
  const unique = [...new Set(tokens)].sort();
  if (unique.length < 2) return null;
  return unique.join("_").slice(0, 150);
}

export interface PricePoint {
  price: number; // KRW
  at: string; // ISO time the deal was posted
  dealId: string;
  groupKey: string;
  shop: string | null;
}

export interface ProductDoc {
  key: string;
  name: string;
  history: PricePoint[]; // oldest first
  lowest: PricePoint | null;
  count: number;
}

export type InsightKind = "lowest" | "below_avg";

export interface PriceInsight {
  kind: InsightKind | null;
  prevLowest: number | null;
  avg: number | null;
  /** How much cheaper than the average, in percent (rounded). */
  pct: number | null;
  /** Earlier prices the comparison is based on. */
  samples: number;
}

export const HISTORY_LIMIT = 40;
const MIN_SAMPLES = 2;
const BELOW_AVG_PCT = 10;

/** Compares a new price with the product's earlier deals (other posts of the same deal excluded). */
export function priceInsight(price: number, history: PricePoint[], groupKey: string): PriceInsight {
  const earlier = history.filter((p) => p.groupKey !== groupKey);
  if (earlier.length === 0) return { kind: null, prevLowest: null, avg: null, pct: null, samples: 0 };
  const prevLowest = Math.min(...earlier.map((p) => p.price));
  const avg = earlier.reduce((s, p) => s + p.price, 0) / earlier.length;
  const pct = Math.round(((avg - price) / avg) * 100);
  let kind: InsightKind | null = null;
  if (earlier.length >= MIN_SAMPLES && price <= prevLowest) kind = "lowest";
  else if (earlier.length >= MIN_SAMPLES && pct >= BELOW_AVG_PCT) kind = "below_avg";
  return { kind, prevLowest, avg: Math.round(avg), pct, samples: earlier.length };
}

/** Adds a price to the product's history; another post of a deal already recorded is ignored. */
export function addPrice(doc: ProductDoc | null, key: string, name: string, point: PricePoint): ProductDoc {
  const history = doc?.history ?? [];
  if (history.some((p) => p.groupKey === point.groupKey || p.dealId === point.dealId)) {
    return doc ?? { key, name, history, lowest: null, count: 0 };
  }
  const next = [...history, point].sort((a, b) => a.at.localeCompare(b.at)).slice(-HISTORY_LIMIT);
  const lowest = next.reduce<PricePoint | null>((lo, p) => (!lo || p.price < lo.price ? p : lo), null);
  return { key, name, history: next, lowest, count: (doc?.count ?? 0) + 1 };
}

/** Popularity that decays with age; the app uses the same formula. */
export function hotScore(d: { upvotes: number; comments: number; views: number; postedAt: Date }, now: Date): number {
  const hours = Math.max(0, (now.getTime() - d.postedAt.getTime()) / 3_600_000);
  return (d.upvotes * 4 + d.comments * 1.5 + d.views / 200 + 1) / Math.pow(hours + 2, 1.5);
}
