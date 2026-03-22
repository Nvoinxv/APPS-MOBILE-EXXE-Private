import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';
import '../hooks/crypto_data_hook.dart';

/// Enum untuk mode Risk Ratio (Buy/Sell)
enum RiskRatioMode { buy, sell }

/// Risk Ratio Button Widget
/// 
/// Button untuk toggle risk ratio mode dengan support:
/// - Tap: Toggle mode on/off
/// - Long press: Switch antara Buy/Sell
/// - Context menu: Additional options
class RiskRatioButton extends StatelessWidget {
  final bool isActive;
  final RiskRatioMode mode;
  final CandlestickStyle style;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(BuildContext, Offset)? onShowContextMenu;
  final String? buyIcon;
  final String? sellIcon;
  final String? label;
  final bool showTooltip;

  const RiskRatioButton({
    Key? key,
    required this.isActive,
    required this.mode,
    required this.style,
    required this.onTap,
    this.onLongPress,
    this.onShowContextMenu,
    this.buyIcon,
    this.sellIcon,
    this.label,
    this.showTooltip = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeColor = mode == RiskRatioMode.buy 
        ? style.bullishColor 
        : style.bearishColor;
    
    final button = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onShowContextMenu != null
          ? (details) => onShowContextMenu!(context, details.globalPosition)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? activeColor.withOpacity(0.2)
              : style.gridColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? activeColor : style.gridColor,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getIcon(),
              style: TextStyle(fontSize: 14),
            ),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: TextStyle(
                  color: isActive ? activeColor : style.textColor,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (showTooltip) {
      return Tooltip(
        message: _getTooltipMessage(),
        child: button,
      );
    }

    return button;
  }

  String _getIcon() {
    if (mode == RiskRatioMode.buy) {
      return buyIcon ?? '📈';
    } else {
      return sellIcon ?? '📉';
    }
  }

  String _getTooltipMessage() {
    final modeText = mode == RiskRatioMode.buy ? 'Buy' : 'Sell';
    return 'Risk/Ratio ($modeText)\nTap: Toggle\nLong press: Switch mode';
  }
}

/// Context Menu untuk Risk Ratio
class RiskRatioContextMenu {
  static void show({
    required BuildContext context,
    required Offset position,
    required RiskRatioMode currentMode,
    required bool isLocked,
    required Color backgroundColor,
    required Color gridColor,
    required Color textColor,
    required Color bullishColor,
    required Color bearishColor,
    required VoidCallback onSwitchMode,
    required VoidCallback onToggleLock,
    required VoidCallback onDelete,
  }) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: gridColor),
      ),
      items: [
        PopupMenuItem(
          onTap: onSwitchMode,
          child: Row(
            children: [
              Icon(
                Icons.swap_vert,
                color: currentMode == RiskRatioMode.buy ? bullishColor : bearishColor,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'Switch to ${currentMode == RiskRatioMode.buy ? 'Sell' : 'Buy'}',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onToggleLock,
          child: Row(
            children: [
              Icon(
                isLocked ? Icons.lock_open : Icons.lock,
                color: textColor,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                isLocked ? 'Unlock' : 'Lock',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onDelete,
          child: Row(
            children: [
              Icon(Icons.delete, color: bearishColor, size: 18),
              const SizedBox(width: 12),
              Text(
                'Delete',
                style: TextStyle(color: bearishColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}