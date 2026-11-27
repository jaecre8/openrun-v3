import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeywordScreen extends StatefulWidget {
  const KeywordScreen({super.key});
  @override
  State<KeywordScreen> createState() => _KeywordScreenState();
}

class _KeywordScreenState extends State<KeywordScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _keywords = [];

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  // [수정] 키워드 로드 시 데이터가 없으면 "무료"를 기본값으로 저장하고 보여줍니다.
  Future<void> _loadKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedKeywords = prefs.getStringList('my_keywords');

    if (savedKeywords == null) {
      savedKeywords = ["무료"];
      await prefs.setStringList('my_keywords', savedKeywords);
    }

    setState(() {
      _keywords = savedKeywords!;
    });
  }

  Future<void> _saveKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_keywords', _keywords);
  }

  void _addKeyword() {
    String text = _controller.text.trim();
    if (text.isNotEmpty && !_keywords.contains(text)) {
      setState(() {
        _keywords.add(text);
        _controller.clear();
      });
      _saveKeywords();
    }
  }

  void _removeKeyword(int index) {
    setState(() {
      _keywords.removeAt(index);
    });
    _saveKeywords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("알림 키워드 설정"), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "알림받을 단어를 입력하세요 (예: 아이패드)",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addKeyword,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF90069)),
                  child: const Text("추가", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _keywords.isEmpty
                ? const Center(child: Text("등록된 키워드가 없습니다."))
                : ListView.builder(
              itemCount: _keywords.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.label_important, color: Color(0xFFF90069)),
                  title: Text(_keywords[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeKeyword(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}