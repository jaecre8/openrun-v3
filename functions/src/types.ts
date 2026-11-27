export type SourceId = "ppomppu" | "ppomppu_global" | "ruliweb" | "clien" | "arca";

export const SOURCE_NAMES: Record<SourceId, string> = {
  ppomppu: "뽐뿌",
  ppomppu_global: "해외뽐뿌",
  ruliweb: "루리웹",
  clien: "클리앙",
  arca: "아카라이브",
};

/** A post as read from a community board, before normalization. */
export interface RawPost {
  source: SourceId;
  postId: string;
  url: string;
  title: string;
  thumbnail: string | null;
  postedAt: Date | null;
  upvotes: number | null;
  comments: number | null;
  views: number | null;
  isEnded: boolean;
  /** Structured fields some boards expose separately from the title. */
  shopHint?: string | null;
  priceText?: string | null;
  shippingText?: string | null;
  sourceCategory?: string | null;
}

export type Category = "digital" | "food" | "living" | "fashion" | "game" | "coupon" | "etc";

export type Currency = "KRW" | "USD" | "EUR" | "JPY" | "CNY";

/** The normalized deal stored in Firestore at deals/{id}. */
export interface Deal {
  id: string;
  source: SourceId;
  sourceName: string;
  postId: string;
  url: string;
  title: string;
  productName: string;
  shop: string | null;
  price: number | null;
  currency: Currency | null;
  shippingFee: number | null;
  category: Category;
  sourceCategory: string | null;
  thumbnail: string | null;
  postedAt: Date;
  upvotes: number;
  comments: number;
  views: number;
  isEnded: boolean;
  groupKey: string;
}

export interface AlertRule {
  id: string;
  uid: string;
  keyword: string;
  maxPrice: number | null;
  excludeWords: string[];
  shops: string[];
  categories: Category[];
  enabled: boolean;
}

export interface UserSettings {
  uid: string;
  fcmTokens: string[];
  pushEnabled: boolean;
  /** Quiet hours in KST, 0-23. Both null = off. */
  quietStart: number | null;
  quietEnd: number | null;
}
