import * as cheerio from "cheerio";
import { RawPost, SourceId } from "../types";
import { cleanText, validDate } from "./util";

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
