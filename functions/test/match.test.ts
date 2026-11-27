import { assertEquals } from "jsr:@std/assert@1";
import { assignGroup, similarity } from "../src/group";
import { inQuietHours, keywordMatches, matchDeals, ruleMatches } from "../src/match";
import { AlertRule, Deal } from "../src/types";

const deal = (over: Partial<Deal> = {}): Deal => ({
  id: "ppomppu_1", source: "ppomppu", sourceName: "뽐뿌", postId: "1", url: "https://x",
  title: "[쿠팡] Apple 에어팟 프로 3 (249,000원/무료)", productName: "Apple 에어팟 프로 3",
  shop: "쿠팡", price: 249000, currency: "KRW", shippingFee: 0, category: "digital", sourceCategory: null,
  thumbnail: null, postedAt: new Date(), upvotes: 0, comments: 0, views: 0, isEnded: false, groupKey: "ppomppu_1",
  ...over,
});

const rule = (over: Partial<AlertRule> = {}): AlertRule => ({
  id: "r1", uid: "u1", keyword: "에어팟 프로", maxPrice: null, excludeWords: [], shops: [], categories: [], enabled: true,
  ...over,
});

Deno.test("keywords ignore case and spacing; all words must appear", () => {
  assertEquals(keywordMatches("에어팟프로", "에어팟 프로 3"), true);
  assertEquals(keywordMatches("AIRPODS pro", "Apple AirPods Pro 3"), true);
  assertEquals(keywordMatches("에어팟 맥스", "에어팟 프로 3"), false);
});

Deno.test("smart rule conditions", () => {
  assertEquals(ruleMatches(rule({ maxPrice: 250000 }), deal()), true);
  assertEquals(ruleMatches(rule({ maxPrice: 200000 }), deal()), false);
  assertEquals(ruleMatches(rule({ maxPrice: 200000 }), deal({ price: null, currency: null })), true);
  assertEquals(ruleMatches(rule({ maxPrice: 100 }), deal({ price: 149, currency: "USD" })), true);
  assertEquals(ruleMatches(rule({ excludeWords: ["리퍼"] }), deal({ title: "[쿠팡] 에어팟 프로 3 리퍼" })), false);
  assertEquals(ruleMatches(rule({ shops: ["G마켓"] }), deal()), false);
  assertEquals(ruleMatches(rule({ shops: ["쿠팡"] }), deal()), true);
  assertEquals(ruleMatches(rule({ categories: ["food"] }), deal()), false);
  assertEquals(ruleMatches(rule({ enabled: false }), deal()), false);
  assertEquals(ruleMatches(rule(), deal({ isEnded: true })), false);
});

Deno.test("one alert per user per deal group", () => {
  const a = deal();
  const b = deal({ id: "arca_9", source: "arca", groupKey: "ppomppu_1" });
  const n = matchDeals([a, b], [rule(), rule({ id: "r2", keyword: "에어팟" }), rule({ id: "r3", uid: "u2" })]);
  assertEquals(n.map((x) => `${x.uid}:${x.rule.id}:${x.deal.id}`), ["u1:r1:ppomppu_1", "u2:r3:ppomppu_1"]);
});

Deno.test("quiet hours use KST and can wrap midnight", () => {
  const at = (kstHour: number) => new Date(Date.UTC(2026, 10, 27, (kstHour + 24 - 9) % 24));
  const user = { quietStart: 23, quietEnd: 7 };
  assertEquals(inQuietHours(user, at(23)), true);
  assertEquals(inQuietHours(user, at(3)), true);
  assertEquals(inQuietHours(user, at(7)), false);
  assertEquals(inQuietHours(user, at(12)), false);
  assertEquals(inQuietHours({ quietStart: 13, quietEnd: 14 }, at(13)), true);
  assertEquals(inQuietHours({ quietStart: null, quietEnd: null }, at(3)), false);
});

Deno.test("grouping merges the same deal across boards only", () => {
  assertEquals(similarity("연육80% 부산 봉어묵 2kg", "연육80% 부산 봉어묵 2kg") >= 0.6, true);
  const ppomppu = { id: "ppomppu_1", source: "ppomppu" as const, productName: "연육80% 부산 봉어묵 2kg", groupKey: "ppomppu_1" };
  assertEquals(assignGroup({ id: "arca_2", source: "arca", productName: "연육80% 부산 봉어묵 2kg" }, [ppomppu]), "ppomppu_1");
  // Same shop and price but a different product stays separate.
  assertEquals(
    assignGroup({ id: "arca_3", source: "arca", productName: "코카콜라 190ml 30캔+닥터페퍼제로 190ml 30캔" },
      [{ id: "ppomppu_4", source: "ppomppu", productName: "코카콜라 제로 + 스프라이트 제로 190ml 총 60캔", groupKey: "ppomppu_4" }]),
    "arca_3",
  );
  // A re-post on the same board is not merged.
  assertEquals(assignGroup({ id: "ppomppu_5", source: "ppomppu", productName: "연육80% 부산 봉어묵 2kg" }, [ppomppu]), "ppomppu_5");
});
