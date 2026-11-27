// Writes a live snapshot of normalized deals to the app's debug fixture
// (assets/fixtures/deals.json), so the app UI can run without Firebase.
// Usage: npm run fixture   (or: deno run -A --sloppy-imports scripts/make_fixture.ts)
import { assignGroup, shopPriceKey } from "../src/group";
import { normalize } from "../src/normalize";
import { crawlAll } from "../src/sources/index";
import { Deal } from "../src/types";

const results = await crawlAll();
for (const r of results) console.error(`${r.source}: ${r.error ?? r.posts.length}`);
const byId = new Map(results.flatMap((r) => r.posts).map((p) => normalize(p)).map((d) => [d.id, d]));
const deals = [...byId.values()].sort((a, b) => a.postedAt.getTime() - b.postedAt.getTime());

const done: Deal[] = [];
for (const d of deals) {
  const key = shopPriceKey(d);
  if (key) d.groupKey = assignGroup(d, done.filter((c) => shopPriceKey(c) === key));
  done.push(d);
}

const out = done.reverse().map((d) => ({ ...d, postedAt: d.postedAt.toISOString() }));
const path = new URL("../../assets/fixtures/deals.json", import.meta.url);
await Deno.mkdir(new URL(".", path), { recursive: true });
await Deno.writeTextFile(path, JSON.stringify(out, null, 1));
console.error(`wrote ${out.length} deals, ${new Set(out.map((d) => d.groupKey)).size} groups → ${path.pathname}`);
