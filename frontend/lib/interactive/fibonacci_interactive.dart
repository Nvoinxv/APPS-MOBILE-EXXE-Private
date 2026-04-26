import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/chart_viewport.dart';
import '../controller/cloneable_overlay.dart';

// ===========================================================================
// FibLevel — konfigurasi warna/style per level (ala TradingView)
// ===========================================================================

class FibLevel {
  final double ratio;
  final String label;
  final Color  lineColor;
  final Color  fillColor;
  final double lineWidth;
  final bool   showLabel;
  final bool   isDashed;

  const FibLevel({
    required this.ratio,
    required this.label,
    required this.lineColor,
    Color?  fillColor,
    this.lineWidth = 1.0,
    this.showLabel = true,
    this.isDashed  = false,
  }) : fillColor = fillColor ?? lineColor;

  FibLevel copyWith({
    Color?  lineColor,
    Color?  fillColor,
    double? lineWidth,
    bool?   showLabel,
    bool?   isDashed,
  }) => FibLevel(
    ratio:     ratio,
    label:     label,
    lineColor: lineColor  ?? this.lineColor,
    fillColor: fillColor  ?? this.fillColor,
    lineWidth: lineWidth  ?? this.lineWidth,
    showLabel: showLabel  ?? this.showLabel,
    isDashed:  isDashed   ?? this.isDashed,
  );

  static List<FibLevel> get defaults => [
    FibLevel(ratio: 0.000, label: '0',     lineColor: const Color(0xFF787B86)),
    FibLevel(ratio: 0.236, label: '0.236', lineColor: const Color(0xFFF7525F)),
    FibLevel(ratio: 0.382, label: '0.382', lineColor: const Color(0xFFFF9800)),
    FibLevel(ratio: 0.500, label: '0.5',   lineColor: const Color(0xFF4CAF50)),
    FibLevel(ratio: 0.618, label: '0.618', lineColor: const Color(0xFF2196F3), lineWidth: 1.5),
    FibLevel(ratio: 0.786, label: '0.786', lineColor: const Color(0xFF9C27B0)),
    FibLevel(ratio: 1.000, label: '1',     lineColor: const Color(0xFF787B86)),
  ];
}

// ===========================================================================
// FibonacciOverlay — data model dalam DATA SPACE
// (identik pola RiskRatioOverlay: simpan candle index float + price)
// ===========================================================================

class FibonacciOverlay implements CloneableOverlay<FibonacciOverlay> {
  final double         startIndexF;  // X titik awal (candle index float)
  final double         endIndexF;    // X titik akhir
  final double         startPrice;   // Y titik awal
  final double         endPrice;     // Y titik akhir
  final List<FibLevel> levels;
  final bool           isLocked;
  final bool           extendLeft;
  final bool           extendRight;

  const FibonacciOverlay({
    required this.startIndexF,
    required this.endIndexF,
    required this.startPrice,
    required this.endPrice,
    List<FibLevel>? levels,
    this.isLocked    = false,
    this.extendLeft  = false,
    this.extendRight = true,
  }) : levels = levels ?? FibLevel.defaults;

  // ── Konversi data space → screen (gunakan ChartViewport persis RR) ────
  double startX(ChartViewport vp) =>
      DataSpacePoint(candleIndexF: startIndexF, price: 0).toScreen(vp).dx;
  double endX(ChartViewport vp) =>
      DataSpacePoint(candleIndexF: endIndexF, price: 0).toScreen(vp).dx;
  double startY(ChartViewport vp) => vp.priceToY(startPrice);
  double endY(ChartViewport vp)   => vp.priceToY(endPrice);

  double priceAtRatio(double ratio) =>
      startPrice + (endPrice - startPrice) * ratio;
  double yAtRatio(double ratio, ChartViewport vp) =>
      vp.priceToY(priceAtRatio(ratio));

  @override
  String get overlayId =>
      'fib_${startIndexF.toStringAsFixed(2)}_${startPrice.toStringAsFixed(4)}';

