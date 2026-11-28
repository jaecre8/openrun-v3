import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/deal.dart';
import '../theme.dart';
import '../widgets/deal_card.dart';

/// 최저가 탭: deals cheaper than the product's earlier deals on OpenRun.
class BargainsScreen extends StatefulWidget {
  const BargainsScreen({super.key});

  @override
  State<BargainsScreen> createState() => _BargainsScreenState();
}

class _BargainsScreenState extends State<BargainsScreen> {
  final _repo = AppServices.instance.deals;
  final _scroll = ScrollController();
  final List<Deal> _deals = [];
  Object? _cursor;
  bool _hasMore = true, _loading = false, _lowestOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _deals.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await _repo.fetchBargains(cursor: _cursor);
      _deals.addAll(page.deals);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (e) {
      _error = '최저가 딜을 불러오지 못했어요.';
      debugPrint('Bargains load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = DealGroup.fromDeals(
        _deals.where((d) => !_lowestOnly || d.insightKind == 'lowest'));
    return Scaffold(
      appBar: AppBar(title: const Text('최저가')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: !_lowestOnly,
                onSelected: (_) => setState(() => _lowestOnly = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('역대 최저가만'),
                selected: _lowestOnly,
                onSelected: (_) => setState(() => _lowestOnly = true),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.main,
              onRefresh: _reload,
              child: groups.isEmpty && !_loading
                  ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.trending_down, size: 44, color: AppColors.sub),
                      const SizedBox(height: 12),
                      Text(
                        _error ??
                            '같은 상품의 딜이 두 번 이상 모이면\n지난 가격과 비교해 최저가를 알려드려요.\n데이터가 쌓일수록 더 많이 보여요.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.sub, height: 1.6),
                      ),
                    ])
                  : ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: groups.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => i == groups.length
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : DealCard(group: groups[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
