import * as cheerio from "cheerio";
import { RawPost } from "../types";
import { absUrl, cleanText, parseCount, validDate } from "./util";

const BASE = "https://www.clien.net";

/** Clien 알뜰구매 list page. Notice rows have no data-role="list-row". */
export function parseClienHtml(html: string): RawPost[] {
  const $ = cheerio.load(html);
  const posts: RawPost[] = [];
  $('.list_item.jirum[data-role="list-row"]').each((_, el) => {
    const row = $(el);
    const postId = row.attr("data-board-sn");
    const title = cleanText(row.find('[data-role="list-title-text"]').text());
    if (!postId || !title) return;

    let thumb = absUrl(row.find(".list_thumbnail img").attr("src"), BASE);
    if (thumb && thumb.includes("noimage")) thumb = null;

    const ts = cleanText(row.find(".list_time .timestamp").text());
    const postedAt = ts ? validDate(new Date(ts.replace(" ", "T") + "+09:00")) : null;

    posts.push({
      source: "clien",
      postId,
      url: `${BASE}/service/board/jirum/${postId}`,
      title,
      thumbnail: thumb,
      postedAt,
      upvotes: parseCount(row.find(".list_symph em").first().text()),
      comments: parseCount(row.attr("data-comment-count")),
      views: parseCount(row.find(".list_hit .hit").text()),
      isEnded: row.hasClass("sold_out"),
      sourceCategory: cleanText(row.find(".keyword a.icon_keyword").first().text()) || null,
    });
  });
  return posts;
}
