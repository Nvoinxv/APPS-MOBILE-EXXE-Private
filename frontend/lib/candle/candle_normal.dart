import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../hooks/crypto_data_hook.dart';

// Extension untuk CryptoCandle helpers
extension CryptoCandle_Helpers on CryptoCandle {
  bool get isBullish => close >= open;
  bool get isBearish => close < open;
  double get bodyHigh => math.max(open, close);
  double get bodyLow => math.min(open, close);
}

// ===== CANDLESTICK CHART WIDGET =====
class CandlestickChart extends StatefulWidget {
  final List<CryptoCandle> candles;
  final CandlestickStyle? style;
  final bool showVolume;
  final bool showGrid;
  final bool showCrosshair;
  final Function(CryptoCandle?)? onCandleSelected;
  
  const CandlestickChart({
    Key? key,
    required this.candles,
    this.style,
    this.showVolume = true,
    this.showGrid = true,
    this.showCrosshair = true,
    this.onCandleSelected,
  }) : super(key: key);

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset? _tapPosition;
  int? _selectedIndex;
  
  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    
    final style = widget.style ?? CandlestickStyle();
    
    return GestureDetector(
      onScaleStart: (details) {
        _previousScale = _scale;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_previousScale * details.scale).clamp(0.5, 3.0);
        });
      },
      onTapDown: widget.showCrosshair
          ? (details) {
              setState(() {
                _tapPosition = details.localPosition;
                _findSelectedCandle(details.localPosition);
              });
            }
          : null,
      onTapUp: (_) {
        if (!widget.showCrosshair) return;
        setState(() {
          _tapPosition = null;
          _selectedIndex = null;
          widget.onCandleSelected?.call(null);
        });
      },
      child: CustomPaint(
        painter: CandlestickPainter(
          candles: widget.candles,
          style: style,
          scale: _scale,
          showVolume: widget.showVolume,
          showGrid: widget.showGrid,
          tapPosition: _tapPosition,
          selectedIndex: _selectedIndex,
        ),
        child: Container(),
      ),
    );
  }
  
  void _findSelectedCandle(Offset position) {
    // Implement candle selection logic
    final chartWidth = context.size?.width ?? 0;
    final candleWidth = (chartWidth / widget.candles.length) * _scale;
    final index = (position.dx / candleWidth).floor();
    
    if (index >= 0 && index < widget.candles.length) {
      setState(() {
        _selectedIndex = index;
        widget.onCandleSelected?.call(widget.candles[index]);
      });
    }
  }
}

// ===== CANDLESTICK PAINTER =====
class CandlestickPainter extends CustomPainter {
  final List<CryptoCandle> candles;
  final CandlestickStyle style;
  final double scale;
  final bool showVolume;
  final bool showGrid;
  final Offset? tapPosition;
  final int? selectedIndex;
  
  CandlestickPainter({
    required this.candles,
    required this.style,
    required this.scale,
    required this.showVolume,
    required this.showGrid,
    this.tapPosition,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    // Calculate dimensions
    final volumeHeight = showVolume ? size.height * 0.2 : 0.0;
    final chartHeight = size.height - volumeHeight - 40; // 40 for padding
    final chartTop = 20.0;
    
    // Find price range
    final prices = candles.expand((c) => [c.high, c.low]).toList();
    final maxPrice = prices.reduce(math.max);
    final minPrice = prices.reduce(math.min);
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1; // 10% padding
    
    // Draw background
    final bgPaint = Paint()..color = style.backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Draw grid
    if (showGrid) {
      _drawGrid(canvas, size, chartTop, chartHeight, maxPrice, minPrice, padding);
    }
    
    // Calculate candle width
    final totalWidth = size.width - 40; // 40 for price axis
    final candleSpacing = (totalWidth / candles.length) * scale;
    final candleWidth = (candleSpacing * 0.7).clamp(1.0, 20.0);
    
    // Draw candles
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = 20 + (i * candleSpacing);
      
      _drawCandle(
        canvas,
        candle,
        x,
        chartTop,
        chartHeight,
        candleWidth,
        maxPrice + padding,
        minPrice - padding,
        isSelected: i == selectedIndex,
      );
      
      // Draw volume
      if (showVolume) {
        _drawVolume(
          canvas,
          candle,
          x,
          size.height - volumeHeight,
          candleWidth,
          volumeHeight,
          candles,
        );
      }
    }
    
    // Draw price axis
    _drawPriceAxis(canvas, size, chartTop, chartHeight, maxPrice, minPrice, padding);
    
    // Draw crosshair
    if (tapPosition != null) {
      _drawCrosshair(canvas, size, tapPosition!);
    }
  }
  
