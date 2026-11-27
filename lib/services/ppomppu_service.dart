import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:cp949_codec/cp949_codec.dart';
import '../models/post_item.dart';

class PpomppuService {
  static Future<List<PostItem>> fetchBoard({required String boardId, int page = 1}) async {
    final response = await http.get(
      Uri.parse('https://www.ppomppu.co.kr/zboard/zboard.php?id=$boardId&page=$page'),
    );

    if (response.statusCode == 200) {
      String decodedBody = cp949.decode(response.bodyBytes);
      var document = parse(decodedBody);
      var rows = document.querySelectorAll('tr.baseList');

      return rows.map((row) {
        var titleElem = row.querySelector('.baseList-title');
        var thumbElem = row.querySelector('.baseList-thumb img');
        var linkElem = row.querySelector('a.baseList-title');
        var dateElem = row.querySelector('.baseList-time');

        String thumb = thumbElem?.attributes['src'] ?? '';
        if (thumb.startsWith('//')) thumb = 'https:$thumb';
        String href = linkElem?.attributes['href'] ?? '';

        return PostItem(
          title: titleElem?.text.trim() ?? '',
          thumbnailUrl: thumb,
          link: 'https://www.ppomppu.co.kr/zboard/$href',
          date: dateElem?.text.trim() ?? '',
        );
      }).toList();
    }
    return [];
  }
}