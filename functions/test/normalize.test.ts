// Run: deno test -A --sloppy-imports test/
import { assertEquals } from "jsr:@std/assert@1";
import { canonicalShop, classify, normalize, parsePrice, productName } from "../src/normalize";
import { RawPost, SourceId } from "../src/types";

const price = (title: string, source: SourceId = "ppomppu") => {
  const p = parsePrice({ title, source });
  return [p.price, p.currency, p.shippingFee];
};

Deno.test("KRW price and shipping from ppomppu-style titles", () => {
  assertEquals(price("[11번가] 코카콜라 제로 190ml 총 60캔 (21,570원/무료)"), [21570, "KRW", 0]);
  assertEquals(price("[옥션] 연육80% 부산 봉어묵 2kg (11,900원) (무료)"), [11900, "KRW", 0]);
  assertEquals(price("[자사몰] 필터샤워기 (9,900원/3,300원)"), [9900, "KRW", 3300]);
  assertEquals(price("[오초몰] 글래드 매직랩 (10,000원/배송비 3,000원)"), [10000, "KRW", 3000]);
  assertEquals(price("[29CM] 윈드브레이커 - 블랙 (39,600원/무료"), [39600, "KRW", 0]);
  assertEquals(price("[쿠팡] 케이블 1m (8,290원 / 무배)"), [8290, "KRW", 0]);
  assertEquals(price("[G마켓] 이니스프리 최대 70% 할인 모음 (다양/무배)"), [null, null, 0]);
});

Deno.test("amounts that are not the price are skipped", () => {
  assertEquals(price("[네이버페이] SK주유소 5만원 이상 주유시 3천포인트 지급")[0], null);
  assertEquals(price("[쿠팡] 앤커 20000mAh 87W 60W 케이블")[0], null);
});

Deno.test("prices without a unit", () => {
  assertEquals(price("[옥션] WD 외장하드 5TB 253,040", "ruliweb"), [253040, "KRW", null]);
  assertEquals(price("[다이렉트 게임즈] 스팀키 [7,700]", "ruliweb")[0], 7700);
  assertEquals(price("[Coravin] 코라뱅 Timeless 6+ (181.92/미국내무료)", "ppomppu_global"), [181.92, "USD", null]);
});

Deno.test("foreign currencies", () => {
  assertEquals(price("[amazon.com] MacBook Air ($1091.34 / 미국내 무배)", "ppomppu_global"), [1091.34, "USD", null]);
  assertEquals(price("[woot] 케이스(49.99달러/ 아마존 프라임 무료)", "ppomppu_global")[0], 49.99);
  assertEquals(price("[Amazon] AirPods Pro 3 (149불/미국내free)", "ppomppu_global")[0], 149);
  assertEquals(price("[amazon.jp] 모니터 (jpy 17,984 / 직배, 무배)", "ppomppu_global"), [17984, "JPY", 0]);
  assertEquals(price("[일본아마존] 에버미디어 GC553G2 (17000엔/1620엔)", "ruliweb"), [17000, "JPY", 1620]);
  assertEquals(price("[아마존재팬] mac mini m6 16gb ram 256gb ssd(144504yen, fs)", "ppomppu_global")[0], 144504);
});

Deno.test("free items", () => {
  assertEquals(price("[iOS] YouPlay 평생 IAP 일시 무료", "clien")[0], 0);
  assertEquals(price("[에픽모바일] A Tiny Sticker Tale (무료)", "ruliweb")[0], 0);
});

Deno.test("structured arca fields win over the title", () => {
  const p = parsePrice({ title: "에어팟 프로 3", source: "arca", priceText: "$149", shippingText: "무료" });
  assertEquals([p.price, p.currency, p.shippingFee], [149, "USD", 0]);
  const q = parsePrice({ title: "케이블", source: "arca", priceText: "4,100원", shippingText: "3,000원" });
  assertEquals([q.price, q.shippingFee], [4100, 3000]);
});

Deno.test("product name drops shop tag and price, keeps model numbers", () => {
  assertEquals(productName("[11번가] 코카콜라 제로 190ml 총 60캔 (21,570원/무료)"), "코카콜라 제로 190ml 총 60캔");
  assertEquals(productName("[플레이샵] PS5 인왕 컬렉션 / 25,800원 / 무배"), "PS5 인왕 컬렉션");
  assertEquals(productName("[하이마트] 앤커 파워뱅크 87와트 A1118 43,610원/무배"), "앤커 파워뱅크 87와트 A1118");
  assertEquals(productName("에어팟 프로 3"), "에어팟 프로 3");
  assertEquals(productName("[아마존재팬] mac mini m6 16gb ram 256gb ssd(144504yen, fs)"), "mac mini m6 16gb ram 256gb ssd");
  assertEquals(productName("[옥션] WD 외장하드 5TB 253,040"), "WD 외장하드 5TB");
});

Deno.test("shop aliases", () => {
  assertEquals(canonicalShop("지마켓"), "G마켓");
  assertEquals(canonicalShop("쿠팡로켓직구"), "쿠팡");
  assertEquals(canonicalShop("GS SHOP"), "GS SHOP");
  assertEquals(canonicalShop("amazon.com"), "아마존");
  assertEquals(canonicalShop("처음보는몰"), "처음보는몰");
});

Deno.test("category from board category, then keywords", () => {
  assertEquals(classify("아무 제목", "PC/가전", null), "digital");
  assertEquals(classify("스너글 오리지널 초고농축 섬유유연제", null, null), "living");
  assertEquals(classify("PS5 진격의 거인 3", null, null), "game");
  assertEquals(classify("YouPlay 일시 무료", null, "앱스토어"), "game");
  assertEquals(classify("한우 꽃등심 200gx3팩", null, null), "food");
  assertEquals(classify("다이소 신상 모음", null, null), "etc");
});

Deno.test("normalize builds a full deal", () => {
  const post: RawPost = {
    source: "ppomppu", postId: "1", url: "https://x", title: "[지마켓] 삼립호빵 12입 (17,320원/무배송)",
    thumbnail: null, postedAt: new Date("2026-11-27T00:00:00Z"), upvotes: 2, comments: 1, views: 10, isEnded: false,
  };
  const d = normalize(post);
  assertEquals([d.id, d.shop, d.price, d.shippingFee, d.category, d.groupKey], ["ppomppu_1", "G마켓", 17320, 0, "food", "ppomppu_1"]);
});
