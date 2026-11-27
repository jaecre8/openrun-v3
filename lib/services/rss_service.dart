import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/post_item.dart';

class RssService {
  static Future<List<PostItem>> fetchRuliweb() async {
    final response = await http.get(Uri.parse('https://bbs.ruliweb.com/market/board/1020/rss'));

    if (response.statusCode == 200) {
      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');

      return items.map((node) {
        final title = node.findElements('title').single.innerText;
        final link = node.findElements('link').single.innerText;
        final description = node.findElements('description').single.innerText;
        final pubDate = node.findElements('pubDate').single.innerText;

        final imgRegExp = RegExp(r'<img[^>]+src="([^">]+)"');
        final thumb = imgRegExp.firstMatch(description)?.group(1) ?? '';

        return PostItem(
          title: title,
          thumbnailUrl: thumb,
          link: link,
          date: pubDate.length > 16 ? pubDate.substring(5, 16) : pubDate,
        );
      }).toList();
    }
    return [];
  }
}