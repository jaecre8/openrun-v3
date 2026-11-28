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
  final String postId;
  /// Same product across deals; null when the post is not one product.
  final String? productKey;
  /// 'lowest' (역대 최저가) or 'below_avg' (평소보다 저렴), from the product's earlier deals.
  final String? insightKind;
  final int? insightPct;
  final num? prevLowest;
  final int insightSamples;

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
    this.postId = '',
    this.productKey,
    this.insightKind,
    this.insightPct,
    this.prevLowest,
    this.insightSamples = 0,
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
      thumbnail: _thumbnailOf(m),
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
      postId: m['postId']?.toString() ?? '',
      productKey: m['productKey'] as String?,
      insightKind: m['insightKind'] as String?,
      insightPct: ((m['insight'] as Map?)?['pct'] as num?)?.toInt(),
      prevLowest: (m['insight'] as Map?)?['prevLowest'] as num?,
      insightSamples: ((m['insight'] as Map?)?['samples'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ppomppu list thumbnails live at a path derived from the post number, so posts
  /// stored before the crawler set them (RSS has no images) still get one.
  static String? _thumbnailOf(Map<String, dynamic> m) {
    final t = m['thumbnail'] as String?;
    if (t != null && t.isNotEmpty) return t;
    final postId = m['postId']?.toString() ?? '';
    final board = switch (m['source']) { 'ppomppu' => 'ppomppu', 'ppomppu_global' => 'ppomppu4', _ => null };
    if (board == null || !RegExp(r'^\d+$').hasMatch(postId)) return null;
    return 'https://cdn4.ppomppu.co.kr/zboard/data/_thumb/$board/${postId[postId.length - 1]}/small_$postId.jpg';
  }

  String? get priceLabel => formatPrice(price, currency);

  /// Short badge text for the price row, or null.
  String? get insightBadge => switch (insightKind) {
        'lowest' => '역대 최저가',
        'below_avg' when (insightPct ?? 0) > 0 => '평소보다 $insightPct%↓',
        _ => null,
      };

  /// A sentence for the detail screen explaining the badge.
  String? get insightDetail {
    if (insightSamples == 0 || prevLowest == null) return null;
    final low = formatPrice(prevLowest, 'KRW');
    return switch (insightKind) {
      'lowest' => '오픈런에 모인 이 상품의 지난 딜 $insightSamples건 중 가장 싸요 (이전 최저 $low)',
      'below_avg' => '지난 딜 $insightSamples건 평균보다 $insightPct% 저렴해요 (이전 최저 $low)',
      _ => '지난 딜 $insightSamples건과 비교했어요 (이전 최저 $low)',
    };
  }

  Map<String, dynamic> toFavorite() => {
        'dealId': id,
        'title': title,
        'productName': productName,
        'shop': shop,
        'price': price,
        'currency': currency,
        'shippingFee': shippingFee,
        'category': category.name,
        'thumbnail': thumbnail,
        'url': url,
        'sourceName': sourceName,
        'groupKey': groupKey,
        'productKey': productKey,
        'postedAt': postedAt.toUtc().toIso8601String(),
      };

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

  /// The post carrying a badge, if any of the group's posts has one.
  Deal get insightDeal => deals.firstWhere((d) => d.insightKind == 'lowest',
      orElse: () => deals.firstWhere((d) => d.insightKind != null, orElse: () => primary));
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
