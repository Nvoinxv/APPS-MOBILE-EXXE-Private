// ══════════════════════════════════════════════════════════════════════════════
// Sl_Strategy_2.dart  —  FIX v3: widget menerima `scale` + `scrollOffset`
//                         sebagai parameter terpisah sehingga mapper selalu
//                         dibuat fresh setiap build/frame. Posisi label dan
//                         zone akan sinkron dengan candle saat pan/zoom.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../utils/chart_utils.dart';
import '../Hooks_Strategy/base_signal.dart';

// ══════════════════════════════════════════════════
// §0  INPUT FROM HOOK
// ══════════════════════════════════════════════════

class TradeSignalInput {
  final String       direction;
  final double       entryPrice;
  final double?      trailingStop;
  final int          barIndex;
  final List<double> recentLows;
  final List<double> recentHighs;

  const TradeSignalInput({
    required this.direction,
    required this.entryPrice,
    required this.barIndex,
    required this.recentLows,
    required this.recentHighs,
    this.trailingStop,
  });

  bool get isLong  => direction == 'long';
  bool get isShort => direction == 'short';

  double get lookbackLow =>
      recentLows.isEmpty ? entryPrice * 0.97 : recentLows.reduce(math.min);

  double get lookbackHigh =>
      recentHighs.isEmpty ? entryPrice * 1.03 : recentHighs.reduce(math.max);
}

// ══════════════════════════════════════════════════
// §1  ENUMS
// ══════════════════════════════════════════════════

enum TradeDirection { long, short }

// ══════════════════════════════════════════════════
// §2  TRADE SETUP DATA MODEL
// ══════════════════════════════════════════════════

class TradeSetup {
  final TradeDirection direction;
  double entryPrice;
  double slPrice;
  double tpPrice;
  double r1Price;
  bool   isBreakeven;
  bool   isActive;
  bool   slHit;
  bool   tpHit;
  double? trailingStopRef;
  final int entryBarIndex;

  // Disimpan sebagai candle index — X dihitung fresh dari mapper setiap frame
  int leftCandleIndex;
  int rightCandleIndex;

  TradeSetup({
    required this.direction,
    required this.entryPrice,
    required this.slPrice,
    required this.tpPrice,
    required this.r1Price,
    required this.entryBarIndex,
    required this.leftCandleIndex,
    required this.rightCandleIndex,
    this.isBreakeven    = false,
    this.isActive       = true,
    this.slHit          = false,
    this.tpHit          = false,
    this.trailingStopRef,
  });

  double get risk => (entryPrice - slPrice).abs();

  // FIX v3: X selalu dihitung fresh dari mapper terbaru
  double leftX (ChartCoordinateMapper m) => m.candleIndexToX(leftCandleIndex);
  double rightX(ChartCoordinateMapper m) => m.candleIndexToX(rightCandleIndex);

  bool checkSlHit({required double low, required double high}) {
    if (!isActive) return false;
    return direction == TradeDirection.long ? low <= slPrice : high >= slPrice;
  }

  bool checkTpHit({required double low, required double high}) {
    if (!isActive) return false;
    return direction == TradeDirection.long ? high >= tpPrice : low <= tpPrice;
  }

  bool check1RHit({required double low, required double high}) =>
      direction == TradeDirection.long ? high >= r1Price : low <= r1Price;

  void applyBreakeven() {
    if (!isBreakeven) { slPrice = entryPrice; isBreakeven = true; }
  }

  void close({required bool byTp}) {
    isActive = false;
    if (byTp) tpHit = true; else slHit = true;
  }
}

// ══════════════════════════════════════════════════
// §3  DRAG HANDLE ENUM
// ══════════════════════════════════════════════════

enum SlDragHandle { none, stopLoss, entry, leftEdge, rightEdge, wholeBox }

// ══════════════════════════════════════════════════
// §4  INTERACTIVE WIDGET
//
// FIX v3: ganti field `mapper` (nullable, sekali pass) dengan dua parameter
// `totalCandles`, `scale`, dan `scrollOffset`. Mapper dibuat fresh via
// getter `_mapper` setiap kali diakses, sehingga selalu berisi
// offset/scale terkini saat pan/zoom.
// ══════════════════════════════════════════════════

