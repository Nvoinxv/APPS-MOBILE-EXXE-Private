import 'package:flutter/material.dart';
import 'dart:math' as math;

// ===== FIBONACCI RETRACEMENT DATA MODEL =====
class FibonacciRetracement {
  Offset startPoint;
  Offset endPoint;
  bool isVisible;
  
  // Standard Fibonacci levels
  static const List<double> levels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];
  static const List<String> levelLabels = ['0%', '23.6%', '38.2%', '50%', '61.8%', '78.6%', '100%'];
  
  FibonacciRetracement({
    required this.startPoint,
    required this.endPoint,
    this.isVisible = true,
  });
  
  // Calculate price at each Fibonacci level
  double getPriceAtLevel(double level, double minPrice, double maxPrice, double chartHeight) {
    final priceRange = maxPrice - minPrice;
    final startY = startPoint.dy;
    final endY = endPoint.dy;
    
    // Convert Y position to price
    final startPrice = maxPrice - ((startY / chartHeight) * priceRange);
    final endPrice = maxPrice - ((endY / chartHeight) * priceRange);
    final fibPrice = startPrice + (endPrice - startPrice) * level;
    
    return fibPrice;
  }
  
  // Get Y position for a Fibonacci level
  double getYAtLevel(double level) {
    return startPoint.dy + (endPoint.dy - startPoint.dy) * level;
  }
  
  // Check if point is near start or end handle
  bool isNearStartHandle(Offset point, double threshold) {
    return (point - startPoint).distance < threshold;
  }
  
  bool isNearEndHandle(Offset point, double threshold) {
    return (point - endPoint).distance < threshold;
  }
}

// ===== FIBONACCI INTERACTIVE WIDGET =====
class FibonacciInteractive extends StatefulWidget {
  final Size chartSize;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final double minPrice;
  final double maxPrice;
  final VoidCallback? onFibonacciChanged;
  
  const FibonacciInteractive({
    Key? key,
    required this.chartSize,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.minPrice,
    required this.maxPrice,
    this.onFibonacciChanged,
  }) : super(key: key);

  @override
  State<FibonacciInteractive> createState() => FibonacciInteractiveState();
}

class FibonacciInteractiveState extends State<FibonacciInteractive> {
  FibonacciRetracement? fibonacci;
  bool isDrawing = false;
  bool isDraggingStart = false;
  bool isDraggingEnd = false;
  bool isLocked = false; // NEW: Lock state untuk prevent dragging
  
  // Drawing state
  Offset? drawStartPoint;
  Offset? currentDrawPoint;
  
  void startDrawing(Offset position) {
    setState(() {
      isDrawing = true;
      drawStartPoint = position;
      currentDrawPoint = position;
      fibonacci = null; // Clear existing fibonacci while drawing
      isLocked = false; // Reset lock
    });
  }
  
  void updateDrawing(Offset position) {
    if (!isDrawing) return;
    setState(() {
      currentDrawPoint = position;
    });
  }
  
  void finishDrawing() {
    if (!isDrawing || drawStartPoint == null || currentDrawPoint == null) return;
    
    setState(() {
      fibonacci = FibonacciRetracement(
        startPoint: drawStartPoint!,
        endPoint: currentDrawPoint!,
      );
      isDrawing = false;
      drawStartPoint = null;
      currentDrawPoint = null;
      isLocked = false; // Not locked yet, bisa di-drag
    });
    
    widget.onFibonacciChanged?.call();
  }
  
  void clearFibonacci() {
    setState(() {
      fibonacci = null;
      isDrawing = false;
      drawStartPoint = null;
      currentDrawPoint = null;
      isLocked = false;
    });
  }
  
  // NEW: Double tap to lock/unlock Fibonacci
  void toggleLock() {
    if (fibonacci == null) return;
    setState(() {
      isLocked = !isLocked;
    });
  }
  
  bool handleTapDown(Offset position) {
    // Kalau locked, nggak bisa drag
    if (fibonacci == null || isLocked) return false;
    
    const threshold = 30.0;
    
    if (fibonacci!.isNearStartHandle(position, threshold)) {
      setState(() {
        isDraggingStart = true;
      });
      return true;
    } else if (fibonacci!.isNearEndHandle(position, threshold)) {
      setState(() {
        isDraggingEnd = true;
      });
      return true;
    }
    
    return false;
  }
  
  void handleDrag(Offset position) {
    // Kalau locked, ignore drag
    if (fibonacci == null || isLocked) return;
    
    setState(() {
      if (isDraggingStart) {
        fibonacci!.startPoint = position;
      } else if (isDraggingEnd) {
        fibonacci!.endPoint = position;
      }
    });
    
    widget.onFibonacciChanged?.call();
  }
  
