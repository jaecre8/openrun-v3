import { Category, Currency, Deal, RawPost, SOURCE_NAMES, SourceId } from "./types";

// ---------------------------------------------------------------- shop

/** Tags in a leading [..] that are not a shop name. */
const NON_SHOP_TAGS = new Set(["예판", "예약", "종료", "품절", "마감", "정보", "이벤트", "공지", "핫딜", "무료", "국내", "해외"]);

/** Lowercased, space-free alias → display name. */
const SHOP_ALIASES: Record<string, string> = {
  "g마켓": "G마켓", "지마켓": "G마켓", "gmarket": "G마켓",
  "옥션": "옥션", "auction": "옥션",
  "11번가": "11번가", "11st": "11번가",
  "쿠팡": "쿠팡", "쿠팡와우": "쿠팡", "쿠팡로켓직구": "쿠팡", "coupang": "쿠팡",
  "네이버": "네이버", "네이버쇼핑": "네이버", "네이버스토어": "네이버", "스마트스토어": "네이버", "네이버페이": "네이버페이",
  "ssg": "SSG", "ssg.com": "SSG", "쓱": "SSG",
  "롯데온": "롯데온", "lotteon": "롯데온",
  "gsshop": "GS SHOP",
  "토스": "토스쇼핑", "토스쇼핑": "토스쇼핑",
  "알리": "알리익스프레스", "알리익스프레스": "알리익스프레스", "aliexpress": "알리익스프레스",
  "아마존": "아마존", "아미존": "아마존", "amazon": "아마존", "amazon.com": "아마존",
  "amazon.jp": "아마존재팬", "일본아마존": "아마존재팬", "아마존재팬": "아마존재팬",
  "ebay": "이베이", "ebay.com": "이베이",
  "bestbuy": "베스트바이", "newegg": "뉴에그", "newegg.com": "뉴에그",
  "ios": "앱스토어", "ios/android": "앱스토어", "macos": "맥 앱스토어",
  "wearos": "플레이스토어", "플레이스토어": "플레이스토어",
  "스팀": "스팀", "steam": "스팀",
  "에픽게임즈": "에픽게임즈", "에픽모바일": "에픽게임즈",
};

const APP_STORES = new Set(["앱스토어", "맥 앱스토어", "플레이스토어", "스팀", "에픽게임즈"]);

export function canonicalShop(name: string | null | undefined): string | null {
  if (!name) return null;
  const trimmed = name.trim();
  if (!trimmed) return null;
  const key = trimmed.toLowerCase().replace(/\s+/g, "");
  return SHOP_ALIASES[key] ?? trimmed;
}

const LEADING_TAG = /^\s*(?:19금\s*)?[[(]([^\])]{1,24})[\])]\s*/;

function leadingShop(title: string): string | null {
  const m = title.match(LEADING_TAG);
  if (!m) return null;
  const tag = m[1].trim();
  if (NON_SHOP_TAGS.has(tag)) return null;
  return tag;
}

// ---------------------------------------------------------------- price

export interface PriceInfo {
  price: number | null;
  currency: Currency | null;
  shippingFee: number | null;
}

const num = (s: string) => parseFloat(s.replace(/,/g, ""));

/** Words right after an amount that mean it is a threshold or a discount, not the price. */
const NOT_A_PRICE_AFTER = /^\s*(?:이상|할인|적립|쿠폰|포인트|이하)/;

interface Candidate {
  index: number;
  end: number;
  price: number;
  currency: Currency;
}

function explicitCandidates(text: string): Candidate[] {
  const out: Candidate[] = [];
  const push = (re: RegExp, currency: Currency, value: (m: RegExpExecArray) => number) => {
    for (const m of text.matchAll(new RegExp(re.source, re.flags.includes("g") ? re.flags : re.flags + "g"))) {
      const end = (m.index ?? 0) + m[0].length;
      if (NOT_A_PRICE_AFTER.test(text.slice(end))) continue;
      out.push({ index: m.index ?? 0, end, price: value(m as RegExpExecArray), currency });
    }
  };
  push(/(?<![\d.,])(\d+(?:\.\d+)?)\s*만\s*원/i, "KRW", (m) => Math.round(num(m[1]) * 10000));
  push(/(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d+)\s*원/i, "KRW", (m) => num(m[1]));
  push(/₩\s*(\d{1,3}(?:,\d{3})+|\d+)/, "KRW", (m) => num(m[1]));
  push(/\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)/, "USD", (m) => num(m[1]));
  push(/(?<![\d.,])(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:\$|달러|불|usd)/i, "USD", (m) => num(m[1]));
  push(/(?:jpy|¥)\s*(\d+(?:,\d{3})*)/i, "JPY", (m) => num(m[1]));
  push(/(?<![\d.,])(\d+(?:,\d{3})*)\s*(?:엔|jpy|yen)/i, "JPY", (m) => num(m[1]));
  push(/(?:€|eur)\s*(\d+(?:,\d{3})*(?:\.\d+)?)/i, "EUR", (m) => num(m[1]));
  push(/(?<![\d.,])(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:유로|eur)/i, "EUR", (m) => num(m[1]));
  push(/(?<![\d.,])(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:위안|cny|yuan)/i, "CNY", (m) => num(m[1]));
  return out.sort((a, b) => a.index - b.index);
}

