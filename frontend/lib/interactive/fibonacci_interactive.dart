import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/chart_viewport.dart';
import '../controller/cloneable_overlay.dart';
import '../controller/overlay_action_controller.dart';
import '../dialogs/overlay_context_menu.dart';
import '../dialogs/chart_style.dart';
import '../dialogs/fib_color_dialog.dart';
import '../dialogs/fib_level.dart';

// ===========================================================================
// FibonacciOverlay — data model (DATA SPACE)
// ===========================================================================

class FibonacciOverlay implements CloneableOverlay<FibonacciOverlay> {
  final double startIndexF;
  final double endIndexF;
  final double startPrice;
  final double endPrice;
  final List<FibLevel> levels;
  final bool isLocked;
  final bool extendLeft;
  final bool extendRight;

  const FibonacciOverlay({
    required this.startIndexF,
    required this.endIndexF,
    required this.startPrice,
    required this.endPrice,
    List<FibLevel>? levels,
    this.isLocked = false,
    this.extendLeft = false,
    this.extendRight = false, // ← DEFAULT FALSE: tidak extend ke kanan
  }) : levels = levels ?? FibLevel.defaults;

  // ── Screen helpers ────────────────────────────────────────────────────────
  double startX(ChartViewport vp) =>
      DataSpacePoint(candleIndexF: startIndexF, price: 0).toScreen(vp).dx;
  double endX(ChartViewport vp) =>
      DataSpacePoint(candleIndexF: endIndexF, price: 0).toScreen(vp).dx;
  double startY(ChartViewport vp) => vp.priceToY(startPrice);
  double endY(ChartViewport vp) => vp.priceToY(endPrice);

  double priceAtRatio(double ratio) =>
      startPrice + (endPrice - startPrice) * ratio;
  double yAtRatio(double ratio, ChartViewport vp) =>
      vp.priceToY(priceAtRatio(ratio));

  // ── CloneableOverlay ──────────────────────────────────────────────────────
  @override
  String get overlayId =>
      'fib_${startIndexF.toStringAsFixed(2)}_${startPrice.toStringAsFixed(4)}';

  @override
  FibonacciOverlay copyWith({
    double? startIndexF,
    double? endIndexF,
    double? startPrice,
    double? endPrice,
    List<FibLevel>? levels,
    bool? isLocked,
    bool? extendLeft,
    bool? extendRight,
  }) =>
      FibonacciOverlay(
        startIndexF: startIndexF ?? this.startIndexF,
        endIndexF:   endIndexF   ?? this.endIndexF,
        startPrice:  startPrice  ?? this.startPrice,
        endPrice:    endPrice    ?? this.endPrice,
        levels:      levels      ?? List.from(this.levels),
        isLocked:    isLocked    ?? this.isLocked,
        extendLeft:  extendLeft  ?? this.extendLeft,
        extendRight: extendRight ?? this.extendRight,
      );

  @override
  FibonacciOverlay cloneWithOffset({
    required double candleOffset,
    required double priceOffset,
  }) =>
      FibonacciOverlay(
        startIndexF: startIndexF + candleOffset,
        endIndexF:   endIndexF   + candleOffset,
        startPrice:  startPrice  + priceOffset,
        endPrice:    endPrice    + priceOffset,
        levels:      List.from(levels),
        isLocked:    false,
      );

  @override
  FibonacciOverlay reverse() => copyWith(
        startIndexF: endIndexF,
        endIndexF:   startIndexF,
        startPrice:  endPrice,
        endPrice:    startPrice,
      );

  // ── Default spawn ─────────────────────────────────────────────────────────
  static FibonacciOverlay defaultForViewport(
    ChartViewport vp, {
    double offsetFactor = 0.0,
  }) {
    final totalVisible = vp.lastVisibleIndex - vp.firstVisibleIndex;
    final centerIdx    = (vp.firstVisibleIndex + vp.lastVisibleIndex) / 2.0;
    final halfWidth    = totalVisible * 0.25;
    final hOffset      = totalVisible * offsetFactor * 0.06;

    final midPrice   = (vp.minPrice + vp.maxPrice) / 2;
    final priceRange = (vp.maxPrice - vp.minPrice);
    final startPrice = midPrice + priceRange * 0.20 + priceRange * offsetFactor * 0.04;
    final endPrice   = midPrice - priceRange * 0.20 + priceRange * offsetFactor * 0.04;

    return FibonacciOverlay(
      startIndexF: centerIdx - halfWidth + hOffset,
      endIndexF:   centerIdx + halfWidth + hOffset,
      startPrice:  startPrice.clamp(vp.minPrice, vp.maxPrice),
      endPrice:    endPrice.clamp(vp.minPrice, vp.maxPrice),
    );
  }
}

