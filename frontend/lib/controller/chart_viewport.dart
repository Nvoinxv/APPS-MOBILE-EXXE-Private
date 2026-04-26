import 'dart:math' as math;
import 'package:flutter/material.dart';

// ===========================================================================
// ChartViewport — Single Source of Truth untuk coordinate system
//
// PRINSIP UTAMA:
//   - Semua overlay disimpan dalam "data space" (priceLevel, candleIndex)
//   - Konversi ke pixel HANYA terjadi saat paint (di dalam CustomPainter)
//   - Ini yang membuat overlay "nempel" otomatis saat zoom/pan
//   - Tidak ada pixel yang disimpan sebagai state jangka panjang
// ===========================================================================

class ChartViewport {
  final int    totalCandles;
  final double minPrice;
  final double maxPrice;
  final Size   chartSize;
  final double scale;      // zoom level, 1.0 = default
  final double offsetX;    // pan horizontal dalam pixel
  final double offsetY;    // pan vertikal dalam pixel

  const ChartViewport({
    required this.totalCandles,
    required this.minPrice,
    required this.maxPrice,
    required this.chartSize,
    this.scale   = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  // ---------------------------------------------------------------------------
  // Lebar satu candle dalam pixel (termasuk scale)
  // ---------------------------------------------------------------------------

  double get candleWidth {
    if (totalCandles == 0) return 8.0;
    return (chartSize.width / totalCandles) * scale;
  }

  // ---------------------------------------------------------------------------
  // Data space → Screen space
  // ---------------------------------------------------------------------------

  /// Candlestick index → pixel X (tengah candle)
  double indexToX(int index) {
    final baseX = (index + 0.5) * candleWidth;
    return baseX + offsetX;
  }

  /// Harga → pixel Y
  double priceToY(double price) {
    final priceRange = maxPrice - minPrice;
    if (priceRange == 0) return chartSize.height / 2;
    final normalized = (price - minPrice) / priceRange; // 0..1, bawah = 0
    return chartSize.height * (1.0 - normalized) + offsetY;
  }

  // ---------------------------------------------------------------------------
  // Screen space → Data space
  // ---------------------------------------------------------------------------

  /// Pixel X → candle index (float, untuk presisi drag)
  double xToIndexF(double px) {
    if (candleWidth == 0) return 0;
    return (px - offsetX) / candleWidth - 0.5;
  }

  /// Pixel X → candle index (int, dibulatkan)
  int xToIndex(double px) => xToIndexF(px).round().clamp(0, totalCandles - 1);

  /// Pixel Y → harga
  double yToPrice(double py) {
    final priceRange = maxPrice - minPrice;
    final normalized = 1.0 - (py - offsetY) / chartSize.height;
    return minPrice + normalized * priceRange;
  }

  // ---------------------------------------------------------------------------
  // Visible range — untuk viewport culling (hanya render candle yang terlihat)
  // ---------------------------------------------------------------------------

  int get firstVisibleIndex {
    final idx = xToIndex(0);
    return (idx - 2).clamp(0, totalCandles - 1);
  }

  int get lastVisibleIndex {
    final idx = xToIndex(chartSize.width);
    return (idx + 2).clamp(0, totalCandles - 1);
  }

  bool isCandleVisible(int index) =>
      index >= firstVisibleIndex && index <= lastVisibleIndex;

  // ---------------------------------------------------------------------------
  // Viewport bounds dalam price space (untuk clamp drag)
  // ---------------------------------------------------------------------------

  double get visibleMinPrice => yToPrice(chartSize.height);
  double get visibleMaxPrice => yToPrice(0);

  // ---------------------------------------------------------------------------
  // Factory — buat viewport baru dengan parameter yang diubah
  // (immutable pattern, tidak mutate state)
  // ---------------------------------------------------------------------------

  ChartViewport copyWith({
    int?    totalCandles,
    double? minPrice,
    double? maxPrice,
    Size?   chartSize,
    double? scale,
    double? offsetX,
    double? offsetY,
  }) {
    return ChartViewport(
      totalCandles: totalCandles ?? this.totalCandles,
      minPrice:     minPrice     ?? this.minPrice,
      maxPrice:     maxPrice     ?? this.maxPrice,
      chartSize:    chartSize    ?? this.chartSize,
      scale:        scale        ?? this.scale,
      offsetX:      offsetX      ?? this.offsetX,
      offsetY:      offsetY      ?? this.offsetY,
    );
  }
}

// ===========================================================================
// DataSpacePoint — representasi titik dalam data space
// Ini yang disimpan di overlay (RiskRatio, Fibonacci, dll)
// BUKAN pixel — pixel dihitung on-the-fly saat paint
// ===========================================================================

class DataSpacePoint {
  /// Floating-point candle index — lebih presisi dari int saat drag
  final double candleIndexF;

  /// Harga
  final double price;

  const DataSpacePoint({
    required this.candleIndexF,
    required this.price,
  });

  /// Konversi ke pixel — dipanggil HANYA di dalam CustomPainter.paint()
  Offset toScreen(ChartViewport vp) {
    // Interpolasi linear antara dua candle untuk sub-candle precision
    final x = (candleIndexF + 0.5) * vp.candleWidth + vp.offsetX;
    final y = vp.priceToY(price);
    return Offset(x, y);
  }

  /// Buat dari pixel (saat user tap/drag) — invert konversi
  factory DataSpacePoint.fromScreen(Offset screen, ChartViewport vp) {
    return DataSpacePoint(
      candleIndexF: vp.xToIndexF(screen.dx),
      price:        vp.yToPrice(screen.dy),
    );
  }

  DataSpacePoint copyWith({double? candleIndexF, double? price}) {
    return DataSpacePoint(
      candleIndexF: candleIndexF ?? this.candleIndexF,
      price:        price        ?? this.price,
    );
  }
}

// ===========================================================================
// DataSpaceRect — bounding box overlay dalam data space
// Digunakan oleh RiskRatioData, FibonacciOverlay, dll
// ===========================================================================

class DataSpaceRect {
  final DataSpacePoint topLeft;
  final DataSpacePoint bottomRight;

  const DataSpaceRect({required this.topLeft, required this.bottomRight});

  /// Konversi ke Rect dalam pixel — dipanggil HANYA saat paint
  Rect toScreenRect(ChartViewport vp) {
    final tl = topLeft.toScreen(vp);
    final br = bottomRight.toScreen(vp);
    return Rect.fromPoints(tl, br);
  }

  double get leftIndexF  => topLeft.candleIndexF;
  double get rightIndexF => bottomRight.candleIndexF;
  double get topPrice    => math.max(topLeft.price, bottomRight.price);
  double get bottomPrice => math.min(topLeft.price, bottomRight.price);
  double get widthIndex  => rightIndexF - leftIndexF;

  /// Center dalam data space
  DataSpacePoint get center => DataSpacePoint(
    candleIndexF: (leftIndexF + rightIndexF) / 2,
    price:        (topPrice + bottomPrice) / 2,
  );

  DataSpaceRect translate({double dIndex = 0, double dPrice = 0}) {
    return DataSpaceRect(
      topLeft: DataSpacePoint(
        candleIndexF: topLeft.candleIndexF + dIndex,
        price:        topLeft.price + dPrice,
      ),
      bottomRight: DataSpacePoint(
        candleIndexF: bottomRight.candleIndexF + dIndex,
        price:        bottomRight.price + dPrice,
      ),
    );
  }
}