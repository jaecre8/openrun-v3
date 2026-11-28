import 'package:cloud_firestore/cloud_firestore.dart';

/// One deal's price in a product's history (products/{key}.history).
class PricePoint {
  final num price;
  final DateTime at;
  final String dealId;
  final String? shop;
  const PricePoint({required this.price, required this.at, required this.dealId, this.shop});

  factory PricePoint.fromMap(Map<String, dynamic> m) => PricePoint(
        price: m['price'] as num? ?? 0,
        at: DateTime.tryParse(m['at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        dealId: m['dealId'] as String? ?? '',
        shop: m['shop'] as String?,
      );
}

/// Price history of one product, built by the crawler from community deals.
class ProductHistory {
  final String key;
  final String name;
  final List<PricePoint> points; // oldest first
  final DateTime? updatedAt;
  const ProductHistory({required this.key, required this.name, required this.points, this.updatedAt});

  factory ProductHistory.fromMap(String key, Map<String, dynamic> m) => ProductHistory(
        key: key,
        name: m['name'] as String? ?? '',
        points: (m['history'] as List? ?? const [])
            .map((e) => PricePoint.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );

  PricePoint? get lowest => points.isEmpty ? null : points.reduce((a, b) => b.price < a.price ? b : a);
  PricePoint? get latest => points.isEmpty ? null : points.last;
  num? get average => points.isEmpty ? null : points.fold<num>(0, (s, p) => s + p.price) / points.length;
}