// ===========================================================================
// Drag handle enum + anchor snapshot
// ===========================================================================

enum _FibHandle {
  none,
  startFree,
  startLockX,
  startLockY,
  endFree,
  endLockX,
  endLockY,
  whole
}

class _FibAnchor {
  final double startIndexF;
  final double endIndexF;
  final double startPrice;
  final double endPrice;
  final double anchorCandleF;
  final double anchorPrice;

  const _FibAnchor({
    required this.startIndexF,
    required this.endIndexF,
    required this.startPrice,
    required this.endPrice,
    required this.anchorCandleF,
    required this.anchorPrice,
  });

  factory _FibAnchor.fromOverlay(
          FibonacciOverlay ov, Offset screen, ChartViewport vp) =>
      _FibAnchor(
        startIndexF:    ov.startIndexF,
        endIndexF:      ov.endIndexF,
        startPrice:     ov.startPrice,
        endPrice:       ov.endPrice,
        anchorCandleF:  vp.xToIndexF(screen.dx),
        anchorPrice:    vp.yToPrice(screen.dy),
      );

  FibonacciOverlay apply(
      _FibHandle handle, Offset current, ChartViewport vp, FibonacciOverlay ov) {
    final dC = vp.xToIndexF(current.dx) - anchorCandleF;
    final dP = vp.yToPrice(current.dy) - anchorPrice;

    switch (handle) {
      case _FibHandle.startFree:
        return ov.copyWith(
          startIndexF: startIndexF + dC,
          startPrice:  (startPrice + dP).clamp(vp.minPrice, vp.maxPrice),
        );
      case _FibHandle.startLockX:
        return ov.copyWith(startIndexF: startIndexF + dC);
      case _FibHandle.startLockY:
        return ov.copyWith(
            startPrice: (startPrice + dP).clamp(vp.minPrice, vp.maxPrice));
      case _FibHandle.endFree:
        return ov.copyWith(
          endIndexF: endIndexF + dC,
          endPrice:  (endPrice + dP).clamp(vp.minPrice, vp.maxPrice),
        );
      case _FibHandle.endLockX:
        return ov.copyWith(endIndexF: endIndexF + dC);
      case _FibHandle.endLockY:
        return ov.copyWith(
            endPrice: (endPrice + dP).clamp(vp.minPrice, vp.maxPrice));
      case _FibHandle.whole:
        return ov.copyWith(
          startIndexF: startIndexF + dC,
          endIndexF:   endIndexF   + dC,
          startPrice:  (startPrice + dP).clamp(vp.minPrice, vp.maxPrice),
          endPrice:    (endPrice   + dP).clamp(vp.minPrice, vp.maxPrice),
        );
      default:
        return ov;
    }
  }
}

// ===========================================================================
// FibonacciInteractive — widget utama
// ===========================================================================

class FibonacciInteractive extends StatefulWidget {
  final ChartViewport    viewport;
  final Color            accentColor;
  final Color            backgroundColor;
  final Color            textColor;
  final ChartStyleState  chartStyle;

  const FibonacciInteractive({
    Key? key,
    required this.viewport,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.chartStyle,
  }) : super(key: key);

  @override
  State<FibonacciInteractive> createState() => FibonacciInteractiveState();
}

