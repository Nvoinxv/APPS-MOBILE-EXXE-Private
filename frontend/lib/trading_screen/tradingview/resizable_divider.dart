// =============================================================================
// resizable_divider.dart
// Path: frontend/lib/trading_screen/tradingview/resizable_divider.dart
//
// SMOOTH DRAG FIX (v2):
//  - minSize / maxSize / current tetap ada sebagai optional params (backward
//    compat dengan tradeview_screen.dart) tapi tidak dipakai untuk clamping
//    di dalam divider — parent clamp via .clamp() di onDrag callback.
//  - Divider TIDAK boleh dibungkus ValueListenableBuilder di parent.
//    Root cause kaku: VLB rebuild → GestureDetector recreated mid-gesture.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../style/apps_colors_tradingview.dart';

class ResizableDivider extends StatefulWidget {
  final Axis                  axis;
  final void Function(double) onDrag;
  final EditorChromeColors?   chrome;
  final Widget?               child;
  final Color?                color;
  final double                thickness;

  // Backward compat — not used for clamping inside divider.
  // Parent is responsible for clamping in the onDrag callback.
  final double minSize;
  final double maxSize;
  final double current;

  const ResizableDivider({
    super.key,
    required this.axis,
    required this.onDrag,
    this.chrome,
    this.child,
    this.color,
    this.thickness = 6,
    this.minSize   = 0,
    this.maxSize   = double.infinity,
    this.current   = 0,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  final _isDragging = ValueNotifier<bool>(false);
  final _isHovered  = ValueNotifier<bool>(false);

  bool get _isVertical => widget.axis == Axis.vertical;

  Color get _activeColor =>
      widget.color ?? widget.chrome?.cursorColor ?? Colors.blueAccent;

  Color get _idleColor =>
      widget.chrome?.gutterBorder ?? Colors.white24;

  @override
  void dispose() {
    _isDragging.dispose();
    _isHovered.dispose();
    super.dispose();
  }

  void _onDelta(double delta) {
    if (delta != 0) widget.onDrag(delta);
  }

  @override
  Widget build(BuildContext context) {
    final dividerBody = MouseRegion(
      cursor:  _isVertical
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => _isHovered.value = true,
      onExit:  (_) => _isHovered.value = false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onHorizontalDragStart: _isVertical ? (_) {
          _isDragging.value = true;
          HapticFeedback.selectionClick();
        } : null,
        onHorizontalDragUpdate: _isVertical
            ? (d) => _onDelta(d.delta.dx)
            : null,
        onHorizontalDragEnd: _isVertical ? (_) {
          _isDragging.value = false;
          HapticFeedback.lightImpact();
        } : null,
        onHorizontalDragCancel: _isVertical
            ? () => _isDragging.value = false
            : null,

        onVerticalDragStart: !_isVertical ? (_) {
          _isDragging.value = true;
          HapticFeedback.selectionClick();
        } : null,
        onVerticalDragUpdate: !_isVertical
            ? (d) => _onDelta(d.delta.dy)
            : null,
        onVerticalDragEnd: !_isVertical ? (_) {
          _isDragging.value = false;
          HapticFeedback.lightImpact();
        } : null,
        onVerticalDragCancel: !_isVertical
            ? () => _isDragging.value = false
            : null,

        child: SizedBox(
          width:  _isVertical ? widget.thickness : double.infinity,
          height: _isVertical ? double.infinity : widget.thickness,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _isDragging,
                builder: (_, dragging, __) => ValueListenableBuilder<bool>(
                  valueListenable: _isHovered,
                  builder: (_, hovered, __) {
                    final active = dragging || hovered;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width:  _isVertical ? 1 : double.infinity,
                      height: _isVertical ? double.infinity : 1,
                      color: active
                          ? _activeColor.withOpacity(0.55)
                          : _idleColor,
                    );
                  },
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _isDragging,
                builder: (_, dragging, __) => ValueListenableBuilder<bool>(
                  valueListenable: _isHovered,
                  builder: (_, hovered, __) {
                    final active = dragging || hovered;
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: active ? 1.0 : 0.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width:  _isVertical ? 3 : 28,
                        height: _isVertical ? 28 : 3,
                        decoration: BoxDecoration(
                          color:        _activeColor,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color:      _activeColor.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.child != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [widget.child!, dividerBody],
      );
    }

    return dividerBody;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ResizableLayout — horizontal split
// ─────────────────────────────────────────────────────────────────────────────

class ResizableLayout extends StatefulWidget {
  final EditorChromeColors            chrome;
  final double                        initialLeft;
  final double                        minLeft;
  final double                        maxLeft;
  final Widget Function(double width) left;
  final Widget Function(double)       right;

  const ResizableLayout({
    super.key,
    required this.chrome,
    required this.initialLeft,
    required this.minLeft,
    required this.maxLeft,
    required this.left,
    required this.right,
  });

  @override
  State<ResizableLayout> createState() => _ResizableLayoutState();
}

class _ResizableLayoutState extends State<ResizableLayout> {
  late final ValueNotifier<double> _leftWidth;

  @override
  void initState() {
    super.initState();
    _leftWidth = ValueNotifier(widget.initialLeft);
  }

  @override
  void dispose() {
    _leftWidth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _leftWidth,
              builder: (_, width, __) => SizedBox(
                width:  width,
                height: constraints.maxHeight,
                child:  widget.left(width),
              ),
            ),
            ResizableDivider(
              axis:   Axis.vertical,
              chrome: widget.chrome,
              onDrag: (delta) {
                _leftWidth.value =
                    (_leftWidth.value + delta)
                        .clamp(widget.minLeft, widget.maxLeft);
              },
            ),
            ValueListenableBuilder<double>(
              valueListenable: _leftWidth,
              builder: (_, width, __) => SizedBox(
                width:  constraints.maxWidth - width - 6,
                height: constraints.maxHeight,
                child:  widget.right(constraints.maxWidth - width - 6),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  VerticalResizableLayout — vertical split
// ─────────────────────────────────────────────────────────────────────────────

class VerticalResizableLayout extends StatefulWidget {
  final EditorChromeColors chrome;
  final double             initialTop;
  final double             minTop;
  final double             maxTop;
  final Widget             top;
  final Widget             bottom;

  const VerticalResizableLayout({
    super.key,
    required this.chrome,
    required this.initialTop,
    required this.minTop,
    required this.maxTop,
    required this.top,
    required this.bottom,
  });

  @override
  State<VerticalResizableLayout> createState() =>
      _VerticalResizableLayoutState();
}

class _VerticalResizableLayoutState extends State<VerticalResizableLayout> {
  late final ValueNotifier<double> _topHeight;

  @override
  void initState() {
    super.initState();
    _topHeight = ValueNotifier(widget.initialTop);
  }

  @override
  void dispose() {
    _topHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _topHeight,
              builder: (_, height, __) => SizedBox(
                width:  constraints.maxWidth,
                height: height,
                child:  widget.top,
              ),
            ),
            ResizableDivider(
              axis:   Axis.horizontal,
              chrome: widget.chrome,
              onDrag: (delta) {
                _topHeight.value =
                    (_topHeight.value + delta)
                        .clamp(widget.minTop, widget.maxTop);
              },
            ),
            Expanded(child: widget.bottom),
          ],
        );
      },
    );
  }
}