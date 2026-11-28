import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openrun/models/product.dart';
import 'package:openrun/widgets/price_chart.dart';

void main() {
  testWidgets('price chart draws several points with a target line', (tester) async {
    final points = [
      PricePoint(price: 12900, at: DateTime(2026, 11, 1), dealId: 'a'),
      PricePoint(price: 11500, at: DateTime(2026, 11, 9), dealId: 'b'),
      PricePoint(price: 13900, at: DateTime(2026, 11, 20), dealId: 'c'),
      PricePoint(price: 9900, at: DateTime(2026, 11, 28), dealId: 'd'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: PriceChart(points: points, target: 10000))),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('최저 9,900원 · 최고 13,900원'), findsOneWidget);
    expect(find.text('11/1'), findsOneWidget);
  });

  testWidgets('price chart explains a single record', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PriceChart(points: [PricePoint(price: 1, at: DateTime(2026), dealId: 'a')])),
    ));
    expect(find.textContaining('1건'), findsOneWidget);
  });
}