function fallbackCandidate(text: string, source: SourceId): Candidate | null {
  if (source === "ppomppu_global") {
    const m = text.match(/(?<![\d.,])(\d+\.\d{2})(?!\d)/);
    if (m) return { index: m.index ?? 0, end: (m.index ?? 0) + m[0].length, price: num(m[1]), currency: "USD" };
    return null;
  }
  const m = text.match(/(?<![\d.,])(\d{1,3}(?:,\d{3})+)(?![\d,]|\s*(?:%|ml|g\b|kg|mah|개|입|매|캔|병|w\b|팩))/i);
  if (m) return { index: m.index ?? 0, end: (m.index ?? 0) + m[0].length, price: num(m[1]), currency: "KRW" };
  return null;
}

const FREE_SHIPPING = /무료\s*배송|무배|무료|free/i;
const DOMESTIC_ABROAD = /미국\s*내|현지/;

function shippingAfter(text: string, priceEnd: number): number | null {
  // Shipping is written right after the price: "(9,900원/3,300원)", "/ 무배", "(배송비 3,000원)".
  const rest = text.slice(priceEnd, priceEnd + 40);
  const fee = rest.match(/^[^/()[\]]*[/(]\s*(?:배송비\s*)?(\d{1,3}(?:,\d{3})+|\d+)\s*(?:원|엔)/);
  if (fee) return num(fee[1]);
  const seg = rest.match(/^[^/]*?[/(]\s*([^)/]*)/)?.[1] ?? "";
  if (FREE_SHIPPING.test(seg) && !DOMESTIC_ABROAD.test(seg)) return 0;
  return null;
}

function shippingAnywhere(text: string): number | null {
  const fee = text.match(/배송비\s*(\d{1,3}(?:,\d{3})+|\d+)\s*원/);
  if (fee) return num(fee[1]);
  if (/무배|무료\s*배송/.test(text) && !DOMESTIC_ABROAD.test(text)) return 0;
  if (/[/(]\s*무료\s*\)?\s*$/.test(text) || /\(무료\)/.test(text)) return 0;
  return null;
}

const FREE_ITEM = /일시\s*무료|무료\s*배포|무료\s*나눔|무료\s*증정|\(무료\)/;

export function parsePrice(post: Pick<RawPost, "title" | "source" | "priceText" | "shippingText">): PriceInfo {
  // Boards with structured fields (arca) win over title parsing.
  if (post.priceText) {
    const c = explicitCandidates(post.priceText)[0] ?? fallbackCandidate(post.priceText, post.source);
    let shippingFee: number | null = null;
    if (post.shippingText) {
      if (FREE_SHIPPING.test(post.shippingText)) shippingFee = 0;
      else {
        const s = explicitCandidates(post.shippingText)[0];
        shippingFee = s ? s.price : null;
      }
    }
    if (c) return { price: c.price, currency: c.currency, shippingFee };
  }

  const title = post.title;
  const c = explicitCandidates(title)[0] ?? fallbackCandidate(title, post.source);
  if (!c) {
    if (FREE_ITEM.test(title)) return { price: 0, currency: "KRW", shippingFee: null };
    return { price: null, currency: null, shippingFee: shippingAnywhere(title) };
  }
  const shippingFee = shippingAfter(title, c.end) ?? shippingAnywhere(title.slice(c.end));
  return { price: c.price, currency: c.currency, shippingFee };
}

// ---------------------------------------------------------------- product name

export function productName(title: string): string {
  let s = title;
  while (LEADING_TAG.test(s)) s = s.replace(LEADING_TAG, "");
  const priceGroup = /\s*[([][^()[\]]*(?:\d\s*원|원\)|무료|무배|\$|달러|불|엔|jpy|yen|free|배송|\d[\d,]*\]?$)[^()[\]]*(?:[)\]]|$)\s*$/i;
  const slashPrice = /\s*\/\s*[^/]*(?:\d\s*원|무배|무료)[^/]*$/;
  // Only strip a trailing number that is clearly a price, never a model number ("A1118", "Pro 3").
  const tailPrice =
    /\s+(?:(?:₩|\$)?(?:\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)\s*(?:원|달러|불|엔)|(?:₩|\$)\d[\d,]*(?:\.\d+)?|\d{1,3}(?:,\d{3})+)\s*$/;
  for (let i = 0; i < 4; i++) {
    const before = s;
    s = s.replace(priceGroup, "").replace(slashPrice, "").replace(tailPrice, "").replace(/[\s/,~-]+$/, "").trim();
    if (s === before) break;
  }
  return s.replace(/\s+/g, " ").trim() || title.trim();
}

// ---------------------------------------------------------------- category

const SOURCE_CATEGORY: Record<string, Category> = {
  "게임S/W": "game", "게임H/W": "game", "게임": "game",
  "PC/가전": "digital", "PC/하드웨어": "digital", "전자제품": "digital", "디지털": "digital",
  "생활용품": "living",
  "음식": "food", "식품": "food",
  "상품권": "coupon", "상품권/쿠폰": "coupon",
  "의류": "fashion", "의류/잡화": "fashion", "화장품": "fashion",
};

