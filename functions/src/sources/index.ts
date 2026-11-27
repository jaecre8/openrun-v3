import { RawPost, SourceId } from "../types";
import { parseArcaHtml } from "./arca";
import { parseClienHtml } from "./clien";
import { parsePpomppuRss } from "./ppomppu";
import { parseRuliwebRss } from "./ruliweb";
import { BROWSER_UA, fetchText } from "./util";

/** Ppomppu's RSS rejects browser-like and curl user agents but accepts a plain client UA. */
const CLIENT_UA = "OpenRun/3.0 (hot-deal aggregator)";

export interface SourceDef {
  id: SourceId;
  url: string;
  userAgent: string;
  parse: (body: string) => RawPost[];
}

export const SOURCES: SourceDef[] = [
  {
    id: "ppomppu",
    url: "https://www.ppomppu.co.kr/rss.php?id=ppomppu",
    userAgent: CLIENT_UA,
    parse: (b) => parsePpomppuRss(b, "ppomppu"),
  },
  {
    id: "ppomppu_global",
    url: "https://www.ppomppu.co.kr/rss.php?id=ppomppu4",
    userAgent: CLIENT_UA,
    parse: (b) => parsePpomppuRss(b, "ppomppu_global"),
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
  error?: string;
}

/** Fetches every source in parallel. One failing source never stops the others. */
export async function crawlAll(sources: SourceDef[] = SOURCES): Promise<CrawlResult[]> {
  return Promise.all(
    sources.map(async (s) => {
      try {
        const body = await fetchText(s.url, s.userAgent);
        return { source: s.id, posts: s.parse(body) };
      } catch (e) {
        return { source: s.id, posts: [], error: String(e) };
      }
    }),
  );
}