class FibonacciInteractiveState extends State<FibonacciInteractive>
    with TickerProviderStateMixin {
  final List<FibonacciOverlay> overlays = [];

  final _actionCtrl = OverlayActionController<FibonacciOverlay>();

  AnimationController? _appearCtrl;
  Animation<double> _appearAnim = const AlwaysStoppedAnimation(1.0);

  bool    isDrawing    = false;
  Offset? _drawStart;
  Offset? _drawCurrent;

  int          _activeIdx    = -1;
  _FibHandle   _activeHandle = _FibHandle.none;
  _FibHandle   _hoveredHandle = _FibHandle.none;
  int          _hoveredIdx   = -1;
  _FibAnchor?  _anchor;
  ChartViewport? _dragVp;

  // ── Throttle drag repaints ────────────────────────────────────────────────
  // Gunakan scheduled frame agar tidak rebuild terlalu sering saat drag
  bool _framePending = false;
  FibonacciOverlay? _pendingOverlay;
  int _pendingIdx = -1;

  static const double _hitHandle = 22.0;
  static const double _hitLine   = 12.0;

  ChartViewport get _vp => widget.viewport;

  @override
  void initState() {
    super.initState();
    _appearCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _appearAnim =
        CurvedAnimation(parent: _appearCtrl!, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _appearCtrl?.dispose();
    super.dispose();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void initializeDefault() {
    final offsetFactor = overlays.length.toDouble();
    setState(() => overlays.add(
          FibonacciOverlay.defaultForViewport(_vp, offsetFactor: offsetFactor),
        ));
    _appearCtrl?.forward(from: 0);
  }

  void clearAll() => setState(() {
        overlays.clear();
        _reset();
        _appearCtrl?.reset();
      });

  void removeAt(int i) {
    if (i < 0 || i >= overlays.length) return;
    setState(() => overlays.removeAt(i));
  }

  void toggleLock([int? idx]) {
    final i = idx ?? (_activeIdx >= 0 ? _activeIdx : overlays.length - 1);
    if (i < 0 || i >= overlays.length) return;
    setState(() =>
        overlays[i] = overlays[i].copyWith(isLocked: !overlays[i].isLocked));
  }

  bool get isLocked {
    if (_activeIdx >= 0 && _activeIdx < overlays.length) {
      return overlays[_activeIdx].isLocked;
    }
    return overlays.isNotEmpty && overlays.last.isLocked;
  }

  void openColorSettings(BuildContext ctx, [int? idx]) {
    final i = idx ?? (_activeIdx >= 0 ? _activeIdx : overlays.length - 1);
    if (i < 0 || i >= overlays.length) return;
    FibColorDialog.show(
      ctx,
      levels:     overlays[i].levels,
      chartStyle: widget.chartStyle,
      onChanged:  (updated) =>
          setState(() => overlays[i] = overlays[i].copyWith(levels: updated)),
    );
  }

  void startDrawing(Offset screen) => setState(() {
        isDrawing    = true;
        _drawStart   = screen;
        _drawCurrent = screen;
      });

  // ── Right-click context menu ──────────────────────────────────────────────

  void handleRightClick(BuildContext context, Offset localPos) {
    final hit    = _detectAll(localPos);
    final target = hit.index >= 0 ? overlays[hit.index] : null;

    final renderBox = this.context.findRenderObject() as RenderBox?;
    final globalPos = renderBox?.localToGlobal(localPos) ?? localPos;

    _actionCtrl.handleRightClick(
      context:         context,
      globalPosition:  globalPos,
      hitOverlay:      target,
      isLocked:        target?.isLocked ?? false,
      onClone:  (cloned)   => setState(() => overlays.add(cloned)),
      onReverse: (reversed) {
        if (hit.index >= 0) setState(() => overlays[hit.index] = reversed);
      },
      onDelete: () {
        if (hit.index >= 0) {
          setState(() {
            overlays.removeAt(hit.index);
            if (_activeIdx == hit.index) {
              _activeIdx    = -1;
              _activeHandle = _FibHandle.none;
            }
          });
        }
      },
      onPaste: () {},
      onLock:  target != null ? toggleLock : null,
      extraActions: [
        if (target != null)
          OverlayContextAction(
            label: 'Edit Colors…',
            icon:  Icons.palette_outlined,
            onTap: () => openColorSettings(context, hit.index),
          ),
      ],
    );
  }

  // ── Keyboard shortcuts ────────────────────────────────────────────────────

  void handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (_activeIdx >= 0 && _activeIdx < overlays.length) {
        _actionCtrl.copy(overlays[_activeIdx]);
      }
      return;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyD) {
      if (_activeIdx >= 0 && _activeIdx < overlays.length) {
        final cloned = _actionCtrl.clone(overlays[_activeIdx]);
        if (cloned != null) setState(() => overlays.add(cloned));
      }
      return;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      final pasted = _actionCtrl.paste();
      if (pasted != null) {
        setState(() => overlays.add(pasted));
        _appearCtrl?.forward(from: 0);
      }
      return;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyR) {
      if (_activeIdx >= 0 && _activeIdx < overlays.length) {
        final reversed = _actionCtrl.reverse(overlays[_activeIdx]);
        setState(() => overlays[_activeIdx] = reversed);
      }
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (_activeIdx >= 0 && _activeIdx < overlays.length) {
        setState(() {
          overlays.removeAt(_activeIdx);
          _activeIdx    = -1;
          _activeHandle = _FibHandle.none;
        });
      }
      return;
    }
  }

  // ── Hit testing ───────────────────────────────────────────────────────────

  ({int index, _FibHandle handle}) _detectAll(Offset screen) {
    for (int i = overlays.length - 1; i >= 0; i--) {
      final h = _detect(screen, overlays[i]);
      if (h != _FibHandle.none) return (index: i, handle: h);
    }
    return (index: -1, handle: _FibHandle.none);
  }

  _FibHandle _detect(Offset screen, FibonacciOverlay ov) {
    final sX    = ov.startX(_vp);
    final sY    = ov.startY(_vp);
    final eX    = ov.endX(_vp);
    final eY    = ov.endY(_vp);
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt   = HardwareKeyboard.instance.isAltPressed;

    if ((screen - Offset(sX, sY)).distance < _hitHandle) {
      if (shift) return _FibHandle.startLockX;
      if (alt)   return _FibHandle.startLockY;
      return _FibHandle.startFree;
    }
    if ((screen - Offset(eX, eY)).distance < _hitHandle) {
      if (shift) return _FibHandle.endLockX;
      if (alt)   return _FibHandle.endLockY;
      return _FibHandle.endFree;
    }
    if (_distToSegment(screen, Offset(sX, sY), Offset(eX, eY)) < _hitLine) {
      return _FibHandle.whole;
    }
    for (final lvl in ov.levels) {
      if ((screen.dy - ov.yAtRatio(lvl.ratio, _vp)).abs() < _hitLine) {
        return _FibHandle.whole;
      }
    }
    return _FibHandle.none;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t  = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) /
        (ab.distanceSquared + 1e-9);
    return (p - (a + ab * t.clamp(0.0, 1.0))).distance;
  }

  bool isInsideInteractiveArea(Offset screen) =>
      overlays.any((ov) => _detect(screen, ov) != _FibHandle.none);

  // ── Pointer events ────────────────────────────────────────────────────────

  bool handlePointerDown(Offset screen) {
    for (int i = overlays.length - 1; i >= 0; i--) {
      if (overlays[i].isLocked) continue;
      final h = _detect(screen, overlays[i]);
      if (h == _FibHandle.none) continue;
      final snapVp = _vp;
      setState(() {
        _activeIdx    = i;
        _activeHandle = h;
        _anchor       = _FibAnchor.fromOverlay(overlays[i], screen, snapVp);
        _dragVp       = snapVp;
      });
      return true;
    }
    return false;
  }

  void handlePointerMove(Offset screen) {
    if (isDrawing) {
      setState(() => _drawCurrent = screen);
      return;
    }

    // ── Drag: throttle via scheduleFrameCallback ──────────────────────────
    if (_activeHandle != _FibHandle.none && _activeIdx >= 0) {
      final a  = _anchor;
      final vp = _dragVp;
      if (a == null || vp == null) return;

      // Hitung updated overlay langsung (tanpa setState dulu)
      _pendingOverlay = a.apply(_activeHandle, screen, vp, overlays[_activeIdx]);
      _pendingIdx     = _activeIdx;

      if (!_framePending) {
        _framePending = true;
        WidgetsBinding.instance.scheduleFrameCallback((_) {
          if (!mounted) return;
          final ov  = _pendingOverlay;
          final idx = _pendingIdx;
          if (ov != null && idx >= 0 && idx < overlays.length) {
            setState(() => overlays[idx] = ov);
          }
          _framePending   = false;
          _pendingOverlay = null;
        });
      }
      return;
    }

    // Hover update
    final hit = _detectAll(screen);
    if (hit.handle != _hoveredHandle || hit.index != _hoveredIdx) {
      setState(() {
        _hoveredHandle = hit.handle;
        _hoveredIdx    = hit.index;
      });
    }
  }

  void handlePointerUp(Offset screen) {
    if (isDrawing) {
      _finishDrawing();
      return;
    }
    // Flush pending update saat finger/mouse up
    final ov  = _pendingOverlay;
    final idx = _pendingIdx;
    setState(() {
      if (ov != null && idx >= 0 && idx < overlays.length) {
        overlays[idx] = ov;
      }
      _activeHandle   = _FibHandle.none;
      _activeIdx      = -1;
      _anchor         = null;
      _dragVp         = null;
      _pendingOverlay = null;
      _pendingIdx     = -1;
    });
  }

  void handlePointerCancel() => setState(_reset);

  void _reset() {
    isDrawing       = false;
    _drawStart      = null;
    _drawCurrent    = null;
    _activeHandle   = _FibHandle.none;
    _activeIdx      = -1;
    _anchor         = null;
    _dragVp         = null;
    _pendingOverlay = null;
    _pendingIdx     = -1;
  }

  void _finishDrawing() {
    final s = _drawStart;
    final c = _drawCurrent;
    if (s == null || c == null) return;
    setState(() {
      overlays.add(FibonacciOverlay(
        startIndexF: _vp.xToIndexF(s.dx),
        endIndexF:   _vp.xToIndexF(c.dx),
        startPrice:  _vp.yToPrice(s.dy),
        endPrice:    _vp.yToPrice(c.dy),
      ));
      _drawStart = _drawCurrent = null;
      isDrawing  = false;
    });
    _appearCtrl?.forward(from: 0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
        animation: _appearAnim,
        builder: (_, __) => CustomPaint(
          painter: _FibPainter(
            overlays:      overlays,
            activeIdx:     _activeIdx,
            activeHandle:  _activeHandle,
            hoveredHandle: _hoveredHandle,
            hoveredIdx:    _hoveredIdx,
            viewport:      _vp,
            isDrawing:     isDrawing,
            drawStart:     _drawStart,
            drawCurrent:   _drawCurrent,
            appearValue:   _appearAnim.value,
          ),
          child: const SizedBox.expand(),
        ),
      );
}

