import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/format.dart';

enum DealCategory {
  digital('디지털·가전'),
  food('식품'),
  living('생활'),
  fashion('패션·뷰티'),
  game('게임·SW'),
  coupon('쿠폰·이벤트'),
  etc('기타');

  const DealCategory(this.label);
  final String label;

  static DealCategory parse(Object? v) =>
      DealCategory.values.firstWhere((c) => c.name == v, orElse: () => DealCategory.etc);
}

const Map<String, String> kSourceNames = {
  'ppomppu': '뽐뿌',
  'ppomppu_global': '해외뽐뿌',
  'ruliweb': '루리웹',
  'clien': '클리앙',
  'arca': '아카라이브',
};

/// A normalized hot deal, as written by the crawler to `deals/{id}`.
class Deal {
  final String id;
  final String source;
  final String sourceName;
  final String url;
  final String title;
  final String productName;
  final String? shop;
  final num? price;
  final String? currency;
  final num? shippingFee;
  final DealCategory category;
  final String? thumbnail;
  final DateTime postedAt;
  final int upvotes;
  final int comments;
  final int views;
  final bool isEnded;
  final String groupKey;

  const Deal({
    required this.id,
    required this.source,
    required this.sourceName,
    required this.url,
    required this.title,
    required this.productName,
    required this.shop,
    required this.price,
    required this.currency,
    required this.shippingFee,
    required this.category,
    required this.thumbnail,
    required this.postedAt,
    required this.upvotes,
    required this.comments,
    required this.views,
    required this.isEnded,
    required this.groupKey,
  });

  factory Deal.fromMap(String id, Map<String, dynamic> m) {
    final posted = m['postedAt'];
    return Deal(
      id: id,
      source: m['source'] as String? ?? '',
      sourceName: m['sourceName'] as String? ?? kSourceNames[m['source']] ?? '',
      url: m['url'] as String? ?? '',
      title: m['title'] as String? ?? '',
      productName: m['productName'] as String? ?? m['title'] as String? ?? '',
      shop: m['shop'] as String?,
      price: m['price'] as num?,
      currency: m['currency'] as String?,
      shippingFee: m['shippingFee'] as num?,
      category: DealCategory.parse(m['category']),
      thumbnail: (m['thumbnail'] as String?)?.isEmpty == true ? null : m['thumbnail'] as String?,
      postedAt: posted is Timestamp
          ? posted.toDate()
          : posted is String
              ? DateTime.tryParse(posted)?.toLocal() ?? DateTime.now()
              : DateTime.now(),
      upvotes: (m['upvotes'] as num?)?.toInt() ?? 0,
      comments: (m['comments'] as num?)?.toInt() ?? 0,
      views: (m['views'] as num?)?.toInt() ?? 0,
      isEnded: m['isEnded'] == true,
      groupKey: m['groupKey'] as String? ?? id,
    );
  }

  String? get priceLabel => formatPrice(price, currency);

  String? get shippingLabel {
    final fee = shippingFee;
    if (fee == null) return null;
    if (fee == 0) return '무료배송';
    return '배송비 ${formatPrice(fee, currency ?? 'KRW')}';
  }

  /// Popularity that decays with age, for the "인기순" sort.
  double hotScore(DateTime now) {
    final hours = now.difference(postedAt).inMinutes / 60.0;
    final engagement = upvotes * 4 + comments * 1.5 + views / 200 + 1;
    return engagement / math.pow(hours.clamp(0, 1000) + 2, 1.5);
  }
}

/// The same deal posted on several boards, shown as one card.
class DealGroup {
  final List<Deal> deals;
  DealGroup(this.deals) : assert(deals.isNotEmpty);

  /// The post with the most engagement represents the group.
  Deal get primary => deals.reduce((a, b) => (b.upvotes + b.comments) > (a.upvotes + a.comments) ? b : a);
  int get upvotes => deals.fold(0, (n, d) => n + d.upvotes);
  int get comments => deals.fold(0, (n, d) => n + d.comments);
  DateTime get postedAt => deals.map((d) => d.postedAt).reduce((a, b) => a.isBefore(b) ? a : b);
  bool get isEnded => deals.every((d) => d.isEnded);
  List<String> get sourceNames => deals.map((d) => d.sourceName).toSet().toList();

  /// The representative post's image, or another board's image of the same deal
  /// (ppomppu's RSS carries no images).
  String? get thumbnail => primary.thumbnail ?? deals.map((d) => d.thumbnail).firstWhere((t) => t != null, orElse: () => null);

  double hotScore(DateTime now) => deals.map((d) => d.hotScore(now)).reduce((a, b) => a + b);

  /// Groups deals by groupKey, keeping the order in which each group first appears.
  static List<DealGroup> fromDeals(Iterable<Deal> deals) {
    final groups = <String, List<Deal>>{};
    for (final d in deals) {
      groups.putIfAbsent(d.groupKey, () => []).add(d);
    }
    return groups.values.map(DealGroup.new).toList();
  }
}
