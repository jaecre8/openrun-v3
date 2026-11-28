import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_services.dart';
import '../models/deal.dart';
import '../theme.dart';
import '../widgets/deal_card.dart';
import 'deal_detail_screen.dart';

enum FeedSort { latest, popular }

/// 통합 핫딜 피드: every board in one list, same deal shown once.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _pageSize = 40;
  static const _popularWindow = Duration(hours: 24);
  static const _popularPool = 160;

  final _repo = AppServices.instance.deals;
  final _scroll = ScrollController();

  FeedSort _sort = FeedSort.latest;
  DealCategory? _category;
  Set<String> _hiddenSources = {};
  bool _hideEnded = false;

  final List<Deal> _deals = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _generation = 0; // drops results of loads started before a filter change

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _restoreFilters().then((_) => _reload());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _restoreFilters() async {
    final p = await SharedPreferences.getInstance();
    _hiddenSources = (p.getStringList('feed_hidden_sources') ?? const []).toSet();
    _hideEnded = p.getBool('feed_hide_ended') ?? false;
  }

  Future<void> _saveFilters() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('feed_hidden_sources', _hiddenSources.toList());
    await p.setBool('feed_hide_ended', _hideEnded);
  }

  void _onScroll() {
    if (_sort == FeedSort.latest && _scroll.position.extentAfter < 600) _loadMore();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _deals.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      do {
        final page = await _repo.fetch(category: _category, cursor: _cursor, limit: _pageSize);
        if (gen != _generation || !mounted) return;
        _deals.addAll(page.deals);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        // Popular sort ranks a pool of recent deals; latest keeps loading while filters hide most rows.
      } while (_hasMore &&
          (_sort == FeedSort.popular
              ? _deals.isNotEmpty && _deals.length < _popularPool && _deals.last.postedAt.isAfter(DateTime.now().subtract(_popularWindow))
              : _visibleGroups().length < 12));
      if (_sort == FeedSort.popular) _hasMore = false;
    } catch (e) {
      if (gen == _generation) _error = '핫딜을 불러오지 못했어요.\n네트워크 상태를 확인해 주세요.';
      debugPrint('Feed load failed: $e');
    } finally {
      if (gen == _generation && mounted) setState(() => _loading = false);
    }
  }

  List<DealGroup> _visibleGroups() {
    final deals = _deals.where((d) => !_hiddenSources.contains(d.source) && !(_hideEnded && d.isEnded));
    final groups = DealGroup.fromDeals(deals);
    if (_sort == FeedSort.popular) {
      final now = DateTime.now();
      final recent = groups.where((g) => now.difference(g.postedAt) < _popularWindow).toList();
      final pool = recent.length >= 10 ? recent : groups;
      pool.sort((a, b) => b.hotScore(now).compareTo(a.hotScore(now)));
      return pool;
    }
    return groups;
  }

  void _setCategory(DealCategory? c) {
    if (_category == c) return;
    _category = c;
    _reload();
  }

  void _setSort(FeedSort s) {
    if (_sort == s) return;
    _sort = s;
    _reload();
  }

  Future<void> _openFilters() async {
    final hidden = {..._hiddenSources};
    var hideEnded = _hideEnded;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('보고 싶은 커뮤니티', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in kSourceNames.entries)
                      FilterChip(
                        label: Text(e.value),
                        selected: !hidden.contains(e.key),
                        onSelected: (on) => setSheet(() => on ? hidden.remove(e.key) : hidden.add(e.key)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('종료된 딜 숨기기'),
                  value: hideEnded,
                  onChanged: (v) => setSheet(() => hideEnded = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied != true) return;
    setState(() {
      _hiddenSources = hidden;
      _hideEnded = hideEnded;
    });
    _saveFilters();
    if (_sort == FeedSort.latest && _visibleGroups().length < 12) _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _visibleGroups();
    final filtersOn = _hiddenSources.isNotEmpty || _hideEnded;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/splash/openrun_logo.png',
          height: 22,
          errorBuilder: (_, _, _) =>
              const Text('OPENRUN', style: TextStyle(color: AppColors.main, fontWeight: FontWeight.w900)),
        ),
        actions: [
          IconButton(
            tooltip: '필터',
            onPressed: _openFilters,
            icon: Badge(isLabelVisible: filtersOn, smallSize: 7, child: const Icon(Icons.tune)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _CategoryChip(label: '전체', selected: _category == null, onTap: () => _setCategory(null)),
                      for (final c in DealCategory.values)
                        _CategoryChip(label: c.label, selected: _category == c, onTap: () => _setCategory(c)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                  child: Row(
                    children: [
                      _SortButton(label: '최신순', selected: _sort == FeedSort.latest, onTap: () => _setSort(FeedSort.latest)),
                      _SortButton(label: '인기순', selected: _sort == FeedSort.popular, onTap: () => _setSort(FeedSort.popular)),
                      const Spacer(),
                      if (AppServices.instance.mode == DataMode.fixture)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('샘플 데이터', style: TextStyle(fontSize: 11, color: Colors.orange)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(groups)),
        ],
      ),
    );
  }

  /// 지금 뜨는 딜: same rule as the server's hot push; shown when at least three qualify.
  List<DealGroup> _hotGroups() {
    if (_sort != FeedSort.latest) return const [];
    final now = DateTime.now();
    final hot = DealGroup.fromDeals(_deals.where((d) => !d.isEnded && !_hiddenSources.contains(d.source)))
        .where((g) =>
            now.difference(g.postedAt) < const Duration(hours: 6) &&
            g.upvotes + g.comments >= 8 &&
            g.deals.map((d) => d.hotScore(now)).reduce((a, b) => a > b ? a : b) >= 3.5)
        .toList()
      ..sort((a, b) => b.hotScore(now).compareTo(a.hotScore(now)));
    return hot.length >= 3 ? hot.take(10).toList() : const [];
  }

  Widget _buildList(List<DealGroup> groups) {
    final hot = _hotGroups();
    if (groups.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            Icon(_error != null ? Icons.wifi_off : Icons.inbox_outlined, size: 44, color: AppColors.sub),
            const SizedBox(height: 12),
            Text(_error ?? '조건에 맞는 핫딜이 아직 없어요.',
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.sub, height: 1.5)),
            if (_error != null) Center(child: TextButton(onPressed: _reload, child: const Text('다시 시도'))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.main,
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: groups.length + (_hasMore || _loading ? 1 : 0) + (hot.isEmpty ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (hot.isNotEmpty && index == 0) return HotCarousel(groups: hot);
          final i = hot.isEmpty ? index : index - 1;
          if (i == groups.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return DealCard(group: groups[i]);
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.text,
          ),
          selectedColor: AppColors.main,
          backgroundColor: AppColors.bg,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
        ),
      );
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? AppColors.text : AppColors.sub,
            ),
          ),
        ),
      );
}

/// 지금 뜨는 딜: deals whose upvotes and comments are climbing fast.
class HotCarousel extends StatelessWidget {
  final List<DealGroup> groups;
  const HotCarousel({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Row(children: [
            Icon(Icons.rocket_launch, color: AppColors.main, size: 18),
            SizedBox(width: 6),
            Text('지금 뜨는 딜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(width: 6),
            Text('추천·댓글이 빠르게 느는 중', style: TextStyle(fontSize: 12, color: AppColors.sub)),
          ]),
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final g = groups[i];
              final d = g.insightDeal;
              return SizedBox(
                width: 168,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DealDetailScreen(group: g))),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 104, child: DealThumb(deal: d, thumbnail: g.thumbnail, ended: false, radius: 10)),
                          const SizedBox(height: 8),
                          Text(d.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                          const Spacer(),
                          Row(children: [
                            if (d.priceLabel != null)
                              Flexible(
                                child: Text(d.priceLabel!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.main)),
                              ),
                            const Spacer(),
                            Text('🔥 ${g.upvotes + g.comments}', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text('새로 올라온 딜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
