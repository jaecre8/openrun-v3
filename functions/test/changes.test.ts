import { assertEquals } from "jsr:@std/assert@1";
import { dealChanges, DealState } from "../src/changes";

const now = new Date("2026-11-27T10:00:00Z");
const base: DealState = { upvotes: 2, comments: 3, views: 400, isEnded: false, thumbnail: "https://x/a.jpg" };
const signed = (expiresAt: Date) => `https://ac.arca.live/a.jpg?expires=${Math.floor(expiresAt.getTime() / 1000)}&key=k`;

Deno.test("small view changes alone are not written", () => {
  assertEquals(dealChanges(base, { ...base, views: 450 }, now), null);
});

Deno.test("views ride along with another change, or on a big jump", () => {
  assertEquals(dealChanges(base, { ...base, views: 450, comments: 4 }, now), { comments: 4, views: 450 });
  assertEquals(dealChanges(base, { ...base, views: 700 }, now), { views: 700 });
  assertEquals(dealChanges({ ...base, views: 0 }, { ...base, views: 120 }, now), { views: 120 });
});

Deno.test("status and counters are written", () => {
  assertEquals(dealChanges(base, { ...base, isEnded: true }, now), { isEnded: true });
  assertEquals(dealChanges(base, { ...base, upvotes: 3 }, now), { upvotes: 3 });
  assertEquals(dealChanges(base, base, now), null);
});

Deno.test("signed thumbnails refresh only near expiry", () => {
  const fresh = { ...base, thumbnail: signed(new Date(now.getTime() + 60 * 60_000)) };
  const newer = signed(new Date(now.getTime() + 70 * 60_000));
  assertEquals(dealChanges(fresh, { ...fresh, thumbnail: newer }, now), null);
  const expiring = { ...base, thumbnail: signed(new Date(now.getTime() + 5 * 60_000)) };
  assertEquals(dealChanges(expiring, { ...expiring, thumbnail: newer }, now), { thumbnail: newer });
  assertEquals(dealChanges({ ...base, thumbnail: null }, { ...base, thumbnail: newer }, now), { thumbnail: newer });
});
