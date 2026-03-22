import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';
import '../controller/risk_ratio_button.dart';
import '../interactive/risk_ratio_interactive.dart';
import '../interactive/fibonacci_interactive.dart';

/// Helper class untuk menampilkan context menus
/// 
/// Digunakan untuk menampilkan menu popup ketika user right-click
/// pada Fibonacci atau Risk Ratio tools
class ContextMenus {
  ContextMenus._();

  /// Show context menu untuk Fibonacci tool
  /// 
  /// Menu options:
  /// - Lock/Unlock: Toggle lock state untuk prevent editing
  /// - Delete: Remove fibonacci dari chart
  static void showFibonacciContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required CandlestickStyle style,
    required GlobalKey<FibonacciInteractiveState> fibonacciKey,
    required VoidCallback onUpdate,
  }) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final fibState = fibonacciKey.currentState;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: style.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: style.gridColor,
          width: 1,
        ),
      ),
      items: [
        // Lock/Unlock menu item
        PopupMenuItem(
          child: _buildMenuItem(
            icon: fibState?.isLocked ?? false 
                ? Icons.lock_open 
                : Icons.lock,
            iconColor: const Color(0xFFFFD700), // Gold color
            text: fibState?.isLocked ?? false 
                ? 'Unlock Fibonacci'
                : 'Lock Fibonacci',
            textColor: style.textColor,
          ),
          onTap: () {
            fibState?.toggleLock();
            onUpdate();
          },
        ),
        
        // Delete menu item
        PopupMenuItem(
          child: _buildMenuItem(
            icon: Icons.delete_outline,
            iconColor: style.bearishColor,
            text: 'Delete Fibonacci',
            textColor: style.bearishColor,
          ),
          onTap: () {
            fibState?.clearFibonacci();
            onUpdate();
          },
        ),
      ],
    );
  }

  /// Show context menu untuk Risk Ratio tool
  /// 
  /// Menu options:
  /// - Switch Mode: Toggle between BUY and SELL mode
  /// - Lock/Unlock: Toggle lock state untuk prevent editing
  /// - Delete: Remove risk ratio dari chart
  static void showRiskRatioContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required CandlestickStyle style,
    required GlobalKey<RiskRatioInteractiveState> riskRatioKey,
    required Function(RiskRatioMode) onModeChanged,
    required VoidCallback onUpdate,
  }) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final rrState = riskRatioKey.currentState;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: style.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: style.gridColor,
          width: 1,
        ),
      ),
      items: [
        // Switch Mode menu item
        PopupMenuItem(
          child: _buildMenuItem(
            icon: Icons.swap_vert,
            iconColor: style.bullishColor,
            text: 'Switch to ${rrState?.riskRatio?.mode == RiskRatioMode.buy ? "SELL" : "BUY"}',
            textColor: style.textColor,
          ),
          onTap: () {
            final currentMode = rrState?.riskRatio?.mode ?? RiskRatioMode.buy;
            final newMode = currentMode == RiskRatioMode.buy 
                ? RiskRatioMode.sell 
                : RiskRatioMode.buy;
            
            onModeChanged(newMode);
            rrState?.setMode(newMode);
          },
        ),
        
        // Lock/Unlock menu item
        PopupMenuItem(
          child: _buildMenuItem(
            icon: rrState?.isLocked ?? false 
                ? Icons.lock_open 
                : Icons.lock,
            iconColor: const Color(0xFFFFD700), // Gold color
            text: rrState?.isLocked ?? false 
                ? 'Unlock' 
                : 'Lock',
            textColor: style.textColor,
          ),
          onTap: () {
            rrState?.toggleLock();
            onUpdate();
          },
        ),
        
        // Delete menu item
        PopupMenuItem(
          child: _buildMenuItem(
            icon: Icons.delete_outline,
            iconColor: style.bearishColor,
            text: 'Delete Risk Ratio',
            textColor: style.bearishColor,
          ),
          onTap: () {
            rrState?.clearRiskRatio();
            onUpdate();
          },
        ),
      ],
    );
  }

  /// Build menu item dengan icon dan text
  static Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 18,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Extension untuk BuildContext untuk memudahkan pemanggilan context menu
extension ContextMenuExtension on BuildContext {
  /// Show Fibonacci context menu
  void showFibonacciMenu({
    required Offset globalPosition,
    required CandlestickStyle style,
    required GlobalKey<FibonacciInteractiveState> fibonacciKey,
    required VoidCallback onUpdate,
  }) {
    ContextMenus.showFibonacciContextMenu(
      context: this,
      globalPosition: globalPosition,
      style: style,
      fibonacciKey: fibonacciKey,
      onUpdate: onUpdate,
    );
  }

  /// Show Risk Ratio context menu
  void showRiskRatioMenu({
    required Offset globalPosition,
    required CandlestickStyle style,
    required GlobalKey<RiskRatioInteractiveState> riskRatioKey,
    required Function(RiskRatioMode) onModeChanged,
    required VoidCallback onUpdate,
  }) {
    ContextMenus.showRiskRatioContextMenu(
      context: this,
      globalPosition: globalPosition,
      style: style,
      riskRatioKey: riskRatioKey,
      onModeChanged: onModeChanged,
      onUpdate: onUpdate,
    );
  }
}

/// Menu item builder untuk custom context menus
class ContextMenuItem {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final VoidCallback onTap;

  const ContextMenuItem({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    required this.onTap,
  });

  /// Build PopupMenuItem dari ContextMenuItem
  PopupMenuItem<void> build() {
    return PopupMenuItem(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Builder untuk membuat custom context menu dengan list items
class CustomContextMenu {
  final BuildContext context;
  final Offset globalPosition;
  final CandlestickStyle style;
  final List<ContextMenuItem> items;

  const CustomContextMenu({
    required this.context,
    required this.globalPosition,
    required this.style,
    required this.items,
  });

  /// Show context menu
  void show() {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: style.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: style.gridColor,
          width: 1,
        ),
      ),
      items: items.map((item) => item.build()).toList(),
    );
  }
}

/// Preset menu items untuk common actions
class MenuItems {
  MenuItems._();

  /// Lock menu item
  static ContextMenuItem lock({
    required bool isLocked,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      icon: isLocked ? Icons.lock_open : Icons.lock,
      iconColor: const Color(0xFFFFD700),
      text: isLocked ? 'Unlock' : 'Lock',
      textColor: textColor,
      onTap: onTap,
    );
  }

  /// Delete menu item
  static ContextMenuItem delete({
    required String itemName,
    required Color deleteColor,
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      icon: Icons.delete_outline,
      iconColor: deleteColor,
      text: 'Delete $itemName',
      textColor: deleteColor,
      onTap: onTap,
    );
  }

  /// Edit menu item
  static ContextMenuItem edit({
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      icon: Icons.edit_outlined,
      iconColor: textColor,
      text: 'Edit',
      textColor: textColor,
      onTap: onTap,
    );
  }

  /// Duplicate menu item
  static ContextMenuItem duplicate({
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      icon: Icons.content_copy,
      iconColor: textColor,
      text: 'Duplicate',
      textColor: textColor,
      onTap: onTap,
    );
  }

  /// Color picker menu item
  static ContextMenuItem changeColor({
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      icon: Icons.palette_outlined,
      iconColor: textColor,
      text: 'Change Color',
      textColor: textColor,
      onTap: onTap,
    );
  }
}