class StopLossInteractive extends StatefulWidget {
  final Size   chartSize;
  final Color  accentColor;
  final Color  backgroundColor;
  final Color  textColor;
  final double minPrice;
  final double maxPrice;
  // FIX v3: ganti mapper nullable dengan tiga parameter ini
  final int    totalCandles;
  final double scale;
  final double scrollOffset;

  final int    slLookback;
  final double rrRatio;
  final bool   useBreakeven;

  final void Function(TradeSetup)? onTradeOpened;
  final void Function(TradeSetup)? onSlHit;
  final void Function(TradeSetup)? onTpHit;
  final void Function(TradeSetup)? onBreakevenApplied;

  final Color longRewardColor;
  final Color shortRewardColor;
  final Color riskZoneColor;
  final Color slLineColor;
  final Color tpLineColor;
  final Color beLineColor;
  final Color entryLineColor;

  const StopLossInteractive({
    Key? key,
    required this.chartSize,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.minPrice,
    required this.maxPrice,
    required this.totalCandles,
    required this.scale,
    required this.scrollOffset,
    this.slLookback         = 15,
    this.rrRatio            = 2.0,
    this.useBreakeven       = true,
    this.onTradeOpened,
    this.onSlHit,
    this.onTpHit,
    this.onBreakevenApplied,
    this.longRewardColor    = const Color(0x3300ffe5),
    this.shortRewardColor   = const Color(0x33ca29ff),
    this.riskZoneColor      = const Color(0x33ff3d6b),
    this.slLineColor        = const Color(0xBFFF3D6B),
    this.tpLineColor        = const Color(0xBF00E5A0),
    this.beLineColor        = const Color(0xBF2979FF),
    this.entryLineColor     = const Color(0xBFFFFFFF),
  }) : super(key: key);

  @override
  State<StopLossInteractive> createState() => StopLossInteractiveState();
}