  @override
  FibonacciOverlay copyWith({
    double?         startIndexF,
    double?         endIndexF,
    double?         startPrice,
    double?         endPrice,
    List<FibLevel>? levels,
    bool?           isLocked,
    bool?           extendLeft,
    bool?           extendRight,
  }) => FibonacciOverlay(
    startIndexF:  startIndexF  ?? this.startIndexF,
    endIndexF:    endIndexF    ?? this.endIndexF,
    startPrice:   startPrice   ?? this.startPrice,
    endPrice:     endPrice     ?? this.endPrice,
    levels:       levels       ?? List.from(this.levels),
    isLocked:     isLocked     ?? this.isLocked,
    extendLeft:   extendLeft   ?? this.extendLeft,
    extendRight:  extendRight  ?? this.extendRight,
  );

  @override
  FibonacciOverlay cloneWithOffset({
    required double candleOffset,
    required double priceOffset,
  }) => FibonacciOverlay(
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
}

// ===========================================================================
// Drag anchor — PERSIS pola _DragAnchor di RiskRatioOverlay
// Snapshot seluruh state saat pointer down, delta dihitung dari sini
// ===========================================================================

enum _FibHandle { none, startFree, startLockX, startLockY, endFree, endLockX, endLockY, whole }

class _FibAnchor {
  final double startIndexF;
  final double endIndexF;
  final double startPrice;
  final double endPrice;
  final double anchorCandleF;  // pointer X dalam data space saat mousedown
  final double anchorPrice;    // pointer Y dalam data space saat mousedown

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
      startIndexF:  ov.startIndexF,
      endIndexF:    ov.endIndexF,
      startPrice:   ov.startPrice,
      endPrice:     ov.endPrice,
      anchorCandleF: vp.xToIndexF(screen.dx),  // screen → data space
      anchorPrice:   vp.yToPrice(screen.dy),
    );

