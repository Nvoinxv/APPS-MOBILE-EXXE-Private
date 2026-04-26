// =============================================================================
// overlay_context_menu.dart
// Context menu UI — dark, Bloomberg-terminal vibe, hover animation
//
// Path: frontend/lib/dialogs/overlay_context_menu.dart
// =============================================================================

import 'package:flutter/material.dart';

class OverlayContextMenu {
  // ── Color tokens ────────────────────────────────────────────────────────────
  static const bgColor      = Color(0xFF0E1117);
  static const borderColor  = Color(0xFF1E2333);
  static const accentGreen  = Color(0xFF00D09C);
  static const accentRed    = Color(0xFFFF4D6D);
  static const accentAmber  = Color(0xFFFFB347);
  static const textPrimary  = Color(0xFFE8EAF0);
  static const textMuted    = Color(0xFF6B7280);
  static const hoverColor   = Color(0xFF161B27);

  static const _menuW = 210.0;
  static const _menuH = 300.0;

  /// Tampilkan context menu di posisi [globalPosition].
  ///
  /// [hasTarget]    — true jika klik mengenai overlay (tampilkan Copy/Clone/Reverse/Delete)
  /// [hasClipboard] — true jika ada sesuatu di clipboard internal (tampilkan Paste aktif)
  static void show({
    required BuildContext context,
    required Offset       globalPosition,
    required bool         hasTarget,
    required bool         hasClipboard,
    bool                  isLocked    = false,
    VoidCallback?         onCopy,
    VoidCallback?         onClone,
    VoidCallback?         onReverse,
    VoidCallback?         onPaste,
    VoidCallback?         onDelete,
    VoidCallback?         onLock,
  }) {
    // Guard: tidak ada yang bisa dilakukan → jangan tampilkan
    if (!hasTarget && !hasClipboard) return;

    // Pastikan menu tidak keluar layar
    final size = MediaQuery.of(context).size;
    final dx   = (globalPosition.dx + _menuW > size.width)
        ? globalPosition.dx - _menuW
        : globalPosition.dx;
    final dy   = (globalPosition.dy + _menuH > size.height)
        ? globalPosition.dy - _menuH
        : globalPosition.dy;

    showDialog<void>(
      context:            context,
      barrierColor:       Colors.transparent,
      barrierDismissible: true,
      builder: (_) => _ContextMenuDialog(
        position:     Offset(dx, dy),
        hasTarget:    hasTarget,
        hasClipboard: hasClipboard,
        isLocked:     isLocked,
        onCopy:       onCopy,
        onClone:      onClone,
        onReverse:    onReverse,
        onPaste:      onPaste,
        onDelete:     onDelete,
        onLock:       onLock,
      ),
    );
  }
}

// ── Dialog wrapper ─────────────────────────────────────────────────────────────

class _ContextMenuDialog extends StatelessWidget {
  final Offset        position;
  final bool          hasTarget;
  final bool          hasClipboard;
  final bool          isLocked;
  final VoidCallback? onCopy;
  final VoidCallback? onClone;
  final VoidCallback? onReverse;
  final VoidCallback? onPaste;
  final VoidCallback? onDelete;
  final VoidCallback? onLock;

