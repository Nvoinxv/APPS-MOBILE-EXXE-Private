import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../controller/risk_ratio_button.dart';
import '../Strategy/utils/chart_utils.dart'; // ← ChartCoordinateMapper lives here

// ══════════════════════════════════════════════════
// DATA MODEL
// ══════════════════════════════════════════════════

class RiskRatioData {
  double entryPrice;
  double stopLossPrice;
  double takeProfitPrice;
  RiskRatioMode mode;
  bool isLocked;

  int leftCandleIndex;
  int rightCandleIndex;
  ChartCoordinateMapper mapper;

  RiskRatioData({
    required this.entryPrice,
    required this.stopLossPrice,
    required this.takeProfitPrice,
    required this.mode,
    required this.leftCandleIndex,
    required this.rightCandleIndex,
    required this.mapper,
    this.isLocked = false,
  });

  double get leftX   => mapper.candleIndexToX(leftCandleIndex);
  double get rightX  => mapper.candleIndexToX(rightCandleIndex);
  double get width   => rightX - leftX;
  double get centerX => (leftX + rightX) / 2;

  set leftX(double px)  => leftCandleIndex  = mapper.xToCandleIndex(px);
  set rightX(double px) => rightCandleIndex = mapper.xToCandleIndex(px);

  void translatePixels(double dx, double chartWidth) {
    final currentLeft  = leftX;
    final currentRight = rightX;
    final w            = currentRight - currentLeft;

    final newLeft  = (currentLeft  + dx).clamp(0.0, chartWidth - w);
    final newRight = newLeft + w;

    leftCandleIndex  = mapper.xToCandleIndex(newLeft);
    rightCandleIndex = mapper.xToCandleIndex(newRight);
  }

  double get risk            => (entryPrice - stopLossPrice).abs();
  double get reward          => (takeProfitPrice - entryPrice).abs();
  double get riskRewardRatio => risk == 0 ? 0 : reward / risk;
  String get riskRewardText  => '1:${riskRewardRatio.toStringAsFixed(2)}';
  bool   get isProfitable    => riskRewardRatio >= 1.5;
}

// ══════════════════════════════════════════════════
// NOTE: ChartCoordinateMapper is NOT defined here.
// It is imported from chart_utils.dart above.
// ══════════════════════════════════════════════════

// ══════════════════════════════════════════════════
// DRAG HANDLE ENUM
// ══════════════════════════════════════════════════

enum DragHandle {
  none,
  entry,
  stopLoss,
  takeProfit,
  leftEdge,
  rightEdge,
  wholeBox,
}

// ══════════════════════════════════════════════════
// HANDLE POSITION HELPER
// ══════════════════════════════════════════════════
double _handleX(RiskRatioData d, DragHandle h) {
  final quarter = d.width / 4;
  switch (h) {
    case DragHandle.stopLoss:   return d.leftX + quarter;
    case DragHandle.entry:      return d.leftX + quarter * 2;
    case DragHandle.takeProfit: return d.leftX + quarter * 3;
    default:                    return d.centerX;
  }
}

// ══════════════════════════════════════════════════
// INTERACTIVE WIDGET
// ══════════════════════════════════════════════════

class RiskRatioInteractive extends StatefulWidget {
  final Size   chartSize;
  final Color  accentColor;
  final Color  backgroundColor;
  final Color  textColor;
  final double minPrice;
  final double maxPrice;
  final RiskRatioMode initialMode;
  final ChartCoordinateMapper mapper;

  const RiskRatioInteractive({
    Key? key,
    required this.chartSize,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.minPrice,
    required this.maxPrice,
    required this.mapper,
    this.initialMode = RiskRatioMode.buy,
  }) : super(key: key);

  @override
  State<RiskRatioInteractive> createState() => RiskRatioInteractiveState();
}

