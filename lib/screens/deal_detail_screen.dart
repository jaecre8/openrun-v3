import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../models/alert_rule.dart';
import '../models/deal.dart';
import '../models/product.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/deal_card.dart';
import '../widgets/price_chart.dart';
import 'web_view_screen.dart';

void openDealUrl(BuildContext context, Deal d) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebViewScreen(url: d.url, title: d.sourceName)),
    );

/// 딜 상세: price and its 역대가 context, the product's price history, and the posts on each board.
class DealDetailScreen extends StatefulWidget {
  final DealGroup group;
  const DealDetailScreen({super.key, required this.group});

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  final _user = AppServices.instance.user;
  late final Deal d = widget.group.insightDeal;
  late final Future<ProductHistory?> _history =
      d.productKey == null ? Future.value(null) : AppServices.instance.deals.product(d.productKey!);
  StreamSubscription<List<Deal>>? _favSub;
  StreamSubscription<List<TrackedProduct>>? _trackSub;
  bool _favorite = false;
  TrackedProduct? _trackedThis;

  @override
  void initState() {
    super.initState();
    // One subscription each; several widgets read the latest values.
    _favSub = _user.watchFavorites().listen((l) => setState(() => _favorite = l.any((f) => f.id == d.id)));
    if (d.productKey != null) {
      _trackSub = _user.watchTracked().listen((l) => setState(() => _trackedThis = l.where((x) => x.key == d.productKey).firstOrNull));
    }
  }

  @override
  void dispose() {
    _favSub?.cancel();
    _trackSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(d.shop ?? '딜 상세')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Community thumbnails are small; show them as a square instead of stretching them.
          Container(
            color: AppColors.bg,
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: SizedBox(
              width: 200,
              height: 200,
              child: DealThumb(deal: d, thumbnail: g.thumbnail, ended: g.isEnded, radius: 20, large: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${g.sourceNames.join(' · ')} · ${timeAgo(g.postedAt)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                const SizedBox(height: 8),
                Text(d.productName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35, color: AppColors.text)),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (d.priceLabel != null)
                      Text(d.priceLabel!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.main)),
                    if (d.shippingLabel != null) Text(d.shippingLabel!, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                    if (d.insightBadge != null) InsightBadge(text: d.insightBadge!, strong: d.insightKind == 'lowest'),
                    if (g.isEnded) const InsightBadge(text: '종료된 딜', strong: false, grey: true),
                  ],
                ),
                if (d.insightDetail != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.mainSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.trending_down, color: AppColors.main, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.insightDetail!, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          if (d.productKey != null) _historySection(),
          const _SectionTitle('올라온 곳'),
          for (final p in g.deals)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(p.sourceName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  [if (p.upvotes > 0) '추천 ${p.upvotes}', if (p.comments > 0) '댓글 ${p.comments}', timeAgo(p.postedAt), if (p.isEnded) '종료']
                      .join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openDealUrl(context, p),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              _SquareButton(
                icon: _favorite ? Icons.favorite : Icons.favorite_border,
                label: '찜',
                color: _favorite ? AppColors.main : AppColors.text,
                onTap: () => _user.setFavorite(d, !_favorite),
              ),
              if (d.productKey != null) ...[
                const SizedBox(width: 8),
                _SquareButton(
                  icon: _trackedThis != null ? Icons.notifications_active : Icons.show_chart,
                  label: _trackedThis != null ? '추적 중' : '가격 추적',
                  color: _trackedThis != null ? AppColors.main : AppColors.text,
                  onTap: () => showTrackSheet(context, key: d.productKey!, name: d.productName, current: _trackedThis, history: _history),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.main,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => g.deals.length == 1 ? openDealUrl(context, g.deals.first) : openDealUrl(context, g.primary),
                  child: const Text('원글 보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historySection() => FutureBuilder<ProductHistory?>(
        future: _history,
        builder: (context, snap) {
          final h = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle('가격 기록', trailing: h == null ? null : '${h.points.length}건'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: snap.connectionState != ConnectionState.done
                    ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : PriceChart(points: h?.points ?? const [], target: _trackedThis?.targetPrice),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text('오픈런에 모인 커뮤니티 핫딜 가격이에요. 쇼핑몰의 평소 판매가와는 다를 수 있어요.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.sub)),
              ),
            ],
          );
        },
      );
}

/// 가격 추적 설정: follow a product, optionally with a target price.
Future<void> showTrackSheet(BuildContext context,
    {required String key, required String name, TrackedProduct? current, Future<ProductHistory?>? history}) {
  final user = AppServices.instance.user;
  final ctrl = TextEditingController(text: current?.targetPrice?.toString() ?? '');
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('가격 추적', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(color: AppColors.sub), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: const InputDecoration(
              labelText: '목표 가격',
              hintText: '비워두면 새 딜이 뜰 때마다 알려드려요',
              suffixText: '원 이하',
              border: OutlineInputBorder(),
            ),
          ),
          if (history != null)
            FutureBuilder<ProductHistory?>(
              future: history,
              builder: (_, snap) {
                final low = snap.data?.lowest;
                return low == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('지금까지 최저 ${formatPrice(low.price, 'KRW')}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                      );
              },
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.main, minimumSize: const Size.fromHeight(50)),
            onPressed: () async {
              await user.saveTracked(TrackedProduct(key: key, name: name, targetPrice: int.tryParse(ctrl.text)));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(current == null ? '추적 시작' : '저장'),
          ),
          if (current != null)
            TextButton(
              onPressed: () async {
                await user.deleteTracked(key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('추적 그만하기', style: TextStyle(color: AppColors.sub)),
            ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
        ]),
      );
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SquareButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          height: 54,
          decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 22),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
