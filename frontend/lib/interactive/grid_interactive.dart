import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../candle/candle_normal.dart';

// ─────────────────────────────────────────────
// Modern Dark Theme — Anthracite + Neon Palette
// ─────────────────────────────────────────────
abstract class TradingColors {
  // Anthracite background family
  static const Color background       = Color(0xFF0D0F14);   // deepest layer
  static const Color surface          = Color(0xFF141720);   // card base
  static const Color surfaceElevated  = Color(0xFF1C1F2A);   // raised glass
  static const Color border           = Color(0xFF262A35);   // subtle divider

  // Accent pair
  static const Color neonGreen  = Color(0xFF00FFA3);  // Buy
  static const Color crimsonRed = Color(0xFFFF3D5A);  // Sell

  // Neutral text
  static const Color textPrimary   = Color(0xFFE8EAF0);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted     = Color(0xFF3D4251);

  // Grid & glass
  static const Color gridLine      = Color(0xFF1E2230);
  static const Color glassFill     = Color(0x1AFFFFFF);  // 10% white
  static const Color glassBorder   = Color(0x26FFFFFF);  // 15% white
}

abstract class TradingTypography {

  static const String fontFamily = 'RobotoMono';

  static const TextStyle priceLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: TradingColors.textPrimary,
  );

  static const TextStyle priceSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: TradingColors.textSecondary,
  );

  static const TextStyle timeLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    color: TradingColors.textSecondary,
  );
}

// ─────────────────────────────────────────────
// Spacing & Sizing tokens
// ─────────────────────────────────────────────
abstract class TradingLayout {
  static const double paddingXS  = 4.0;
  static const double paddingS   = 6.0;
  static const double paddingM   = 8.0;
  static const double paddingL   = 12.0;

  static const double radius     = 16.0;
  static const double radiusS    = 8.0;
  static const double radiusXS   = 4.0;

  static const double strokeThin = 0.5;
  static const double strokeGrid = 0.75;

  // Consistent vertical padding for every row in the grid
  static const double rowPaddingV = 6.0;
}

// ─────────────────────────────────────────────
// GridInteractive — Modern Dark Theme Painter
// ─────────────────────────────────────────────
class GridInteractive extends CustomPainter {
  final List<CryptoCandle> candles;
  final CandlestickStyle style;
  final double scale;
  final Offset offset;   // FIX 1: hapus duplikat, sisakan satu
  final double offsetY;
  final bool showVolume;
  final String selectedInterval;

  GridInteractive({
    required this.candles,
    required this.style,
    required this.scale,
    required this.offset,
    required this.offsetY,
    required this.showVolume,
    required this.selectedInterval,
  });

  // ── Cached paints (created once per paint call) ──────────────────────────

  late final Paint _gridPaint = Paint()
    ..color = TradingColors.gridLine
    ..strokeWidth = TradingLayout.strokeGrid
    ..isAntiAlias = false;

  late final Paint _gridSubtlePaint = Paint()
    ..color = TradingColors.gridLine.withOpacity(0.45)
    ..strokeWidth = TradingLayout.strokeThin
    ..isAntiAlias = false;

  late final Paint _glassFill = Paint()
    ..color = TradingColors.glassFill;

  late final Paint _glassBorder = Paint()
    ..color = TradingColors.glassBorder
    ..style = PaintingStyle.stroke
    ..strokeWidth = TradingLayout.strokeThin;

  late final Paint _buyAccentPaint = Paint()
    ..color = TradingColors.neonGreen.withOpacity(0.08);

  late final Paint _sellAccentPaint = Paint()
    ..color = TradingColors.crimsonRed.withOpacity(0.08);

  @override
  void paint(Canvas canvas, Size size) {
    if (!DataValidator.isCandlesValid(candles)) return;

    final maxPrice   = PriceRangeHelper.getMaxPrice(candles);
    final minPrice   = PriceRangeHelper.getMinPrice(candles);
    final priceRange = PriceRangeHelper.getPriceRange(candles);
    final chartHeight = showVolume ? size.height * 0.70 : size.height;

    _drawBackground(canvas, size, chartHeight);
    _drawGrid(canvas, size, chartHeight, minPrice, maxPrice, priceRange);
    if (showVolume) _drawVolumeZoneDivider(canvas, size, chartHeight);
  }