const KEYWORDS: [Category, string[]][] = [
  ["game", ["ps5", "ps4", "플스", "스위치", "switch", "닌텐도", "xbox", "엑스박스", "스팀", "steam", "에픽", "dlc", "게임", "타이틀", "스팀키", "젤다", "포켓몬", "앱스토어", "플레이스토어", "iap", "워치페이스"]],
  ["digital", ["노트북", "맥북", "아이패드", "갤럭시", "아이폰", "에어팟", "버즈", "모니터", "ssd", "hdd", "외장하드", "키보드", "마우스", "충전기", "보조배터리", "파워뱅크", "케이블", "멀티탭", "이어폰", "헤드폰", "headphone", "earbuds", "airpods", "스피커", "공유기", "그래픽카드", "rtx", "라데온", "cpu", "ddr", "usb", "태블릿", "카메라", "청소기", "냉장고", "세탁기", "에어컨", "가습기", "공기청정기", "전자레인지", "밥솥", "드라이기", "면도기", "프린터", "nas", "메모리", "sd카드", "마이크로sd", "hdmi", "턴테이블", "블루투스", "완본체", "macbook", "ryzen", "라이젠", "tv", "티비", "스마트워치", "필름"]],
  ["food", ["라면", "커피", "생수", "우유", "쌀", "한우", "돼지", "삼겹", "닭", "치킨", "피자", "과자", "음료", "콜라", "사이다", "제로", "김치", "만두", "어묵", "연어", "새우", "견과", "간장", "고추장", "참치", "햇반", "간편식", "아이스크림", "맥주", "와인", "위스키", "녹차", "홍삼", "영양제", "비타민", "유산균", "프로틴", "단백질", "계란", "과일", "사과", "귤", "딸기", "밀키트", "초콜릿", "초코", "빵", "호빵", "케익", "케이크", "오리로스", "생오리", "오리고기", "오리양념", "소시지", "햄", "레몬즙", "구미"]],
  ["living", ["휴지", "화장지", "물티슈", "세제", "샴푸", "바디워시", "핸드워시", "치약", "칫솔", "섬유유연제", "주방", "프라이팬", "냄비", "밀폐용기", "매직랩", "크린랩", "수건", "침구", "이불", "베개", "매트리스", "의자", "책상", "수납", "기저귀", "생리대", "마스크", "건전지", "전구", "캠핑", "텐트", "샤워기", "안경닦이", "푸쉬업", "내복"]],
  ["fashion", ["신발", "운동화", "자켓", "재킷", "패딩", "바지", "셔츠", "티셔츠", "후드", "맨투맨", "가방", "지갑", "나이키", "아디다스", "뉴발란스", "스케쳐스", "화장품", "스킨", "로션", "선크림", "향수", "쿠션", "이니스프리", "윈드브레이커", "니트", "코트", "넥워머", "유니폼", "무신사"]],
  ["coupon", ["쿠폰", "상품권", "기프티콘", "적립", "포인트", "페이백", "캐시백", "할인코드", "리딤", "구독", "멤버십", "랜덤", "뽑기", "프로모션"]],
];

export function classify(title: string, sourceCategory: string | null, shop: string | null): Category {
  if (sourceCategory && SOURCE_CATEGORY[sourceCategory]) return SOURCE_CATEGORY[sourceCategory];
  if (shop && APP_STORES.has(shop)) return "game";
  const t = title.toLowerCase();
  let best: Category = "etc";
  let bestScore = 0;
  for (const [cat, words] of KEYWORDS) {
    const score = words.reduce((n, w) => (t.includes(w) ? n + 1 : n), 0);
    if (score > bestScore) {
      best = cat;
      bestScore = score;
    }
  }
  if (best === "etc" && sourceCategory === "이벤트정보") return "coupon";
  return best;
}

// ---------------------------------------------------------------- deal

export function dealId(post: Pick<RawPost, "source" | "postId">): string {
  return `${post.source}_${post.postId}`;
}

/** Converts a crawled post into a Deal. groupKey defaults to the deal's own id; grouping refines it. */
export function normalize(post: RawPost, now: Date = new Date()): Deal {
  const shop = canonicalShop(post.shopHint ?? leadingShop(post.title));
  const price = parsePrice(post);
  const name = productName(post.title);
  const id = dealId(post);
  return {
    id,
    source: post.source,
    sourceName: SOURCE_NAMES[post.source],
    postId: post.postId,
    url: post.url,
    title: post.title,
    productName: name,
    shop,
    price: price.price,
    currency: price.currency,
    shippingFee: price.shippingFee,
    category: classify(post.title, post.sourceCategory ?? null, shop),
    sourceCategory: post.sourceCategory ?? null,
    thumbnail: post.thumbnail,
    postedAt: post.postedAt ?? now,
    upvotes: post.upvotes ?? 0,
    comments: post.comments ?? 0,
    views: post.views ?? 0,
    isEnded: post.isEnded,
    groupKey: id,
  };
}
