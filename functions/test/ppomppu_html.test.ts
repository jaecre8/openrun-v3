import { assertEquals } from "jsr:@std/assert@1";
import { parsePpomppuHtml, parsePpomppuRss, ppomppuThumbnail } from "../src/sources/ppomppu";

// Rows trimmed from the real list page (zboard.php?id=ppomppu, 2026-11-28).
const html = `<table id="revolution_main_table"><tbody>
<tr align="center" id="page_show_noti_1" class="baseNotice">
  <td class="baseList-space baseList-numb" colspan="2"><span id="notice_con">공지</span></td>
  <td class="baseList-space" align="left"><a class="baseList-title" href="view.php?id=regulation&amp;page=1&amp;divpage=202&amp;no=6">전체 게시판 이용 규칙</a></td>
</tr>
<tr align="center" class="baseList bbs_new1  hotpop_bg_color">
<td class="baseList-space baseList-numb" colspan="2">752388</td>
<td align="left" class="baseList-space title">
<a class="baseList-thumb" href="view.php?id=ppomppu&amp;page=1&amp;divpage=119&amp;&amp;no=752388"><img src="//cdn4.ppomppu.co.kr/zboard/data/_thumb/ppomppu/8/small_752388.jpg?t=1795778927" onerror="this.src='//cdn3.ppomppu.co.kr/st/www/img/noimage/noimage_60x50.jpg'"></a><div class="baseList-box"><div class="baseList-cover"><img src="//cdn3.ppomppu.co.kr/images/menu/pop_icon2.jpg" class="icons_vertical"> <a class="baseList-title  " href="view.php?id=ppomppu&amp;page=1&amp;divpage=119&amp;no=752388"><span><em class="baseList-head subject_preface">[롯데온]</em>[정상가: 219,000] 나이키 보메로 플러스 HV8150-111, 109천원</span></a> <span class="baseList-c">5</span></div><small class="baseList-small">[의류/잡화]</small></div></td>
<td class="baseList-space" colspan="2" align="left"><span class="baseList-name">브로우마이드</span></td>
<td class="baseList-space" colspan="2" title="26.11.27 20:28:47"><time class="baseList-time">26/11/27</time></td>
<td class="baseList-space baseList-rec" colspan="2"></td>
<td class="baseList-space baseList-views" colspan="2">7759</td>
</tr>
<tr align="center" class="baseList bbs_new1 ">
<td class="baseList-space baseList-numb" colspan="2">752414</td>
<td align="left" class="baseList-space title">
<a class="baseList-thumb" href="view.php?id=ppomppu&amp;page=1&amp;divpage=119&amp;&amp;no=752414"><img src="//cdn4.ppomppu.co.kr/zboard/data/_thumb/ppomppu/4/small_752414.jpg?t=1795792107"></a><div class="baseList-box"><div class="baseList-cover"><a class="baseList-title  " href="view.php?id=ppomppu&amp;page=1&amp;divpage=119&amp;no=752414"><span><em class="baseList-head subject_preface">[무신사]</em>비오템 아쿠아파워 올인원 200ml 듀오 세트 (카카오65,330원/무료)</span></a> <span class="baseList-c">1</span></div><small class="baseList-small">[기타]</small></div></td>
<td class="baseList-space" colspan="2" title="26.11.28 00:08:27"><time class="baseList-time">00:08:27</time></td>
<td class="baseList-space baseList-rec" colspan="2">1 - 0</td>
<td class="baseList-space baseList-views" colspan="2">334</td>
</tr>
<tr align="center" class="baseList bbs_new1">
<td class="baseList-space baseList-numb" colspan="2"><img src="/images/shopping_ppom.png?v=2" alt="쇼핑뽐뿌 아이콘"></td>
<td align="left" class="baseList-space title">
<a class="baseList-thumb" href="/zboard/view.php?id=pmarket&amp;&amp;no=304606"><img src="//cdn4.ppomppu.co.kr/zboard/data/_thumb/pmarket/6/small_304606.jpg"></a>
<div class="baseList-box"><div class="baseList-cover"><a class="baseList-title" href="/zboard/view.php?id=pmarket&amp;&amp;no=304606"><span>[G마켓 블프] 광고 글</span></a></div></div></td>
<td class="baseList-space" colspan="2"><time class="baseList-time">26/11/27</time></td>
<td class="baseList-space baseList-rec" colspan="2">45 - 0</td>
<td class="baseList-space baseList-views" colspan="2">1654</td></tr>
<tr align="center" class="baseList bbs_new1">
<td class="baseList-space baseList-numb" colspan="2"><img src="x.png" alt="쇼핑포럼 아이콘"></td>
<td align="left" class="baseList-space title">
<a class="baseList-thumb" href="/zboard/view.php?id=social&amp;no=51113"><img src="//cdn3.ppomppu.co.kr/st/www/img/noimage/noimage_60x50.jpg"></a>
<div class="baseList-box"><div class="baseList-cover"><a class="baseList-title" href="/zboard/view.php?id=social&amp;no=51113"><span>쇼핑포럼 글</span></a></div></div></td>
</tr>
</tbody></table>`;

Deno.test("real list page rows", () => {
  const posts = parsePpomppuHtml(html, "ppomppu", new Date("2026-11-27T15:30:00Z"));
  assertEquals(posts.map((p) => p.postId), ["752388", "752414"]); // notice, 쇼핑뽐뿌 and 쇼핑포럼 rows skipped
  const [a, b] = posts;
  assertEquals(a.title, "[롯데온] [정상가: 219,000] 나이키 보메로 플러스 HV8150-111, 109천원");
  assertEquals(a.thumbnail, "https://cdn4.ppomppu.co.kr/zboard/data/_thumb/ppomppu/8/small_752388.jpg");
  assertEquals(a.postedAt?.toISOString(), "2026-11-27T11:28:47.000Z");
  assertEquals([a.upvotes, a.comments, a.views, a.isEnded, a.sourceCategory], [0, 5, 7759, false, "의류/잡화"]);
  assertEquals(a.url, "https://www.ppomppu.co.kr/zboard/view.php?id=ppomppu&no=752388");
  assertEquals(b.title, "[무신사] 비오템 아쿠아파워 올인원 200ml 듀오 세트 (카카오65,330원/무료)");
  assertEquals([b.upvotes, b.comments, b.views, b.sourceCategory], [1, 1, 334, "기타"]);
  assertEquals(b.postedAt?.toISOString(), "2026-11-27T15:08:27.000Z");
});

Deno.test("thumbnail path from the post number", () => {
  assertEquals(ppomppuThumbnail("ppomppu", "752418"), "https://cdn4.ppomppu.co.kr/zboard/data/_thumb/ppomppu/8/small_752418.jpg");
  assertEquals(ppomppuThumbnail("ppomppu_global", "126977"), "https://cdn4.ppomppu.co.kr/zboard/data/_thumb/ppomppu4/7/small_126977.jpg");
  const rss = `<rss><channel><item><title>[옥션] 봉어묵 (11,900원)</title><link>http://www.ppomppu.co.kr/zboard/view.php?id=ppomppu&amp;no=752252</link><pubDate>Fri, 27 Nov 2026 03:35:50 GMT</pubDate><hits> [3|679|0|0]</hits></item></channel></rss>`;
  assertEquals(parsePpomppuRss(rss, "ppomppu")[0].thumbnail, "https://cdn4.ppomppu.co.kr/zboard/data/_thumb/ppomppu/2/small_752252.jpg");
});
