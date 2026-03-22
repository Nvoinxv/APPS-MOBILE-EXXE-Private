import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../hooks/crypto_data_hook.dart';

/// Futuristic volume bars component with TradingView style
class FuturisticVolumeBar extends StatelessWidget {
  final List<CryptoCandle> candles;
  final Color bullishColor;
  final Color bearishColor;
  final Color backgroundColor;
  final double scale;
  final Offset offset;
  final int? selectedIndex;
  final double height;
  
  const FuturisticVolumeBar({
    Key? key,
    required this.candles,
    required this.bullishColor,
    required this.bearishColor,
    required this.backgroundColor,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.selectedIndex,
    this.height = 100,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: VolumeBarPainter(
          candles: candles,
          bullishColor: bullishColor,
          bearishColor: bearishColor,
          backgroundColor: backgroundColor,
          scale: scale,
          offset: offset,
          selectedIndex: selectedIndex,
        ),
        child: Container(),
      ),
    );
  }
}

/// Custom painter for volume bars
class VolumeBarPainter extends CustomPainter {
  final List<CryptoCandle> candles;
  final Color bullishColor;
  final Color bearishColor;
  final Color backgroundColor;
  final double scale;
  final Offset offset;
  final int? selectedIndex;

  VolumeBarPainter({
    required this.candles,
    required this.bullishColor,
    required this.bearishColor,
    required this.backgroundColor,
    required this.scale,
    required this.offset,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    // Find max volume for scaling
    final maxVolume = candles.map((c) => c.volume).reduce((a, b) => a > b ? a : b);
    if (maxVolume == 0) return;

    final candleCount = candles.length;
    final barWidth = (size.width / candleCount) * scale;
    final barSpacing = barWidth * 0.2; // 20% spacing untuk lebih clean
    final actualBarWidth = barWidth - barSpacing;

    // Draw volume bars
    for (int i = 0; i < candleCount; i++) {
      final candle = candles[i];
      final isBullish = candle.close >= candle.open;
      final isSelected = i == selectedIndex;
      
      // Calculate position
      final x = (i * barWidth) + offset.dx + (barSpacing / 2);
      
      // Skip if outside visible area
      if (x + actualBarWidth < 0 || x > size.width) continue;
      
      // Calculate bar height (normalized)
      final volumeRatio = candle.volume / maxVolume;
      final barHeight = size.height * volumeRatio * 0.95; // 95% max height for padding
      final y = size.height - barHeight;

      // Determine colors
      final baseColor = isBullish ? bullishColor : bearishColor;

      // Draw main bar with gradient (clean, no glow)
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth * 0.1),
      );
      
      // Gradient from bottom (bright) to top (darker) - lebih subtle
      final gradient = ui.Gradient.linear(
        Offset(x, size.height),
        Offset(x, y),
        [
          baseColor.withOpacity(0.5),
          baseColor.withOpacity(0.75),
          baseColor.withOpacity(isSelected ? 0.95 : 0.85),
        ],
        [0.0, 0.5, 1.0],
      );
      
      final barPaint = Paint()
        ..shader = gradient
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(barRect, barPaint);

      // Top cap (solid color untuk emphasis)
      if (barHeight > 3) {
        final capHeight = barHeight > 20 ? 3.0 : 2.0;
        final capPaint = Paint()
          ..color = baseColor.withOpacity(isSelected ? 1.0 : 0.9)
          ..style = PaintingStyle.fill;
        
        final capRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, actualBarWidth, capHeight),
          Radius.circular(actualBarWidth * 0.1),
        );
        
        canvas.drawRRect(capRect, capPaint);
      }

      // Selection indicator (simple clean border)
      if (isSelected) {
        final selectionBorderPaint = Paint()
          ..color = baseColor.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        
        canvas.drawRRect(
          barRect.inflate(1),
          selectionBorderPaint,
        );
      }
    }

    // Draw volume scale indicator (max volume line)
    _drawVolumeScaleIndicator(canvas, size, maxVolume);
  }

  void _drawVolumeScaleIndicator(Canvas canvas, Size size, double maxVolume) {
    // Draw subtle max volume reference line at 80%
    final y80 = size.height * 0.2; // 20% from top = 80% of max
    
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Dashed line
    final dashWidth = 4.0;
    final dashSpace = 4.0;
    var startX = 0.0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y80),
        Offset((startX + dashWidth).clamp(0, size.width), y80),
        linePaint,
      );
      startX += dashWidth + dashSpace;
    }

    // Draw volume label
    final volumeText = _formatVolume(maxVolume);
    final textSpan = TextSpan(
      text: volumeText,
      style: TextStyle(
        color: Colors.white.withOpacity(0.3),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(4, y80 - textPainter.height - 2),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(VolumeBarPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.bullishColor != bullishColor ||
        oldDelegate.bearishColor != bearishColor;
  }
}

/// Volume info panel widget
class VolumeInfoPanel extends StatelessWidget {
  final CryptoCandle? selectedCandle;
  final Color textColor;
  final Color bullishColor;
  final Color bearishColor;
  
  const VolumeInfoPanel({
    Key? key,
    required this.selectedCandle,
    required this.textColor,
    required this.bullishColor,
    required this.bearishColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedCandle == null) return const SizedBox.shrink();
    
    final isBullish = selectedCandle!.close >= selectedCandle!.open;
    final volumeColor = isBullish ? bullishColor : bearishColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Volume icon
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: volumeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.bar_chart,
              size: 12,
              color: volumeColor,
            ),
          ),
          const SizedBox(width: 8),
          
          // Volume text
          Text(
            'Vol: ',
            style: TextStyle(
              color: textColor.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          Text(
            _formatVolume(selectedCandle!.volume),
            style: TextStyle(
              color: volumeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(2)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(2)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(2)}K';
    }
    return volume.toStringAsFixed(0);
  }
}