// ===========================================================================
// _FibPainter — CustomPainter
// ===========================================================================

class _FibPainter extends CustomPainter {
  final List<FibonacciOverlay> overlays;
  final int          activeIdx;
  final _FibHandle   activeHandle;
  final _FibHandle   hoveredHandle;
  final int          hoveredIdx;
  final ChartViewport viewport;
  final bool         isDrawing;
  final Offset?      drawStart;
  final Offset?      drawCurrent;
  final double       appearValue;

  static const Color _bg = Color(0xFF0B0E17);

  const _FibPainter({
    required this.overlays,
    required this.activeIdx,
    required this.activeHandle,
    required this.hoveredHandle,
    required this.hoveredIdx,
    required this.viewport,
    required this.isDrawing,
    required this.drawStart,
    required this.drawCurrent,
    required this.appearValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isDrawing && drawStart != null && drawCurrent != null) {
      _paintPreview(canvas, drawStart!, drawCurrent!);
    }
    for (int i = 0; i < overlays.length; i++) {
      _paintOverlay(canvas, size, overlays[i], i == activeIdx, i);
    }
  }

  void _paintPreview(Canvas canvas, Offset s, Offset e) {
    canvas.drawLine(s, e,
        Paint()..color = Colors.white38..strokeWidth = 1.2);
    canvas.drawCircle(s, 5, Paint()..color = Colors.white54);
    canvas.drawCircle(e, 5, Paint()..color = Colors.white54);
  }

