import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

/// Smooth crosshair widget with TradingView-like interaction
class SmoothCrosshair extends StatefulWidget {
  final Offset? position;
  final Color color;
  final double strokeWidth;
  final Size chartSize;
  final bool showLabels;
  final String? priceLabel;
  final String? timeLabel;
  final Color labelBackgroundColor;
  final Color labelTextColor;
  final Function(Offset)? onPositionChanged;
  
  const SmoothCrosshair({
    Key? key,
    required this.position,
    this.color = const Color(0xFF00FF88),
    this.strokeWidth = 1.0,
    required this.chartSize,
    this.showLabels = true,
    this.priceLabel,
    this.timeLabel,
    this.labelBackgroundColor = const Color(0xFF1A2332),
    this.labelTextColor = const Color(0xFF00FF88),
    this.onPositionChanged,
  }) : super(key: key);

  @override
  State<SmoothCrosshair> createState() => _SmoothCrosshairState();
}

class _SmoothCrosshairState extends State<SmoothCrosshair>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Offset? _currentPosition;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
    
    if (widget.position != null) {
      _currentPosition = widget.position;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SmoothCrosshair oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.position != oldWidget.position) {
      if (widget.position != null) {
        setState(() {
          _currentPosition = widget.position;
        });
        if (!_controller.isAnimating && _controller.value == 0.0) {
          _controller.forward();
        }
      } else if (!_isInteracting) {
        _controller.reverse().then((_) {
          if (mounted && !_isInteracting) {
            setState(() {
              _currentPosition = null;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isInteracting = true;
      _currentPosition = details.localPosition;
      _controller.forward();
    });
    widget.onPositionChanged?.call(details.localPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPosition = details.localPosition;
    });
    widget.onPositionChanged?.call(details.localPosition);
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isInteracting = false;
    });
    
    // Fade out after a delay if no new position
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isInteracting && widget.position == null) {
        _controller.reverse().then((_) {
          if (mounted && !_isInteracting) {
            setState(() {
              _currentPosition = null;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) return const SizedBox.shrink();

    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: widget.chartSize,
            painter: CrosshairPainter(
              position: _currentPosition!,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
              showLabels: widget.showLabels,
              priceLabel: widget.priceLabel,
              timeLabel: widget.timeLabel,
              labelBackgroundColor: widget.labelBackgroundColor,
              labelTextColor: widget.labelTextColor,
              opacity: _fadeAnimation.value,
              isInteracting: _isInteracting,
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for smooth crosshair lines
class CrosshairPainter extends CustomPainter {
  final Offset position;
  final Color color;
  final double strokeWidth;
  final bool showLabels;
  final String? priceLabel;
  final String? timeLabel;
  final Color labelBackgroundColor;
  final Color labelTextColor;
  final double opacity;
  final bool isInteracting;

  CrosshairPainter({
    required this.position,
    required this.color,
    required this.strokeWidth,
    required this.showLabels,
    this.priceLabel,
    this.timeLabel,
    required this.labelBackgroundColor,
    required this.labelTextColor,
    this.opacity = 1.0,
    this.isInteracting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dashed line style for more professional look
    final linePaint = Paint()
      ..color = color.withOpacity(0.6 * opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Subtle glow effect (lebih halus dari sebelumnya)
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15 * opacity)
      ..strokeWidth = strokeWidth * 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Draw dashed vertical line
    _drawDashedLine(
      canvas,
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      glowPaint,
      dashWidth: 4,
      dashSpace: 3,
    );
    
    _drawDashedLine(
      canvas,
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      linePaint,
      dashWidth: 4,
      dashSpace: 3,
    );

    // Draw dashed horizontal line
    _drawDashedLine(
      canvas,
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      glowPaint,
      dashWidth: 4,
      dashSpace: 3,
    );
    
    _drawDashedLine(
      canvas,
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      linePaint,
      dashWidth: 4,
      dashSpace: 3,
    );

    // Draw center point with pulsing effect when interacting
    final centerSize = isInteracting ? 4.0 : 3.0;
    final ringSize = isInteracting ? 8.0 : 6.0;
    
    // Center dot glow
    final centerGlowPaint = Paint()
      ..color = color.withOpacity(0.3 * opacity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(position, centerSize + 2, centerGlowPaint);
    
    // Center dot
    final centerPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, centerSize, centerPaint);
    
    // Outer ring
    final ringPaint = Paint()
      ..color = color.withOpacity(0.4 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawCircle(position, ringSize, ringPaint);

    // Draw labels if enabled
    if (showLabels && opacity > 0.3) {
      if (priceLabel != null) {
        _drawPriceLabel(canvas, size);
      }
      if (timeLabel != null) {
        _drawTimeLabel(canvas, size);
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 3,
  }) {
    final path = Path();
    final distance = (end - start).distance;
    final normalizedVector = Offset(
      (end.dx - start.dx) / distance,
      (end.dy - start.dy) / distance,
    );

    var currentDistance = 0.0;
    var isDash = true;

    while (currentDistance < distance) {
      final segmentLength = isDash ? dashWidth : dashSpace;
      final nextDistance = currentDistance + segmentLength;
      
      if (isDash) {
        final segmentStart = Offset(
          start.dx + normalizedVector.dx * currentDistance,
          start.dy + normalizedVector.dy * currentDistance,
        );
        final segmentEnd = Offset(
          start.dx + normalizedVector.dx * nextDistance.clamp(0, distance),
          start.dy + normalizedVector.dy * nextDistance.clamp(0, distance),
        );
        
        path.moveTo(segmentStart.dx, segmentStart.dy);
        path.lineTo(segmentEnd.dx, segmentEnd.dy);
      }
      
      currentDistance = nextDistance;
      isDash = !isDash;
    }

    canvas.drawPath(path, paint);
  }

  void _drawPriceLabel(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: priceLabel,
      style: TextStyle(
        color: labelTextColor.withOpacity(opacity),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();

    // Label styling
    final padding = 6.0;
    final labelWidth = textPainter.width + padding * 2;
    final labelHeight = textPainter.height + padding * 2;
    
    // Position on right side
    final labelLeft = size.width - labelWidth - 4;
    final labelTop = (position.dy - labelHeight / 2).clamp(
      4.0,
      size.height - labelHeight - 4,
    );

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelLeft, labelTop, labelWidth, labelHeight),
      const Radius.circular(3),
    );

    // Shadow with opacity
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawRRect(labelRect.shift(const Offset(1, 1)), shadowPaint);

    // Background
    final bgPaint = Paint()
      ..color = labelBackgroundColor.withOpacity(0.95 * opacity)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(labelRect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = color.withOpacity(0.7 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(labelRect, borderPaint);

    // Text
    textPainter.paint(
      canvas,
      Offset(labelLeft + padding, labelTop + padding),
    );
  }

  void _drawTimeLabel(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: timeLabel,
      style: TextStyle(
        color: labelTextColor.withOpacity(opacity),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();

    // Label styling
    final padding = 6.0;
    final labelWidth = textPainter.width + padding * 2;
    final labelHeight = textPainter.height + padding * 2;
    
    // Position at bottom, centered on x
    final labelLeft = (position.dx - labelWidth / 2).clamp(
      4.0,
      size.width - labelWidth - 4,
    );
    final labelTop = size.height - labelHeight - 4;

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelLeft, labelTop, labelWidth, labelHeight),
      const Radius.circular(3),
    );

    // Shadow with opacity
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawRRect(labelRect.shift(const Offset(1, 1)), shadowPaint);

    // Background
    final bgPaint = Paint()
      ..color = labelBackgroundColor.withOpacity(0.95 * opacity)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(labelRect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = color.withOpacity(0.7 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(labelRect, borderPaint);

    // Text
    textPainter.paint(
      canvas,
      Offset(labelLeft + padding, labelTop + padding),
    );
  }

  @override
  bool shouldRepaint(CrosshairPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.color != color ||
        oldDelegate.priceLabel != priceLabel ||
        oldDelegate.timeLabel != timeLabel ||
        oldDelegate.opacity != opacity ||
        oldDelegate.isInteracting != isInteracting;
  }
}