  /// Hitung overlay baru dari delta pointer (data space) sesuai handle.
  ///
  /// Lock X  = Shift held → hanya startIndexF / endIndexF berubah, price tetap
  /// Lock Y  = Alt held   → hanya price berubah, index tetap
  /// Free    = keduanya berubah
  FibonacciOverlay apply(_FibHandle handle, Offset current, ChartViewport vp,
      FibonacciOverlay ov) {
    final dC = vp.xToIndexF(current.dx) - anchorCandleF;  // Δ candle
    final dP = vp.yToPrice(current.dy)  - anchorPrice;    // Δ price

    switch (handle) {

      // ── start handle ────────────────────────────────────────────────────
      case _FibHandle.startFree:
        return ov.copyWith(
          startIndexF: startIndexF + dC,
          startPrice:  (startPrice + dP).clamp(vp.minPrice, vp.maxPrice),
        );
      case _FibHandle.startLockX:          // Shift: geser X, price KUNCI
        return ov.copyWith(startIndexF: startIndexF + dC);
      case _FibHandle.startLockY:          // Alt: geser Y, index KUNCI
        return ov.copyWith(
          startPrice: (startPrice + dP).clamp(vp.minPrice, vp.maxPrice),
        );

      // ── end handle ──────────────────────────────────────────────────────
      case _FibHandle.endFree:
        return ov.copyWith(
          endIndexF: endIndexF + dC,
          endPrice:  (endPrice + dP).clamp(vp.minPrice, vp.maxPrice),
        );
      case _FibHandle.endLockX:            // Shift: geser X saja
        return ov.copyWith(endIndexF: endIndexF + dC);
      case _FibHandle.endLockY:            // Alt: geser Y saja
        return ov.copyWith(
          endPrice: (endPrice + dP).clamp(vp.minPrice, vp.maxPrice),
        );

      // ── whole overlay (drag dari tengah) ────────────────────────────────
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
// Widget utama
// ===========================================================================

class FibonacciInteractive extends StatefulWidget {
  final ChartViewport viewport;
  final Color         accentColor;
  final Color         backgroundColor;
  final Color         textColor;

  const FibonacciInteractive({
    Key? key,
    required this.viewport,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  State<FibonacciInteractive> createState() => FibonacciInteractiveState();
}

class FibonacciInteractiveState extends State<FibonacciInteractive> {

  final List<FibonacciOverlay> overlays = [];

  // Drawing state
  bool    isDrawing        = false;
  Offset? _drawStart;
  Offset? _drawCurrent;

  // Drag state — persis RR: simpan index overlay + handle + anchor snapshot
  int          _activeIdx    = -1;
  _FibHandle   _activeHandle = _FibHandle.none;
  _FibHandle   _hoveredHandle = _FibHandle.none;
  int          _hoveredIdx   = -1;
  _FibAnchor?  _anchor;
  ChartViewport? _dragVp;   // snapshot viewport saat mousedown

  static const double _hitHandle = 22.0;
  static const double _hitLine   = 12.0;

  ChartViewport get _vp => widget.viewport;

  // ── Public API (dipanggil dari parent) ───────────────────────────────

  void clearAll() => setState(() {
    overlays.clear();
    _reset();
  });

  void removeAt(int i) {
    if (i < 0 || i >= overlays.length) return;
    setState(() => overlays.removeAt(i));
  }

  void toggleLock([int? idx]) {
    final i = idx ?? _activeIdx;
    if (i < 0 || i >= overlays.length) return;
    setState(() => overlays[i] = overlays[i].copyWith(isLocked: !overlays[i].isLocked));
  }

  void openColorSettings(BuildContext ctx, [int? idx]) {
    final i = idx ?? (_activeIdx >= 0 ? _activeIdx : overlays.length - 1);
    if (i < 0 || i >= overlays.length) return;
    showDialog(
      context: ctx,
      builder: (_) => _FibColorDialog(
        levels: overlays[i].levels,
        onChanged: (updated) => setState(
          () => overlays[i] = overlays[i].copyWith(levels: updated),
        ),
      ),
    );
  }

  void startDrawing(Offset screen) => setState(() {
    isDrawing = true;
    _drawStart = _drawCurrent = screen;
  });

  bool get isLocked {
    if (_activeIdx >= 0 && _activeIdx < overlays.length) {
      return overlays[_activeIdx].isLocked;
    }
    return overlays.isNotEmpty && overlays.last.isLocked;
  }

  // ── Hit testing ──────────────────────────────────────────────────────

  /// Deteksi handle + tentukan mode lock dari modifier key.
  _FibHandle _detect(Offset screen, FibonacciOverlay ov) {
    final sX = ov.startX(_vp);  final sY = ov.startY(_vp);
    final eX = ov.endX(_vp);    final eY = ov.endY(_vp);

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt   = HardwareKeyboard.instance.isAltPressed;

    if ((screen - Offset(sX, sY)).distance < _hitHandle) {
      if (shift) return _FibHandle.startLockX;  // lock Y, geser X
      if (alt)   return _FibHandle.startLockY;  // lock X, geser Y
      return _FibHandle.startFree;
    }
    if ((screen - Offset(eX, eY)).distance < _hitHandle) {
      if (shift) return _FibHandle.endLockX;
      if (alt)   return _FibHandle.endLockY;
      return _FibHandle.endFree;
    }

    // Hit garis trend + semua level lines → whole overlay drag
    if (_distToSegment(screen, Offset(sX, sY), Offset(eX, eY)) < _hitLine)
      return _FibHandle.whole;
    for (final lvl in ov.levels) {
      if ((screen.dy - ov.yAtRatio(lvl.ratio, _vp)).abs() < _hitLine)
        return _FibHandle.whole;
    }
    return _FibHandle.none;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t  = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) /
               (ab.distanceSquared + 1e-9);
    return (p - (a + ab * t.clamp(0.0, 1.0))).distance;
  }

  bool isInsideInteractiveArea(Offset screen) {
    for (final ov in overlays) {
      if (_detect(screen, ov) != _FibHandle.none) return true;
    }
    return false;
  }

  // ── Pointer events ───────────────────────────────────────────────────

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
    if (_activeHandle != _FibHandle.none && _activeIdx >= 0) {
      final a  = _anchor;
      final vp = _dragVp;
      if (a == null || vp == null) return;
      setState(() {
        overlays[_activeIdx] =
            a.apply(_activeHandle, screen, vp, overlays[_activeIdx]);
      });
      return;
    }
    // Hover
    for (int i = overlays.length - 1; i >= 0; i--) {
      final h = _detect(screen, overlays[i]);
      if (h != _FibHandle.none) {
        if (_hoveredHandle != h || _hoveredIdx != i)
          setState(() { _hoveredHandle = h; _hoveredIdx = i; });
        return;
      }
    }
    if (_hoveredHandle != _FibHandle.none)
      setState(() { _hoveredHandle = _FibHandle.none; _hoveredIdx = -1; });
  }

  void handlePointerUp(Offset screen) {
    if (isDrawing) { _finishDrawing(); return; }
    setState(() {
      _activeHandle = _FibHandle.none;
      _activeIdx    = -1;
      _anchor       = null;
      _dragVp       = null;
    });
  }

  void handlePointerCancel() => setState(_reset);

  void _reset() {
    isDrawing    = false;
    _drawStart   = null;
    _drawCurrent = null;
    _activeHandle = _FibHandle.none;
    _activeIdx   = -1;
    _anchor      = null;
    _dragVp      = null;
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
      isDrawing = false;
    });
  }

  @override
  Widget build(BuildContext ctx) => CustomPaint(
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
      bgColor:       widget.backgroundColor,
    ),
    child: const SizedBox.expand(),
  );
}

