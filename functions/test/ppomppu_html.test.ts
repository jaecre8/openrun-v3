import { assertEquals } from "jsr:@std/assert@1";
import { parsePpomppuHtml } from "../src/sources/ppomppu";

// Minimal markup shaped like the v2 app's selectors. The real page could not be fetched
// (403) when this was written, so verify against it once Ppomppu allows our UA.
const html = `<table>
<tr class="baseList">
  <td class="baseList-thumb"><img src="//cdn2.ppomppu.co.kr/zboard/data3/2026/1127/m_1.jpg"></td>
  <td><a class="baseList-title" href="view.php?id=ppomppu&page=1&no=752252">[옥션] 연육80% 부산 봉어묵 2kg (11,900원/무료) <span class="baseList-c">3</span></a></td>
  <td class="baseList-time">12:35:50</td>
  <td class="baseList-rec">4 - 0</td>
  <td class="baseList-views">679</td>
</tr>
<tr class="baseList">
  <td><a class="baseList-title end2" href="view.php?id=ppomppu&no=752100">[종료] [G마켓] 끝난 딜 (9,900원)</a></td>
  <td class="baseList-time">26/11/26</td>
</tr>
<tr class="baseList"><td>광고</td></tr>
</table>`;

Deno.test("ppomppu list rows", () => {
  const now = new Date("2026-11-27T05:00:00Z"); // 14:00 KST
  const [a, b, ...rest] = parsePpomppuHtml(html, "ppomppu", now);
  assertEquals(rest.length, 0);
  assertEquals(a.postId, "752252");
  assertEquals(a.title, "[옥션] 연육80% 부산 봉어묵 2kg (11,900원/무료)");
  assertEquals(a.thumbnail, "https://cdn2.ppomppu.co.kr/zboard/data3/2026/1127/m_1.jpg");
  assertEquals([a.upvotes, a.comments, a.views, a.isEnded], [4, 3, 679, false]);
  assertEquals(a.postedAt?.toISOString(), "2026-11-27T03:35:50.000Z");
  assertEquals(a.url, "https://www.ppomppu.co.kr/zboard/view.php?id=ppomppu&no=752252");
  assertEquals([b.isEnded, b.title], [true, "[G마켓] 끝난 딜 (9,900원)"]);
  assertEquals(b.postedAt?.toISOString(), "2026-11-26T03:00:00.000Z");
});

Deno.test("a list time later than now is yesterday", () => {
  const now = new Date("2026-11-27T00:30:00Z"); // 09:30 KST
  const one = `<tr class="baseList"><td><a class="baseList-title" href="view.php?no=1">x</a></td><td class="baseList-time">23:10:00</td></tr>`;
  assertEquals(parsePpomppuHtml(`<table>${one}</table>`, "ppomppu", now)[0].postedAt?.toISOString(), "2026-11-26T14:10:00.000Z");
});
