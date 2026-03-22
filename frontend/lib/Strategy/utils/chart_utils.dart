// ══════════════════════════════════════════════════════════════════════════════
// chart_utils.dart
//
// FIX v3: ChartCoordinateMapper implements == dan hashCode
// supaya shouldRepaint di painter bisa detect perubahan mapper
// (pan/zoom) dan trigger repaint dengan benar.
//
// Formula koordinat (satu sumber kebenaran, konsisten dengan painter):
//   candleWidth = chartSize.width * scale / totalCandles
//   x_center    = (i * candleWidth) + offset   ← pixel scroll offset
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

// ══════════════════════════════════════════════════════════════════════════════
// §1  COORDINATE MAPPER
// ══════════════════════════════════════════════════════════════════════════════

class ChartCoordinateMapper {
  final int    totalCandles;
  final double minPrice;
  final double maxPrice;
  final Size   chartSize;
  final double scale;
  /// offset adalah pixel scroll offset (state.offset.dx),
  /// BUKAN candle-unit index. Konsisten dengan GridInteractive & painter.
  final double offset;

  const ChartCoordinateMapper({
    required this.totalCandles,
    required this.minPrice,
    required this.maxPrice,
    required this.chartSize,
    required this.scale,
    required this.offset,
  });

  // candleWidth identik dengan InteractiveCandlestickPainter
  double get _candleWidth =>
      totalCandles > 0 ? chartSize.width * scale / totalCandles : 1.0;

  // x = (i * candleWidth) + offset  ← pixel offset
  double candleIndexToX(int index) => (index * _candleWidth) + offset;

  // index = (x - offset) / candleWidth
  int xToCandleIndex(double x) =>
      ((x - offset) / _candleWidth).round().clamp(0, totalCandles - 1);

  double priceToY(double price) {
    final range = maxPrice - minPrice;
    if (range == 0) return chartSize.height / 2;
    return chartSize.height * (1.0 - (price - minPrice) / range);
  }

  double yToPrice(double y) {
    final range = maxPrice - minPrice;
    return minPrice + (1.0 - y / chartSize.height) * range;
  }

  // Center X dari candle i (untuk trigger dot, dsb.)
  double candleCenterX(int index) =>
      candleIndexToX(index) + _candleWidth / 2;

  // ══════════════════════════════════════════════
  // FIX: equality & hashCode agar shouldRepaint
  // bisa mendeteksi perubahan offset/scale/price
  // setiap frame saat user pan atau zoom.
  // ══════════════════════════════════════════════
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChartCoordinateMapper) return false;
    return other.totalCandles == totalCandles &&
        other.minPrice    == minPrice    &&
        other.maxPrice    == maxPrice    &&
        other.chartSize   == chartSize   &&
        other.scale       == scale       &&
        other.offset      == offset;
  }

  @override
  int get hashCode => Object.hash(
        totalCandles, minPrice, maxPrice, chartSize, scale, offset);
}

