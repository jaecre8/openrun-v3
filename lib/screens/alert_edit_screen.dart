import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../models/alert_rule.dart';
import '../models/deal.dart';
import '../theme.dart';

const kCommonShops = ['쿠팡', '네이버', 'G마켓', '11번가', '옥션', 'SSG', '롯데온', '토스쇼핑', '알리익스프레스', '아마존', '무신사'];

/// 스마트 키워드 알림 편집: keyword + max price + exclude words + shops + categories.
class AlertEditScreen extends StatefulWidget {
  final AlertRule? rule;
  const AlertEditScreen({super.key, this.rule});

  @override
  State<AlertEditScreen> createState() => _AlertEditScreenState();
}

class _AlertEditScreenState extends State<AlertEditScreen> {
  late final _keyword = TextEditingController(text: widget.rule?.keyword ?? '');
  late final _maxPrice = TextEditingController(text: widget.rule?.maxPrice?.toString() ?? '');
  final _exclude = TextEditingController();
  late final List<String> _excludeWords = [...?widget.rule?.excludeWords];
  late final Set<String> _shops = {...?widget.rule?.shops};
  late final Set<DealCategory> _categories = {...?widget.rule?.categories};
  bool _saving = false;

  bool get _isNew => widget.rule?.id == null;

  @override
  void dispose() {
    _keyword.dispose();
    _maxPrice.dispose();
    _exclude.dispose();
    super.dispose();
  }

  void _addExclude() {
    final w = _exclude.text.trim();
    if (w.isEmpty || _excludeWords.contains(w) || _excludeWords.length >= 10) return;
    setState(() {
      _excludeWords.add(w);
      _exclude.clear();
    });
  }

  Future<void> _save() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림받을 키워드를 입력해 주세요.')));
      return;
    }
    _addExclude();
    setState(() => _saving = true);
    try {
      await AppServices.instance.user.saveAlert(AlertRule(
        id: widget.rule?.id,
        keyword: keyword,
        maxPrice: int.tryParse(_maxPrice.text.replaceAll(',', '')),
        excludeWords: _excludeWords,
        shops: _shops.toList(),
        categories: DealCategory.values.where(_categories.contains).toList(),
        enabled: widget.rule?.enabled ?? true,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 잠시 후 다시 시도해 주세요.')));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알림 조건 삭제'),
        content: Text("'${widget.rule!.keyword}' 알림을 삭제할까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await AppServices.instance.user.deleteAlert(widget.rule!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isNew ? '알림 조건 추가' : '알림 조건 수정'),
        actions: [
          if (!_isNew) IconButton(tooltip: '삭제', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const _Label('키워드', help: '띄어쓴 단어가 모두 들어간 글만 알려드려요.'),
          TextField(
            controller: _keyword,
            maxLength: 40,
            autofocus: _isNew,
            decoration: const InputDecoration(hintText: '예: 에어팟 프로', border: OutlineInputBorder()),
          ),
          const _Label('최대 가격', help: '가격을 알 수 없는 글과 해외 가격 글은 함께 알려드려요.'),
          TextField(
            controller: _maxPrice,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: const InputDecoration(hintText: '제한 없음', suffixText: '원 이하', border: OutlineInputBorder()),
          ),
          const _Label('제외할 단어', help: '이 단어가 들어간 글은 알리지 않아요.'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _exclude,
                  onSubmitted: (_) => _addExclude(),
                  decoration: const InputDecoration(hintText: '예: 리퍼, 중고', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _addExclude, child: const Text('추가')),
            ],
          ),
          if (_excludeWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in _excludeWords)
                    InputChip(label: Text(w), onDeleted: () => setState(() => _excludeWords.remove(w))),
                ],
              ),
            ),
          const _Label('쇼핑몰', help: '선택하지 않으면 모든 쇼핑몰'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in kCommonShops)
                FilterChip(
                  label: Text(s),
                  selected: _shops.contains(s),
                  onSelected: (on) => setState(() => on ? _shops.add(s) : _shops.remove(s)),
                ),
            ],
          ),
          const _Label('카테고리', help: '선택하지 않으면 모든 카테고리'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in DealCategory.values)
                FilterChip(
                  label: Text(c.label),
                  selected: _categories.contains(c),
                  onSelected: (on) => setState(() => on ? _categories.add(c) : _categories.remove(c)),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.main,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중…' : '저장', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? help;
  const _Label(this.text, {this.help});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (help != null) ...[
              const SizedBox(height: 2),
              Text(help!, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
            ],
          ],
        ),
      );
}
