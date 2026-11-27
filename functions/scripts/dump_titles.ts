// Dev helper: prints every crawled post as TSV (source, category, shop, price, shipping, title).
import { crawlAll } from "../src/sources/index";
const r = await crawlAll();
for (const x of r) for (const p of x.posts) console.log(`${p.source}\t${p.sourceCategory ?? ""}\t${p.shopHint ?? ""}\t${p.priceText ?? ""}\t${p.shippingText ?? ""}\t${p.title}`);