  const _ContextMenuDialog({
    required this.position,
    required this.hasTarget,
    required this.hasClipboard,
    required this.isLocked,
    this.onCopy,
    this.onClone,
    this.onReverse,
    this.onPaste,
    this.onDelete,
    this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap / right-click di luar → tutup
        Positioned.fill(
          child: GestureDetector(
            onTap:          () => Navigator.of(context).pop(),
            onSecondaryTap: () => Navigator.of(context).pop(),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),

        Positioned(
          left: position.dx,
          top:  position.dy,
          child: _MenuCard(
            children: [
              _MenuHeader(
                label: hasTarget ? 'OVERLAY ACTIONS' : 'CHART ACTIONS',
              ),

              const _MenuDivider(),

              // ── Target-specific actions ──────────────────────────────────
              if (hasTarget) ...[
                _MenuItem(
                  icon:     Icons.copy_rounded,
                  label:    'Copy',
                  shortcut: 'Ctrl+C',
                  color:    OverlayContextMenu.textPrimary,
                  onTap:    onCopy != null
                      ? () { Navigator.of(context).pop(); onCopy!(); }
                      : null,
                ),
                _MenuItem(
                  icon:     Icons.control_point_duplicate_rounded,
                  label:    'Clone',
                  shortcut: 'Ctrl+D',
                  color:    OverlayContextMenu.accentGreen,
                  onTap:    onClone != null
                      ? () { Navigator.of(context).pop(); onClone!(); }
                      : null,
                ),
                _MenuItem(
                  icon:     Icons.swap_vert_rounded,
                  label:    'Reverse',
                  shortcut: 'Ctrl+R',
                  color:    OverlayContextMenu.accentRed,
                  onTap:    onReverse != null
                      ? () { Navigator.of(context).pop(); onReverse!(); }
                      : null,
                ),
              ],

              // ── Paste (selalu tampil, disabled kalau clipboard kosong) ───
              _MenuItem(
                icon:     Icons.content_paste_rounded,
                label:    'Paste',
                shortcut: 'Ctrl+V',
                color:    OverlayContextMenu.textPrimary,
                enabled:  hasClipboard,
                onTap:    hasClipboard && onPaste != null
                    ? () { Navigator.of(context).pop(); onPaste!(); }
                    : null,
              ),

              if (hasTarget) ...[
                const _MenuDivider(),

                // ── Lock / Unlock ────────────────────────────────────────
                _MenuItem(
                  icon:  isLocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  label: isLocked ? 'Unlock' : 'Lock',
                  color: OverlayContextMenu.accentAmber,
                  onTap: onLock != null
                      ? () { Navigator.of(context).pop(); onLock!(); }
                      : null,
                ),

                // ── Delete ───────────────────────────────────────────────
                _MenuItem(
                  icon:          Icons.delete_outline_rounded,
                  label:         'Delete',
                  shortcut:      'Del',
                  color:         OverlayContextMenu.accentRed,
                  isDestructive: true,
                  onTap:         onDelete != null
                      ? () { Navigator.of(context).pop(); onDelete!(); }
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Card container ─────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          color:        OverlayContextMenu.bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OverlayContextMenu.borderColor),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.55),
              blurRadius: 24,
              offset:     const Offset(0, 8),
            ),
            BoxShadow(
              color:      Colors.black.withOpacity(0.20),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:           children,
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _MenuHeader extends StatelessWidget {
  final String label;
  const _MenuHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Text(
        label,
        style: const TextStyle(
          color:         OverlayContextMenu.textMuted,
          fontSize:      9.5,
          fontWeight:    FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ── Divider ────────────────────────────────────────────────────────────────────

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color:  OverlayContextMenu.borderColor,
    );
  }
}

// ── Menu item dengan hover effect ──────────────────────────────────────────────

class _MenuItem extends StatefulWidget {
  final IconData      icon;
  final String        label;
  final String?       shortcut;
  final Color         color;
  final bool          enabled;
  final bool          isDestructive;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.shortcut,
    this.enabled       = true,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.enabled
        ? widget.color
        : OverlayContextMenu.textMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor:  widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          decoration: BoxDecoration(
            color: _hovered && widget.enabled
                ? (widget.isDestructive
                    ? OverlayContextMenu.accentRed.withOpacity(0.08)
                    : OverlayContextMenu.hoverColor)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(widget.icon, size: 15, color: effectiveColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color:      effectiveColor,
                    fontSize:   13,
                    fontWeight: widget.isDestructive
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.shortcut != null)
                Text(
                  widget.shortcut!,
                  style: const TextStyle(
                    color:      OverlayContextMenu.textMuted,
                    fontSize:   10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}