import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/format.dart';
import 'deal.dart';

/// A smart keyword alert, stored at `users/{uid}/alerts/{id}`.
class AlertRule {
  final String? id;
  final String keyword;
  final int? maxPrice;
  final List<String> excludeWords;
  final List<String> shops;
  final List<DealCategory> categories;
  final bool enabled;

  const AlertRule({
    this.id,
    required this.keyword,
    this.maxPrice,
    this.excludeWords = const [],
    this.shops = const [],
    this.categories = const [],
    this.enabled = true,
  });

  factory AlertRule.fromMap(String id, Map<String, dynamic> m) => AlertRule(
        id: id,
        keyword: m['keyword'] as String? ?? '',
        maxPrice: (m['maxPrice'] as num?)?.toInt(),
        excludeWords: List<String>.from(m['excludeWords'] as List? ?? const []),
        shops: List<String>.from(m['shops'] as List? ?? const []),
        categories: (m['categories'] as List? ?? const []).map(DealCategory.parse).toList(),
        enabled: m['enabled'] != false,
      );

  Map<String, dynamic> toMap() => {
        'keyword': keyword,
        'maxPrice': maxPrice,
        'excludeWords': excludeWords,
        'shops': shops,
        'categories': categories.map((c) => c.name).toList(),
        'enabled': enabled,
      };

  AlertRule copyWith({String? id, bool? enabled}) => AlertRule(
        id: id ?? this.id,
        keyword: keyword,
        maxPrice: maxPrice,
        excludeWords: excludeWords,
        shops: shops,
        categories: categories,
        enabled: enabled ?? this.enabled,
      );

  /// One-line summary of the extra conditions, e.g. "25만원 이하 · 리퍼 제외 · 쿠팡".
  String get conditionSummary {
    final parts = <String>[
      if (maxPrice != null) '${formatPrice(maxPrice, 'KRW')} 이하',
      if (excludeWords.isNotEmpty) '${excludeWords.join(', ')} 제외',
      if (shops.isNotEmpty) shops.join(', '),
      if (categories.isNotEmpty) categories.map((c) => c.label).join(', '),
    ];
    return parts.isEmpty ? '모든 핫딜' : parts.join(' · ');
  }
}

/// An alert the server sent (or held during quiet hours), at `users/{uid}/sent/{id}`.
class SentAlert {
  final String id;
  final String keyword;
  final String productName;
  final String? shop;
  final String? priceLabel;
  final String sourceName;
  final String url;
  final String? thumbnail;
  final bool delivered;
  final DateTime sentAt;

  const SentAlert({
    required this.id,
    required this.keyword,
    required this.productName,
    required this.shop,
    required this.priceLabel,
    required this.sourceName,
    required this.url,
    required this.thumbnail,
    required this.delivered,
    required this.sentAt,
  });

  factory SentAlert.fromMap(String id, Map<String, dynamic> m) => SentAlert(
        id: id,
        keyword: m['keyword'] as String? ?? '',
        productName: m['productName'] as String? ?? m['title'] as String? ?? '',
        shop: m['shop'] as String?,
        priceLabel: formatPrice(m['price'] as num?, m['currency'] as String?),
        sourceName: m['sourceName'] as String? ?? '',
        url: m['url'] as String? ?? '',
        thumbnail: m['thumbnail'] as String?,
        delivered: m['delivered'] == true,
        sentAt: (m['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

/// Per-user push settings stored on `users/{uid}`.
class PushSettings {
  final bool pushEnabled;
  final int? quietStart;
  final int? quietEnd;

  const PushSettings({this.pushEnabled = true, this.quietStart, this.quietEnd});

  bool get quietEnabled => quietStart != null && quietEnd != null;

  factory PushSettings.fromMap(Map<String, dynamic>? m) => PushSettings(
        pushEnabled: m?['pushEnabled'] != false,
        quietStart: (m?['quietStart'] as num?)?.toInt(),
        quietEnd: (m?['quietEnd'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {'pushEnabled': pushEnabled, 'quietStart': quietStart, 'quietEnd': quietEnd};
}
