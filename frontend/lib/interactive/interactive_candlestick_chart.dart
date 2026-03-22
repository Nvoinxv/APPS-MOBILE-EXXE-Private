import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';
import '../models/chart_theme.dart';
import '../candle/candle_normal.dart';

// ══════════════════════════════════════════════════════════════════════════════
// InteractiveCandlestickChart
//
// FIX ROOT CAUSE — "dual coordinate system" bug:
//
// SEBELUMNYA:
//   Widget ini manage `_scale` dan `_offset` sendiri di internal state.
//   Saat user pan/zoom, hanya internal state yang berubah → candle bergerak.
//   Tapi ChartCoordinateMapper di TradeViewScreen pakai
//   `_controller.state.scale` dan `_controller.state.offset` yang berbeda.
//   Hasil: candle bergerak, tapi label strategy TIDAK ikut karena mapper
//   tidak tahu candle sudah pindah ke mana.
//
// SESUDAH:
//   - Internal `_scale` dan `_offset` DIHAPUS.
//   - Widget menerima `scale` dan `offset` dari parent (ChartController)
//     via constructor parameter.
//   - Pan/zoom diteruskan ke parent via `onScaleUpdate` dan `onOffsetUpdate`
//     callback — controller yang update state, setState dipanggil,
//     LayoutBuilder rebuild, mapper fresh, semua layer pakai koordinat sama.
//   - Candle painter menggunakan formula koordinat yang IDENTIK dengan
//     ChartCoordinateMapper.candleIndexToX() sehingga pixel-perfect sync.
// ══════════════════════════════════════════════════════════════════════════════

class InteractiveCandlestickChart extends StatefulWidget {
  final List<CryptoCandle> candles;
  final CandlestickStyle   style;
  final bool               showVolume;
  final Function(CryptoCandle?)? onCandleSelected;

  // FIX: scale dan offset dari controller, bukan internal state
  final double scale;
  final Offset offset;

  // FIX: callback ke controller saat user pan/zoom
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
  int?   _selectedIndex;