  // ── Background — subtle scanline texture feel ────────────────────────────
  void _drawBackground(Canvas canvas, Size size, double chartHeight) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, chartHeight),
      Paint()..color = TradingColors.background,
    );

    final scanPaint = Paint()..color = Colors.white.withOpacity(0.012);
    for (double y = 0; y < chartHeight; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scanPaint);
    }

    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          TradingColors.surfaceElevated.withOpacity(0.30),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight * 0.35));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, chartHeight * 0.35),
      gradPaint,
    );
  }

  // ── Volume zone separator ─────────────────────────────────────────────────
  void _drawVolumeZoneDivider(Canvas canvas, Size size, double chartHeight) {
    final paint = Paint()
      ..color = TradingColors.neonGreen.withOpacity(0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, chartHeight, size.width, size.height - chartHeight),
      Paint()..color = TradingColors.surface,
    );
  }

  // ── Main grid ─────────────────────────────────────────────────────────────
  void _drawGrid(
    Canvas canvas,
    Size size,
    double chartHeight,
    double minPrice,
    double maxPrice,
    double priceRange,
  ) {
    _drawHorizontalGrid(canvas, size, chartHeight, minPrice, maxPrice, priceRange);
    _drawVerticalGrid(canvas, size, chartHeight);
  }

  // ── Horizontal grid + price labels ───────────────────────────────────────
  void _drawHorizontalGrid(
    Canvas canvas,
    Size size,
    double chartHeight,
    double minPrice,
    double maxPrice,
    double priceRange,
  ) {
    const int lines = 8;
    final double midY    = chartHeight / 2;
    final double midPrice = (maxPrice + minPrice) / 2;

    // FIX 2: hapus loop duplikat, satukan jadi satu loop yang benar
    for (int i = 0; i <= lines; i++) {
      final double y     = (chartHeight / lines) * i;
      final bool isMidLine = i == lines ~/ 2;
      final bool isEdge    = i == 0 || i == lines;

      // Alternate row tinting (buy zone above mid, sell zone below)
      if (!isEdge && i % 2 == 0) {
        final double zoneTop  = y - (chartHeight / lines);
        final zoneColor = y < midY ? _buyAccentPaint : _sellAccentPaint;
        canvas.drawRect(
          Rect.fromLTWH(0, zoneTop, size.width, chartHeight / lines),
          zoneColor,
        );
      }

      // Horizontal line — mid-line solid, lainnya dashed
      final linePaint = isMidLine ? _gridPaint : _gridSubtlePaint;
      _drawDashedHorizontal(canvas, size.width, y, linePaint, isMidLine);

      // FIX 3: panggil _drawPriceLabel dengan benar di sini
      if (!isEdge) {
        final double price = maxPrice - (priceRange / lines) * i;
        _drawPriceLabel(canvas, size, y, price, isMidLine);
      }
    }
  }

  void _drawDashedHorizontal(
    Canvas canvas,
    double width,
    double y,
    Paint paint,
    bool solid,
  ) {
    if (solid) {
      canvas.drawLine(Offset(0, y), Offset(width, y), paint);
      return;
    }
    const double dashLen = 6.0;
    const double gapLen  = 4.0;
    double x = 0;
    while (x < width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashLen, y), paint);
      x += dashLen + gapLen;
    }
  }

  void _drawPriceLabel(
    Canvas canvas,
    Size size,
    double y,
    double price,
    bool highlight,
  ) {
    final textStyle = highlight
        ? TradingTypography.priceLarge.copyWith(color: TradingColors.neonGreen)
        : TradingTypography.priceSmall;

    final priceText = ChartHelpers.formatPrice(price);
    final tp = TextPainter(
      text: TextSpan(text: priceText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    const double ph = TradingLayout.paddingS;
    const double pv = TradingLayout.rowPaddingV;

    final double lw = tp.width + ph * 2;
    final double lh = tp.height + pv * 2;
    final double lx = size.width - lw - TradingLayout.paddingXS;
    final double ly = y - lh / 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(lx, ly, lw, lh),
      const Radius.circular(TradingLayout.radiusXS),
    );

    canvas.drawRRect(rrect, _glassFill);
    canvas.drawRRect(rrect, _glassBorder);

    if (highlight) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lx, ly, 2, lh),
          const Radius.circular(1),
        ),
        Paint()..color = TradingColors.neonGreen,
      );
    }

    tp.paint(canvas, Offset(lx + ph, ly + pv));
  }

  // ── Vertical grid + time labels ──────────────────────────────────────────
  void _drawVerticalGrid(Canvas canvas, Size size, double chartHeight) {
    final double candleWidth    = (size.width / candles.length) * scale;
    final int    visibleCandles = (size.width / candleWidth).ceil();

    final int step = switch (visibleCandles) {
      > 100 => 20,
      > 50  => 10,
      > 20  => 5,
      _     => 2,
    };

    for (int i = 0; i < candles.length; i += step) {
      final double x = (i * candleWidth) + offset.dx;
      if (x < 0 || x > size.width) continue;

      _drawDashedVertical(canvas, x, chartHeight, _gridSubtlePaint);

      if (!DataValidator.isIndexInRange(i, candles)) continue;

      final candle     = candles[i];
      final candleTime = CandleDateTimeHelper.getDateTime(candle);
      final timeText   = ChartHelpers.formatTime(candleTime, selectedInterval);

      _drawTimeLabel(canvas, size, x, chartHeight, timeText);
    }
  }

  void _drawDashedVertical(
    Canvas canvas,
    double x,
    double height,
    Paint paint,
  ) {
    const double dashLen = 5.0;
    const double gapLen  = 4.0;
    double y = 0;
    while (y < height) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dashLen), paint);
      y += dashLen + gapLen;
    }
  }

  void _drawTimeLabel(
    Canvas canvas,
    Size size,
    double x,
    double chartHeight,
    String text,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TradingTypography.timeLabel),
      textDirection: TextDirection.ltr,
    )..layout();

    const double ph = TradingLayout.paddingS;
    const double pv = TradingLayout.rowPaddingV;

    final double lw = tp.width + ph * 2;
    final double lh = tp.height + pv * 2;
    final double lx = x - lw / 2;
    final double ly = chartHeight - lh - TradingLayout.paddingM;

    if (lx < 0 || lx + lw > size.width) return;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(lx, ly, lw, lh),
      const Radius.circular(TradingLayout.radiusXS),
    );

    canvas.drawRRect(rrect, _glassFill);
    canvas.drawRRect(rrect, _glassBorder);
    tp.paint(canvas, Offset(lx + ph, ly + pv));
  }

  @override
  bool shouldRepaint(covariant GridInteractive old) {
    return old.candles          != candles          ||
           old.scale            != scale            ||
           old.offset           != offset           ||
           old.showVolume       != showVolume       ||
           old.selectedInterval != selectedInterval;
  }
}

// ─────────────────────────────────────────────
// Glassmorphism Card Widget
// ─────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? accentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TradingLayout.radius),
        color: TradingColors.glassFill,
        border: Border.all(
          color: accentColor != null
              ? accentColor!.withOpacity(0.35)
              : TradingColors.glassBorder,
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (accentColor != null)
            BoxShadow(
              color: accentColor!.withOpacity(0.12),
              blurRadius: 16,
              spreadRadius: -4,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TradingLayout.radius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(TradingLayout.paddingL),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Buy / Sell Pill Badge
// ─────────────────────────────────────────────
class TradingBadge extends StatelessWidget {
  final bool isBuy;
  final String label;

  const TradingBadge({super.key, required this.isBuy, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = isBuy ? TradingColors.neonGreen : TradingColors.crimsonRed;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TradingLayout.paddingL,
        vertical: TradingLayout.rowPaddingV,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TradingLayout.radius),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.40), width: 0.75),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: TradingTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}