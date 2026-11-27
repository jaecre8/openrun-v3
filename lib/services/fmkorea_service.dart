import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../models/post_item.dart';

class FmKoreaService {
  static Future<List<PostItem>> fetchFmKorea({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.fmkorea.com/index.php?mid=hotdeal&page=$page'),
        headers: {
          // 모바일 기기로 오해하도록 User-Agent와 Referer를 더 정교하게 설정
          "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
          "Referer": "https://www.fmkorea.com/",
          "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃 추가

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var rows = document.querySelectorAll('.fm_best_widget > ul > li');

        if (rows.isEmpty) return []; // 데이터가 없으면 빈 리스트 반환

        return rows.map((row) {
          var titleElem = row.querySelector('.title .ellipsis-target');
          var linkElem = row.querySelector('.title a');
          var thumbElem = row.querySelector('img.thumb');
          var dateElem = row.querySelector('.regdate');

          String thumb = thumbElem?.attributes['data-original'] ?? thumbElem?.attributes['src'] ?? '';
          if (thumb.startsWith('//')) thumb = 'https:$thumb';

          String href = linkElem?.attributes['href'] ?? '';

          return PostItem(
            title: titleElem?.text.trim() ?? '제목 없음',
            thumbnailUrl: thumb,
            link: href.startsWith('http') ? href : 'https://www.fmkorea.com$href',
            date: dateElem?.text.trim() ?? '',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print("펨코 에러 발생: $e");
      return []; // 에러 시 빈 리스트 반환하여 UI에서 처리
    }
  }
}