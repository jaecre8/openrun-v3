import { assertEquals } from "jsr:@std/assert@1";
import { addPrice, hotScore, priceInsight, PricePoint, productKey } from "../src/insight";

Deno.test("product key ignores word order, shop tags and promo words", () => {
  const a = productKey("코카콜라 제로 190ml 30캔");
  assertEquals(a, productKey("제로 코카콜라 190ml 30캔 무료배송"));
  assertEquals(a, productKey("[특가] 코카콜라 제로 190ml 30캔 (선착순)"));
  // a different size is a different product
  assertEquals(a === productKey("코카콜라 제로 355ml 24캔"), false);
});

Deno.test("collections and sales get no key", () => {
  assertEquals(productKey("이니스프리 블랙프라이데이 최대 70% 할인 모음"), null);
  assertEquals(productKey("반다이몰 겨울 세일 시작"), null);
  assertEquals(productKey("샘표 토장찌개양념 등 7종 2+2개 골라담기"), null);
  assertEquals(productKey("에어팟"), null); // one word is too vague
});

const pt = (price: number, day: number, groupKey = `g${day}`): PricePoint => ({
  price, at: `2026-11-${String(day).padStart(2, "0")}T00:00:00Z`, dealId: `d${day}`, groupKey, shop: null,
});

Deno.test("badges need at least two earlier prices", () => {
  assertEquals(priceInsight(9000, [], "x").kind, null);
  assertEquals(priceInsight(9000, [pt(10000, 1)], "x").kind, null);
  const h = [pt(12000, 1), pt(11000, 2), pt(13000, 3)];
  assertEquals(priceInsight(10900, h, "x"), { kind: "lowest", prevLowest: 11000, avg: 12000, pct: 9, samples: 3 });
  assertEquals(priceInsight(11000, h, "x").kind, "lowest"); // ties count
  assertEquals(priceInsight(11500, h, "x").kind, null); // above the low, 4% under average
  const wide = [pt(20000, 1), pt(9000, 2), pt(19000, 3)];
  assertEquals(priceInsight(14000, wide, "x").kind, "below_avg"); // 12% under the 16,000 average
});

Deno.test("other posts of the same deal are not compared against", () => {
  const h = [pt(12000, 1), pt(11000, 2), pt(9000, 3, "same")];
  assertEquals(priceInsight(9000, h, "same").kind, "lowest");
});

Deno.test("history keeps one entry per deal, oldest first, capped", () => {
  let doc = addPrice(null, "k", "n", pt(12000, 2));
  doc = addPrice(doc, "k", "n", pt(11000, 1));
  doc = addPrice(doc, "k", "n", { ...pt(9000, 3), groupKey: "g2" }); // repost of day 2's deal
  assertEquals(doc.history.map((p) => p.price), [11000, 12000]);
  assertEquals([doc.count, doc.lowest?.price], [2, 11000]);
  for (let d = 4; d < 60; d++) doc = addPrice(doc, "k", "n", { ...pt(10000, (d % 28) + 1, `x${d}`), dealId: `x${d}` });
  assertEquals(doc.history.length, 40);
});

Deno.test("hot score rewards engagement and decays with age", () => {
  const now = new Date("2026-11-28T12:00:00Z");
  const fresh = hotScore({ upvotes: 5, comments: 10, views: 800, postedAt: new Date("2026-11-28T11:00:00Z") }, now);
  const old = hotScore({ upvotes: 5, comments: 10, views: 800, postedAt: new Date("2026-11-27T12:00:00Z") }, now);
  assertEquals(fresh > old * 10, true);
});