  void handleDragEnd() {
    setState(() {
      isDraggingStart = false;
      isDraggingEnd = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FibonacciPainter(
        fibonacci: fibonacci,
        isDrawing: isDrawing,
        drawStartPoint: drawStartPoint,
        currentDrawPoint: currentDrawPoint,
        accentColor: widget.accentColor,
        backgroundColor: widget.backgroundColor,
        textColor: widget.textColor,
        minPrice: widget.minPrice,
        maxPrice: widget.maxPrice,
        chartHeight: widget.chartSize.height,
        isLocked: isLocked, // Pass lock state ke painter
      ),
      child: Container(),
    );
  }
}

// ===== FIBONACCI PAINTER =====
class FibonacciPainter extends CustomPainter {
  final FibonacciRetracement? fibonacci;
  final bool isDrawing;
  final Offset? drawStartPoint;
  final Offset? currentDrawPoint;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final double minPrice;
  final double maxPrice;
  final double chartHeight;
  final bool isLocked; // NEW: Lock indicator
  
  FibonacciPainter({
    this.fibonacci,
    required this.isDrawing,
    this.drawStartPoint,
    this.currentDrawPoint,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.minPrice,
    required this.maxPrice,
    required this.chartHeight,
    this.isLocked = false, // Default unlocked
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw preview while drawing
    if (isDrawing && drawStartPoint != null && currentDrawPoint != null) {
      _drawPreview(canvas, size, drawStartPoint!, currentDrawPoint!);
    }
    
    // Draw completed Fibonacci
    if (fibonacci != null && fibonacci!.isVisible) {
      _drawFibonacci(canvas, size, fibonacci!);
    }
  }
  
  void _drawPreview(Canvas canvas, Size size, Offset start, Offset end) {
    final paint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    // Draw preview line
    canvas.drawLine(start, end, paint);
    
    // Draw preview handles
    _drawHandle(canvas, start, accentColor.withOpacity(0.5));
    _drawHandle(canvas, end, accentColor.withOpacity(0.5));
  }
  
  void _drawFibonacci(Canvas canvas, Size size, FibonacciRetracement fib) {
    final start = fib.startPoint;
    final end = fib.endPoint;
    
    // Draw main trend line (thicker, more visible)
    final trendPaint = Paint()
      ..color = accentColor.withOpacity(isLocked ? 0.5 : 0.8) // Dimmer when locked
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(start, end, trendPaint);
    
    // Draw Fibonacci levels
    for (int i = 0; i < FibonacciRetracement.levels.length; i++) {
      final level = FibonacciRetracement.levels[i];
      final label = FibonacciRetracement.levelLabels[i];
      
      _drawFibLevel(canvas, size, fib, level, label, i);
    }
    
    // Draw draggable handles (different style when locked)
    if (isLocked) {
      _drawLockedHandle(canvas, start, accentColor);
      _drawLockedHandle(canvas, end, accentColor);
      
      // Draw lock icon di tengah
      _drawLockIcon(canvas, Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      ));
    } else {
      _drawHandle(canvas, start, accentColor);
      _drawHandle(canvas, end, accentColor);
    }
    
    // Draw price labels on handles (only when not locked)
    if (!isLocked) {
      _drawHandlePrice(canvas, start, size, fib, 0.0);
      _drawHandlePrice(canvas, end, size, fib, 1.0);
    }
  }
  
  void _drawFibLevel(Canvas canvas, Size size, FibonacciRetracement fib, 
                     double level, String label, int index) {
    final y = fib.getYAtLevel(level);
    
    // Color variations for different levels
    Color levelColor;
    if (level == 0.0 || level == 1.0) {
      levelColor = accentColor.withOpacity(0.8); // Start/End - brightest
    } else if (level == 0.618) {
      levelColor = const Color(0xFFFFD700).withOpacity(0.6); // Golden ratio - gold
    } else if (level == 0.5) {
      levelColor = const Color(0xFF00FFFF).withOpacity(0.5); // 50% - cyan
    } else {
      levelColor = accentColor.withOpacity(0.4); // Other levels
    }
    
    // Draw horizontal line
    final linePaint = Paint()
      ..color = levelColor
      ..strokeWidth = level == 0.618 ? 1.5 : 1.0 // Golden ratio thicker
      ..style = PaintingStyle.stroke;
    
    // Dashed line for non-critical levels
    if (level != 0.0 && level != 1.0 && level != 0.618) {
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), linePaint);
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    
    // Draw level label with background
    final price = fib.getPriceAtLevel(level, minPrice, maxPrice, chartHeight);
    final labelText = '$label  \$${price.toStringAsFixed(2)}';
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: levelColor,
          fontSize: level == 0.618 ? 12 : 11,
          fontWeight: level == 0.618 ? FontWeight.bold : FontWeight.w600,
          shadows: [
            Shadow(
              color: backgroundColor,
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Draw label background
    final labelBgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - textPainter.width - 12,
        y - textPainter.height / 2 - 4,
        textPainter.width + 8,
        textPainter.height + 8,
      ),
      const Radius.circular(4),
    );
    
