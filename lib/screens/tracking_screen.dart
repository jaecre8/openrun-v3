import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/alert_rule.dart';
import '../models/deal.dart';
import '../models/product.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/deal_card.dart';
import '../widgets/price_chart.dart';
import 'deal_detail_screen.dart';

/// 내 추적 탭: 찜한 딜 and 추적 상품 (products followed with an optional target price).
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 추적'),
          bottom: const TabBar(
            indicatorColor: AppColors.main,
            labelColor: AppColors.main,
            unselectedLabelColor: AppColors.sub,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: '추적 상품'), Tab(text: '찜한 딜')],
          ),
        ),
        body: const TabBarView(children: [_TrackedTab(), _FavoritesTab()]),
      ),
    );
  }
}

class _TrackedTab extends StatefulWidget {
  const _TrackedTab();
  @override
  State<_TrackedTab> createState() => _TrackedTabState();
}

class _TrackedTabState extends State<_TrackedTab> {
  late final Stream<List<TrackedProduct>> _tracked = AppServices.instance.user.watchTracked();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TrackedProduct>>(
        stream: _tracked,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final items = snap.data!;
          if (items.isEmpty) {
            return const _Empty(
                icon: Icons.show_chart,
                text: '딜 상세에서 「가격 추적」을 누르면\n그 상품의 가격 기록을 보고\n목표가 이하로 뜨면 알림을 받아요.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TrackedCard(item: items[i]),
          );
        },
      );
}

class _TrackedCard extends StatefulWidget {
  final TrackedProduct item;
  const _TrackedCard({required this.item});
  @override
  State<_TrackedCard> createState() => _TrackedCardState();
}

class _TrackedCardState extends State<_TrackedCard> {
  late final Future<ProductHistory?> _history = AppServices.instance.deals.product(widget.item.key);

  @override
  Widget build(BuildContext context) {
    final t = widget.item;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTrackSheet(context, key: t.key, name: t.name, current: t, history: _history),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: FutureBuilder<ProductHistory?>(
            future: _history,
            builder: (context, snap) {
              final h = snap.data;
              final low = h?.lowest, last = h?.latest;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, children: [
                    Text(t.targetPrice == null ? '목표가 없음 · 새 딜마다 알림' : '목표 ${formatPrice(t.targetPrice, 'KRW')} 이하',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                    if (low != null)
                      Text('최저 ${formatPrice(low.price, 'KRW')}', style: const TextStyle(fontSize: 12.5, color: AppColors.main, fontWeight: FontWeight.w700)),
                    if (last != null)
                      Text('최근 ${formatPrice(last.price, 'KRW')} · ${timeAgo(last.at)}', style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                  ]),
                  const SizedBox(height: 10),
                  if (snap.connectionState == ConnectionState.done)
                    PriceChart(points: h?.points ?? const [], target: t.targetPrice, height: 110),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab();
  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  late final Stream<List<Deal>> _favorites = AppServices.instance.user.watchFavorites();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Deal>>(
        stream: _favorites,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final items = snap.data!;
          if (items.isEmpty) {
            return const _Empty(icon: Icons.favorite_border, text: '딜 상세에서 ♡를 누르면\n여기에 모아둘 수 있어요.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => Dismissible(
              key: ValueKey(items[i].id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(color: AppColors.main, borderRadius: BorderRadius.circular(16)),
                child: const Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              onDismissed: (_) => AppServices.instance.user.setFavorite(items[i], false),
              child: DealCard(group: DealGroup([items[i]])),
            ),
          );
        },
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: AppColors.sub),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.sub, height: 1.6)),
          ]),
        ),
      );
}
