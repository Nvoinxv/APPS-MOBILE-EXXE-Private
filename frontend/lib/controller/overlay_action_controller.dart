// =============================================================================
// overlay_action_controller.dart
// Path: frontend/lib/controller/overlay_action_controller.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'cloneable_overlay.dart';
import '../dialogs/overlay_context_menu.dart';

class OverlayActionController<T extends CloneableOverlay<T>> {

  T? _clipboard;

  bool get hasClipboard => _clipboard != null;
  T?   get clipboard    => _clipboard;

  // ---------------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------------

  void copy(T overlay) {
    _clipboard = overlay.copyWith();
  }

  // ---------------------------------------------------------------------------
  // Clone
  // ---------------------------------------------------------------------------

  T? clone(
    T overlay, {
    double candleOffset = 8.0,
    double priceOffset  = 0.0,
  }) {
    return overlay.cloneWithOffset(
      candleOffset: candleOffset,
      priceOffset:  priceOffset,
    );
  }

  // ---------------------------------------------------------------------------
  // Paste
  // ---------------------------------------------------------------------------

  T? paste({
    double candleOffset = 5.0,
    double priceOffset  = 0.0,
  }) {
    final cb = _clipboard;
    if (cb == null) return null;
    return cb.cloneWithOffset(
      candleOffset: candleOffset,
      priceOffset:  priceOffset,
    );
  }

  // ---------------------------------------------------------------------------
  // Reverse
  // ---------------------------------------------------------------------------

  T reverse(T overlay) => overlay.reverse();

  // ---------------------------------------------------------------------------
  // Clear clipboard
  // ---------------------------------------------------------------------------

  void clearClipboard() => _clipboard = null;

  // ---------------------------------------------------------------------------
  // handleRightClick — tampilkan OverlayContextMenu, return true jika dikonsumsi
  // ---------------------------------------------------------------------------

  bool handleRightClick({
    required BuildContext     context,
    required Offset           globalPosition,
    required T?               hitOverlay,
    required void Function(T) onClone,
    required void Function(T) onReverse,
    required void Function()  onDelete,
    required void Function()  onPaste,
    VoidCallback?             onLock,
    bool                      isLocked = false,
  }) {
    if (hitOverlay == null && !hasClipboard) return false;

    OverlayContextMenu.show(
      context:        context,
      globalPosition: globalPosition,
      hasTarget:      hitOverlay != null,
      hasClipboard:   hasClipboard,
      isLocked:       isLocked,
      onCopy: hitOverlay != null
          ? () => copy(hitOverlay)
          : null,
      onClone: hitOverlay != null
          ? () {
              final cloned = clone(hitOverlay);
              if (cloned != null) onClone(cloned);
            }
          : null,
      onReverse: hitOverlay != null
          ? () => onReverse(reverse(hitOverlay))
          : null,
      onPaste: hasClipboard
          ? () {
              final pasted = paste();
              if (pasted != null) onClone(pasted);
            }
          : null,
      onDelete: hitOverlay != null ? onDelete : null,
      onLock:   hitOverlay != null ? onLock   : null,
    );

    return true;
  }
}