class RiskRatioInteractiveState extends State<RiskRatioInteractive>
    with TickerProviderStateMixin {
  RiskRatioData? riskRatio;
  RiskRatioMode currentMode = RiskRatioMode.buy;

  bool    isDrawing     = false;
  Offset? drawStartPos;
  Offset? drawCurrentPos;

  DragHandle activeDragHandle = DragHandle.none;

  Offset? _dragAnchor;
  double? _anchorLeftX;
  double? _anchorRightX;
  double? _anchorEntryPrice;
  double? _anchorSlPrice;
  double? _anchorTpPrice;

  AnimationController? _pulseController;
  AnimationController? _appearController;
  Animation<double> _pulseAnim  = const AlwaysStoppedAnimation(0.5);
  Animation<double> _appearAnim = const AlwaysStoppedAnimation(1.0);

  DragHandle _hoveredHandle = DragHandle.none;

  static const double _handleHitRadius = 28.0;
  static const double _edgeHitWidth    = 20.0;

  @override
  void initState() {
    super.initState();
    currentMode = widget.initialMode;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseAnim  = CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut);
    _appearAnim = CurvedAnimation(parent: _appearController!, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _appearController?.dispose();
    super.dispose();
  }

  // ── Coordinate helpers ───────────────────────────

  double _yToPrice(double y) {
    final range = widget.maxPrice - widget.minPrice;
    return widget.minPrice + (1.0 - y / widget.chartSize.height) * range;
  }

  double _priceToY(double price) {
    final range = widget.maxPrice - widget.minPrice;
    return widget.chartSize.height * (1.0 - (price - widget.minPrice) / range);
  }

  // ── Default 1:1 initializer ──────────────────────

  void initializeDefault() {
    if (riskRatio != null) return;

    final mapper   = widget.mapper;
    final midPrice = (widget.minPrice + widget.maxPrice) / 2;
    final step     = (widget.maxPrice - widget.minPrice) * 0.10;

    final double entryPrice, slPrice, tpPrice;
    if (currentMode == RiskRatioMode.buy) {
      entryPrice = midPrice; slPrice = midPrice - step; tpPrice = midPrice + step;
    } else {
      entryPrice = midPrice; slPrice = midPrice + step; tpPrice = midPrice - step;
    }

    final boxW       = widget.chartSize.width * 0.40;
    final centerPx   = widget.chartSize.width / 2;
    final pixelLeft  = centerPx - boxW / 2;
    final pixelRight = centerPx + boxW / 2;

    setState(() {
      riskRatio = RiskRatioData(
        entryPrice:       entryPrice,
        stopLossPrice:    slPrice,
        takeProfitPrice:  tpPrice,
        mode:             currentMode,
        leftCandleIndex:  mapper.xToCandleIndex(pixelLeft),
        rightCandleIndex: mapper.xToCandleIndex(pixelRight),
        mapper:           mapper,
      );
    });
    _appearController?.forward(from: 0);
  }

  // ── Hit testing ──────────────────────────────────────────────────────────

  bool isInsideInteractiveArea(Offset pos) {
    if (riskRatio == null) return false;
    return _detectHandle(pos) != DragHandle.none;
  }

  bool isInsideBox(Offset pos) {
    if (riskRatio == null) return false;
    final rr   = riskRatio!;
    final topY = [_priceToY(rr.entryPrice), _priceToY(rr.stopLossPrice), _priceToY(rr.takeProfitPrice)].reduce(math.min);
    final botY = [_priceToY(rr.entryPrice), _priceToY(rr.stopLossPrice), _priceToY(rr.takeProfitPrice)].reduce(math.max);
    return pos.dx >= rr.leftX  - _edgeHitWidth &&
           pos.dx <= rr.rightX + _edgeHitWidth &&
           pos.dy >= topY - 24 && pos.dy <= botY + 24;
  }

  DragHandle _detectHandle(Offset pos) {
    if (riskRatio == null) return DragHandle.none;
    final rr   = riskRatio!;
    final eY   = _priceToY(rr.entryPrice);
    final sY   = _priceToY(rr.stopLossPrice);
    final tY   = _priceToY(rr.takeProfitPrice);
    final topY = [eY, sY, tY].reduce(math.min);
    final botY = [eY, sY, tY].reduce(math.max);
    final inBoxY = pos.dy >= topY - 24 && pos.dy <= botY + 24;

    if ((pos.dx - rr.leftX).abs()  < _edgeHitWidth && inBoxY) return DragHandle.leftEdge;
    if ((pos.dx - rr.rightX).abs() < _edgeHitWidth && inBoxY) return DragHandle.rightEdge;

    final inBoxX = pos.dx >= rr.leftX && pos.dx <= rr.rightX;
    if (!inBoxX) return DragHandle.none;

    if ((pos - Offset(_handleX(rr, DragHandle.stopLoss),   sY)).distance < _handleHitRadius) return DragHandle.stopLoss;
    if ((pos - Offset(_handleX(rr, DragHandle.entry),      eY)).distance < _handleHitRadius) return DragHandle.entry;
    if ((pos - Offset(_handleX(rr, DragHandle.takeProfit), tY)).distance < _handleHitRadius) return DragHandle.takeProfit;

    if (inBoxY) return DragHandle.wholeBox;
    return DragHandle.none;
  }

  // ── Public gesture API ───────────────────────────

  bool handlePointerDown(Offset pos) {
    if (riskRatio == null || riskRatio!.isLocked) return false;
    final handle = _detectHandle(pos);
    if (handle == DragHandle.none) return false;

    final rr = riskRatio!;
    setState(() {
      activeDragHandle  = handle;
      _dragAnchor       = pos;
      _anchorLeftX      = rr.leftX;
      _anchorRightX     = rr.rightX;
      _anchorEntryPrice = rr.entryPrice;
      _anchorSlPrice    = rr.stopLossPrice;
      _anchorTpPrice    = rr.takeProfitPrice;
    });
    return true;
  }

  void handlePointerMove(Offset pos) {
    if (isDrawing) { updateDrawing(pos); return; }
    if (activeDragHandle != DragHandle.none) _handleDrag(pos);
    setState(() => _hoveredHandle = _detectHandle(pos));
  }

  void handlePointerUp(Offset pos) {
    if (isDrawing) finishDrawing();
    else _endDrag();
  }

  void handlePointerCancel() {
    if (isDrawing) {
      setState(() { isDrawing = false; drawStartPos = null; drawCurrentPos = null; });
    } else {
      _endDrag();
    }
  }

  // ── Drawing ──────────────────────────────────────

  void startDrawing(Offset pos) {
    setState(() { isDrawing = true; drawStartPos = pos; drawCurrentPos = pos; });
  }

  void updateDrawing(Offset pos) {
    if (!isDrawing) return;
    setState(() => drawCurrentPos = pos);
  }

  void finishDrawing() {
    if (!isDrawing || drawStartPos == null || drawCurrentPos == null) return;

    final startPos    = drawStartPos!;
    final curPos      = drawCurrentPos!;
    final entryPrice  = _yToPrice(startPos.dy);
    final targetPrice = _yToPrice(curPos.dy);
    final pixelLeft   = math.min(startPos.dx, curPos.dx);
    final pixelRight  = math.max(startPos.dx, curPos.dx);

    if (pixelRight - pixelLeft < 80) {
      setState(() { isDrawing = false; drawStartPos = null; drawCurrentPos = null; });
      return;
    }

    double slPrice, tpPrice;
    final diff = (targetPrice - entryPrice).abs();
    if (currentMode == RiskRatioMode.buy) {
      if (targetPrice > entryPrice) { tpPrice = targetPrice; slPrice = entryPrice - diff; }
      else                          { slPrice = targetPrice; tpPrice = entryPrice + diff; }
    } else {
      if (targetPrice < entryPrice) { tpPrice = targetPrice; slPrice = entryPrice + diff; }
      else                          { slPrice = targetPrice; tpPrice = entryPrice - diff; }
    }

    setState(() {
      riskRatio = RiskRatioData(
        entryPrice:       entryPrice,
        stopLossPrice:    slPrice,
        takeProfitPrice:  tpPrice,
        mode:             currentMode,
        leftCandleIndex:  widget.mapper.xToCandleIndex(pixelLeft),
        rightCandleIndex: widget.mapper.xToCandleIndex(pixelRight),
        mapper:           widget.mapper,
      );
      isDrawing = false; drawStartPos = null; drawCurrentPos = null;
    });
    _appearController?.forward(from: 0);
  }

  // ── Drag (anchor-based, no accumulated error) ──

  void _handleDrag(Offset pos) {
    if (_dragAnchor == null) return;

    final totalDx = pos.dx - _dragAnchor!.dx;
    final totalDy = pos.dy - _dragAnchor!.dy;

    setState(() {
      final rr         = riskRatio!;
      final pricePerPx = (widget.maxPrice - widget.minPrice) / widget.chartSize.height;

      switch (activeDragHandle) {
        case DragHandle.entry:
          rr.entryPrice = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
          break;
        case DragHandle.stopLoss:
          rr.stopLossPrice = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
          break;
        case DragHandle.takeProfit:
          rr.takeProfitPrice = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
          break;
        case DragHandle.leftEdge:
          final newLeft = (_anchorLeftX! + totalDx).clamp(0.0, _anchorRightX! - 80);
          rr.leftCandleIndex = widget.mapper.xToCandleIndex(newLeft);
          break;
        case DragHandle.rightEdge:
          final newRight = (_anchorRightX! + totalDx).clamp(_anchorLeftX! + 80, widget.chartSize.width);
          rr.rightCandleIndex = widget.mapper.xToCandleIndex(newRight);
          break;
        case DragHandle.wholeBox:
          final w        = _anchorRightX! - _anchorLeftX!;
          final newLeft  = (_anchorLeftX! + totalDx).clamp(0.0, widget.chartSize.width - w);
          final newRight = newLeft + w;

          rr.leftCandleIndex  = widget.mapper.xToCandleIndex(newLeft);
          rr.rightCandleIndex = widget.mapper.xToCandleIndex(newRight);

          final deltaPrice = -totalDy * pricePerPx;
          rr.entryPrice      = (_anchorEntryPrice! + deltaPrice).clamp(widget.minPrice, widget.maxPrice);
          rr.stopLossPrice   = (_anchorSlPrice!    + deltaPrice).clamp(widget.minPrice, widget.maxPrice);
          rr.takeProfitPrice = (_anchorTpPrice!    + deltaPrice).clamp(widget.minPrice, widget.maxPrice);
          break;
        case DragHandle.none:
          break;
      }
    });
  }

  void _endDrag() {
    setState(() {
      activeDragHandle  = DragHandle.none;
      _dragAnchor       = null;
      _anchorLeftX      = null;
      _anchorRightX     = null;
      _anchorEntryPrice = null;
      _anchorSlPrice    = null;
      _anchorTpPrice    = null;
    });
  }

  // ── Public control ────────────────────────────────

  void clearRiskRatio() {
    setState(() {
      riskRatio = null; isDrawing = false; drawStartPos = null;
      drawCurrentPos = null; activeDragHandle = DragHandle.none;
      _dragAnchor = null; _hoveredHandle = DragHandle.none;
    });
    _appearController?.reset();
  }

  void toggleLock() {
    if (riskRatio != null) setState(() => riskRatio!.isLocked = !riskRatio!.isLocked);
  }

  void setMode(RiskRatioMode mode) {
    setState(() { currentMode = mode; riskRatio?.mode = mode; });
  }

  bool get isLocked => riskRatio?.isLocked ?? false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _appearAnim]),
      builder: (context, _) {
        return CustomPaint(
          painter: RiskRatioPainter(
            riskRatio:        riskRatio,
            isDrawing:        isDrawing,
            drawStartPos:     drawStartPos,
            drawCurrentPos:   drawCurrentPos,
            chartSize:        widget.chartSize,
            accentColor:      widget.accentColor,
            backgroundColor:  widget.backgroundColor,
            textColor:        widget.textColor,
            minPrice:         widget.minPrice,
            maxPrice:         widget.maxPrice,
            activeDragHandle: activeDragHandle,
            hoveredHandle:    _hoveredHandle,
            pulseValue:       _pulseAnim.value,
            appearValue:      _appearAnim.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════
// GESTURE ROUTER
// ══════════════════════════════════════════════════

class RiskRatioGestureRouter extends StatefulWidget {
  final GlobalKey<RiskRatioInteractiveState> rrKey;
  final bool   isRiskRatioMode;
  final Widget child;

  const RiskRatioGestureRouter({
    Key? key,
    required this.rrKey,
    required this.isRiskRatioMode,
    required this.child,
  }) : super(key: key);

  @override
  State<RiskRatioGestureRouter> createState() => _RiskRatioGestureRouterState();
}

class _RiskRatioGestureRouterState extends State<RiskRatioGestureRouter> {
  final Set<int>         _rrPointers  = {};
  final Map<int, Offset> _pendingDraw = {};
  static const double    _drawThreshold = 8.0;

  bool _isOnExistingRR(Offset pos) =>
      widget.rrKey.currentState?.isInsideInteractiveArea(pos) ?? false;

  bool _drawModeReady() {
    final s = widget.rrKey.currentState;
    if (s == null) return false;
    return widget.isRiskRatioMode && s.riskRatio == null && !s.isDrawing;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (e.buttons == kSecondaryButton) return;
        final rrState = widget.rrKey.currentState;
        if (rrState == null) return;
        if (_isOnExistingRR(e.localPosition)) {
          _rrPointers.add(e.pointer);
          rrState.handlePointerDown(e.localPosition);
          return;
        }
        if (_drawModeReady()) _pendingDraw[e.pointer] = e.localPosition;
      },
      onPointerMove: (e) {
        if (_rrPointers.contains(e.pointer)) {
          widget.rrKey.currentState?.handlePointerMove(e.localPosition);
          return;
        }
        final sp = _pendingDraw[e.pointer];
        if (sp != null && (e.localPosition - sp).distance >= _drawThreshold) {
          _pendingDraw.remove(e.pointer);
          _rrPointers.add(e.pointer);
          widget.rrKey.currentState?.startDrawing(sp);
          widget.rrKey.currentState?.updateDrawing(e.localPosition);
        }
      },
      onPointerUp: (e) {
        _pendingDraw.remove(e.pointer);
        if (_rrPointers.remove(e.pointer)) {
          widget.rrKey.currentState?.handlePointerUp(e.localPosition);
        }
      },
      onPointerCancel: (e) {
        _pendingDraw.remove(e.pointer);
        if (_rrPointers.remove(e.pointer)) {
          widget.rrKey.currentState?.handlePointerCancel();
        }
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════
// PAINTER
// ══════════════════════════════════════════════════

class RiskRatioPainter extends CustomPainter {
  final RiskRatioData? riskRatio;
  final bool           isDrawing;
  final Offset?        drawStartPos;
  final Offset?        drawCurrentPos;
  final Size           chartSize;
  final Color          accentColor;
  final Color          backgroundColor;
  final Color          textColor;
  final double         minPrice;
  final double         maxPrice;
  final DragHandle     activeDragHandle;
  final DragHandle     hoveredHandle;
  final double         pulseValue;
  final double         appearValue;

  RiskRatioPainter({
    required this.riskRatio,
    required this.isDrawing,
    required this.drawStartPos,
    required this.drawCurrentPos,
    required this.chartSize,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.minPrice,
    required this.maxPrice,
    required this.activeDragHandle,
    required this.hoveredHandle,
    required this.pulseValue,
    required this.appearValue,
  });

  static const _slColor        = Color(0xFFFF3D6B);
  static const _tpColor        = Color(0xFF00E5A0);
  static const _entryBuyColor  = Color(0xFF00E5A0);
  static const _entrySellColor = Color(0xFFFF3D6B);
  static const _labelBg        = Color(0xFF0F1923);

  double _priceToY(double price) {
    final range = maxPrice - minPrice;
    if (range == 0) return chartSize.height / 2;
    return chartSize.height * (1.0 - (price - minPrice) / range);
  }

  Color get _entryColor =>
      riskRatio?.mode == RiskRatioMode.buy ? _entryBuyColor : _entrySellColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (isDrawing && drawStartPos != null && drawCurrentPos != null) {
      _paintPreview(canvas);
    }
    if (riskRatio != null) _paintRiskRatio(canvas, riskRatio!);
  }

  void _paintPreview(Canvas canvas) {
    final start  = drawStartPos!;
    final cur    = drawCurrentPos!;
    final lx     = math.min(start.dx, cur.dx);
    final rx     = math.max(start.dx, cur.dx);
    final isWide = rx - lx >= 80;

    _drawDashedLine(canvas, Offset(start.dx, 0), Offset(start.dx, chartSize.height),
        Paint()..color = accentColor.withOpacity(0.25)..strokeWidth = 1.0);

    if (!isWide) {
      canvas.drawLine(Offset(lx, start.dy), Offset(rx, start.dy),
          Paint()..color = Colors.orange.withOpacity(0.6)..strokeWidth = 2.0);
      _drawMinWidthHint(canvas, lx, rx, start.dy);
      return;
    }

    final entryY  = start.dy;
    final targetY = cur.dy;
    canvas.drawRect(
      cur.dy > start.dy ? Rect.fromLTRB(lx, entryY, rx, targetY)
                        : Rect.fromLTRB(lx, targetY, rx, entryY),
      Paint()..color = (cur.dy > start.dy ? _slColor : _tpColor).withOpacity(0.12),
    );
    _drawGlowLine(canvas, Offset(lx, entryY), Offset(rx, entryY), accentColor, 2.0, 0.5);
    _drawDashedLine(canvas, Offset(lx, targetY), Offset(rx, targetY),
        Paint()..color = accentColor.withOpacity(0.5)..strokeWidth = 1.5);
    _drawEdgeLine(canvas, lx, math.min(entryY, targetY), math.max(entryY, targetY), false);
    _drawEdgeLine(canvas, rx, math.min(entryY, targetY), math.max(entryY, targetY), false);
  }

  void _paintRiskRatio(Canvas canvas, RiskRatioData d) {
    final eY   = _priceToY(d.entryPrice);
    final sY   = _priceToY(d.stopLossPrice);
    final tY   = _priceToY(d.takeProfitPrice);
    final topY = [eY, sY, tY].reduce(math.min);
    final botY = [eY, sY, tY].reduce(math.max);

    if (appearValue < 1.0 && appearValue > 0.0) {
      canvas.save();
      canvas.translate(d.centerX, (topY + botY) / 2);
      canvas.scale(0.85 + 0.15 * appearValue, 0.85 + 0.15 * appearValue);
      canvas.translate(-d.centerX, -(topY + botY) / 2);
    }

    _paintZone(canvas, d, eY, sY, tY);
    _drawEdgeLine(canvas, d.leftX,  topY, botY, activeDragHandle == DragHandle.leftEdge);
    _drawEdgeLine(canvas, d.rightX, topY, botY, activeDragHandle == DragHandle.rightEdge);

    _paintPriceLine(canvas, d, sY, _slColor,    'SL',    d.stopLossPrice,   DragHandle.stopLoss);
    _paintPriceLine(canvas, d, eY, _entryColor, 'ENTRY', d.entryPrice,      DragHandle.entry);
    _paintPriceLine(canvas, d, tY, _tpColor,    'TP',    d.takeProfitPrice, DragHandle.takeProfit);

    _paintRRBadge(canvas, d, eY, tY);
    _paintMoveHandle(canvas, d, eY, sY, tY, activeDragHandle == DragHandle.wholeBox);
    if (d.isLocked) _paintLockIcon(canvas, d.centerX, topY - 18);

    if (appearValue < 1.0 && appearValue > 0.0) canvas.restore();
  }

  void _paintZone(Canvas canvas, RiskRatioData d, double eY, double sY, double tY) {
    canvas.drawRect(
      Rect.fromLTRB(d.leftX, math.min(eY, sY), d.rightX, math.max(eY, sY)),
      Paint()..shader = ui.Gradient.linear(
        Offset(d.leftX, math.min(eY, sY)), Offset(d.leftX, math.max(eY, sY)),
        [_slColor.withOpacity(0.18), _slColor.withOpacity(0.06)]),
    );
    canvas.drawRect(
      Rect.fromLTRB(d.leftX, math.min(eY, tY), d.rightX, math.max(eY, tY)),
      Paint()..shader = ui.Gradient.linear(
        Offset(d.leftX, math.min(eY, tY)), Offset(d.leftX, math.max(eY, tY)),
        [_tpColor.withOpacity(0.06), _tpColor.withOpacity(0.18)]),
    );
    final noisePaint = Paint()..color = Colors.white.withOpacity(0.025)..strokeWidth = 0.5;
    for (var x = d.leftX; x < d.rightX; x += 8) {
      canvas.drawLine(Offset(x, math.min(eY, sY)), Offset(x + 8, math.max(eY, sY)), noisePaint);
    }
  }

  void _paintPriceLine(Canvas canvas, RiskRatioData d, double y, Color color,
      String label, double price, DragHandle handle) {
    final isActive  = activeDragHandle == handle;
    final isHovered = hoveredHandle    == handle;
    final opacity   = (isActive || isHovered) ? 1.0 : 0.85;

    if (isActive) {
      canvas.drawLine(Offset(d.leftX, y), Offset(d.rightX, y), Paint()
        ..color = color.withOpacity(0.25)..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    canvas.drawLine(Offset(d.leftX, y), Offset(d.rightX, y), Paint()
      ..color = color.withOpacity(opacity)..strokeWidth = isActive ? 2.5 : 1.8);

    _paintLabelPill(canvas, d.leftX + 6, y, label, price, color, isActive);

    final hx = _handleX(d, handle);
    _paintDragHandle(canvas, Offset(hx, y), color, isActive, isHovered, label);
  }

  void _paintLabelPill(Canvas canvas, double x, double y, String label,
      double price, Color color, bool isActive) {
    final priceStr = '\$${price.toStringAsFixed(2)}';
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(text: '$label  ',
            style: TextStyle(color: color, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        TextSpan(text: priceStr,
            style: const TextStyle(color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final w    = tp.width + 16;
    const h    = 22.0;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - h / 2, w, h), const Radius.circular(5));

    canvas.drawRRect(rect, Paint()..color = _labelBg.withOpacity(isActive ? 0.98 : 0.88));
    canvas.drawRRect(rect, Paint()
      ..color = color.withOpacity(isActive ? 0.9 : 0.45)
      ..strokeWidth = isActive ? 1.5 : 1.0
      ..style = PaintingStyle.stroke);
    tp.paint(canvas, Offset(x + 8, y - tp.height / 2));
  }

  void _paintDragHandle(Canvas canvas, Offset center, Color color,
      bool isActive, bool isHovered, String label) {
    final radius = isActive ? 15.0 : (isHovered ? 13.5 : 12.0);

    if (isActive || isHovered) {
      canvas.drawCircle(center, radius + 7, Paint()
        ..color      = color.withOpacity(isActive ? 0.28 : 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isActive ? 7 : 4));
    }
    if (isActive) {
      canvas.drawCircle(center, radius + 11 + pulseValue * 7, Paint()
        ..color = color.withOpacity(0.18 * (1 - pulseValue))
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    canvas.drawCircle(center, radius + 2.5, Paint()..color = _labelBg);
    canvas.drawCircle(center, radius, Paint()..color = color);

    final initials = (label == 'ENTRY') ? 'E' : label;
    final tLabel = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: _labelBg, fontSize: initials.length == 1 ? 12.0 : 9.0,
          fontWeight: FontWeight.w900,
          letterSpacing: initials.length > 1 ? -0.5 : 0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tLabel.paint(canvas, Offset(center.dx - tLabel.width / 2, center.dy - tLabel.height / 2));
  }

  void _drawEdgeLine(Canvas canvas, double x, double topY, double botY, bool isActive) {
    canvas.drawLine(Offset(x, topY), Offset(x, botY), Paint()
      ..color = Colors.black.withOpacity(0.3)..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawLine(Offset(x, topY), Offset(x, botY), Paint()
      ..color = accentColor.withOpacity(isActive ? 1.0 : 0.5)
      ..strokeWidth = isActive ? 2.5 : 1.5);
    final capPaint = Paint()..color = accentColor.withOpacity(isActive ? 1.0 : 0.6);
    canvas.drawCircle(Offset(x, topY), isActive ? 4.5 : 3.0, capPaint);
    canvas.drawCircle(Offset(x, botY), isActive ? 4.5 : 3.0, capPaint);
    if (isActive) {
      final gp = Paint()..color = accentColor.withOpacity(0.8)..strokeWidth = 1.5;
      final cy = (topY + botY) / 2;
      canvas.drawLine(Offset(x - 4, cy - 4), Offset(x - 4, cy + 4), gp);
      canvas.drawLine(Offset(x + 4, cy - 4), Offset(x + 4, cy + 4), gp);
    }
  }

  void _paintRRBadge(Canvas canvas, RiskRatioData d, double eY, double tY) {
    final cx         = d.centerX;
    final cy         = (eY + tY) / 2;
    final modeText   = d.mode == RiskRatioMode.buy ? '▲ LONG' : '▼ SHORT';
    final modeColor  = d.mode == RiskRatioMode.buy ? _entryBuyColor : _entrySellColor;
    final rrText     = 'R:R  ${d.riskRewardText}';
    final badgeColor = d.isProfitable ? _tpColor : Colors.orange;

    final modeTp = TextPainter(
      text: TextSpan(text: modeText, style: TextStyle(
          color: modeColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final rrTp = TextPainter(
      text: TextSpan(text: rrText, style: TextStyle(
          color: badgeColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final totalW = math.max(modeTp.width, rrTp.width) + 28;
    final totalH = modeTp.height + rrTp.height + 16;
    final rect   = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: totalW, height: totalH),
      const Radius.circular(10),
    );

    canvas.drawRRect(rect, Paint()..color = _labelBg.withOpacity(0.92));
    canvas.drawRRect(rect, Paint()
      ..shader = ui.Gradient.linear(rect.outerRect.topLeft, rect.outerRect.bottomRight,
          [modeColor.withOpacity(0.8), badgeColor.withOpacity(0.4)])
      ..strokeWidth = 1.5..style = PaintingStyle.stroke);
    modeTp.paint(canvas, Offset(cx - modeTp.width / 2, cy - totalH / 2 + 7));
    rrTp.paint(  canvas, Offset(cx - rrTp.width   / 2, cy - totalH / 2 + 7 + modeTp.height + 4));
  }

  void _paintMoveHandle(Canvas canvas, RiskRatioData d, double eY, double sY,
      double tY, bool isActive) {
    final topY = [eY, sY, tY].reduce(math.min);
    final botY = [eY, sY, tY].reduce(math.max);
    final cx   = d.centerX;
    final cy   = (topY + botY) / 2;
    final op   = isActive ? 1.0 : 0.45;
    for (var c = -1; c <= 1; c++) {
      for (var r = -1; r <= 1; r++) {
        canvas.drawCircle(
          Offset(cx + c * 5, cy + r * 5),
          isActive ? 2.5 : 1.8,
          Paint()..color = isActive
              ? accentColor.withOpacity(op) : Colors.white.withOpacity(op),
        );
      }
    }
  }

  void _drawMinWidthHint(Canvas canvas, double lx, double rx, double y) {
    final tp = TextPainter(
      text: TextSpan(text: '← too narrow →',
          style: TextStyle(color: Colors.orange.withOpacity(0.7),
              fontSize: 10, fontWeight: FontWeight.w600)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((lx + rx) / 2 - tp.width / 2, y + 8));
  }

  void _paintLockIcon(Canvas canvas, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.lock.codePoint),
        style: TextStyle(fontSize: 16, fontFamily: Icons.lock.fontFamily,
            color: const Color(0xFFFFD700)),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  void _drawGlowLine(Canvas canvas, Offset start, Offset end, Color color,
      double width, double opacity) {
    canvas.drawLine(start, end, Paint()
      ..color = color.withOpacity(opacity * 0.4)..strokeWidth = width + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawLine(start, end, Paint()
      ..color = color.withOpacity(opacity)..strokeWidth = width);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    const gap  = 4.0;
    final dist = (end - start).distance;
    if (dist == 0) return;
    final count = (dist / (dash + gap)).floor();
    for (var i = 0; i < count; i++) {
      final s = (dash + gap) * i;
      final e = s + dash;
      canvas.drawLine(
        Offset.lerp(start, end, s / dist)!,
        Offset.lerp(start, end, (e / dist).clamp(0.0, 1.0))!,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RiskRatioPainter old) =>
      old.riskRatio        != riskRatio        ||
      old.isDrawing        != isDrawing        ||
      old.drawStartPos     != drawStartPos     ||
      old.drawCurrentPos   != drawCurrentPos   ||
      old.activeDragHandle != activeDragHandle ||
      old.hoveredHandle    != hoveredHandle    ||
      old.pulseValue       != pulseValue       ||
      old.appearValue      != appearValue;
}