// ===========================================================================
// Painter
// ===========================================================================

class _FibPainter extends CustomPainter {
  final List<FibonacciOverlay> overlays;
  final int                     activeIdx;
  final _FibHandle              activeHandle;
  final _FibHandle              hoveredHandle;
  final int                     hoveredIdx;
  final ChartViewport           viewport;
  final bool                    isDrawing;
  final Offset?                 drawStart;
  final Offset?                 drawCurrent;
  final Color                   bgColor;

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
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isDrawing && drawStart != null && drawCurrent != null)
      _paintPreview(canvas, size, drawStart!, drawCurrent!);
    for (int i = 0; i < overlays.length; i++)
      _paintOverlay(canvas, size, overlays[i], i == activeIdx);
  }

  void _paintPreview(Canvas canvas, Size size, Offset s, Offset e) {
    final p = Paint()..color = Colors.white38..strokeWidth = 1.2;
    canvas.drawLine(s, e, p);
    canvas.drawCircle(s, 5, Paint()..color = Colors.white54);
    canvas.drawCircle(e, 5, Paint()..color = Colors.white54);
  }

  void _paintOverlay(Canvas canvas, Size size,
      FibonacciOverlay ov, bool isActive) {
    final sX = ov.startX(viewport);  final sY = ov.startY(viewport);
    final eX = ov.endX(viewport);    final eY = ov.endY(viewport);
    final col0 = ov.levels.first.lineColor;
    final colN = ov.levels.last.lineColor;

    // Trend line
    canvas.drawLine(Offset(sX, sY), Offset(eX, eY),
      Paint()..color = col0.withOpacity(0.55)..strokeWidth = 1.2);

    // Fill bands
    for (int i = 0; i < ov.levels.length - 1; i++) {
      final y1 = ov.yAtRatio(ov.levels[i].ratio,     viewport);
      final y2 = ov.yAtRatio(ov.levels[i+1].ratio,  viewport);
      final lx = ov.extendLeft  ? 0.0        : math.min(sX, eX);
      final rx = ov.extendRight ? size.width  : math.max(sX, eX);
      canvas.drawRect(
        Rect.fromLTRB(lx, math.min(y1, y2), rx, math.max(y1, y2)),
        Paint()..color = ov.levels[i].fillColor.withOpacity(0.045),
      );
    }

    // Level lines + labels
    for (final lvl in ov.levels) {
      final y  = ov.yAtRatio(lvl.ratio, viewport);
      final lx = ov.extendLeft  ? 0.0        : math.min(sX, eX);
      final rx = ov.extendRight ? size.width  : math.max(sX, eX);
      final lp = Paint()
        ..color       = lvl.lineColor.withOpacity(isActive ? 0.90 : 0.65)
        ..strokeWidth = lvl.lineWidth;
      if (lvl.isDashed) _dashed(canvas, Offset(lx, y), Offset(rx, y), lp);
      else              canvas.drawLine(Offset(lx, y), Offset(rx, y), lp);
      if (lvl.showLabel) _paintLabel(canvas, size, lvl, ov, y);
    }

    // Handles
    _paintHandle(canvas, Offset(sX, sY), col0, isActive);
    _paintHandle(canvas, Offset(eX, eY), colN, isActive);

    if (ov.isLocked) {
      _paintLockIcon(canvas, Offset((sX + eX) / 2, (sY + eY) / 2));
    }
  }

  void _paintLabel(Canvas canvas, Size size,
      FibLevel lvl, FibonacciOverlay ov, double y) {
    final price = ov.priceAtRatio(lvl.ratio);
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(text: lvl.label,
          style: TextStyle(
            color: lvl.lineColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
        TextSpan(text: '  ${_fmt(price)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.72), fontSize: 9.5)),
      ]),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const xOff = 6.0; const bh = 18.0;
    final bw = tp.width + 14;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(xOff, y - bh / 2, bw, bh), const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..color = _bg.withOpacity(0.90));
    canvas.drawRRect(rr, Paint()
      ..color = lvl.lineColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    tp.paint(canvas, Offset(xOff + 7, y - tp.height / 2));
  }

  void _paintHandle(Canvas canvas, Offset center, Color color, bool isActive) {
    final r = isActive ? 9.0 : 7.0;
    canvas.drawCircle(center, r + 1.5, Paint()..color = _bg);
    canvas.drawCircle(center, r,       Paint()..color = color);
  }

  void _paintLockIcon(Canvas canvas, Offset c) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.lock_rounded.codePoint),
        style: TextStyle(fontSize: 15,
          fontFamily: Icons.lock_rounded.fontFamily,
          color: Colors.amber.withOpacity(0.9)),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  void _dashed(Canvas canvas, Offset s, Offset e, Paint p) {
    const d = 5.0; const g = 3.5;
    final dist = (e - s).distance;
    final n = (e - s) / dist;
    var x = 0.0;
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
    o.viewport      != viewport      ||
    o.isDrawing     != isDrawing     ||
    o.drawStart     != drawStart     ||
    o.drawCurrent   != drawCurrent;
}

