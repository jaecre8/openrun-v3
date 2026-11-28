// Renders promo.html to frames, then to an MP4 with ffmpeg.
//   node render.mjs [page.html]     → full video (promo.html → out/openrun_shorts.mp4, review.html → out/review_video.mp4)
//   node render.mjs --stills 1.5 9  → only PNG stills at those seconds (out/still_*.png)
import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync } from "node:fs";
import puppeteer from "puppeteer-core";

const FPS = 30;
const dir = new URL(".", import.meta.url).pathname;
const args = process.argv.slice(2);
const pageArg = args[0]?.endsWith(".html") ? args.shift() : "promo.html";
const outName = pageArg === "promo.html" ? "openrun_shorts.mp4" : "review_video.mp4";
const stills = args[0] === "--stills" ? args.slice(1).map(Number) : null;

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  args: ["--allow-file-access-from-files", "--font-render-hinting=none"],
});
const page = await browser.newPage();
await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 1 });
await page.goto(`file://${dir}${pageArg}`, { waitUntil: "networkidle0" });
await page.evaluate(() => document.fonts.ready);
const duration = await page.evaluate(() => window.DURATION);

mkdirSync(`${dir}out`, { recursive: true });
if (stills) {
  for (const t of stills) {
    await page.evaluate((t) => window.render(t), t);
    await page.screenshot({ path: `${dir}out/still_${t}.png` });
  }
} else {
  rmSync(`${dir}frames`, { recursive: true, force: true });
  mkdirSync(`${dir}frames`);
  const total = Math.round(duration * FPS);
  for (let i = 0; i < total; i++) {
    await page.evaluate((t) => window.render(t), i / FPS);
    await page.screenshot({ path: `${dir}frames/${String(i).padStart(4, "0")}.jpg`, type: "jpeg", quality: 92 });
    if (i % 150 === 0) console.log(`frame ${i}/${total}`);
  }
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-framerate", String(FPS), "-i", `${dir}frames/%04d.jpg`,
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow", "-movflags", "+faststart",
    `${dir}out/${outName}`]);
  rmSync(`${dir}frames`, { recursive: true, force: true });
  console.log(`wrote out/${outName}`);
}
await browser.close();
