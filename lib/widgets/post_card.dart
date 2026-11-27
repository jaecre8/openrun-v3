import 'package:flutter/material.dart';
import '../models/post_item.dart';
import '../screens/web_view_screen.dart';

class PostCard extends StatelessWidget {
  final PostItem item;
  const PostCard({super.key, required this.item});

  // 강조할 키워드 리스트
  static const List<String> highlightKeywords = ['역대급', '품절', '알리', '무료', '종료', '대란'];
  static const mainColor = Color(0xFFF90069);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebViewScreen(url: item.link))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.thumbnailUrl.isNotEmpty
                    ? Image.network(item.thumbnailUrl, width: 80, height: 80, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildNoImage())
                    : _buildNoImage(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 특정 단어 강조 로직 적용 ---
                    _buildHighlightedTitle(item.title),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(item.date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        const Text('자세히 보기', style: TextStyle(fontSize: 11, color: mainColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 제목 안의 키워드를 찾아 다른 색상을 입히는 함수
  Widget _buildHighlightedTitle(String title) {
    List<TextSpan> spans = [];

    // 정규식을 이용해 키워드들을 한꺼번에 찾습니다.
    String pattern = highlightKeywords.join('|');
    RegExp regExp = RegExp(pattern, caseSensitive: false);

    int start = 0;
    regExp.allMatches(title).forEach((match) {
      // 키워드 이전 텍스트 추가
      if (match.start > start) {
        spans.add(TextSpan(text: title.substring(start, match.start)));
      }
      // 키워드 텍스트 추가 (강조 색상)
      spans.add(TextSpan(
        text: title.substring(match.start, match.end),
        style: const TextStyle(color: mainColor, fontWeight: FontWeight.bold),
      ));
      start = match.end;
    });

    // 남은 텍스트 추가
    if (start < title.length) {
      spans.add(TextSpan(text: title.substring(start)));
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Color(0xFF222222), height: 1.4, fontWeight: FontWeight.w500),
        children: spans,
      ),
    );
  }

  Widget _buildNoImage() => Container(width: 80, height: 80, color: const Color(0xFFF5F5F7), child: const Icon(Icons.image_not_supported, color: Colors.grey));
}