// =============================================================================
// risk_ratio_button.dart
// Path: frontend/lib/controller/risk_ratio_button.dart
//
// Simplified — tidak ada tap toggle di button.
// Context menu muncul via right-click langsung di overlay chart.
// Button ini hanya trigger aktif/nonaktif drawing mode.
// =============================================================================

import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';

enum RiskRatioMode { buy, sell }

class RiskRatioButton extends StatelessWidget {
  final bool          isActive;
  final RiskRatioMode mode;
  final CandlestickStyle style;
  final VoidCallback  onTap;

  const RiskRatioButton({
    Key? key,
    required this.isActive,
    required this.mode,
    required this.style,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeColor = mode == RiskRatioMode.buy
        ? style.bullishColor
        : style.bearishColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve:    Curves.easeInOut,
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            // Mode indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width:  7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? activeColor
                    : style.textColor.withOpacity(0.35),
              ),
            ),
            const SizedBox(width: 8),

            // Label
            Text(
              mode == RiskRatioMode.buy ? 'R/R  Long' : 'R/R  Short',
              style: TextStyle(
                color: isActive
                    ? activeColor
                    : style.textColor.withOpacity(0.55),
                fontSize:   12,
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