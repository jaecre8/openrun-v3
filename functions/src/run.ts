/**
 * Standalone crawler for running outside Cloud Functions (GitHub Actions, a VM, any always-on machine).
 *
 *   FIREBASE_SERVICE_ACCOUNT='<service account JSON>' node lib/run.js
 *
 * Env:
 *   FIREBASE_SERVICE_ACCOUNT  service account key JSON (or set GOOGLE_APPLICATION_CREDENTIALS to a key file)
 *   RUN_FOR_MINUTES           keep crawling for this long (default 0 = one run, then exit)
 *   INTERVAL_SECONDS          pause between runs while looping (default 120)
 *   TASK=backfill             instead of crawling, rebuild product price histories from stored deals once
 */
import { applicationDefault, cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { backfillProducts, CrawlCache, runCrawl } from "./pipeline";

const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
initializeApp({ credential: serviceAccount ? cert(JSON.parse(serviceAccount)) : applicationDefault() });

const runForMs = Number(process.env.RUN_FOR_MINUTES ?? 0) * 60_000;
const intervalMs = Number(process.env.INTERVAL_SECONDS ?? 120) * 1000;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const db = getFirestore();
  if (process.env.TASK === "backfill") {
    console.log("backfill", JSON.stringify(await backfillProducts(db)));
    return;
  }
  const messaging = getMessaging();
  const cache = new CrawlCache();
  const started = Date.now();
  let failures = 0;

  for (;;) {
    const cycleStart = Date.now();
    try {
      const stats = await runCrawl(db, messaging, new Date(), cache);
      console.log(new Date().toISOString(), JSON.stringify(stats));
      failures = 0;
    } catch (e) {
      failures++;
      console.error(new Date().toISOString(), "crawl failed:", e);
      if (failures >= 3) throw e;
    }
    const next = cycleStart + intervalMs;
    if (next - started >= runForMs) break;
    await sleep(Math.max(0, next - Date.now()));
  }
}

main().then(
  () => process.exit(0),
  () => process.exit(1),
);
