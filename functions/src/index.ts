import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { runCrawl, sendTestPush } from "./pipeline";

initializeApp();

const REGION = "asia-northeast3"; // Seoul

/** Collects hot deals from every board, stores them, and pushes keyword alerts. */
export const crawlDeals = onSchedule(
  {
    schedule: "every 2 minutes",
    timeZone: "Asia/Seoul",
    region: REGION,
    timeoutSeconds: 100,
    memory: "512MiB",
    maxInstances: 1,
    retryCount: 0,
  },
  async () => {
    const stats = await runCrawl(getFirestore(), getMessaging());
    logger.info("crawlDeals", stats);
  },
);

export const testPush = onCall({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const sent = await sendTestPush(getFirestore(), getMessaging(), req.auth.uid);
  return { sent };
});