  void _drawCandle(
    Canvas canvas,
    CryptoCandle candle,
    double x,
    double top,
    double height,
    double width,
    double maxPrice,
    double minPrice,
    {bool isSelected = false}
  ) {
    final priceRange = maxPrice - minPrice;
    
    // Calculate positions
    final highY = top + ((maxPrice - candle.high) / priceRange) * height;
    final lowY = top + ((maxPrice - candle.low) / priceRange) * height;
    final openY = top + ((maxPrice - candle.open) / priceRange) * height;
    final closeY = top + ((maxPrice - candle.close) / priceRange) * height;
    
    final bodyTop = math.min(openY, closeY);
    final bodyBottom = math.max(openY, closeY);
    final bodyHeight = math.max(bodyBottom - bodyTop, 1.0);
    
    // Choose colors
    final wickColor = candle.isBullish ? style.bullishColor : style.bearishColor;
    final bodyColor = candle.isBullish ? style.bullishColor : style.bearishColor;
    
    // Draw wick (high-low line)
    final wickPaint = Paint()
      ..color = isSelected ? style.selectedColor : wickColor
      ..strokeWidth = style.wickWidth
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(x + width / 2, highY),
      Offset(x + width / 2, lowY),
      wickPaint,
    );
    
    // Draw body
    final bodyPaint = Paint()
      ..color = isSelected ? style.selectedColor : bodyColor
      ..style = candle.isBullish && style.bullishStyle == CandleBodyStyle.hollow
          ? PaintingStyle.stroke
          : PaintingStyle.fill
      ..strokeWidth = style.bodyBorderWidth;
    
    final bodyRect = Rect.fromLTWH(x, bodyTop, width, bodyHeight);
    
