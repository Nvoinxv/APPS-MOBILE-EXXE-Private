// ══════════════════════════════════════════════════════════════════════════════
// frontend/lib/controller/strategy_button_2.dart
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../candle/candle_normal.dart'; // CandlestickStyle ada di sini

class Strategy2Button extends StatelessWidget {
  final bool             isActive;
  final VoidCallback     onTap;
  final CandlestickStyle style; // ← FIX: CandlestickStyle, bukan ChartStyle

  const Strategy2Button({
    Key? key,
    required this.isActive,
    required this.onTap,
    required this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF00C8FF);
    final color       = isActive ? activeColor : style.textColor.withOpacity(0.4);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeInOut,
        padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        style.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.6) : style.gridColor,
            width: 1.2,
          ),
          boxShadow: isActive
              ? [BoxShadow(
                  color:        activeColor.withOpacity(0.25),
                  blurRadius:   8,
                  spreadRadius: 1,
                )]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dot indicator ──────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  7,
              height: 7,
              decoration: BoxDecoration(
                color:  color,
                shape:  BoxShape.circle,
                boxShadow: isActive
                    ? [BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 4)]
                    : [],
              ),
            ),
            const SizedBox(width: 6),

            // ── Label S2 ───────────────────────────────────────────────
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color:         color,
                fontSize:      11,
                fontWeight:    FontWeight.w600,
                letterSpacing: 0.4,
              ),
              child: const Text('S2'),
            ),
            const SizedBox(width: 4),

            // ── ON / OFF ───────────────────────────────────────────────
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color:      color.withOpacity(0.7),
                fontSize:   9,
                fontWeight: FontWeight.w400,
              ),
              child: Text(isActive ? 'ON' : 'OFF'),
            ),
          ],
        ),
      ),
    );
  }
}