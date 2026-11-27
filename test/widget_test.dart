import 'package:flutter_test/flutter_test.dart';
import 'package:openrun/models/alert_rule.dart';
import 'package:openrun/models/deal.dart';
import 'package:openrun/utils/format.dart';

Deal _deal(String id, {String group = '', int up = 0, int cm = 0, bool ended = false, Duration age = Duration.zero}) =>
    Deal.fromMap(id, {
      'source': id.split('_').first,
      'title': 't',
      'productName': 'p',
      'groupKey': group.isEmpty ? id : group,
      'upvotes': up,
      'comments': cm,
      'isEnded': ended,
      'postedAt': DateTime.now().subtract(age).toUtc().toIso8601String(),
      'price': 21570,
      'currency': 'KRW',
      'shippingFee': 0,
      'category': 'food',
    });

void main() {
  test('price and shipping labels', () {
    expect(formatPrice(21570, 'KRW'), '21,570원');
    expect(formatPrice(1091.34, 'USD'), '\$1,091.34');
    expect(formatPrice(0, 'KRW'), '무료');
    expect(formatPrice(null, 'KRW'), isNull);
    final d = _deal('ppomppu_1');
    expect(d.priceLabel, '21,570원');
    expect(d.shippingLabel, '무료배송');
    expect(d.category, DealCategory.food);
    expect(d.sourceName, '뽐뿌');
  });

  test('deals with the same groupKey become one card', () {
    final groups = DealGroup.fromDeals([
      _deal('ppomppu_1', up: 1),
      _deal('clien_2'),
      _deal('arca_3', group: 'ppomppu_1', up: 5, ended: true),
    ]);
    expect(groups.length, 2);
    expect(groups.first.deals.length, 2);
    expect(groups.first.primary.id, 'arca_3');
    expect(groups.first.upvotes, 6);
    expect(groups.first.isEnded, isFalse); // still open on one board
    expect(groups.first.sourceNames, ['뽐뿌', '아카라이브']);
  });

  test('hot score favours engagement and decays with age', () {
    final now = DateTime.now();
    final fresh = _deal('a_1', up: 5, age: const Duration(hours: 1));
    final old = _deal('a_2', up: 5, age: const Duration(hours: 20));
    final quiet = _deal('a_3', age: const Duration(hours: 1));
    expect(fresh.hotScore(now), greaterThan(old.hotScore(now)));
    expect(fresh.hotScore(now), greaterThan(quiet.hotScore(now)));
  });

  test('alert rule summary', () {
    expect(const AlertRule(keyword: 'x').conditionSummary, '모든 핫딜');
    expect(
      const AlertRule(keyword: '에어팟', maxPrice: 250000, excludeWords: ['리퍼'], shops: ['쿠팡']).conditionSummary,
      '250,000원 이하 · 리퍼 제외 · 쿠팡',
    );
  });

  test('time ago', () {
    final now = DateTime(2026, 11, 27, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), '방금');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5분 전');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3시간 전');
  });
}
