import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';
import '../models/chart_theme.dart';
import '../candle/candle_normal.dart';

// ══════════════════════════════════════════════════════════════════════════════
// InteractiveCandlestickChart
//
// ARSITEKTUR:
//   Widget ini adalah PURE DISPLAY widget — tidak manage gesture pan/zoom.
//   Semua pan/zoom ditangani oleh TradeViewScreen via Listener + GestureDetector
//   di level atas (parent). Widget ini hanya:
//     1. Menerima scale + offset dari controller (via parent)
//     2. Render candle sesuai koordinat tersebut
//     3. Detect TAP untuk select candle
//
// KENAPA GESTURE DIHAPUS DARI SINI:
//   GestureDetector internal (onScaleUpdate) dan Listener di parent
//   keduanya aktif bersamaan untuk event yang sama → double-pan.
//   Setiap swipe menghasilkan 2x applyPanDelta → chart loncat 2x lipat.
//   Solusi: satu sumber kebenaran untuk gesture, yaitu TradeViewScreen.
// ══════════════════════════════════════════════════════════════════════════════

class InteractiveCandlestickChart extends StatefulWidget {
  final List<CryptoCandle> candles;
  final CandlestickStyle   style;
  final bool               showVolume;
  final Function(CryptoCandle?)? onCandleSelected;

  final double scale;
  final Offset offset;

  // onScaleUpdate dan onOffsetUpdate TIDAK digunakan lagi untuk pan/zoom.
  // Dipertahankan untuk backward-compatibility — tidak akan dipanggil
  // dari dalam widget ini, tapi parent masih boleh pass callback.
  final void Function(double newScale)?  onScaleUpdate;
  final void Function(Offset newOffset)? onOffsetUpdate;

  const InteractiveCandlestickChart({
    Key? key,
    required this.candles,
    required this.style,
    required this.showVolume,
    required this.scale,
    required this.offset,
    this.onCandleSelected,
    this.onScaleUpdate,
    this.onOffsetUpdate,
  }) : super(key: key);

  @override
  State<InteractiveCandlestickChart> createState() =>
      _InteractiveCandlestickChartState();
}

