// Dev helper: crawls every source and prints normalized deals as a table.
import { crawlAll } from "../src/sources/index";
import { normalize } from "../src/normalize";
const r = await crawlAll();
for (const x of r) for (const p of x.posts) {
  const d = normalize(p);
  console.log([d.source, d.category, d.shop ?? "-", d.price === null ? "-" : `${d.price}${d.currency}`, d.shippingFee ?? "-", d.isEnded ? "END" : "", d.productName].join("\t"));
}
