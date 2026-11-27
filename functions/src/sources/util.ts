export const BROWSER_UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";

export class HttpError extends Error {
  constructor(readonly url: string, readonly status: number) {
    super(`${url} → HTTP ${status}`);
  }
}

/** Fetches a page and decodes it with the charset it declares (header or <meta>), e.g. EUC-KR. */
export async function fetchText(url: string, userAgent: string, timeoutMs = 10_000): Promise<string> {
  const res = await fetch(url, {
    headers: { "User-Agent": userAgent, Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new HttpError(url, res.status);
  const bytes = new Uint8Array(await res.arrayBuffer());
  const head = new TextDecoder("latin1").decode(bytes.subarray(0, 2048));
  const charset =
    res.headers.get("content-type")?.match(/charset=([\w-]+)/i)?.[1] ??
    head.match(/<meta[^>]+charset=["']?([\w-]+)/i)?.[1] ??
    head.match(/<\?xml[^>]+encoding=["']([\w-]+)/i)?.[1] ??
    "utf-8";
  try {
    return new TextDecoder(charset.toLowerCase()).decode(bytes);
  } catch {
    return new TextDecoder("utf-8").decode(bytes);
  }
}

/** "3,973" → 3973, "17.0 k" → 17000, "1.2만" → 12000. */
export function parseCount(text: string | undefined | null): number | null {
  if (!text) return null;
  const t = text.replace(/,/g, "").trim().toLowerCase();
  const m = t.match(/(\d+(?:\.\d+)?)\s*(k|만|천)?/);
  if (!m) return null;
  const n = parseFloat(m[1]);
  const mult = m[2] === "k" || m[2] === "천" ? 1000 : m[2] === "만" ? 10000 : 1;
  return Math.round(n * mult);
}

export function absUrl(src: string | undefined | null, base: string): string | null {
  if (!src) return null;
  const s = src.trim();
  if (!s) return null;
  if (s.startsWith("//")) return `https:${s}`;
  if (s.startsWith("http")) return s.replace(/^http:\/\//, "https://");
  return new URL(s, base).toString();
}

export function cleanText(s: string | undefined | null): string {
  return (s ?? "").replace(/\s+/g, " ").trim();
}

export function validDate(d: Date): Date | null {
  return isNaN(d.getTime()) ? null : d;
}
