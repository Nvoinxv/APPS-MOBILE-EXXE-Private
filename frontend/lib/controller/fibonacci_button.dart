// =============================================================================
// fibonacci_button.dart
// Path: frontend/lib/controller/fibonacci_button.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';

class FibonacciButton extends StatelessWidget {
  final bool isActive;
  final CandlestickStyle style;
  final VoidCallback onTap;

  const FibonacciButton({
    Key? key,
    required this.isActive,
    required this.style,
    required this.onTap,
  }) : super(key: key);

  // ← expose sebagai public static biar bisa diakses dari TradeViewScreen
  static const Color fibColor = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    const activeColor = fibColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? activeColor : style.gridColor,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? activeColor
                    : style.textColor.withOpacity(0.35),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Fibonacci',
              style: TextStyle(
                color: isActive
                    ? activeColor
                    : style.textColor.withOpacity(0.55),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}