class StopLossInteractiveState extends State<StopLossInteractive>
    with TickerProviderStateMixin, ChartAnimationMixin {

  TradeSetup? _trade;

  bool    _isDrawing    = false;
  Offset? _drawStart;
  Offset? _drawCurrent;

  SlDragHandle _activeDrag    = SlDragHandle.none;
  Offset?      _dragAnchor;
  double?      _anchorLeftX, _anchorRightX, _anchorEntry, _anchorSl;
  SlDragHandle _hoveredHandle = SlDragHandle.none;

  static const double _handleRadius = 26.0;
  static const double _edgeWidth    = 18.0;

  // FIX v3: mapper selalu fresh dari widget properties terkini
  ChartCoordinateMapper get _mapper => ChartCoordinateMapper(
    totalCandles: widget.totalCandles,
    minPrice:     widget.minPrice,
    maxPrice:     widget.maxPrice,
    chartSize:    widget.chartSize,
    scale:        widget.scale,
    offset:       widget.scrollOffset,
  );

  @override
  void initState() {
    super.initState();
    initChartAnimations(this);
  }

  @override
  void dispose() {
    disposeChartAnimations();
    super.dispose();
  }

  // ── Coordinate helpers ─────────────────────────────────────────────────

  double _priceToY(double p) {
    final range = widget.maxPrice - widget.minPrice;
    if (range == 0) return widget.chartSize.height / 2;
    return widget.chartSize.height * (1 - (p - widget.minPrice) / range);
  }

  double _yToPrice(double y) {
    final range = widget.maxPrice - widget.minPrice;
    return widget.minPrice + (1.0 - y / widget.chartSize.height) * range;
  }

  // ══════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════

  void openTradeFromSignal(TradeSignalInput input) {
    if (_trade != null && _trade!.isActive) return;

    final m     = _mapper;
    final entry = input.entryPrice;
    double sl, tp, r1;

    if (input.isLong) {
      sl = input.lookbackLow;
      final risk = entry - sl;
      tp = entry + risk * widget.rrRatio;
      r1 = entry + risk;
    } else {
      sl = input.lookbackHigh;
      final risk = sl - entry;
      tp = entry - risk * widget.rrRatio;
      r1 = entry - risk;
    }

    final totalW = widget.chartSize.width;
    final cx     = m.candleIndexToX(input.barIndex);
    final halfW  = totalW * 0.20;

    final leftIdx  = m.xToCandleIndex((cx - halfW).clamp(0, totalW));
    final rightIdx = m.xToCandleIndex((cx + halfW).clamp(0, totalW));

    final setup = TradeSetup(
      direction:          input.isLong ? TradeDirection.long : TradeDirection.short,
      entryPrice:         entry,
      slPrice:            sl,
      tpPrice:            tp,
      r1Price:            r1,
      entryBarIndex:      input.barIndex,
      leftCandleIndex:    leftIdx,
      rightCandleIndex:   rightIdx,
      trailingStopRef:    input.trailingStop,
    );

    setState(() => _trade = setup);
    appearCtrl.forward(from: 0);
    widget.onTradeOpened?.call(setup);
  }

  void extendToBar(int barIndex) {
    if (_trade == null || !_trade!.isActive) return;
    setState(() => _trade!.rightCandleIndex = barIndex);
  }

  void processBar({required double high, required double low}) {
    final t = _trade;
    if (t == null || !t.isActive) return;

    setState(() {
      if (widget.useBreakeven && !t.isBreakeven && t.check1RHit(low: low, high: high)) {
        t.applyBreakeven();
        widget.onBreakevenApplied?.call(t);
      }
      if (t.checkSlHit(low: low, high: high)) {
        t.close(byTp: false);
        hitCtrl.forward(from: 0);
        widget.onSlHit?.call(t);
        return;
      }
      if (t.checkTpHit(low: low, high: high)) {
        t.close(byTp: true);
        widget.onTpHit?.call(t);
      }
    });
  }

  void clearTrade() {
    setState(() {
      _trade      = null;
      _isDrawing  = false;
      _drawStart  = _drawCurrent = null;
      _activeDrag = SlDragHandle.none;
    });
    appearCtrl.reset();
    hitCtrl.reset();
  }

  void applyBreakevenManual() {
    if (_trade == null || !widget.useBreakeven) return;
    setState(() => _trade!.applyBreakeven());
    widget.onBreakevenApplied?.call(_trade!);
  }

  TradeSetup? get currentTrade  => _trade;
  bool        get hasTrade      => _trade != null;
  bool        get isTradeActive => _trade?.isActive ?? false;

  // ── Gesture API ────────────────────────────────────────────────────────

  bool isInsideInteractiveArea(Offset pos) {
    if (_trade == null) return false;
    return _detectHandle(pos) != SlDragHandle.none;
  }

  bool handlePointerDown(Offset pos) {
    if (_trade == null) return false;

    final h = _detectHandle(pos);
    if (h == SlDragHandle.none) return false;

    // FIX v3: ambil koordinat pixel fresh dari mapper saat drag dimulai
    final m = _mapper;
    setState(() {
      _activeDrag   = h;
      _dragAnchor   = pos;
      _anchorLeftX  = _trade!.leftX(m);
      _anchorRightX = _trade!.rightX(m);
      _anchorEntry  = _trade!.entryPrice;
      _anchorSl     = _trade!.slPrice;
    });
    return true;
  }

  void handlePointerMove(Offset pos) {
    if (_isDrawing)                       { _updateDrawing(pos); return; }
    if (_activeDrag != SlDragHandle.none)   _handleDrag(pos);
    setState(() => _hoveredHandle = _detectHandle(pos));
  }

  void handlePointerUp(Offset pos) =>
      _isDrawing ? _finishDrawing() : _endDrag();

  void handlePointerCancel() {
    if (_isDrawing) setState(() { _isDrawing = false; _drawStart = _drawCurrent = null; });
    else            _endDrag();
  }

  void startDrawing(Offset pos) =>
      setState(() { _isDrawing = true; _drawStart = pos; _drawCurrent = pos; });

  // ── Hit test ───────────────────────────────────────────────────────────

  SlDragHandle _detectHandle(Offset pos) {
    if (_trade == null) return SlDragHandle.none;

    // FIX v3: selalu gunakan mapper terbaru untuk koordinat X
    final m  = _mapper;
    final lx = _trade!.leftX(m);
    final rx = _trade!.rightX(m);

    final slY  = _priceToY(_trade!.slPrice);
    final eY   = _priceToY(_trade!.entryPrice);
    final topY  = math.min(slY, eY);
    final botY  = math.max(slY, eY);
    final inBoxY = pos.dy >= topY - 24 && pos.dy <= botY + 24;

    if ((lx - pos.dx).abs() < _edgeWidth && inBoxY) return SlDragHandle.leftEdge;
    if ((rx - pos.dx).abs() < _edgeWidth && inBoxY) return SlDragHandle.rightEdge;

    final inBoxX = pos.dx >= lx && pos.dx <= rx;
    if (!inBoxX) return SlDragHandle.none;

    final w = rx - lx;
    if ((pos - Offset(lx + w * 0.30, slY)).distance < _handleRadius) return SlDragHandle.stopLoss;
    if ((pos - Offset(lx + w * 0.65, eY )).distance < _handleRadius) return SlDragHandle.entry;

    if (inBoxY) return SlDragHandle.wholeBox;
    return SlDragHandle.none;
  }

  // ── Drawing ────────────────────────────────────────────────────────────

  void _updateDrawing(Offset pos) => setState(() => _drawCurrent = pos);

  void _finishDrawing() {
    if (!_isDrawing || _drawStart == null || _drawCurrent == null) return;

    final lx = math.min(_drawStart!.dx, _drawCurrent!.dx);
    final rx = math.max(_drawStart!.dx, _drawCurrent!.dx);
    if (rx - lx < 80) {
      setState(() { _isDrawing = false; _drawStart = _drawCurrent = null; });
      return;
    }

    final m       = _mapper;
    final entryP  = _yToPrice(_drawStart!.dy);
    final slP     = _yToPrice(_drawCurrent!.dy);
    final valid   = entryP > slP;
    final finalSl = valid ? slP : entryP * 0.97;
    final risk    = entryP - finalSl;

    final leftIdx  = m.xToCandleIndex(lx);
    final rightIdx = m.xToCandleIndex(rx);

    setState(() {
      _trade = TradeSetup(
        direction:        TradeDirection.long,
        entryPrice:       entryP,
        slPrice:          finalSl,
        tpPrice:          entryP + risk * widget.rrRatio,
        r1Price:          entryP + risk,
        entryBarIndex:    leftIdx,
        leftCandleIndex:  leftIdx,
        rightCandleIndex: rightIdx,
      );
      _isDrawing = false; _drawStart = _drawCurrent = null;
    });
    appearCtrl.forward(from: 0);
    widget.onTradeOpened?.call(_trade!);
  }

  // ── Drag ───────────────────────────────────────────────────────────────

  void _handleDrag(Offset pos) {
    if (_dragAnchor == null || _trade == null) return;

    final dx  = pos.dx - _dragAnchor!.dx;
    final dy  = pos.dy - _dragAnchor!.dy;
    final ppp = (widget.maxPrice - widget.minPrice) / widget.chartSize.height;
    // FIX v3: mapper fresh untuk konversi pixel → candle index saat drag
    final m = _mapper;

    setState(() {
      final t = _trade!;
      switch (_activeDrag) {
        case SlDragHandle.stopLoss:
          t.slPrice = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
          break;
        case SlDragHandle.entry:
          final newE  = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
          final delta = newE - t.entryPrice;
          t.entryPrice = newE;
          t.slPrice    = (t.slPrice + delta).clamp(widget.minPrice, widget.maxPrice);
          t.tpPrice    = (t.tpPrice + delta).clamp(widget.minPrice, widget.maxPrice);
          t.r1Price    = (t.r1Price + delta).clamp(widget.minPrice, widget.maxPrice);
          break;
        case SlDragHandle.leftEdge:
          t.leftCandleIndex = m.xToCandleIndex(
              (_anchorLeftX! + dx).clamp(0.0, _anchorRightX! - 80));
          break;
        case SlDragHandle.rightEdge:
          t.rightCandleIndex = m.xToCandleIndex(
              (_anchorRightX! + dx).clamp(_anchorLeftX! + 80, widget.chartSize.width));
          break;
        case SlDragHandle.wholeBox:
          final w     = _anchorRightX! - _anchorLeftX!;
          final newLx = (_anchorLeftX! + dx).clamp(0.0, widget.chartSize.width - w);
          t.leftCandleIndex  = m.xToCandleIndex(newLx);
          t.rightCandleIndex = m.xToCandleIndex(newLx + w);
          final dp   = -dy * ppp;
          t.entryPrice = (_anchorEntry! + dp).clamp(widget.minPrice, widget.maxPrice);
          t.slPrice    = (_anchorSl!    + dp).clamp(widget.minPrice, widget.maxPrice);
          break;
        case SlDragHandle.none:
          break;
      }
    });
  }

  void _endDrag() {
    setState(() {
      _activeDrag   = SlDragHandle.none;
      _dragAnchor   = null;
      _anchorLeftX  = _anchorRightX = null;
      _anchorEntry  = _anchorSl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX v3: buat mapper fresh setiap build — berisi offset/scale terkini
    final liveMapper = _mapper;

    return AnimatedBuilder(
      animation: chartAnimListenable,
      builder: (_, __) => CustomPaint(
        painter: _StopLossPainter(
          trade:           _trade,
          // FIX v3: selalu pass mapper terbaru ke painter
          mapper:          liveMapper,
          isDrawing:       _isDrawing,
          drawStart:       _drawStart,
          drawCurrent:     _drawCurrent,
          chartSize:       widget.chartSize,
          minPrice:        widget.minPrice,
          maxPrice:        widget.maxPrice,
          activeDrag:      _activeDrag,
          hoveredHandle:   _hoveredHandle,
          pulseValue:      pulseAnim.value,
          appearValue:     appearAnim.value,
          hitValue:        hitAnim.value,
          longRewardColor: widget.longRewardColor,
          shortRewardColor:widget.shortRewardColor,
          riskZoneColor:   widget.riskZoneColor,
          slLineColor:     widget.slLineColor,
          tpLineColor:     widget.tpLineColor,
          beLineColor:     widget.beLineColor,
          entryLineColor:  widget.entryLineColor,
          accentColor:     widget.accentColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// §5  GESTURE ROUTER
// ══════════════════════════════════════════════════

class StopLossGestureRouter extends StatefulWidget {
  final GlobalKey<StopLossInteractiveState> slKey;
  final bool   isSlMode;
  final Widget child;

  const StopLossGestureRouter({
    Key? key,
    required this.slKey,
    required this.isSlMode,
    required this.child,
  }) : super(key: key);

  @override
  State<StopLossGestureRouter> createState() => _StopLossGestureRouterState();
}

class _StopLossGestureRouterState extends State<StopLossGestureRouter> {
  final Set<int>         _pointers    = {};
  final Map<int, Offset> _pendingDraw = {};
  static const double    _threshold   = 8.0;

  bool _onExisting(Offset p) =>
      widget.slKey.currentState?.isInsideInteractiveArea(p) ?? false;

  bool _canDraw() {
    final s = widget.slKey.currentState;
    return widget.isSlMode && s != null && !s.hasTrade && !s._isDrawing;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (e.buttons == kSecondaryButton) return;
        if (_onExisting(e.localPosition)) {
          _pointers.add(e.pointer);
          widget.slKey.currentState?.handlePointerDown(e.localPosition);
          return;
        }
        if (_canDraw()) _pendingDraw[e.pointer] = e.localPosition;
      },
      onPointerMove: (e) {
        if (_pointers.contains(e.pointer)) {
          widget.slKey.currentState?.handlePointerMove(e.localPosition);
          return;
        }
        final sp = _pendingDraw[e.pointer];
        if (sp != null && (e.localPosition - sp).distance >= _threshold) {
          _pendingDraw.remove(e.pointer);
          _pointers.add(e.pointer);
          widget.slKey.currentState?.startDrawing(sp);
          widget.slKey.currentState?._updateDrawing(e.localPosition);
        }
      },
      onPointerUp: (e) {
        _pendingDraw.remove(e.pointer);
        if (_pointers.remove(e.pointer))
          widget.slKey.currentState?.handlePointerUp(e.localPosition);
      },
      onPointerCancel: (e) {
        _pendingDraw.remove(e.pointer);
        if (_pointers.remove(e.pointer))
          widget.slKey.currentState?.handlePointerCancel();
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════
// §6  PAINTER
//
// FIX v3: shouldRepaint menggunakan == dari ChartCoordinateMapper
// (implement == & hashCode di chart_utils.dart) sehingga setiap
// perubahan offset/scale akan trigger repaint dengan benar.
// ══════════════════════════════════════════════════

class _StopLossPainter extends CustomPainter with ChartPainterUtils {
  final TradeSetup?            trade;
  final ChartCoordinateMapper? mapper;
  final bool                   isDrawing;
  final Offset?                drawStart;
  final Offset?                drawCurrent;
  final Size                   chartSize;
  final double                 minPrice;
  final double                 maxPrice;
  final SlDragHandle           activeDrag;
  final SlDragHandle           hoveredHandle;
  final double                 pulseValue;
  final double                 appearValue;
  final double                 hitValue;
  final Color                  longRewardColor;
  final Color                  shortRewardColor;
  final Color                  riskZoneColor;
  final Color                  slLineColor;
  final Color                  tpLineColor;
  final Color                  beLineColor;
  final Color                  entryLineColor;
  final Color                  accentColor;

  _StopLossPainter({
    required this.trade,
    required this.mapper,
    required this.isDrawing,
    required this.drawStart,
    required this.drawCurrent,
    required this.chartSize,
    required this.minPrice,
    required this.maxPrice,
    required this.activeDrag,
    required this.hoveredHandle,
    required this.pulseValue,
    required this.appearValue,
    required this.hitValue,
    required this.longRewardColor,
    required this.shortRewardColor,
    required this.riskZoneColor,
    required this.slLineColor,
    required this.tpLineColor,
    required this.beLineColor,
    required this.entryLineColor,
    required this.accentColor,
  });

  double _py(double price) {
    final r = maxPrice - minPrice;
    if (r == 0) return chartSize.height / 2;
    return chartSize.height * (1.0 - (price - minPrice) / r);
  }

  Color get _slColor => trade?.isBreakeven == true ? beLineColor : slLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final m = mapper;
    if (m == null) return;

    if (isDrawing && drawStart != null && drawCurrent != null)
      _paintPreview(canvas);
    if (trade != null) _paintTrade(canvas, trade!, m);
  }

  void _paintPreview(Canvas canvas) {
    final sp = drawStart!; final cp = drawCurrent!;
    final lx = math.min(sp.dx, cp.dx); final rx = math.max(sp.dx, cp.dx);
    if (rx - lx < 80) {
      _textLabel(canvas, (lx + rx) / 2, sp.dy + 10, '← min 80px →', Colors.orange);
      return;
    }
    canvas.drawRect(
      Rect.fromLTRB(lx, math.min(sp.dy, cp.dy), rx, math.max(sp.dy, cp.dy)),
      Paint()..color = riskZoneColor,
    );
    canvas.drawLine(Offset(lx, sp.dy), Offset(rx, sp.dy),
        Paint()..color = entryLineColor.withOpacity(0.8)..strokeWidth = 2.0);
    drawDashedLine(canvas, Offset(lx, cp.dy), Offset(rx, cp.dy),
        Paint()..color = slLineColor.withOpacity(0.7)..strokeWidth = 1.5);
  }

  // FIX v3: _paintTrade menerima mapper fresh, hitung lx/rx per frame
  void _paintTrade(Canvas canvas, TradeSetup t, ChartCoordinateMapper m) {
    // FIX v3: X selalu fresh dari candle index + mapper terbaru
    final lx  = t.leftX(m);
    final rx  = t.rightX(m);
    final eY  = _py(t.entryPrice);
    final slY = _py(t.slPrice);
    final tpY = _py(t.tpPrice);
    final r1Y = _py(t.r1Price);

    if (appearValue > 0.0 && appearValue < 1.0) {
      canvas.save();
      final cy = (math.min(slY, tpY) + math.max(slY, tpY)) / 2;
      canvas.translate((lx + rx) / 2, cy);
      final s = 0.85 + 0.15 * appearValue;
      canvas.scale(s, s);
      canvas.translate(-(lx + rx) / 2, -cy);
    }

    // Fills
    final rewardCol = t.direction == TradeDirection.long ? longRewardColor : shortRewardColor;
    canvas.drawRect(
        Rect.fromLTRB(lx, math.min(eY, tpY), rx, math.max(eY, tpY)),
        Paint()..color = rewardCol);
    canvas.drawRect(
        Rect.fromLTRB(lx, math.min(eY, slY), rx, math.max(eY, slY)),
        Paint()..color = riskZoneColor);

    // Edges
    final topY = [eY, slY, tpY, r1Y].reduce(math.min);
    final botY = [eY, slY, tpY, r1Y].reduce(math.max);
    drawEdgeLine(canvas, lx, topY, botY,
        isActive: activeDrag == SlDragHandle.leftEdge, accentColor: accentColor);
    drawEdgeLine(canvas, rx, topY, botY,
        isActive: activeDrag == SlDragHandle.rightEdge, accentColor: accentColor);

    // SL line
    _horizLine(canvas, lx, rx, slY, _slColor,
        label:    t.isBreakeven ? 'BE' : 'SL',
        price:    t.slPrice,
        isDashed: t.isBreakeven,
        isActive: activeDrag == SlDragHandle.stopLoss);

    // TP line
    _horizLine(canvas, lx, rx, tpY, tpLineColor,
        label:   'TP',
        price:   t.tpPrice,
        suffix:  _rrStr(t),
        isActive: false);

    // 1R line
    _horizLine(canvas, lx, rx, r1Y, beLineColor,
        label:    '1R',
        price:    t.r1Price,
        isDashed: true,
        isActive: false);

    // Entry line
    _horizLine(canvas, lx, rx, eY, entryLineColor,
        label:   t.direction == TradeDirection.long ? 'ENTRY ▲' : 'ENTRY ▼',
        price:   t.entryPrice,
        isActive: activeDrag == SlDragHandle.entry);

    // Drag handles
    final w = rx - lx;
    drawDragHandle(canvas, Offset(lx + w * 0.30, slY), _slColor,
        isActive: activeDrag == SlDragHandle.stopLoss,
        isHovered: hoveredHandle == SlDragHandle.stopLoss,
        label: 'SL', pulseValue: pulseValue);
    drawDragHandle(canvas, Offset(lx + w * 0.65, eY), entryLineColor,
        isActive: activeDrag == SlDragHandle.entry,
        isHovered: hoveredHandle == SlDragHandle.entry,
        label: 'E', pulseValue: pulseValue);

    // Move handle
    drawMoveHandle(canvas,
        centerX: (lx + rx) / 2,
        centerY: (topY + botY) / 2,
        isActive: activeDrag == SlDragHandle.wholeBox,
        accentColor: accentColor);

    // Hit markers
    if (t.slHit) {
      canvas.drawRect(
          Rect.fromLTRB(lx, math.min(eY, slY), rx, math.max(eY, slY)),
          Paint()..color = slLineColor.withOpacity(0.15 * (1.0 - hitValue)));
      _textLabel(canvas, rx + 12, slY - 6, '✖  SL HIT', slLineColor, fontSize: 11);
    }
    if (t.tpHit) {
      _textLabel(canvas, rx + 12, tpY - 6, '✔  TP HIT', tpLineColor, fontSize: 11);
    }

    if (appearValue > 0.0 && appearValue < 1.0) canvas.restore();
  }

  void _horizLine(
    Canvas canvas,
    double lx, double rx, double y,
    Color col, {
    required String label,
    required double price,
    bool    isDashed = false,
    bool    isActive = false,
    String? suffix,
  }) {
    if (isActive) {
      canvas.drawLine(Offset(lx, y), Offset(rx, y),
          Paint()
            ..color      = col.withOpacity(0.22)
            ..strokeWidth = 10
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    final p = Paint()
      ..color      = col.withOpacity(isActive ? 1.0 : 0.88)
      ..strokeWidth = isActive ? 2.6 : 2.0;
    isDashed
        ? drawDashedLine(canvas, Offset(lx, y), Offset(rx, y), p)
        : canvas.drawLine(Offset(lx, y), Offset(rx, y), p);

    drawLabelPill(canvas,
        x: lx + 6, y: y,
        label: label, price: price, color: col,
        isActive: isActive, suffix: suffix);
  }

  String _rrStr(TradeSetup t) {
    if (t.risk == 0) return '∞';
    return '${((t.tpPrice - t.entryPrice).abs() / t.risk).toStringAsFixed(1)}R';
  }

  void _textLabel(Canvas canvas, double x, double y, String text, Color col,
      {double fontSize = 9.5}) {
    final tp = TextPainter(
      text: TextSpan(text: text,
          style: TextStyle(color: col, fontSize: fontSize, fontWeight: FontWeight.w700)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_StopLossPainter old) =>
      // FIX v3: mapper == operator sudah implement equality di chart_utils
      // → repaint otomatis setiap kali offset/scale berubah (pan/zoom)
      old.mapper        != mapper        ||
      old.trade         != trade         ||
      old.isDrawing     != isDrawing     ||
      old.drawStart     != drawStart     ||
      old.drawCurrent   != drawCurrent   ||
      old.activeDrag    != activeDrag    ||
      old.hoveredHandle != hoveredHandle ||
      old.pulseValue    != pulseValue    ||
      old.appearValue   != appearValue   ||
      old.hitValue      != hitValue;
}