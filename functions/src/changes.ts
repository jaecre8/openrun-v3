/**
 * Decides which fields of an already stored deal are worth a Firestore write.
 * The free Spark quota is 20k writes/day; rewriting every changed view count
 * every 2 minutes would cost ~80k.
 */

export interface DealState {
  upvotes: number;
  comments: number;
  views: number;
  isEnded: boolean;
  thumbnail: string | null;
  /** Already announced as a hot deal (hotAt set). */
  hot?: boolean;
}

/** Refresh a signed thumbnail URL only when the stored one is about to expire. */
const THUMB_REFRESH_MS = 15 * 60 * 1000;

export function thumbnailExpiresAt(url: string | null | undefined): number | null {
  const m = url?.match(/[?&]expires=(\d+)/);
  return m ? Number(m[1]) * 1000 : null;
}

export function dealChanges(prev: DealState, next: DealState, now: Date): Partial<DealState> | null {
  const c: Partial<DealState> = {};
  if (next.upvotes !== prev.upvotes) c.upvotes = next.upvotes;
  if (next.comments !== prev.comments) c.comments = next.comments;
  if (next.isEnded !== prev.isEnded) c.isEnded = next.isEnded;

  if (next.thumbnail && next.thumbnail !== prev.thumbnail) {
    const exp = thumbnailExpiresAt(prev.thumbnail);
    // Arca signs every list response with a fresh URL; keep the stored one while it is valid.
    if (!prev.thumbnail || exp === null || exp - now.getTime() < THUMB_REFRESH_MS) c.thumbnail = next.thumbnail;
  }

  // Views only feed the popularity sort: write them along with another change, or on a big jump.
  const bigJump = next.views >= Math.max(prev.views * 1.5, prev.views + 100);
  if (next.views !== prev.views && (Object.keys(c).length > 0 || bigJump)) c.views = next.views;

  return Object.keys(c).length > 0 ? c : null;
}

export function stateOf(d: DealState & { hotAt?: unknown }): DealState {
  return {
    upvotes: d.upvotes, comments: d.comments, views: d.views, isEnded: d.isEnded, thumbnail: d.thumbnail,
    hot: d.hot ?? (d.hotAt !== undefined && d.hotAt !== null),
  };
}
