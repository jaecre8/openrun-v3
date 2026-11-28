import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Price history of a product: one point per deal, the lowest one marked.
class PriceChart extends StatelessWidget {
  final List<PricePoint> points;
  /// Optional price to draw as a dashed line (e.g. the user's target price).
  final num? target;
  final double height;
  const PriceChart({super.key, required this.points, this.target, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(points.isEmpty ? '아직 가격 기록이 없어요' : '가격 기록이 1건이에요. 딜이 더 모이면 그래프가 보여요.',
              style: const TextStyle(color: AppColors.sub, fontSize: 13)),
        ),
      );
    }
    final low = points.reduce((a, b) => b.price < a.price ? b : a);
    final high = points.reduce((a, b) => b.price > a.price ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: height, child: CustomPaint(painter: _ChartPainter(points, low, target))),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(_date(points.first.at), style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
            Expanded(
              child: Text('최저 ${formatPrice(low.price, 'KRW')} · 최고 ${formatPrice(high.price, 'KRW')}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
            ),
            Text(_date(points.last.at), style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
          ],
        ),
      ],
    );
  }

  static String _date(DateTime t) => '${t.month}/${t.day}';
}

class _ChartPainter extends CustomPainter {
  final List<PricePoint> points;
  final PricePoint low;
  final num? target;
  _ChartPainter(this.points, this.low, this.target);

  @override
  void paint(Canvas canvas, Size size) {
    const padTop = 22.0, padBottom = 8.0, padX = 10.0;
    final prices = [...points.map((p) => p.price.toDouble()), if (target != null) target!.toDouble()];
    var lo = prices.reduce(math.min), hi = prices.reduce(math.max);
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    final t0 = points.first.at.millisecondsSinceEpoch.toDouble();
    final t1 = math.max(points.last.at.millisecondsSinceEpoch.toDouble(), t0 + 1);
    Offset at(PricePoint p) => Offset(
          padX + (p.at.millisecondsSinceEpoch - t0) / (t1 - t0) * (size.width - padX * 2),
          padTop + (1 - (p.price - lo) / (hi - lo)) * (size.height - padTop - padBottom),
        );

    // grid
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = padTop + i * (size.height - padTop - padBottom) / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // target price
    if (target != null) {
      final y = padTop + (1 - (target! - lo) / (hi - lo)) * (size.height - padTop - padBottom);
      final dash = Paint()
        ..color = const Color(0xFF2E7D32)
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), dash);
      }
      _label(canvas, '목표 ${formatPrice(target, 'KRW')}', Offset(size.width - 4, y - 16), const Color(0xFF2E7D32), right: true);
    }

    // line + area
    final pts = points.map(at).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = AppColors.main.withValues(alpha: .08));
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.main
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);

    // points; the lowest one is filled and labelled
    for (var i = 0; i < pts.length; i++) {
      final isLow = identical(points[i], low);
      canvas.drawCircle(pts[i], isLow ? 6 : 3.5, Paint()..color = AppColors.main);
      if (!isLow) canvas.drawCircle(pts[i], 2, Paint()..color = Colors.white);
    }
    final lp = at(low);
    _label(canvas, formatPrice(low.price, 'KRW')!, Offset(lp.dx, lp.dy - 20), AppColors.main);
  }

  void _label(Canvas canvas, String text, Offset anchor, Color color, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = right ? anchor.dx - tp.width : anchor.dx - tp.width / 2;
    x = x.clamp(0, double.infinity);
    tp.paint(canvas, Offset(x, math.max(0, anchor.dy)));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.points != points || old.target != target;
}
