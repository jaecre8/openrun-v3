import { RawPost, SourceId } from "../types";
import { parseArcaHtml } from "./arca";
import { parseClienHtml } from "./clien";
import { parsePpomppuHtml, parsePpomppuRss } from "./ppomppu";
import { parseRuliwebRss } from "./ruliweb";
import { BROWSER_UA, fetchText, HttpError } from "./util";

/**
 * Our honest client UA. Ppomppu serves its RSS to it; this is also the UA
 * Ppomppu needs to allow for its list pages.
 */
export const CLIENT_UA = "OpenRun/3.0 (hot-deal aggregator)";

interface Endpoint {
  url: string;
  userAgent: string;
  parse: (body: string) => RawPost[];
}

export interface SourceDef extends Endpoint {
  id: SourceId;
  /** Richer endpoint tried first; on failure the source falls back to url/parse. */
  preferred?: Endpoint;
}

/** After the preferred endpoint is refused, wait this long before trying it again. */
const PREFERRED_RETRY_MS = 30 * 60 * 1000;
const preferredBlockedUntil = new Map<SourceId, number>();

export const SOURCES: SourceDef[] = [
  {
    id: "ppomppu",
    url: "https://www.ppomppu.co.kr/rss.php?id=ppomppu",
    userAgent: CLIENT_UA,
    parse: (b) => parsePpomppuRss(b, "ppomppu"),
    preferred: {
      url: "https://www.ppomppu.co.kr/zboard/zboard.php?id=ppomppu",
      userAgent: CLIENT_UA,
      parse: (b) => parsePpomppuHtml(b, "ppomppu"),
    },
  },
  {
    id: "ppomppu_global",
    url: "https://www.ppomppu.co.kr/rss.php?id=ppomppu4",
    userAgent: CLIENT_UA,
    parse: (b) => parsePpomppuRss(b, "ppomppu_global"),
    preferred: {
      url: "https://www.ppomppu.co.kr/zboard/zboard.php?id=ppomppu4",
      userAgent: CLIENT_UA,
      parse: (b) => parsePpomppuHtml(b, "ppomppu_global"),
    },
  },
  {
    id: "ruliweb",
    url: "https://bbs.ruliweb.com/market/board/1020/rss",
    userAgent: BROWSER_UA,
    parse: parseRuliwebRss,
  },
  {
    id: "clien",
    url: "https://www.clien.net/service/board/jirum?od=T31&category=0&po=0",
    userAgent: BROWSER_UA,
    parse: parseClienHtml,
  },
  {
    id: "arca",
    url: "https://arca.live/b/hotdeal",
    userAgent: BROWSER_UA,
    parse: parseArcaHtml,
  },
];

export interface CrawlResult {
  source: SourceId;
  posts: RawPost[];
  /** Which endpoint the posts came from. */
  via?: "preferred" | "fallback";
  error?: string;
}

async function fetchPreferred(s: SourceDef, now: number): Promise<RawPost[] | null> {
  if (!s.preferred || (preferredBlockedUntil.get(s.id) ?? 0) > now) return null;
  try {
    const posts = s.preferred.parse(await fetchText(s.preferred.url, s.preferred.userAgent));
    if (posts.length > 0) return posts;
    // An empty parse usually means the markup changed; use the fallback meanwhile.
  } catch (e) {
    // Refused (403), timed out or unreachable: fall back, and retry later.
    if (!(e instanceof HttpError)) console.warn(`${s.id}: preferred endpoint failed:`, String(e));
  }
  preferredBlockedUntil.set(s.id, now + PREFERRED_RETRY_MS);
  return null;
}

/** Fetches every source in parallel. One failing source never stops the others. */
export async function crawlAll(sources: SourceDef[] = SOURCES, now = Date.now()): Promise<CrawlResult[]> {
  return Promise.all(
    sources.map(async (s): Promise<CrawlResult> => {
      try {
        const preferred = await fetchPreferred(s, now);
        if (preferred) return { source: s.id, posts: preferred, via: "preferred" };
        const body = await fetchText(s.url, s.userAgent);
        return { source: s.id, posts: s.parse(body), via: s.preferred ? "fallback" : undefined };
      } catch (e) {
        return { source: s.id, posts: [], error: String(e) };
      }
    }),
  );
}