  void _paintOverlay(
      Canvas canvas, Size size, FibonacciOverlay ov, bool isActive, int idx) {
    final sX   = ov.startX(viewport);
    final sY   = ov.startY(viewport);
    final eX   = ov.endX(viewport);
    final eY   = ov.endY(viewport);
    final col0 = ov.levels.first.lineColor;
    final colN = ov.levels.last.lineColor;

    // ── Batas kiri/kanan level lines ────────────────────────────────────────
    // extendLeft/Right hanya aktif kalau user toggle — default keduanya false
    // sehingga lines terbatas antara startX dan endX
    final lx = ov.extendLeft  ? 0.0        : math.min(sX, eX);
    final rx = ov.extendRight ? size.width  : math.max(sX, eX);

    // Appear animation
    final doAnimate = appearValue < 1.0 && idx == overlays.length - 1;
    if (doAnimate) {
      canvas.save();
      final sc     = 0.93 + 0.07 * appearValue;
      final pivotY = (sY + eY) / 2;
      canvas.translate(0, pivotY);
      canvas.scale(1.0, sc);
      canvas.translate(0, -pivotY);
    }

    // Trend line — hanya antara dua handle
    canvas.drawLine(
      Offset(sX, sY),
      Offset(eX, eY),
      Paint()..color = col0.withOpacity(0.55)..strokeWidth = 1.2,
    );

    // Fill bands
    for (int i = 0; i < ov.levels.length - 1; i++) {
      final y1 = ov.yAtRatio(ov.levels[i].ratio, viewport);
      final y2 = ov.yAtRatio(ov.levels[i + 1].ratio, viewport);
      canvas.drawRect(
        Rect.fromLTRB(lx, math.min(y1, y2), rx, math.max(y1, y2)),
        Paint()..color = ov.levels[i].fillColor.withOpacity(0.045),
      );
    }

    // Level lines + labels
    for (final lvl in ov.levels) {
      final y  = ov.yAtRatio(lvl.ratio, viewport);
      final lp = Paint()
        ..color       = lvl.lineColor.withOpacity(isActive ? 0.90 : 0.65)
        ..strokeWidth = lvl.lineWidth;
      if (lvl.isDashed) {
        _dashed(canvas, Offset(lx, y), Offset(rx, y), lp);
      } else {
        canvas.drawLine(Offset(lx, y), Offset(rx, y), lp);
      }
      if (lvl.showLabel) _paintLabel(canvas, lvl, ov, y);
    }

    // Endpoint handles
    _paintHandle(canvas, Offset(sX, sY), col0, isActive, isStart: true,  ov: ov);
    _paintHandle(canvas, Offset(eX, eY), colN, isActive, isStart: false, ov: ov);

    if (ov.isLocked) {
      _paintLockIcon(canvas, Offset((sX + eX) / 2, (sY + eY) / 2));
    }

    if (doAnimate) canvas.restore();
  }

