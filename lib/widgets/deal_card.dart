import 'package:flutter/material.dart';

import '../models/deal.dart';
import '../screens/web_view_screen.dart';
import '../theme.dart';
import '../utils/format.dart';

const _categoryIcons = {
  DealCategory.digital: Icons.devices_other,
  DealCategory.food: Icons.restaurant,
  DealCategory.living: Icons.home_outlined,
  DealCategory.fashion: Icons.checkroom,
  DealCategory.game: Icons.sports_esports_outlined,
  DealCategory.coupon: Icons.confirmation_number_outlined,
  DealCategory.etc: Icons.local_offer_outlined,
};

/// One hot deal: price, shop and engagement readable without opening the post.
class DealCard extends StatelessWidget {
  final DealGroup group;
  const DealCard({super.key, required this.group});

  void _open(BuildContext context) {
    if (group.deals.length == 1) {
      _openDeal(context, group.deals.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('같은 딜이 여러 곳에 올라왔어요',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final d in group.deals)
              ListTile(
                title: Text(d.sourceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('추천 ${d.upvotes} · 댓글 ${d.comments} · ${timeAgo(d.postedAt)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDeal(context, d);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static void _openDeal(BuildContext context, Deal d) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WebViewScreen(url: d.url, title: d.sourceName)),
      );

  @override
  Widget build(BuildContext context) {
    final d = group.primary;
    final ended = group.isEnded;
    final sources = group.sourceNames;
    final sourceText = sources.length > 1 ? '${sources.first} 외 ${sources.length - 1}곳' : sources.first;

    return Opacity(
      opacity: ended ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(deal: d, thumbnail: group.thumbnail, ended: ended),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (d.shop != null) ...[
                            _Badge(text: d.shop!),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              '$sourceText · ${timeAgo(group.postedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.sub),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (d.priceLabel != null)
                            Text(d.priceLabel!,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.main)),
                          if (d.priceLabel != null && d.shippingLabel != null) const SizedBox(width: 6),
                          if (d.shippingLabel != null)
                            Text(d.shippingLabel!, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                          const Spacer(),
                          if (group.upvotes > 0) _Stat(icon: Icons.thumb_up_alt_outlined, value: group.upvotes),
                          if (group.comments > 0) _Stat(icon: Icons.chat_bubble_outline, value: group.comments),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Background colours for shop tiles shown when a deal has no image.
/// Plain colour + the shop's name in text; no logos.
const _shopColors = {
  '쿠팡': Color(0xFFE5483B),
  'G마켓': Color(0xFF2DB400),
  '옥션': Color(0xFFE4002B),
  '11번가': Color(0xFFFF3B4E),
  '네이버': Color(0xFF03C75A),
  '네이버페이': Color(0xFF03C75A),
  'SSG': Color(0xFFFF5A2E),
  '롯데온': Color(0xFFE0001B),
  '토스쇼핑': Color(0xFF3182F6),
  '알리익스프레스': Color(0xFFFF6A00),
  '아마존': Color(0xFF232F3E),
  '아마존재팬': Color(0xFF232F3E),
  '무신사': Color(0xFF111111),
  '29CM': Color(0xFF111111),
  'GS SHOP': Color(0xFF6CC24A),
  '하이마트': Color(0xFFE60012),
  '이베이': Color(0xFF0064D2),
  '스팀': Color(0xFF1B2838),
  '에픽게임즈': Color(0xFF2A2A2A),
  '앱스토어': Color(0xFF0A84FF),
  '플레이스토어': Color(0xFF01875F),
};

/// Shops not in the list get a stable colour from a muted palette.
const _fallbackColors = [
  Color(0xFF5B6CFF), Color(0xFF00A3A3), Color(0xFFB45CE6), Color(0xFFE68A00),
  Color(0xFF3D8BFD), Color(0xFFD9467A), Color(0xFF4F9D2D), Color(0xFF7A6CF0),
];

Color shopColor(String shop) =>
    _shopColors[shop] ?? _fallbackColors[shop.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff) % _fallbackColors.length];

class _Thumb extends StatelessWidget {
  final Deal deal;
  final String? thumbnail;
  final bool ended;
  const _Thumb({required this.deal, required this.thumbnail, required this.ended});

  Widget _placeholder() {
    final shop = deal.shop;
    if (shop == null) {
      return Container(
        color: AppColors.bg,
        alignment: Alignment.center,
        child: Icon(_categoryIcons[deal.category], color: const Color(0xFFBDBDC2), size: 30),
      );
    }
    return Container(
      color: shopColor(shop),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_categoryIcons[deal.category], color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            shop,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: shop.length <= 4 ? 15 : 12,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          fit: StackFit.expand,
          children: [
            thumbnail == null
                ? placeholder
                : Image.network(thumbnail!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
            if (ended)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: const Text('종료',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.mainSoft, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.main)),
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final int value;
  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.sub),
            const SizedBox(width: 3),
            Text(formatCount(value), style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          ],
        ),
      );
}
