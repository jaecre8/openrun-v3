import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../models/post_item.dart';

class ClienService {
  static Future<List<PostItem>> fetchClien({int page = 0}) async {
    final response = await http.get(
      Uri.parse('https://www.clien.net/service/board/jirum?&od=T31&category=0&po=$page'),
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
      },
    );

    if (response.statusCode == 200) {
      var document = parse(response.body);
      // 공지사항을 제외한 일반 게시글 리스트 선택
      var rows = document.querySelectorAll('.list_item.jirum');
      List<PostItem> items = [];

      for (var row in rows) {
        if (row.classes.contains('notice')) continue;

        // 1. 제목 및 상세 링크 추출
        var titleElem = row.querySelector('.list_subject a');

        // 2. 썸네일 이미지 추출 (수정: .list_thumbnail 내부의 img를 직접 찾습니다)
        var thumbElem = row.querySelector('.list_thumbnail img');

        // 3. 날짜 추출
        var dateElem = row.querySelector('.list_time .time');

        if (titleElem != null) {
          String title = titleElem.text.trim();
          String href = titleElem.attributes['href'] ?? '';
          String link = 'https://www.clien.net$href';

          // 4. 이미지 주소 처리 (중요: ? 뒤의 인자를 삭제하지 않고 그대로 사용합니다)
          String thumb = thumbElem?.attributes['src'] ?? '';
          if (thumb.startsWith('//')) {
            thumb = 'https:$thumb';
          }

          String date = dateElem?.text.trim() ?? '';

          items.add(PostItem(
            title: title,
            thumbnailUrl: thumb,
            link: link,
            date: date,
          ));
        }
      }
      return items;
    } else {
      throw Exception('Clien 로드 실패');
    }
  }
}