// ===========================================================================
// _FibColorDialog — edit warna/style tiap level (ala TradingView)
// ===========================================================================

class _FibColorDialog extends StatefulWidget {
  final List<FibLevel>                levels;
  final ValueChanged<List<FibLevel>> onChanged;
  const _FibColorDialog({required this.levels, required this.onChanged});
  @override
  State<_FibColorDialog> createState() => _FibColorDialogState();
}

class _FibColorDialogState extends State<_FibColorDialog> {
  late List<FibLevel> _levels;

  @override
  void initState() { super.initState(); _levels = List.from(widget.levels); }

  void _upd(int i, FibLevel v) {
    setState(() => _levels[i] = v);
    widget.onChanged(_levels);
  }

  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: const Text('Fibonacci levels'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const SizedBox(width: 52, child: Text('Level',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(width: 28, child: Text('Color',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                const Expanded(child: Text('Width',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(width: 36,
                  child: Text('---', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(width: 32,
                  child: Text('Show', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
            ...List.generate(_levels.length, (i) {
              final lvl = _levels[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  // Ratio label
                  SizedBox(width: 52,
                    child: Text(lvl.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  // Color swatch
                  GestureDetector(
                    onTap: () => _pickColor(ctx, i, lvl),
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color:        lvl.lineColor,
                        borderRadius: BorderRadius.circular(4),
                        border:       Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Width slider
                  Expanded(child: Slider(
                    min: 0.5, max: 3.0, divisions: 5,
                    value: lvl.lineWidth,
                    onChanged: (v) => _upd(i, lvl.copyWith(lineWidth: v)),
                  )),
                  // Dashed toggle
                  SizedBox(width: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        lvl.isDashed ? Icons.more_horiz : Icons.horizontal_rule,
                        size: 18,
                        color: lvl.isDashed ? Theme.of(ctx).colorScheme.primary : null,
                      ),
                      onPressed: () => _upd(i, lvl.copyWith(isDashed: !lvl.isDashed)),
                      tooltip: lvl.isDashed ? 'Solid' : 'Dashed',
                    ),
                  ),
                  // Show label toggle
                  SizedBox(width: 32,
                    child: Checkbox(
                      value: lvl.showLabel,
                      onChanged: (v) => _upd(i, lvl.copyWith(showLabel: v ?? true)),
                    ),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          setState(() => _levels = FibLevel.defaults);
          widget.onChanged(_levels);
        },
        child: const Text('Reset defaults'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Done'),
      ),
    ],
  );

  void _pickColor(BuildContext ctx, int i, FibLevel lvl) {
    // Gunakan package flutter_colorpicker.
    // Panggil showDialog dengan ColorPicker widget di dalamnya.
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Color — ${lvl.label}'),
        content: ColorPicker(            // flutter_colorpicker ^1.1.0
          pickerColor:   lvl.lineColor,
          onColorChanged: (c) => _upd(i, lvl.copyWith(lineColor: c)),
          enableAlpha:   true,
          pickerAreaHeightPercent: 0.5,
        ),
        actions: [FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        )],
      ),
    );
  }
}