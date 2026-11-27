import * as cheerio from "cheerio";
import { RawPost, SourceId } from "../types";
import { absUrl, cleanText, parseCount, validDate } from "./util";

const BASE = "https://www.ppomppu.co.kr/zboard/";

/** "13:35:50" is today in KST; "26/11/26" is a past date. */
function parseListTime(text: string, now: Date): Date | null {
  const t = text.trim();
  const kstToday = new Date(now.getTime() + 9 * 3600_000).toISOString().slice(0, 10);
  const hms = t.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  if (hms) {
    const d = new Date(`${kstToday}T${hms[1].padStart(2, "0")}:${hms[2]}:${hms[3] ?? "00"}+09:00`);
    // A time later than now belongs to yesterday.
    return validDate(d.getTime() > now.getTime() + 60_000 ? new Date(d.getTime() - 86_400_000) : d);
  }
  const ymd = t.match(/^(\d{2})\/(\d{2})\/(\d{2})$/);
  if (ymd) return validDate(new Date(`20${ymd[1]}-${ymd[2]}-${ymd[3]}T12:00:00+09:00`));
  return null;
}

/**
 * Ppomppu board list page (zboard.php). Gives thumbnails and the ended state,
 * which the RSS feed lacks. Selectors follow the v2 app's parser.
 */
export function parsePpomppuHtml(html: string, source: SourceId, now = new Date()): RawPost[] {
  const $ = cheerio.load(html);
  const posts: RawPost[] = [];
  $("tr.baseList").each((_, el) => {
    const row = $(el);
    const link = row.find("a.baseList-title").first();
    const href = link.attr("href") ?? "";
    const postId = href.match(/[?&]no=(\d+)/)?.[1];
    const titleEl = link.clone();
    titleEl.find("span.baseList-c, .list_comment2").remove();
    const rawTitle = cleanText(titleEl.text());
    if (!postId || !rawTitle) return;

    const rec = cleanText(row.find(".baseList-rec").first().text()); // "3 - 0"
    const titleClass = `${link.attr("class") ?? ""} ${row.attr("class") ?? ""}`;
    const ended = /end|종료/.test(titleClass) || /^\[?종료\]?/.test(rawTitle) || row.find("img[alt*='종료']").length > 0;
    let thumb = absUrl(row.find(".baseList-thumb img").first().attr("src"), BASE);
    if (thumb && /noimage|no_img/i.test(thumb)) thumb = null;

    posts.push({
      source,
      postId,
      url: `${BASE}view.php?id=${source === "ppomppu_global" ? "ppomppu4" : "ppomppu"}&no=${postId}`,
      title: rawTitle.replace(/^\[?종료\]?\s*/, ""),
      thumbnail: thumb,
      postedAt: parseListTime(cleanText(row.find(".baseList-time").first().text()), now),
      upvotes: parseCount(rec.split("-")[0]),
      comments: parseCount(row.find(".baseList-c, .list_comment2").first().text()) ?? 0,
      views: parseCount(row.find(".baseList-views").first().text()),
      isEnded: ended,
    });
  });
  return posts;
}

/**
 * Ppomppu blocks its list pages for non-browser clients but serves RSS.
 * The RSS <hits> element reads "[comments|views|recommend|notRecommend]".
 */
export function parsePpomppuRss(xml: string, source: SourceId): RawPost[] {
  const $ = cheerio.load(xml, { xmlMode: true });
  const posts: RawPost[] = [];
  $("item").each((_, el) => {
    const item = $(el);
    const link = cleanText(item.find("link").text()).replace(/^http:\/\//, "https://");
    const postId = link.match(/[?&]no=(\d+)/)?.[1];
    const title = cleanText(item.find("title").text());
    if (!postId || !title) return;

    const hits = item.find("hits").text().match(/\[(\d+)\|(\d+)\|(\d+)\|(\d+)\]/);
    const pub = item.find("pubDate").text();

    posts.push({
      source,
      postId,
      url: link,
      title: title.replace(/^\[?종료\]?\s*/, ""),
      thumbnail: null,
      postedAt: pub ? validDate(new Date(pub)) : null,
      comments: hits ? Number(hits[1]) : null,
      views: hits ? Number(hits[2]) : null,
      upvotes: hits ? Number(hits[3]) : null,
      isEnded: /^\[?종료\]?/.test(title),
    });
  });
  return posts;
}