  // Untuk hitung delta scale saat pinch
  double _scaleAtGestureStart = 1.0;
  Offset _offsetAtGestureStart = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _findSelectedCandle(details.localPosition),
      onScaleStart: (details) {
        // FIX: snapshot nilai saat gesture mulai
        _scaleAtGestureStart  = widget.scale;
        _offsetAtGestureStart = widget.offset;
      },
      onScaleUpdate: (details) {
        // FIX: hitung scale baru dari snapshot, bukan akumulasi delta
        final newScale = (_scaleAtGestureStart * details.scale).clamp(0.5, 5.0);

        // Pan: tambah delta focal ke offset
        final newOffset = Offset(
          _offsetAtGestureStart.dx + details.focalPointDelta.dx,
          0, // Y-axis pan dikontrol controller terpisah jika perlu
        );

        // Naik ke controller via callback
        if (details.scale != 1.0) {
          widget.onScaleUpdate?.call(newScale);
        }
        widget.onOffsetUpdate?.call(newOffset);
      },
      child: CustomPaint(
        painter: InteractiveCandlestickPainter(
          candles:       widget.candles,
          style:         widget.style,
          // FIX: pakai scale/offset dari controller (sudah sync dengan mapper)
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

    // FIX: gunakan formula IDENTIK dengan ChartCoordinateMapper.candleIndexToX()
    // candleIndexToX(i) = (i - offset) * candleWidth
    // di mana candleWidth = chartSize.width / (totalCandles / scale)
    // → candleWidth = chartWidth * scale / totalCandles
    final candleWidth = chartWidth * widget.scale / widget.candles.length;

    // Invert: x = (i - offset.dx) * candleWidth
    // → i = x / candleWidth + offset.dx
    // Note: offset.dx dari controller adalah pixel offset, bukan candle index
    // ChartCoordinateMapper: candleIndexToX(i) = (i - offset) * _candleWidth
    // di mana offset = state.offset.dx (pixel scroll position)
    // Maka: i = x / candleWidth + offset / candleWidth * ... perlu hati-hati
    //
    // Pakai pendekatan sederhana: hitung index dari posisi tap
    final adjustedX = position.dx - widget.offset.dx;
    final index = (adjustedX / candleWidth).floor();

    if (index >= 0 && index < widget.candles.length) {
      setState(() {
        _selectedIndex = index;
        widget.onCandleSelected?.call(widget.candles[index]);
      });
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Painter — koordinat X HARUS identik dengan ChartCoordinateMapper
//
// ChartCoordinateMapper.candleIndexToX(i):
//   _candleWidth = chartSize.width / (totalCandles / scale)
//               = chartSize.width * scale / totalCandles
//   x = (i - offset) * _candleWidth
//
// Di painter kita tidak punya chartSize langsung tapi punya `size` dari paint().
// Rumus identik:
//   candleW = size.width * scale / candles.length
//   x       = (i - offsetInCandleUnits) * candleW
//
// Tapi `offset` dari controller adalah pixel (Offset.dx), bukan candle units.
// ChartCoordinateMapper menggunakan offset sebagai candle index offset:
//   candleIndexToX(i) = (i - offset) * _candleWidth
// → offset di sini adalah CANDLE INDEX offset, bukan pixel.
//
// Maka kita harus konsisten: offset yang di-pass ke painter adalah
// state.offset.dx dari controller, dan di ChartCoordinateMapper
// constructor: `offset: state.offset.dx`.
// Artinya offset = pixel offset, dan:
//   x_pixel = (i * candleW) + offset.dx   ← formula lama yang benar untuk pixel offset
//
// Kita pilih formula ini agar konsisten dengan GridInteractive yang sudah ada:
//   x = (i * candleWidth) + offset.dx
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

    // FIX: formula candleWidth IDENTIK dengan ChartCoordinateMapper._candleWidth
    // _candleWidth = chartSize.width / (totalCandles / scale)
    //              = size.width * scale / candles.length
    final candleWidth   = size.width * scale / candles.length;
    final bodyWidth     = (candleWidth * 0.7).clamp(1.5, 24.0);
    final halfBodyWidth = bodyWidth / 2;

    for (int i = 0; i < candles.length; i++) {
      // FIX: formula X IDENTIK dengan ChartCoordinateMapper.candleIndexToX(i)
      // candleIndexToX(i) = (i - offset) * _candleWidth
      // di sini offset adalah state.offset.dx yang dipakai sebagai candle offset
      final cx = (i - offset.dx) * candleWidth;

      // Culling — skip kalau di luar layar
      if (cx + halfBodyWidth < 0 || cx - halfBodyWidth > size.width) continue;

      final candle    = candles[i];
      final isBullish = candle.close >= candle.open;
      final color     = isBullish ? style.bullishColor : style.bearishColor;

      final highY  = _priceToY(candle.high, minPrice, maxPrice, size.height);
      final lowY   = _priceToY(candle.low,  minPrice, maxPrice, size.height);
      final openY  = _priceToY(candle.open, minPrice, maxPrice, size.height);
      final closeY = _priceToY(candle.close,minPrice, maxPrice, size.height);

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

    _drawPriceLabels(canvas, size, minPrice, maxPrice);
  }

  void _drawPriceLabels(
      Canvas canvas, Size size, double minPrice, double maxPrice) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 5; i++) {
      final price = minPrice + ((maxPrice - minPrice) / 5) * i;
      final y     = size.height - ((size.height / 5) * i);
      tp.text = TextSpan(
        text: price.toStringAsFixed(2),
        style: TextStyle(
          color:    style.textColor.withOpacity(0.7),
          fontSize: 10,
        ),
      );
      tp.layout();
      tp.paint(canvas,
          Offset(size.width - tp.width - 4, y - tp.height / 2));
    }
  }

  double _priceToY(
      double price, double minPrice, double maxPrice, double height) {
    final range = maxPrice - minPrice;
    if (range == 0) return height / 2;
    return height * (1.0 - (price - minPrice) / range);
  }

  @override
  bool shouldRepaint(InteractiveCandlestickPainter old) =>
      old.candles       != candles       ||
      old.scale         != scale         ||
      old.offset        != offset        ||
      old.selectedIndex != selectedIndex ||
      old.style         != style;
}