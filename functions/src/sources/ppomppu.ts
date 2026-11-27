import * as cheerio from "cheerio";
import { RawPost, SourceId } from "../types";
import { absUrl, cleanText, parseCount, validDate } from "./util";

const BASE = "https://www.ppomppu.co.kr/zboard/";

const boardId = (source: SourceId) => (source === "ppomppu_global" ? "ppomppu4" : "ppomppu");

/**
 * List thumbnails live at a path derived from the post number, so RSS posts get
 * them too: /_thumb/{board}/{last digit}/small_{no}.jpg. A post without an image
 * returns 404 there, and the app falls back to its shop tile.
 */
export function ppomppuThumbnail(source: SourceId, postId: string): string {
  return `https://cdn4.ppomppu.co.kr/zboard/data/_thumb/${boardId(source)}/${postId.slice(-1)}/small_${postId}.jpg`;
}

/** The date cell's title, "26.11.28 00:20:43", in KST. */
function parseCellDateTime(text: string): Date | null {
  const m = text.trim().match(/^(\d{2})\.(\d{2})\.(\d{2}) (\d{2}):(\d{2}):(\d{2})$/);
  return m ? validDate(new Date(`20${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}+09:00`)) : null;
}

/** The visible date: "00:20:43" is today in KST, "26/11/27" a past day. */
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
 * Ppomppu board list page (zboard.php, EUC-KR). Adds the board category, the
 * ended state and exact times to what RSS gives. Rows linking to other boards
 * (쇼핑뽐뿌 ads, 쇼핑포럼 bridge) and notices are skipped.
 */
export function parsePpomppuHtml(html: string, source: SourceId, now = new Date()): RawPost[] {
  const $ = cheerio.load(html);
  const board = boardId(source);
  const posts: RawPost[] = [];
  $("tr.baseList").each((_, el) => {
    const row = $(el);
    if (!/^\d+$/.test(cleanText(row.find(".baseList-numb").first().text()))) return;
    const link = row.find("a.baseList-title").first();
    const href = link.attr("href") ?? "";
    if (!new RegExp(`[?&]id=${board}(&|$)`).test(href)) return;
    const postId = href.match(/[?&]no=(\d+)/)?.[1];
    // "<em>[G마켓]</em>제목" → "[G마켓] 제목"
    const head = cleanText(link.find("em.baseList-head").text());
    const body = link.find("span").first().clone();
    body.find("em.baseList-head").remove();
    const rawTitle = cleanText(`${head} ${body.text()}`);
    if (!postId || !rawTitle) return;

    const rec = cleanText(row.find(".baseList-rec").first().text()); // "1 - 0" or empty
    const ended =
      /\bend\d?\b/.test(link.attr("class") ?? "") ||
      /^\[?종료\]?/.test(rawTitle) ||
      row.find("img[alt*='종료'], .end, .end2").length > 0;
    let thumb = absUrl(row.find("a.baseList-thumb img").first().attr("src"), BASE);
    if (thumb && /noimage/i.test(thumb)) thumb = null;
    const timeCell = row.find("time.baseList-time").first();
    const category = cleanText(row.find("small.baseList-small").first().text()).replace(/^\[|\]$/g, "");

    posts.push({
      source,
      postId,
      url: `${BASE}view.php?id=${board}&no=${postId}`,
      title: rawTitle.replace(/^\[?종료\]?\s*/, ""),
      thumbnail: thumb ? thumb.replace(/\?t=\d+$/, "") : ppomppuThumbnail(source, postId),
      postedAt:
        parseCellDateTime(timeCell.parent().attr("title") ?? "") ?? parseListTime(cleanText(timeCell.text()), now),
      upvotes: parseCount(rec.split("-")[0]) ?? 0,
      comments: parseCount(row.find("span.baseList-c").first().text()) ?? 0,
      views: parseCount(row.find(".baseList-views").first().text()),
      isEnded: ended,
      sourceCategory: category || null,
    });
  });
  return posts;
}

/**
 * Ppomppu RSS, used while the list page refuses us.
 * The <hits> element reads "[comments|views|recommend|notRecommend]".
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
      thumbnail: ppomppuThumbnail(source, postId),
      postedAt: pub ? validDate(new Date(pub)) : null,
      comments: hits ? Number(hits[1]) : null,
      views: hits ? Number(hits[2]) : null,
      upvotes: hits ? Number(hits[3]) : null,
      isEnded: /^\[?종료\]?/.test(title),
    });
  });
  return posts;
}