    final bgPaint = Paint()
      ..color = backgroundColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(labelBgRect, bgPaint);
    
    // Draw border for golden ratio
    if (level == 0.618) {
      final borderPaint = Paint()
        ..color = levelColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(labelBgRect, borderPaint);
    }
    
    // Draw text
    textPainter.paint(
      canvas,
      Offset(size.width - textPainter.width - 8, y - textPainter.height / 2),
    );
  }
  
  void _drawHandle(Canvas canvas, Offset position, Color color) {
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 12, glowPaint);
    
    // Inner circle
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 8, handlePaint);
    
    // Border
    final borderPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, 8, borderPaint);
  }
  
  // NEW: Locked handle style (smaller, gray)
  void _drawLockedHandle(Canvas canvas, Offset position, Color color) {
    // Small gray circle to indicate locked
    final lockedPaint = Paint()
      ..color = const Color(0xFF6B7280) // Gray
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 5, lockedPaint);
    
    // Border
    final borderPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, 5, borderPaint);
  }
  
  // NEW: Draw lock icon at center
  void _drawLockIcon(Canvas canvas, Offset center) {
    final lockPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.8) // Gold lock
      ..style = PaintingStyle.fill;
    
    // Lock body (rectangle)
    final lockBody = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 3),
        width: 12,
        height: 10,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(lockBody, lockPaint);
    
    // Lock shackle (arc)
    final shacklePaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 2),
        width: 10,
        height: 10,
      ),
      math.pi, // Start at bottom
      math.pi, // Sweep 180 degrees
      false,
      shacklePaint,
    );
    
    // Background circle for better visibility
    final bgPaint = Paint()
      ..color = backgroundColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 14, bgPaint);
    
    // Redraw lock on top of background
    canvas.drawRRect(lockBody, lockPaint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 2),
        width: 10,
        height: 10,
      ),
      math.pi,
      math.pi,
      false,
      shacklePaint,
    );
  }
  
  void _drawHandlePrice(Canvas canvas, Offset position, Size size, 
                       FibonacciRetracement fib, double level) {
    final price = fib.getPriceAtLevel(level, minPrice, maxPrice, chartHeight);
    final priceText = '\$${price.toStringAsFixed(2)}';
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: TextStyle(
          color: accentColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: backgroundColor,
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position label next to handle
    final labelX = position.dx > size.width / 2 
        ? position.dx - textPainter.width - 16
        : position.dx + 16;
    
    textPainter.paint(
      canvas,
      Offset(labelX, position.dy - textPainter.height / 2),
    );
  }
  
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double distance = (end - start).distance;
    
    final normalizedOffset = Offset(
      (end.dx - start.dx) / distance,
      (end.dy - start.dy) / distance,
    );
    
    double drawn = 0.0;
    while (drawn < distance) {
      final drawEnd = math.min(drawn + dashWidth, distance);
      canvas.drawLine(
        Offset(
          start.dx + normalizedOffset.dx * drawn,
          start.dy + normalizedOffset.dy * drawn,
        ),
        Offset(
          start.dx + normalizedOffset.dx * drawEnd,
          start.dy + normalizedOffset.dy * drawEnd,
        ),
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(FibonacciPainter oldDelegate) {
    return fibonacci != oldDelegate.fibonacci ||
           isDrawing != oldDelegate.isDrawing ||
           drawStartPoint != oldDelegate.drawStartPoint ||
           currentDrawPoint != oldDelegate.currentDrawPoint ||
           isLocked != oldDelegate.isLocked; // Include lock state
  }
}

// ===== FIBONACCI TOOLBAR =====
class FibonacciToolbar extends StatelessWidget {
  final bool isFibonacciMode;
  final bool hasFibonacci;
  final VoidCallback onToggleFibonacci;
  final VoidCallback onClearFibonacci;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  
  const FibonacciToolbar({
    Key? key,
    required this.isFibonacciMode,
    required this.hasFibonacci,
    required this.onToggleFibonacci,
    required this.onClearFibonacci,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildToolButton('📐 Fib', isFibonacciMode, onToggleFibonacci),
        if (hasFibonacci) ...[
          const SizedBox(width: 8),
          _buildToolButton('🗑️ Clear', false, onClearFibonacci),
        ],
      ],
    );
  }
  
  Widget _buildToolButton(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive 
              ? LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.2),
                    accentColor.withOpacity(0.1),
                  ],
                )
              : null,
          color: isActive ? null : backgroundColor,
          border: Border.all(
            color: isActive ? accentColor : const Color(0xFF1A2332),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [
            BoxShadow(
              color: accentColor.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? accentColor : textColor.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}