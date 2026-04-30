// =============================================================================
// risk_ratio_button.dart
// Path: frontend/lib/controller/risk_ratio_button.dart
//
// Button R/R dengan mode switcher Buy/Sell built-in.
// - Tap label "Long" atau "Short" untuk ganti mode
// - Tap di luar segmen (dot) untuk toggle aktif/nonaktif
// - onModeChanged dipanggil saat mode berubah
// =============================================================================
import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';

enum RiskRatioMode { buy, sell }

class RiskRatioButton extends StatelessWidget {
  final bool isActive;
  final RiskRatioMode mode;
  final CandlestickStyle style;
  final VoidCallback onTap;

  /// Dipanggil saat user tap segmen mode yang berbeda.
  /// Parent wajib update [mode] di setState.
  final ValueChanged<RiskRatioMode> onModeChanged;

  const RiskRatioButton({
    Key? key,
    required this.isActive,
    required this.mode,
    required this.style,
    required this.onTap,
    required this.onModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buyColor = style.bullishColor;
    final sellColor = style.bearishColor;
    final activeColor = mode == RiskRatioMode.buy ? buyColor : sellColor;
    final inactiveTextColor = style.textColor.withOpacity(0.45);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withOpacity(0.10)
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
          // ── Dot + Toggle aktif/nonaktif ──────────────────────────────
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? activeColor
                      : style.textColor.withOpacity(0.30),
                ),
              ),
            ),
          ),

          // ── Divider vertikal ─────────────────────────────────────────
          Container(
            width: 1,
            height: 20,
            color: style.gridColor.withOpacity(0.5),
          ),

          // ── Segmen "Long" ─────────────────────────────────────────────
          _ModeSegment(
            label: 'Long',
            isSelected: mode == RiskRatioMode.buy,
            isActive: isActive,
            selectedColor: buyColor,
            inactiveColor: inactiveTextColor,
            onTap: () {
              if (mode != RiskRatioMode.buy) {
                onModeChanged(RiskRatioMode.buy);
              } else if (!isActive) {
                onTap(); // aktifkan jika mode sudah sama tapi nonaktif
              }
            },
          ),

          // ── Divider tengah ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              width: 1,
              color: style.gridColor.withOpacity(0.35),
            ),
          ),

          // ── Segmen "Short" ────────────────────────────────────────────
          _ModeSegment(
            label: 'Short',
            isSelected: mode == RiskRatioMode.sell,
            isActive: isActive,
            selectedColor: sellColor,
            inactiveColor: inactiveTextColor,
            onTap: () {
              if (mode != RiskRatioMode.sell) {
                onModeChanged(RiskRatioMode.sell);
              } else if (!isActive) {
                onTap();
              }
            },
          ),

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// =============================================================================
// _ModeSegment — segmen internal untuk "Long" / "Short"
// =============================================================================
class _ModeSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isActive;
  final Color selectedColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _ModeSegment({
    required this.label,
    required this.isSelected,
    required this.isActive,
    required this.selectedColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Warna teks:
    // - mode aktif & widget aktif   → selectedColor penuh
    // - mode aktif & widget nonaktif → selectedColor redup
    // - mode tidak aktif             → inactiveColor
    final Color textColor = isSelected
        ? (isActive ? selectedColor : selectedColor.withOpacity(0.5))
        : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected && isActive
              ? selectedColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}