// ══════════════════════════════════════════════════════════════════════════════
// §2  STATIC PRICE HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class ChartPriceHelpers {
  ChartPriceHelpers._();

  static double lowestN(List<double> lows, int n) {
    if (lows.isEmpty) return 0;
    final endIdx   = lows.length - 1;
    final startIdx = math.max(0, endIdx - n);
    final slice    = lows.sublist(startIdx, endIdx);
    return slice.isEmpty ? lows.last : slice.reduce(math.min);
  }

  static double highestN(List<double> highs, int n) {
    if (highs.isEmpty) return 0;
    final endIdx   = highs.length - 1;
    final startIdx = math.max(0, endIdx - n);
    final slice    = highs.sublist(startIdx, endIdx);
    return slice.isEmpty ? highs.last : slice.reduce(math.max);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §3  CHART PAINTER UTILS
// ══════════════════════════════════════════════════════════════════════════════

mixin ChartPainterUtils {
  static const Color kLabelBg = Color(0xFF0A1520);

  void drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0, gap = 4.0;
    final dist  = (end - start).distance;
    if (dist == 0) return;
    final count = (dist / (dash + gap)).floor();
    for (var i = 0; i < count; i++) {
      final s = (dash + gap) * i;
      canvas.drawLine(
        Offset.lerp(start, end, s / dist)!,
        Offset.lerp(start, end, ((s + dash) / dist).clamp(0.0, 1.0))!,
        paint,
      );
    }
  }

  void drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const gap  = 5.0;
    final dist = (end - start).distance;
    if (dist == 0) return;
    final count = (dist / gap).floor();
    for (var i = 0; i <= count; i++) {
      final t = ((gap * i) / dist).clamp(0.0, 1.0);
      final p = Offset.lerp(start, end, t)!;
      canvas.drawCircle(p, paint.strokeWidth * 0.7, Paint()..color = paint.color);
    }
  }

  void drawEdgeLine(
    Canvas canvas,
    double x,
    double topY,
    double botY, {
    required bool  isActive,
    required Color accentColor,
  }) {
    canvas.drawLine(Offset(x, topY), Offset(x, botY),
        Paint()
          ..color       = Colors.black.withOpacity(0.28)
          ..strokeWidth = 4
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawLine(Offset(x, topY), Offset(x, botY),
        Paint()
          ..color       = accentColor.withOpacity(isActive ? 1.0 : 0.5)
          ..strokeWidth = isActive ? 2.5 : 1.5);
    final cap = Paint()..color = accentColor.withOpacity(isActive ? 1.0 : 0.6);
    canvas.drawCircle(Offset(x, topY), isActive ? 4.5 : 3.0, cap);
    canvas.drawCircle(Offset(x, botY), isActive ? 4.5 : 3.0, cap);
  }

  void drawLabelPill(
    Canvas canvas, {
    required double x,
    required double y,
    required String label,
    required double price,
    required Color  color,
    required bool   isActive,
    String? suffix,
    bool    strikethrough = false,
  }) {
    final priceStr  = '\$${price.toStringAsFixed(2)}';
    final suffixStr = suffix != null ? '  $suffix' : '';
    final deco      = strikethrough ? TextDecoration.lineThrough : TextDecoration.none;

    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '$label  ',
          style: TextStyle(
            color:         color.withOpacity(strikethrough ? 0.5 : 1.0),
            fontSize:      10,
            fontWeight:    FontWeight.w800,
            letterSpacing: 0.5,
            decoration:    deco,
          ),
        ),
        TextSpan(
          text: priceStr + suffixStr,
          style: TextStyle(
            color:      Colors.white.withOpacity(strikethrough ? 0.4 : 0.92),
            fontSize:   10,
            fontWeight: FontWeight.w600,
            decoration: deco,
          ),
        ),
      ]),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const h    = 22.0;
    final w    = tp.width + 18;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - h / 2, w, h), const Radius.circular(5));
    canvas.drawRRect(rect,
        Paint()..color = kLabelBg.withOpacity(isActive ? 0.98 : 0.86));
    canvas.drawRRect(
      rect,
      Paint()
        ..color       = color.withOpacity(isActive ? 0.88 : 0.38)
        ..strokeWidth = isActive ? 1.6 : 1.0
        ..style       = PaintingStyle.stroke,
    );
    tp.paint(canvas, Offset(x + 9, y - tp.height / 2));
  }

  void drawDragHandle(
    Canvas canvas,
    Offset center,
    Color  color, {
    required bool   isActive,
    required bool   isHovered,
    required String label,
    required double pulseValue,
  }) {
    final radius = isActive ? 15.0 : (isHovered ? 13.5 : 11.5);

    if (isActive || isHovered) {
      canvas.drawCircle(center, radius + 7,
          Paint()
            ..color      = color.withOpacity(isActive ? 0.28 : 0.13)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, isActive ? 7 : 4));
    }
    if (isActive) {
      canvas.drawCircle(center, radius + 11 + pulseValue * 7,
          Paint()
            ..color       = color.withOpacity(0.18 * (1 - pulseValue))
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    canvas.drawCircle(center, radius + 2.5, Paint()..color = kLabelBg);
    canvas.drawCircle(center, radius,       Paint()..color = color);

    final short = label.length > 3 ? label.substring(0, 2) : label;
    final tl = TextPainter(
      text: TextSpan(
        text: short,
        style: TextStyle(
          color:      kLabelBg,
          fontSize:   short.length <= 2 ? 11.0 : 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tl.paint(canvas, Offset(center.dx - tl.width / 2, center.dy - tl.height / 2));
  }

  void drawMoveHandle(
    Canvas canvas, {
    required double centerX,
    required double centerY,
    required bool   isActive,
    required Color  accentColor,
  }) {
    for (var c = -1; c <= 1; c++) {
      for (var r = -1; r <= 1; r++) {
        canvas.drawCircle(
          Offset(centerX + c * 5, centerY + r * 5),
          isActive ? 2.5 : 1.8,
          Paint()
            ..color = isActive
                ? accentColor.withOpacity(1.0)
                : Colors.white.withOpacity(0.42),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §4  CHART ANIMATION MIXIN
// ══════════════════════════════════════════════════════════════════════════════

mixin ChartAnimationMixin {
  late AnimationController pulseCtrl;
  late AnimationController appearCtrl;
  late AnimationController hitCtrl;

  late Animation<double> pulseAnim;
  late Animation<double> appearAnim;
  late Animation<double> hitAnim;

  void initChartAnimations(TickerProvider vsync) {
    pulseCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    appearCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 450));
    hitCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 700));

    pulseAnim  = CurvedAnimation(parent: pulseCtrl,  curve: Curves.easeInOut);
    appearAnim = CurvedAnimation(parent: appearCtrl, curve: Curves.elasticOut);
    hitAnim    = CurvedAnimation(parent: hitCtrl,    curve: Curves.easeOut);
  }

  void disposeChartAnimations() {
    pulseCtrl.dispose();
    appearCtrl.dispose();
    hitCtrl.dispose();
  }

  Listenable get chartAnimListenable =>
      Listenable.merge([pulseAnim, appearAnim, hitAnim]);
}