    if (style.candleStyle == CandleStyle.rounded) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(2)),
        bodyPaint,
      );
    } else {
      canvas.drawRect(bodyRect, bodyPaint);
    }
    
    // Draw border for hollow candles
    if (candle.isBullish && style.bullishStyle == CandleBodyStyle.hollow) {
      final borderPaint = Paint()
        ..color = isSelected ? style.selectedColor : bodyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.bodyBorderWidth;
      canvas.drawRect(bodyRect, borderPaint);
    }
  }
  
  void _drawVolume(
    Canvas canvas,
    CryptoCandle candle,
    double x,
    double top,
    double width,
    double volumeHeight,
    List<CryptoCandle> allCandles,
  ) {
    final maxVolume = allCandles.map((c) => c.volume).reduce(math.max);
    final barHeight = (candle.volume / maxVolume) * volumeHeight * 0.8;
    
    final volumePaint = Paint()
      ..color = (candle.isBullish ? style.bullishColor : style.bearishColor)
          .withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(x, top + volumeHeight - barHeight, width, barHeight),
      volumePaint,
    );
  }
  
  void _drawGrid(
    Canvas canvas,
    Size size,
    double top,
    double height,
    double maxPrice,
    double minPrice,
    double padding,
  ) {
    final gridPaint = Paint()
      ..color = style.gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // Horizontal lines
    for (int i = 0; i <= 5; i++) {
      final y = top + (height / 5) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width - 40, y),
        gridPaint,
      );
    }
    
    // Vertical lines (every 10 candles)
    final totalWidth = size.width - 40;
    final candleSpacing = (totalWidth / candles.length) * scale;
    for (int i = 0; i < candles.length; i += 10) {
      final x = 20 + (i * candleSpacing);
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + height),
        gridPaint,
      );
    }
  }
  
  void _drawPriceAxis(
    Canvas canvas,
    Size size,
    double top,
    double height,
    double maxPrice,
    double minPrice,
    double padding,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    final priceRange = maxPrice - minPrice;
    
    for (int i = 0; i <= 5; i++) {
      final price = maxPrice - (priceRange / 5) * i;
      final y = top + (height / 5) * i;
      
      textPainter.text = TextSpan(
        text: price.toStringAsFixed(2),
        style: TextStyle(
          color: style.textColor,
          fontSize: 10,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - 35, y - 6));
    }
  }
  
  void _drawCrosshair(Canvas canvas, Size size, Offset position) {
    final crosshairPaint = Paint()
      ..color = style.crosshairColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Vertical line
    canvas.drawLine(
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      crosshairPaint,
    );
    
    // Horizontal line
    canvas.drawLine(
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(CandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.scale != scale ||
        oldDelegate.tapPosition != tapPosition ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

// ===== INTERACTIVE CANDLESTICK PAINTER (with zoom & pan support) =====
class InteractiveCandlestickPainter extends CustomPainter {
  final List<CryptoCandle> candles;
  final CandlestickStyle style;
  final double scale;
  final Offset offset;
  final bool showVolume;
  final bool showGrid;
  final Offset? tapPosition;
  final int? selectedIndex;
  
  InteractiveCandlestickPainter({
    required this.candles,
    required this.style,
    required this.scale,
    required this.offset,
    required this.showVolume,
    required this.showGrid,
    this.tapPosition,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    // Calculate dimensions
    final volumeHeight = showVolume ? size.height * 0.2 : 0.0;
    final chartHeight = size.height - volumeHeight - 40;
    final chartTop = 20.0;
    
    // Calculate candle width with zoom
    final totalWidth = size.width - 40;
    final candleSpacing = ((totalWidth / candles.length) * scale).clamp(1.0, 100.0);
    final candleWidth = (candleSpacing * 0.7).clamp(1.0, 50.0);
    
    // Find visible range for price calculation
    final startX = -offset.dx;
    final endX = startX + size.width;
    final visibleStartIndex = ((startX / candleSpacing) - 10).floor().clamp(0, candles.length - 1);
    final visibleEndIndex = ((endX / candleSpacing) + 10).ceil().clamp(0, candles.length);
    
    // Get visible candles for price range
    final visibleCandles = candles.sublist(visibleStartIndex, visibleEndIndex);
    
    final prices = visibleCandles.isEmpty 
        ? candles.expand((c) => [c.high, c.low]).toList()
        : visibleCandles.expand((c) => [c.high, c.low]).toList();
    
    final maxPrice = prices.isNotEmpty ? prices.reduce(math.max) : 100.0;
    final minPrice = prices.isNotEmpty ? prices.reduce(math.min) : 0.0;
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;
    
    // Draw background with futuristic gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0A0E17),
          const Color(0xFF0F1419),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Draw grid
    if (showGrid) {
      _drawGrid(canvas, size, chartTop, chartHeight, maxPrice, minPrice, padding);
    }
    
    // Save canvas state for clipping
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, chartTop, size.width - 40, chartHeight));
    
    // Draw candles - NO BOUNDS, allow scrolling beyond
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = 20 + (i * candleSpacing) + offset.dx;
      
      // Draw ALL candles, even if outside visible area (will be clipped)
      _drawCandle(
        canvas,
        candle,
        x,
        chartTop,
        chartHeight,
        candleWidth,
        maxPrice + padding,
        minPrice - padding,
        isSelected: i == selectedIndex,
      );
      
      // Draw volume
      if (showVolume) {
        _drawVolume(
          canvas,
          candle,
          x,
          size.height - volumeHeight,
          candleWidth,
          volumeHeight,
          candles,
        );
      }
    }
    
    canvas.restore();
    
    // Draw price axis
    _drawPriceAxis(canvas, size, chartTop, chartHeight, maxPrice, minPrice, padding);
    
    // Draw crosshair
    if (tapPosition != null) {
      _drawCrosshair(canvas, size, tapPosition!);
    }
    
    // Draw zoom indicator
    _drawZoomIndicator(canvas, size);
  }
  
  void _drawCandle(
    Canvas canvas,
    CryptoCandle candle,
    double x,
    double top,
    double height,
    double width,
    double maxPrice,
    double minPrice,
    {bool isSelected = false}
  ) {
    final priceRange = maxPrice - minPrice;
    
    final highY = top + ((maxPrice - candle.high) / priceRange) * height;
    final lowY = top + ((maxPrice - candle.low) / priceRange) * height;
    final openY = top + ((maxPrice - candle.open) / priceRange) * height;
    final closeY = top + ((maxPrice - candle.close) / priceRange) * height;
    
    final bodyTop = math.min(openY, closeY);
    final bodyBottom = math.max(openY, closeY);
    final bodyHeight = math.max(bodyBottom - bodyTop, 1.0);
    
    final wickColor = candle.isBullish ? style.bullishColor : style.bearishColor;
    final bodyColor = candle.isBullish ? style.bullishColor : style.bearishColor;
    
    // Draw wick with glow effect
    final wickPaint = Paint()
      ..color = isSelected ? style.selectedColor : wickColor
      ..strokeWidth = style.wickWidth
      ..style = PaintingStyle.stroke;
    
    if (isSelected) {
      final glowPaint = Paint()
        ..color = style.selectedColor.withOpacity(0.3)
        ..strokeWidth = style.wickWidth * 3
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawLine(
        Offset(x + width / 2, highY),
        Offset(x + width / 2, lowY),
        glowPaint,
      );
    }
    
    canvas.drawLine(
      Offset(x + width / 2, highY),
      Offset(x + width / 2, lowY),
      wickPaint,
    );
    
    // Draw body with glow
    final bodyPaint = Paint()
      ..color = isSelected ? style.selectedColor : bodyColor
      ..style = candle.isBullish && style.bullishStyle == CandleBodyStyle.hollow
          ? PaintingStyle.stroke
          : PaintingStyle.fill
      ..strokeWidth = style.bodyBorderWidth;
    
    final bodyRect = Rect.fromLTWH(x, bodyTop, width, bodyHeight);
    
    if (isSelected) {
      final glowPaint = Paint()
        ..color = style.selectedColor.withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect.inflate(2), Radius.circular(3)),
        glowPaint,
      );
    }
    
    if (style.candleStyle == CandleStyle.rounded) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(2)),
        bodyPaint,
      );
    } else {
      canvas.drawRect(bodyRect, bodyPaint);
    }
    
    if (candle.isBullish && style.bullishStyle == CandleBodyStyle.hollow) {
      final borderPaint = Paint()
        ..color = isSelected ? style.selectedColor : bodyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.bodyBorderWidth;
      canvas.drawRect(bodyRect, borderPaint);
    }
  }
  
  void _drawVolume(
    Canvas canvas,
    CryptoCandle candle,
    double x,
    double top,
    double width,
    double volumeHeight,
    List<CryptoCandle> allCandles,
  ) {
    final maxVolume = allCandles.map((c) => c.volume).reduce(math.max);
    final barHeight = (candle.volume / maxVolume) * volumeHeight * 0.8;
    
    final volumePaint = Paint()
      ..color = (candle.isBullish ? style.bullishColor : style.bearishColor)
          .withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(x, top + volumeHeight - barHeight, width, barHeight),
      volumePaint,
    );
  }
  
  void _drawGrid(
    Canvas canvas,
    Size size,
    double top,
    double height,
    double maxPrice,
    double minPrice,
    double padding,
  ) {
    final gridPaint = Paint()
      ..color = style.gridColor.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // Horizontal lines with subtle glow
    for (int i = 0; i <= 5; i++) {
      final y = top + (height / 5) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width - 40, y),
        gridPaint,
      );
    }
  }
  
  void _drawPriceAxis(
    Canvas canvas,
    Size size,
    double top,
    double height,
    double maxPrice,
    double minPrice,
    double padding,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    final priceRange = maxPrice - minPrice;
    
    // Draw axis background
    final axisPaint = Paint()
      ..color = const Color(0xFF0F1419);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 40, 0, 40, size.height),
      axisPaint,
    );
    
    for (int i = 0; i <= 5; i++) {
      final price = maxPrice - (priceRange / 5) * i;
      final y = top + (height / 5) * i;
      
      textPainter.text = TextSpan(
        text: price.toStringAsFixed(2),
        style: TextStyle(
          color: style.textColor,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - 38, y - 6));
    }
  }
  
  void _drawCrosshair(Canvas canvas, Size size, Offset position) {
    final crosshairPaint = Paint()
      ..color = style.crosshairColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Vertical line with glow
    final glowPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawLine(
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      glowPaint,
    );
    
    canvas.drawLine(
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      crosshairPaint,
    );
    
    canvas.drawLine(
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      glowPaint,
    );
    
    canvas.drawLine(
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      crosshairPaint,
    );
  }
  
  void _drawZoomIndicator(Canvas canvas, Size size) {
    if (scale == 1.0) return;
    
    final text = '${(scale * 100).toStringAsFixed(0)}%';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Draw background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - 60,
        10,
        textPainter.width + 12,
        textPainter.height + 8,
      ),
      Radius.circular(4),
    );
    
    final bgPaint = Paint()
      ..color = const Color(0xFF0F1419).withOpacity(0.9);
    
    final borderPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPaint);
    
    textPainter.paint(canvas, Offset(size.width - 54, 14));
  }

  @override
  bool shouldRepaint(InteractiveCandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.tapPosition != tapPosition ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

// ===== STYLE CONFIGURATION =====
class CandlestickStyle {
  final Color bullishColor;
  final Color bearishColor;
  final Color backgroundColor;
  final Color gridColor;
  final Color textColor;
  final Color crosshairColor;
  final Color selectedColor;
  
  final CandleBodyStyle bullishStyle;
  final CandleBodyStyle bearishStyle;
  final CandleStyle candleStyle;
  
  final double wickWidth;
  final double bodyBorderWidth;
  
  CandlestickStyle({
    this.bullishColor = const Color(0xFF26A69A), // Green
    this.bearishColor = const Color(0xFFEF5350), // Red
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.gridColor = const Color(0xFF2D2D2D),
    this.textColor = const Color(0xFFB2B5BE),
    this.crosshairColor = const Color(0xFF787B86),
    this.selectedColor = const Color(0xFFFFD700), // Gold
    this.bullishStyle = CandleBodyStyle.filled,
    this.bearishStyle = CandleBodyStyle.filled,
    this.candleStyle = CandleStyle.normal,
    this.wickWidth = 1.0,
    this.bodyBorderWidth = 1.0,
  });
  
  CandlestickStyle copyWith({
    Color? bullishColor,
    Color? bearishColor,
    Color? backgroundColor,
    Color? gridColor,
    Color? textColor,
    Color? crosshairColor,
    Color? selectedColor,
    CandleBodyStyle? bullishStyle,
    CandleBodyStyle? bearishStyle,
    CandleStyle? candleStyle,
    double? wickWidth,
    double? bodyBorderWidth,
  }) {
    return CandlestickStyle(
      bullishColor: bullishColor ?? this.bullishColor,
      bearishColor: bearishColor ?? this.bearishColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gridColor: gridColor ?? this.gridColor,
      textColor: textColor ?? this.textColor,
      crosshairColor: crosshairColor ?? this.crosshairColor,
      selectedColor: selectedColor ?? this.selectedColor,
      bullishStyle: bullishStyle ?? this.bullishStyle,
      bearishStyle: bearishStyle ?? this.bearishStyle,
      candleStyle: candleStyle ?? this.candleStyle,
      wickWidth: wickWidth ?? this.wickWidth,
      bodyBorderWidth: bodyBorderWidth ?? this.bodyBorderWidth,
    );
  }
}

enum CandleBodyStyle {
  filled,   // Solid color
  hollow,   // Outline only
}

enum CandleStyle {
  normal,   // Square candles
  rounded,  // Rounded corners
}