  void _paintLabel(Canvas canvas, FibLevel lvl, FibonacciOverlay ov, double y) {
    final price = ov.priceAtRatio(lvl.ratio);
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text:  lvl.label,
          style: TextStyle(
            color:      lvl.lineColor,
            fontSize:   9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text:  '  ${_fmt(price)}',
          style: TextStyle(
            color:    Colors.white.withOpacity(0.72),
            fontSize: 9.5,
          ),
        ),
      ]),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const xOff = 6.0;
    const bh   = 18.0;
    final bw   = tp.width + 14;
    final rr   = RRect.fromRectAndRadius(
      Rect.fromLTWH(xOff, y - bh / 2, bw, bh),
      const Radius.circular(3),
    );
    canvas.drawRRect(rr, Paint()..color = _bg.withOpacity(0.90));
    canvas.drawRRect(
      rr,
      Paint()
        ..color       = lvl.lineColor.withOpacity(0.35)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    tp.paint(canvas, Offset(xOff + 7, y - tp.height / 2));
  }

  void _paintHandle(
    Canvas canvas,
    Offset center,
    Color color,
    bool isActive, {
    required bool isStart,
    required FibonacciOverlay ov,
  }) {
    final handle = isStart ? _FibHandle.startFree : _FibHandle.endFree;
    final isHov  = hoveredHandle == handle;
    final r      = isActive ? 9.0 : (isHov ? 8.0 : 7.0);

    if (isActive) {
      canvas.drawCircle(
        center, r + 4,
        Paint()
          ..color      = color.withOpacity(0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawCircle(center, r + 1.5, Paint()..color = _bg);
    canvas.drawCircle(center, r,       Paint()..color = color);
  }

  void _paintLockIcon(Canvas canvas, Offset c) {
    final tp = TextPainter(
      text: TextSpan(
        text:  String.fromCharCode(Icons.lock_rounded.codePoint),
        style: TextStyle(
          fontSize:   15,
          fontFamily: Icons.lock_rounded.fontFamily,
          color:      Colors.amber.withOpacity(0.9),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  void _dashed(Canvas canvas, Offset s, Offset e, Paint p) {
    const d    = 5.0;
    const g    = 3.5;
    final dist = (e - s).distance;
    if (dist < 1e-6) return;
    final n = (e - s) / dist;
    var x   = 0.0;
    while (x < dist) {
      canvas.drawLine(s + n * x, s + n * math.min(x + d, dist), p);
      x += d + g;
    }
  }

  String _fmt(double p) {
    if (p >= 10000) return p.toStringAsFixed(1);
    if (p >= 1000)  return p.toStringAsFixed(2);
    if (p >= 1)     return p.toStringAsFixed(3);
    return p.toStringAsFixed(5);
  }

  @override
  bool shouldRepaint(_FibPainter o) =>
      o.overlays      != overlays      ||
      o.activeIdx     != activeIdx     ||
      o.activeHandle  != activeHandle  ||
      o.hoveredHandle != hoveredHandle ||
      o.hoveredIdx    != hoveredIdx    ||
      o.viewport      != viewport      ||
      o.isDrawing     != isDrawing     ||
      o.drawStart     != drawStart     ||
      o.drawCurrent   != drawCurrent   ||
      o.appearValue   != appearValue;
}