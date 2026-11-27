import * as cheerio from "cheerio";
import { RawPost } from "../types";
import { cleanText, validDate } from "./util";

/** Ruliweb user hot-deal board RSS. No counters are exposed in the feed. */
export function parseRuliwebRss(xml: string): RawPost[] {
  const $ = cheerio.load(xml, { xmlMode: true });
  const posts: RawPost[] = [];
  $("item").each((_, el) => {
    const item = $(el);
    const link = cleanText(item.find("link").text());
    const postId = link.match(/\/read\/(\d+)/)?.[1];
    const title = cleanText(item.find("title").text());
    if (!postId || !title) return;

    const desc = item.find("description").text();
    const thumb = desc.match(/<img[^>]+src="([^"]+)"/)?.[1] ?? null;
    const pub = item.find("pubDate").text();

    posts.push({
      source: "ruliweb",
      postId,
      url: link,
      title,
      thumbnail: thumb,
      postedAt: pub ? validDate(new Date(pub)) : null,
      upvotes: null,
      comments: null,
      views: null,
      isEnded: /^\[?종료\]?/.test(title),
      sourceCategory: cleanText(item.find("category").text()) || null,
    });
  });
  return posts;
}
