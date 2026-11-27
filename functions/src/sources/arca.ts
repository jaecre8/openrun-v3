import * as cheerio from "cheerio";
import { RawPost } from "../types";
import { absUrl, cleanText, parseCount, validDate } from "./util";

const BASE = "https://arca.live";

/**
 * Arca.live 핫딜 channel. Each row exposes shop, price and shipping as
 * separate fields, and ended deals carry the "deal-close" class.
 * Thumbnail URLs are signed and expire after about an hour.
 */
export function parseArcaHtml(html: string): RawPost[] {
  const $ = cheerio.load(html);
  const posts: RawPost[] = [];
  $(".vrow.hybrid").each((_, el) => {
    const row = $(el);
    const titleEl = row.find("a.title.hybrid-title").first();
    const href = titleEl.attr("href") ?? "";
    const postId = href.match(/\/b\/hotdeal\/(\d+)/)?.[1];
    const titleClone = titleEl.clone();
    titleClone.find(".info, .media-icon").remove();
    const title = cleanText(titleClone.text());
    if (!postId || !title) return;

    const datetime = row.find("time[datetime]").attr("datetime");

    posts.push({
      source: "arca",
      postId,
      url: `${BASE}/b/hotdeal/${postId}`,
      title,
      thumbnail: absUrl(row.find(".vrow-preview img").attr("src"), BASE),
      postedAt: datetime ? validDate(new Date(datetime)) : null,
      upvotes: parseCount(row.find(".col-rate").text()),
      comments: parseCount(row.find(".comment-count").text()) ?? 0,
      views: parseCount(row.find(".col-view").text()),
      isEnded: row.find(".deal-close").length > 0,
      shopHint: cleanText(row.find(".deal-store").text()) || null,
      priceText: cleanText(row.find(".deal-price").text()) || null,
      shippingText: cleanText(row.find(".deal-delivery").text()) || null,
      sourceCategory: cleanText(row.find(".badges a.badge").first().text()) || null,
    });
  });
  return posts;
}