class _InteractiveCandlestickChartState
    extends State<InteractiveCandlestickChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // HANYA tap — tidak ada onScaleStart/Update/End di sini.
      // Pan dan zoom sepenuhnya ditangani TradeViewScreen via:
      //   - Listener.onPointerMove → applyPanDelta (pan 1 jari)
      //   - GestureDetector.onScaleUpdate → updateScale (pinch 2 jari)
      onTapDown: (details) => _findSelectedCandle(details.localPosition),
      child: CustomPaint(
        painter: InteractiveCandlestickPainter(
          candles:       widget.candles,
          style:         widget.style,
          scale:         widget.scale,
          offset:        widget.offset,
          showVolume:    widget.showVolume,
          selectedIndex: _selectedIndex,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _findSelectedCandle(Offset position) {
    final chartWidth = context.size?.width ?? 0;
    if (chartWidth == 0 || widget.candles.isEmpty) return;

    final candleWidth = chartWidth * widget.scale / widget.candles.length;
    if (candleWidth <= 0) return;

    // Invert formula: x = (i * candleWidth) + offset.dx
    // → i = (x - offset.dx) / candleWidth
    final index = ((position.dx - widget.offset.dx) / candleWidth).floor();

    if (index >= 0 && index < widget.candles.length) {
      setState(() {
        _selectedIndex = index;
        widget.onCandleSelected?.call(widget.candles[index]);
      });
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Painter
// Koordinat X: x = (i * candleWidth) + offset.dx
// Koordinat Y: y = height * (1 - normalizedPrice) + offset.dy  ← FIX vertical pan
// Konsisten dengan GridInteractive dan ChartViewport.indexToX()
// ══════════════════════════════════════════════════════════════════════════════

class InteractiveCandlestickPainter extends CustomPainter {
  final List<CryptoCandle> candles;
  final CandlestickStyle   style;
  final double             scale;
  final Offset             offset;
  final bool               showVolume;
  final int?               selectedIndex;

  InteractiveCandlestickPainter({
    required this.candles,
    required this.style,
    required this.scale,
    required this.offset,
    required this.showVolume,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final minPrice   = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxPrice   = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    if (priceRange == 0) return;

    // FIX: clip canvas agar candle yang keluar batas tidak kelihatan
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final candleWidth   = size.width * scale / candles.length;
    final bodyWidth     = (candleWidth * 0.7).clamp(1.5, 24.0);
    final halfBodyWidth = bodyWidth / 2;

    for (int i = 0; i < candles.length; i++) {
      // Formula X: konsisten dengan GridInteractive dan ChartViewport
      final cx = (i * candleWidth) + offset.dx;

      // Viewport culling — horizontal
      if (cx + halfBodyWidth < 0 || cx - halfBodyWidth > size.width) continue;

      final candle    = candles[i];
      final isBullish = candle.close >= candle.open;
      final color     = isBullish ? style.bullishColor : style.bearishColor;

      // FIX: semua Y sekarang pakai offset.dy lewat _priceToY
      final highY  = _priceToY(candle.high,  minPrice, maxPrice, size.height);
      final lowY   = _priceToY(candle.low,   minPrice, maxPrice, size.height);
      final openY  = _priceToY(candle.open,  minPrice, maxPrice, size.height);
      final closeY = _priceToY(candle.close, minPrice, maxPrice, size.height);

      // Wick
      canvas.drawLine(
        Offset(cx, highY),
        Offset(cx, lowY),
        Paint()
          ..color       = color
          ..strokeWidth = 1.2
          ..strokeCap   = StrokeCap.round,
      );

      // Body
      final bodyTop    = openY < closeY ? openY  : closeY;
      final bodyBottom = openY > closeY ? openY  : closeY;
      final bodyHeight = (bodyBottom - bodyTop).clamp(1.5, double.infinity);

      final bodyRect = Rect.fromLTWH(
        cx - halfBodyWidth,
        bodyTop,
        bodyWidth,
        bodyHeight,
      );

      final isSelected = selectedIndex == i;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(2)),
        Paint()
          ..color = isSelected
              ? style.selectedColor.withOpacity(0.85)
              : color,
      );

      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(bodyRect.inflate(2), const Radius.circular(4)),
          Paint()
            ..color       = style.selectedColor
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    canvas.restore();

    _drawPriceLabels(canvas, size, minPrice, maxPrice);
  }

  void _drawPriceLabels(
      Canvas canvas, Size size, double minPrice, double maxPrice) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 5; i++) {
      final price = minPrice + ((maxPrice - minPrice) / 5) * i;
      // FIX: label Y juga ikut offset.dy supaya label tetap align sama candle
      final y = _priceToY(price, minPrice, maxPrice, size.height);
      tp.text = TextSpan(
        text: price.toStringAsFixed(2),
        style: TextStyle(
          color:    style.textColor.withOpacity(0.7),
          fontSize: 10,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(size.width - tp.width - 4, y - tp.height / 2));
    }
  }

  // FIX: tambah offset.dy — ini root cause vertical pan tidak jalan
  // Sebelumnya: height * (1 - normalized)  → offset.dy diabaikan total
  // Sekarang  : height * (1 - normalized) + offset.dy  → pan atas-bawah jalan
  double _priceToY(
      double price, double minPrice, double maxPrice, double height) {
    final range = maxPrice - minPrice;
    if (range == 0) return height / 2 + offset.dy;
    return height * (1.0 - (price - minPrice) / range) + offset.dy;
  }

  @override
  bool shouldRepaint(InteractiveCandlestickPainter old) =>
      old.candles       != candles       ||
      old.scale         != scale         ||
      old.offset        != offset        ||
      old.selectedIndex != selectedIndex ||
      old.style         != style;
}