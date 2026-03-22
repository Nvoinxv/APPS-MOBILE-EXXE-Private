// ══════════════════════════════════════════════════════════════════════════════
// multi_tp_risk_ratio.dart  —  FIX v3: mapper di-rebuild setiap frame
//                               sehingga posisi label/zone selalu sinkron
//                               dengan candle saat pan/zoom.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../utils/chart_utils.dart';
import '../Hooks_Strategy/base_signal.dart';

// ══════════════════════════════════════════════════
// §1  ENUMS & MODELS
// ══════════════════════════════════════════════════

enum RiskRatioMode { buy, sell }

class TpLevel {
  final int index;
  double    price;
  double    rrMultiplier;
  double    lotPct;
  bool      isHit;

  TpLevel({
    required this.index,
    required this.price,
    required this.rrMultiplier,
    required this.lotPct,
    this.isHit = false,
  });

  String get label    => 'TP$index';
  String get lotLabel => '${lotPct.toStringAsFixed(0)}%';
}

// ══════════════════════════════════════════════════
// §2  MULTI-TP DATA MODEL
// ══════════════════════════════════════════════════

class MultiTpData {
  double        entryPrice;
  double        stopLossPrice;
  List<TpLevel> tpLevels;
  RiskRatioMode mode;
  bool          isLocked;
  bool          isBreakeven;
  int?          triggerBarIndex;
  double?       shortKalman, longKalman, midBands, upperBands, lowerBands;
  bool          trendUp;
  String        signalClass;

  int leftCandleIndex;
  int rightCandleIndex;

  MultiTpData({
    required this.entryPrice,
    required this.stopLossPrice,
    required this.tpLevels,
    required this.mode,
    required this.leftCandleIndex,
    required this.rightCandleIndex,
    this.isLocked        = false,
    this.isBreakeven     = false,
    this.triggerBarIndex,
    this.shortKalman, this.longKalman,
    this.midBands, this.upperBands, this.lowerBands,
    this.trendUp         = true,
    this.signalClass     = '',
  });

  // FIX: semua geometry selalu dihitung fresh dari mapper terbaru (live offset/scale)
  double leftX  (ChartCoordinateMapper m) => m.candleIndexToX(leftCandleIndex);
  double rightX (ChartCoordinateMapper m) => m.candleIndexToX(rightCandleIndex);
  double width  (ChartCoordinateMapper m) => rightX(m) - leftX(m);
  double centerX(ChartCoordinateMapper m) => (leftX(m) + rightX(m)) / 2;

  double get risk => (entryPrice - stopLossPrice).abs();
  double rrOf(TpLevel tp) =>
      risk == 0 ? 0 : (tp.price - entryPrice).abs() / risk;

  void recalcTpFromMultipliers() {
    final r   = risk;
    final dir = mode == RiskRatioMode.buy ? 1.0 : -1.0;
    for (final tp in tpLevels) {
      tp.price = entryPrice + dir * r * tp.rrMultiplier;
    }
  }

  List<double> allPrices() =>
      [entryPrice, stopLossPrice, ...tpLevels.map((t) => t.price)];

  TradeHitResult checkHit({required double high, required double low}) {
    if (mode == RiskRatioMode.buy) {
      if (low <= stopLossPrice) return TradeHitResult.slHit;
      for (var i = 0; i < tpLevels.length; i++) {
        if (!tpLevels[i].isHit && high >= tpLevels[i].price)
          return TradeHitResult.tpHit(i);
      }
    } else {
      if (high >= stopLossPrice) return TradeHitResult.slHit;
      for (var i = 0; i < tpLevels.length; i++) {
        if (!tpLevels[i].isHit && low <= tpLevels[i].price)
          return TradeHitResult.tpHit(i);
      }
    }
    return TradeHitResult.none;
  }

  factory MultiTpData.fromSignalBar(
    SignalBar bar, {
    required List<double>          lows,
    required List<double>          highs,
    required ChartCoordinateMapper mapper,
    required int                   slLookback,
    List<double>                   rrMultipliers  = const [1.0, 2.0, 3.0],
    List<double>                   lotPercentages = const [25.0, 50.0, 25.0],
    double                         boxWidthFraction = 0.4,
  }) {
    final isLong  = bar.brightBuy;
    final slPrice = isLong
        ? ChartPriceHelpers.lowestN(lows,   slLookback)
        : ChartPriceHelpers.highestN(highs, slLookback);
    final entry = bar.close;
    final risk  = (entry - slPrice).abs();
    final dir   = isLong ? 1.0 : -1.0;

    final tps = <TpLevel>[
      for (var i = 0; i < rrMultipliers.length; i++)
        TpLevel(
          index:        i + 1,
          price:        entry + dir * risk * rrMultipliers[i],
          rrMultiplier: rrMultipliers[i],
          lotPct:       lotPercentages[i],
        ),
    ];

    final cx   = mapper.candleIndexToX(bar.barIndex);
    final half = mapper.chartSize.width * boxWidthFraction / 2;

    return MultiTpData(
      entryPrice:       entry,
      stopLossPrice:    slPrice,
      tpLevels:         tps,
      mode:             isLong ? RiskRatioMode.buy : RiskRatioMode.sell,
      leftCandleIndex:  mapper.xToCandleIndex(cx - half),
      rightCandleIndex: mapper.xToCandleIndex(cx + half),
      triggerBarIndex:  bar.barIndex,
      shortKalman:      bar.shortKalman,
      longKalman:       bar.longKalman,
      midBands:         bar.midBands,
      upperBands:       bar.upperBands,
      lowerBands:       bar.lowerBands,
      trendUp:          bar.trendUp,
      signalClass:      bar.signalClass,
    );
  }

  factory MultiTpData.fromBrightBar(
    BrightSignalBar bar, {
    required List<double>          lows,
    required List<double>          highs,
    required ChartCoordinateMapper mapper,
    required int                   slLookback,
    List<double>                   rrMultipliers  = const [1.0, 2.0, 3.0],
    List<double>                   lotPercentages = const [25.0, 50.0, 25.0],
  }) {
    final isLong  = bar.isLong;
    final slPrice = isLong
        ? ChartPriceHelpers.lowestN(lows,   slLookback)
        : ChartPriceHelpers.highestN(highs, slLookback);
    final entry = bar.close;
    final risk  = (entry - slPrice).abs();
    final dir   = isLong ? 1.0 : -1.0;

    final tps = <TpLevel>[
      for (var i = 0; i < rrMultipliers.length; i++)
        TpLevel(
          index:        i + 1,
          price:        entry + dir * risk * rrMultipliers[i],
          rrMultiplier: rrMultipliers[i],
          lotPct:       lotPercentages[i],
        ),
    ];

    final cx   = mapper.candleIndexToX(bar.barIndex);
    final half = mapper.chartSize.width * 0.4 / 2;

    return MultiTpData(
      entryPrice:       entry,
      stopLossPrice:    slPrice,
      tpLevels:         tps,
      mode:             isLong ? RiskRatioMode.buy : RiskRatioMode.sell,
      leftCandleIndex:  mapper.xToCandleIndex(cx - half),
      rightCandleIndex: mapper.xToCandleIndex(cx + half),
      triggerBarIndex:  bar.barIndex,
      shortKalman:      bar.shortKalman,
      longKalman:       bar.longKalman,
      midBands:         bar.midBands,
      trendUp:          (bar.shortKalman ?? 0) > (bar.longKalman ?? 0),
      signalClass:      bar.signalClass,
    );
  }

  factory MultiTpData.fromRR({
    required double               entryPrice,
    required double               stopLossPrice,
    required RiskRatioMode        mode,
    required int                  leftCandleIndex,
    required int                  rightCandleIndex,
    List<double>                  rrMultipliers  = const [1.0, 2.0, 3.0],
    List<double>                  lotPercentages = const [25.0, 50.0, 25.0],
  }) {
    final risk = (entryPrice - stopLossPrice).abs();
    final dir  = mode == RiskRatioMode.buy ? 1.0 : -1.0;
    return MultiTpData(
      entryPrice:       entryPrice,
      stopLossPrice:    stopLossPrice,
      tpLevels: [
        for (var i = 0; i < rrMultipliers.length; i++)
          TpLevel(
            index:        i + 1,
            price:        entryPrice + dir * risk * rrMultipliers[i],
            rrMultiplier: rrMultipliers[i],
            lotPct:       lotPercentages[i],
          ),
      ],
      mode:             mode,
      leftCandleIndex:  leftCandleIndex,
      rightCandleIndex: rightCandleIndex,
    );
  }
}

// ══════════════════════════════════════════════════
// §3  TRADE HIT RESULT
// ══════════════════════════════════════════════════

class TradeHitResult {
  final bool isSlHit;
  final int? tpHitIndex;

  const TradeHitResult._({this.isSlHit = false, this.tpHitIndex});

  static const TradeHitResult none  = TradeHitResult._();
  static const TradeHitResult slHit = TradeHitResult._(isSlHit: true);
  static TradeHitResult tpHit(int i) => TradeHitResult._(tpHitIndex: i);

  bool get isNone  => !isSlHit && tpHitIndex == null;
  bool get isTpHit => tpHitIndex != null;
}

// ══════════════════════════════════════════════════
// §4  DRAG HANDLE ENUM
// ══════════════════════════════════════════════════

enum MultiTpDragHandle {
  none, entry, stopLoss,
  takeProfit1, takeProfit2, takeProfit3, takeProfit4,
  leftEdge, rightEdge, wholeBox,
}

extension MultiTpDragHandleX on MultiTpDragHandle {
  bool get isTakeProfit =>
      index >= MultiTpDragHandle.takeProfit1.index &&
      index <= MultiTpDragHandle.takeProfit4.index;
  int get tpIndex => index - MultiTpDragHandle.takeProfit1.index;
}

double _multiHandleX(
    MultiTpData d, MultiTpDragHandle h, ChartCoordinateMapper m) {
  final lx = d.leftX(m);
  final w  = d.width(m);
  switch (h) {
    case MultiTpDragHandle.stopLoss:    return lx + w * 0.15;
    case MultiTpDragHandle.entry:       return lx + w * 0.30;
    case MultiTpDragHandle.takeProfit1: return lx + w * 0.50;
    case MultiTpDragHandle.takeProfit2: return lx + w * 0.65;
    case MultiTpDragHandle.takeProfit3: return lx + w * 0.80;
    case MultiTpDragHandle.takeProfit4: return lx + w * 0.92;
    default:                            return d.centerX(m);
  }
}

MultiTpDragHandle _tpIndexToHandle(int i) {
  switch (i) {
    case 0:  return MultiTpDragHandle.takeProfit1;
    case 1:  return MultiTpDragHandle.takeProfit2;
    case 2:  return MultiTpDragHandle.takeProfit3;
    case 3:  return MultiTpDragHandle.takeProfit4;
    default: return MultiTpDragHandle.none;
  }
}

// ══════════════════════════════════════════════════
// §5  INTERACTIVE WIDGET
//
// FIX v3: widget menerima `scale` dan `offset` sebagai parameter terpisah
// agar bisa membuat mapper baru setiap build(). Dengan demikian painter
// selalu mendapat mapper yang fresh (berisi offset/scale terkini) dan
// shouldRepaint() akan return true saat pan/zoom berubah.
// ══════════════════════════════════════════════════

class MultiTpRiskRatioInteractive extends StatefulWidget {
  final Size                   chartSize;
  final Color                  accentColor;
  final Color                  backgroundColor;
  final Color                  textColor;
  final double                 minPrice;
  final double                 maxPrice;
  final RiskRatioMode          initialMode;
  final int                    totalCandles;
  // FIX v3: terima scale & offset sebagai parameter agar mapper selalu fresh
  final double                 scale;
  final double                 scrollOffset;
  final int                    defaultTpCount;
  final List<double>           defaultRrMultipliers;
  final List<double>           defaultLotPercentages;
  final bool                   useBreakeven;
  final int                    slLookback;

  const MultiTpRiskRatioInteractive({
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
    this.initialMode           = RiskRatioMode.buy,
    this.defaultTpCount        = 3,
    this.defaultRrMultipliers  = const [1.0, 2.0, 3.0],
    this.defaultLotPercentages = const [25.0, 50.0, 25.0],
    this.useBreakeven          = true,
    this.slLookback            = 15,
  }) : super(key: key);

  @override
  State<MultiTpRiskRatioInteractive> createState() =>
      MultiTpRiskRatioInteractiveState();
}

class MultiTpRiskRatioInteractiveState
    extends State<MultiTpRiskRatioInteractive>
    with TickerProviderStateMixin, ChartAnimationMixin {

  MultiTpData?      data;
  RiskRatioMode     currentMode      = RiskRatioMode.buy;
  bool              isDrawing        = false;
  Offset?           drawStartPos;
  Offset?           drawCurrentPos;
  MultiTpDragHandle activeDragHandle = MultiTpDragHandle.none;
  Offset?           _dragAnchor;
  double?           _anchorLeftX, _anchorRightX, _anchorEntry, _anchorSl;
  List<double>      _anchorTpPrices  = [];
  MultiTpDragHandle _hoveredHandle   = MultiTpDragHandle.none;
  bool              _tradeActive     = false;

  static const double _handleHitRadius = 28.0;
  static const double _edgeHitWidth    = 20.0;

  // FIX v3: mapper selalu dibuat fresh dari widget properties terkini
  // (termasuk scale & scrollOffset yang berubah saat pan/zoom)
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
    currentMode = widget.initialMode;
    initChartAnimations(this);
  }

  @override
  void dispose() {
    disposeChartAnimations();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  //  PUBLIC HOOK API
  // ══════════════════════════════════════════════

  void openFromSignalBar(
    SignalBar bar, {
    required List<double> lows,
    required List<double> highs,
  }) {
    if (_tradeActive) return;
    if (!bar.brightBuy && !bar.brightSell) return;

    final m = _mapper;
    setState(() {
      data = MultiTpData.fromSignalBar(
        bar,
        lows:           lows,
        highs:          highs,
        mapper:         m,
        slLookback:     widget.slLookback,
        rrMultipliers:  widget.defaultRrMultipliers.take(widget.defaultTpCount).toList(),
        lotPercentages: widget.defaultLotPercentages.take(widget.defaultTpCount).toList(),
      );
      _tradeActive = true;
    });
    appearCtrl.forward(from: 0);
  }

  void openFromBrightBar(
    BrightSignalBar bar, {
    required List<double> lows,
    required List<double> highs,
  }) {
    if (_tradeActive) return;

    final m = _mapper;
    setState(() {
      data = MultiTpData.fromBrightBar(
        bar,
        lows:           lows,
        highs:          highs,
        mapper:         m,
        slLookback:     widget.slLookback,
        rrMultipliers:  widget.defaultRrMultipliers.take(widget.defaultTpCount).toList(),
        lotPercentages: widget.defaultLotPercentages.take(widget.defaultTpCount).toList(),
      );
      _tradeActive = true;
    });
    appearCtrl.forward(from: 0);
  }

  TradeHitResult updateWithLatestBar(LatestBarResponse bar,
      {required double high, required double low}) {
    if (data == null || !_tradeActive) return TradeHitResult.none;
    return _processHit(data!.checkHit(high: high, low: low));
  }

  TradeHitResult updateWithSignalBar(SignalBar bar) {
    if (data == null || !_tradeActive) return TradeHitResult.none;
    return _processHit(data!.checkHit(high: bar.high, low: bar.low));
  }

  TradeHitResult _processHit(TradeHitResult hit) {
    if (hit.isSlHit) {
      setState(() => _tradeActive = false);
      return hit;
    }
    if (hit.isTpHit) {
      final idx = hit.tpHitIndex!;
      setState(() {
        data!.tpLevels[idx].isHit = true;
        if (widget.useBreakeven && idx == 0 && !data!.isBreakeven) {
          data!.stopLossPrice = data!.entryPrice;
          data!.isBreakeven   = true;
        }
        if (data!.tpLevels.every((t) => t.isHit)) _tradeActive = false;
      });
      return hit;
    }
    return TradeHitResult.none;
  }

  // ══════════════════════════════════════════════
  //  PUBLIC CONTROLS
  // ══════════════════════════════════════════════

  void initializeDefault() {
    if (data != null) return;

    final m    = _mapper;
    final mid  = (widget.minPrice + widget.maxPrice) / 2;
    final step = (widget.maxPrice - widget.minPrice) * 0.08;
    final slP  = currentMode == RiskRatioMode.buy ? mid - step : mid + step;
    final cx   = widget.chartSize.width / 2;
    final half = widget.chartSize.width * 0.21;

    setState(() {
      data = MultiTpData.fromRR(
        entryPrice:       mid,
        stopLossPrice:    slP,
        mode:             currentMode,
        leftCandleIndex:  m.xToCandleIndex(cx - half),
        rightCandleIndex: m.xToCandleIndex(cx + half),
        rrMultipliers:    widget.defaultRrMultipliers.take(widget.defaultTpCount).toList(),
        lotPercentages:   widget.defaultLotPercentages.take(widget.defaultTpCount).toList(),
      );
      _tradeActive = false;
    });
    appearCtrl.forward(from: 0);
  }

  void clearData() {
    setState(() {
      data             = null;
      _tradeActive     = false;
      isDrawing        = false;
      drawStartPos     = drawCurrentPos = null;
      activeDragHandle = MultiTpDragHandle.none;
      _hoveredHandle   = MultiTpDragHandle.none;
      _dragAnchor      = null;
    });
    appearCtrl.reset();
  }

  void toggleLock() {
    if (data != null) setState(() => data!.isLocked = !data!.isLocked);
  }

  void setMode(RiskRatioMode m) =>
      setState(() { currentMode = m; data?.mode = m; });

  void addTpLevel({double rrMultiplier = 4.0, double lotPct = 10.0}) {
    if (data == null || data!.tpLevels.length >= 4) return;
    setState(() {
      final d   = data!;
      final dir = d.mode == RiskRatioMode.buy ? 1.0 : -1.0;
      d.tpLevels.add(TpLevel(
        index:        d.tpLevels.length + 1,
        price:        d.entryPrice + dir * d.risk * rrMultiplier,
        rrMultiplier: rrMultiplier,
        lotPct:       lotPct,
      ));
    });
  }

  void removeTpLevel() {
    if (data == null || data!.tpLevels.length <= 1) return;
    setState(() => data!.tpLevels.removeLast());
  }

  void simulateTpHit(int tpIndex) {
    if (data == null || tpIndex >= data!.tpLevels.length) return;
    setState(() {
      data!.tpLevels[tpIndex].isHit = true;
      if (widget.useBreakeven && tpIndex == 0 && !data!.isBreakeven) {
        data!.stopLossPrice = data!.entryPrice;
        data!.isBreakeven   = true;
      }
    });
  }

  bool get isLocked    => data?.isLocked ?? false;
  bool get tradeActive => _tradeActive;

  // ── Hit test + drag ──────────────────────────────────────────────────

  bool isInsideInteractiveArea(Offset pos) {
    return data != null && _detectHandle(pos) != MultiTpDragHandle.none;
  }

  MultiTpDragHandle _detectHandle(Offset pos) {
    if (data == null) return MultiTpDragHandle.none;
    final d = data!;
    final m = _mapper;

    final allPY  = d.allPrices().map(_priceToY).toList();
    final topY   = allPY.reduce(math.min);
    final botY   = allPY.reduce(math.max);
    final inBoxY = pos.dy >= topY - 24 && pos.dy <= botY + 24;

    if ((pos.dx - d.leftX(m)).abs()  < _edgeHitWidth && inBoxY) return MultiTpDragHandle.leftEdge;
    if ((pos.dx - d.rightX(m)).abs() < _edgeHitWidth && inBoxY) return MultiTpDragHandle.rightEdge;
    if (pos.dx < d.leftX(m) || pos.dx > d.rightX(m)) return MultiTpDragHandle.none;

    for (var i = d.tpLevels.length - 1; i >= 0; i--) {
      final handle = _tpIndexToHandle(i);
      if ((pos - Offset(_multiHandleX(d, handle, m), _priceToY(d.tpLevels[i].price)))
              .distance < _handleHitRadius) return handle;
    }
    if ((pos - Offset(_multiHandleX(d, MultiTpDragHandle.entry, m),    _priceToY(d.entryPrice))).distance    < _handleHitRadius) return MultiTpDragHandle.entry;
    if ((pos - Offset(_multiHandleX(d, MultiTpDragHandle.stopLoss, m), _priceToY(d.stopLossPrice))).distance < _handleHitRadius) return MultiTpDragHandle.stopLoss;

    if (inBoxY) return MultiTpDragHandle.wholeBox;
    return MultiTpDragHandle.none;
  }

  double _priceToY(double price) {
    final range = widget.maxPrice - widget.minPrice;
    if (range == 0) return widget.chartSize.height / 2;
    return widget.chartSize.height * (1 - (price - widget.minPrice) / range);
  }

  double _yToPrice(double y) {
    final range = widget.maxPrice - widget.minPrice;
    return widget.minPrice + (1.0 - y / widget.chartSize.height) * range;
  }

  bool handlePointerDown(Offset pos) {
    if (data == null || data!.isLocked) return false;
    final handle = _detectHandle(pos);
    if (handle == MultiTpDragHandle.none) return false;
    final d = data!;
    final m = _mapper;
    setState(() {
      activeDragHandle = handle;
      _dragAnchor      = pos;
      _anchorLeftX     = d.leftX(m);
      _anchorRightX    = d.rightX(m);
      _anchorEntry     = d.entryPrice;
      _anchorSl        = d.stopLossPrice;
      _anchorTpPrices  = d.tpLevels.map((t) => t.price).toList();
    });
    return true;
  }

  void handlePointerMove(Offset pos) {
    if (isDrawing) { _updateDrawing(pos); return; }
    if (activeDragHandle != MultiTpDragHandle.none) _handleDrag(pos);
    setState(() => _hoveredHandle = _detectHandle(pos));
  }

  void handlePointerUp(Offset pos) =>
      isDrawing ? _finishDrawing() : _endDrag();

  void handlePointerCancel() {
    if (isDrawing) setState(() { isDrawing = false; drawStartPos = drawCurrentPos = null; });
    else           _endDrag();
  }

  void startDrawing(Offset pos) =>
      setState(() { isDrawing = true; drawStartPos = pos; drawCurrentPos = pos; });

  void _updateDrawing(Offset pos) => setState(() => drawCurrentPos = pos);

  void _finishDrawing() {
    if (!isDrawing || drawStartPos == null || drawCurrentPos == null) return;

    final sp = drawStartPos!;
    final cp = drawCurrentPos!;
    final lx = math.min(sp.dx, cp.dx);
    final rx = math.max(sp.dx, cp.dx);
    if (rx - lx < 80) {
      setState(() { isDrawing = false; drawStartPos = drawCurrentPos = null; });
      return;
    }

    final m      = _mapper;
    final entryP = _yToPrice(sp.dy);
    final slP    = currentMode == RiskRatioMode.buy
        ? entryP - (_yToPrice(cp.dy) - entryP).abs()
        : entryP + (_yToPrice(cp.dy) - entryP).abs();

    setState(() {
      data = MultiTpData.fromRR(
        entryPrice:       entryP,
        stopLossPrice:    slP,
        mode:             currentMode,
        leftCandleIndex:  m.xToCandleIndex(lx),
        rightCandleIndex: m.xToCandleIndex(rx),
        rrMultipliers:    widget.defaultRrMultipliers.take(widget.defaultTpCount).toList(),
        lotPercentages:   widget.defaultLotPercentages.take(widget.defaultTpCount).toList(),
      );
      _tradeActive = false;
      isDrawing = false;
      drawStartPos = drawCurrentPos = null;
    });
    appearCtrl.forward(from: 0);
  }

  void _handleDrag(Offset pos) {
    if (_dragAnchor == null || data == null) return;

    final totalDx = pos.dx - _dragAnchor!.dx;
    final totalDy = pos.dy - _dragAnchor!.dy;
    final ppp     = (widget.maxPrice - widget.minPrice) / widget.chartSize.height;
    // FIX v3: mapper fresh untuk konversi pixel → candle index saat drag
    final m = _mapper;

    setState(() {
      final d = data!;
      switch (activeDragHandle) {
        case MultiTpDragHandle.entry:
          d.entryPrice = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
          d.recalcTpFromMultipliers();
          break;
        case MultiTpDragHandle.stopLoss:
          d.stopLossPrice = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
          d.recalcTpFromMultipliers();
          break;
        case MultiTpDragHandle.takeProfit1:
        case MultiTpDragHandle.takeProfit2:
        case MultiTpDragHandle.takeProfit3:
        case MultiTpDragHandle.takeProfit4:
          final idx = activeDragHandle.tpIndex;
          if (idx < d.tpLevels.length) {
            final np = _yToPrice(pos.dy).clamp(widget.minPrice, widget.maxPrice);
            d.tpLevels[idx].price = np;
            if (d.risk > 0) {
              final dir = d.mode == RiskRatioMode.buy ? 1.0 : -1.0;
              d.tpLevels[idx].rrMultiplier =
                  (dir * (np - d.entryPrice) / d.risk).clamp(0.1, 99.0);
            }
          }
          break;
        case MultiTpDragHandle.leftEdge:
          d.leftCandleIndex = m.xToCandleIndex(
              (_anchorLeftX! + totalDx).clamp(0.0, _anchorRightX! - 80));
          break;
        case MultiTpDragHandle.rightEdge:
          d.rightCandleIndex = m.xToCandleIndex(
              (_anchorRightX! + totalDx).clamp(_anchorLeftX! + 80, widget.chartSize.width));
          break;
        case MultiTpDragHandle.wholeBox:
          final w   = _anchorRightX! - _anchorLeftX!;
          final nl  = (_anchorLeftX! + totalDx).clamp(0.0, widget.chartSize.width - w);
          d.leftCandleIndex  = m.xToCandleIndex(nl);
          d.rightCandleIndex = m.xToCandleIndex(nl + w);
          final dp = -totalDy * ppp;
          d.entryPrice    = (_anchorEntry! + dp).clamp(widget.minPrice, widget.maxPrice);
          d.stopLossPrice = (_anchorSl!    + dp).clamp(widget.minPrice, widget.maxPrice);
          for (var i = 0; i < d.tpLevels.length; i++) {
            d.tpLevels[i].price =
                (_anchorTpPrices[i] + dp).clamp(widget.minPrice, widget.maxPrice);
          }
          break;
        case MultiTpDragHandle.none:
          break;
      }
    });
  }

  void _endDrag() {
    setState(() {
      activeDragHandle = MultiTpDragHandle.none;
      _dragAnchor = _anchorLeftX = _anchorRightX = _anchorEntry = _anchorSl = null;
      _anchorTpPrices = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX v3: buat mapper fresh setiap build — berisi scale & offset terkini
    final liveMapper = _mapper;

    return AnimatedBuilder(
      animation: Listenable.merge([pulseAnim, appearAnim]),
      builder: (context, _) => CustomPaint(
        painter: MultiTpPainter(
          data:             data,
          // FIX v3: selalu pass mapper terbaru ke painter
          mapper:           liveMapper,
          isDrawing:        isDrawing,
          drawStartPos:     drawStartPos,
          drawCurrentPos:   drawCurrentPos,
          chartSize:        widget.chartSize,
          accentColor:      widget.accentColor,
          minPrice:         widget.minPrice,
          maxPrice:         widget.maxPrice,
          activeDragHandle: activeDragHandle,
          hoveredHandle:    _hoveredHandle,
          pulseValue:       pulseAnim.value,
          appearValue:      appearAnim.value,
          tradeActive:      _tradeActive,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// §6  GESTURE ROUTER
// ══════════════════════════════════════════════════

class MultiTpGestureRouter extends StatefulWidget {
  final GlobalKey<MultiTpRiskRatioInteractiveState> rrKey;
  final bool   isRiskRatioMode;
  final Widget child;

  const MultiTpGestureRouter({
    Key? key,
    required this.rrKey,
    required this.isRiskRatioMode,
    required this.child,
  }) : super(key: key);

  @override
  State<MultiTpGestureRouter> createState() => _MultiTpGestureRouterState();
}

class _MultiTpGestureRouterState extends State<MultiTpGestureRouter> {
  final Set<int>         _rrPointers  = {};
  final Map<int, Offset> _pendingDraw = {};
  static const double    _drawThreshold = 8.0;

  bool _isOnExistingRR(Offset pos) =>
      widget.rrKey.currentState?.isInsideInteractiveArea(pos) ?? false;

  bool _drawModeReady() {
    final s = widget.rrKey.currentState;
    return s != null && widget.isRiskRatioMode && s.data == null && !s.isDrawing;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (e.buttons == kSecondaryButton) return;
        final s = widget.rrKey.currentState;
        if (s == null) return;
        if (_isOnExistingRR(e.localPosition)) {
          _rrPointers.add(e.pointer);
          s.handlePointerDown(e.localPosition);
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
          widget.rrKey.currentState?._updateDrawing(e.localPosition);
        }
      },
      onPointerUp: (e) {
        _pendingDraw.remove(e.pointer);
        if (_rrPointers.remove(e.pointer))
          widget.rrKey.currentState?.handlePointerUp(e.localPosition);
      },
      onPointerCancel: (e) {
        _pendingDraw.remove(e.pointer);
        if (_rrPointers.remove(e.pointer))
          widget.rrKey.currentState?.handlePointerCancel();
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════
// §7  PAINTER
//
// FIX v3: shouldRepaint menggunakan == operator dari ChartCoordinateMapper
// (yang sudah implement == & hashCode) sehingga setiap kali offset/scale
// berubah, painter langsung repaint dengan koordinat baru.
// ══════════════════════════════════════════════════

class MultiTpPainter extends CustomPainter {
  final MultiTpData?           data;
  final ChartCoordinateMapper? mapper;
  final bool                   isDrawing;
  final Offset?                drawStartPos;
  final Offset?                drawCurrentPos;
  final Size                   chartSize;
  final Color                  accentColor;
  final double                 minPrice;
  final double                 maxPrice;
  final MultiTpDragHandle      activeDragHandle;
  final MultiTpDragHandle      hoveredHandle;
  final double                 pulseValue;
  final double                 appearValue;
  final bool                   tradeActive;

  static const _slColor        = Color(0xFFFF3D6B);
  static const _entryBuyColor  = Color(0xFF00E5A0);
  static const _entrySellColor = Color(0xFFFF3D6B);
  static const _beColor        = Color(0xFF2979FF);
  static const _labelBg        = Color(0xFF0F1923);
  static const _tpColor        = Color(0xFF00E5A0);
  static const List<Color> _tpColors = [
    Color(0xFF00E5A0), Color(0xFF00C8FF),
    Color(0xFFBB86FC), Color(0xFFFFD700),
  ];

  MultiTpPainter({
    required this.data,
    required this.mapper,
    required this.isDrawing,
    required this.drawStartPos,
    required this.drawCurrentPos,
    required this.chartSize,
    required this.accentColor,
    required this.minPrice,
    required this.maxPrice,
    required this.activeDragHandle,
    required this.hoveredHandle,
    required this.pulseValue,
    required this.appearValue,
    this.tradeActive = false,
  });

  double _priceToY(double price) {
    final range = maxPrice - minPrice;
    if (range == 0) return chartSize.height / 2;
    return chartSize.height * (1 - (price - minPrice) / range);
  }

  Color _entryColor(MultiTpData d) =>
      d.mode == RiskRatioMode.buy ? _entryBuyColor : _entrySellColor;

  @override
  void paint(Canvas canvas, Size size) {
    final m = mapper;
    if (m == null) return;

    if (isDrawing && drawStartPos != null && drawCurrentPos != null)
      _paintPreview(canvas);
    if (data != null) _paintAll(canvas, data!, m);
  }

  void _paintPreview(Canvas canvas) {
    final sp = drawStartPos!; final cp = drawCurrentPos!;
    final lx = math.min(sp.dx, cp.dx); final rx = math.max(sp.dx, cp.dx);

    _drawDashedLine(canvas, Offset(sp.dx, 0), Offset(sp.dx, chartSize.height),
        Paint()..color = accentColor.withOpacity(0.25)..strokeWidth = 1.0);

    if (rx - lx < 80) {
      canvas.drawLine(Offset(lx, sp.dy), Offset(rx, sp.dy),
          Paint()..color = Colors.orange.withOpacity(0.6)..strokeWidth = 2.0);
      _drawMinWidthHint(canvas, lx, rx, sp.dy);
      return;
    }

    canvas.drawRect(
      cp.dy > sp.dy
          ? Rect.fromLTRB(lx, sp.dy, rx, cp.dy)
          : Rect.fromLTRB(lx, cp.dy, rx, sp.dy),
      Paint()..color = (cp.dy > sp.dy ? _slColor : _tpColor).withOpacity(0.12),
    );
    _drawGlowLine(canvas, Offset(lx, sp.dy), Offset(rx, sp.dy), accentColor, 2.0, 0.5);
    _drawDashedLine(canvas, Offset(lx, cp.dy), Offset(rx, cp.dy),
        Paint()..color = accentColor.withOpacity(0.5)..strokeWidth = 1.5);
    _drawEdgeLine(canvas, lx, math.min(sp.dy, cp.dy), math.max(sp.dy, cp.dy), false);
    _drawEdgeLine(canvas, rx, math.min(sp.dy, cp.dy), math.max(sp.dy, cp.dy), false);
  }

  void _paintAll(Canvas canvas, MultiTpData d, ChartCoordinateMapper m) {
    final allY = d.allPrices().map(_priceToY).toList();
    final topY = allY.reduce(math.min);
    final botY = allY.reduce(math.max);

    if (appearValue > 0.0 && appearValue < 1.0) {
      canvas.save();
      final cy = (topY + botY) / 2;
      canvas.translate(d.centerX(m), cy);
      canvas.scale(0.85 + 0.15 * appearValue, 0.85 + 0.15 * appearValue);
      canvas.translate(-d.centerX(m), -cy);
    }

    _paintZones(canvas, d, m);

    _drawEdgeLine(canvas, d.leftX(m),  topY, botY, activeDragHandle == MultiTpDragHandle.leftEdge);
    _drawEdgeLine(canvas, d.rightX(m), topY, botY, activeDragHandle == MultiTpDragHandle.rightEdge);

    _priceLine(canvas, d, m, d.stopLossPrice,
        d.isBreakeven ? _beColor : _slColor,
        d.isBreakeven ? 'BE' : 'SL',
        MultiTpDragHandle.stopLoss);

    _priceLine(canvas, d, m, d.entryPrice,
        _entryColor(d), 'ENTRY', MultiTpDragHandle.entry);

    for (var i = 0; i < d.tpLevels.length; i++) {
      _priceLine(canvas, d, m, d.tpLevels[i].price,
          _tpColors[i % _tpColors.length],
          d.tpLevels[i].label,
          _tpIndexToHandle(i),
          isHit:    d.tpLevels[i].isHit,
          lotLabel: d.tpLevels[i].lotLabel);
    }

    _paintRRBadge(canvas, d, m);
    _paintMoveHandle(canvas, d, m, topY, botY);
    if (d.isLocked)                _paintLockIcon(canvas, d.centerX(m), topY - 18);
    if (d.triggerBarIndex != null) _paintTriggerDot(canvas, d, m);

    if (appearValue > 0.0 && appearValue < 1.0) canvas.restore();
  }

  void _paintZones(Canvas canvas, MultiTpData d, ChartCoordinateMapper m) {
    final eY  = _priceToY(d.entryPrice);
    final sY  = _priceToY(d.stopLossPrice);
    final col = d.isBreakeven ? _beColor : _slColor;

    canvas.drawRect(
      Rect.fromLTRB(d.leftX(m), math.min(eY, sY), d.rightX(m), math.max(eY, sY)),
      Paint()..shader = ui.Gradient.linear(
        Offset(d.leftX(m), math.min(eY, sY)),
        Offset(d.leftX(m), math.max(eY, sY)),
        [col.withOpacity(0.18), col.withOpacity(0.06)]),
    );

    final buy = d.mode == RiskRatioMode.buy;
    for (var i = 0; i < d.tpLevels.length; i++) {
      final tpY   = _priceToY(d.tpLevels[i].price);
      final prevY = i == 0 ? eY : _priceToY(d.tpLevels[i - 1].price);
      final y1    = math.min(prevY, tpY);
      final y2    = math.max(prevY, tpY);
      final c     = _tpColors[i % _tpColors.length];
      canvas.drawRect(
        Rect.fromLTRB(d.leftX(m), y1, d.rightX(m), y2),
        Paint()..shader = ui.Gradient.linear(
          Offset(d.leftX(m), buy ? y2 : y1),
          Offset(d.leftX(m), buy ? y1 : y2),
          [c.withOpacity(0.06), c.withOpacity(0.18)]));
    }

    final noisePaint = Paint()..color = Colors.white.withOpacity(0.025)..strokeWidth = 0.5;
    for (var x = d.leftX(m); x < d.rightX(m); x += 8) {
      canvas.drawLine(
        Offset(x, math.min(eY, sY)),
        Offset(x + 8, math.max(eY, sY)),
        noisePaint,
      );
    }
  }

  void _priceLine(
    Canvas canvas, MultiTpData d, ChartCoordinateMapper m,
    double price, Color color, String label,
    MultiTpDragHandle handle, {bool isHit = false, String? lotLabel}
  ) {
    final y         = _priceToY(price);
    final isActive  = activeDragHandle == handle;
    final isHovered = hoveredHandle    == handle;
    final opacity   = (isActive || isHovered) ? 1.0 : (isHit ? 0.45 : 0.85);

    if (isActive) {
      canvas.drawLine(Offset(d.leftX(m), y), Offset(d.rightX(m), y), Paint()
        ..color      = color.withOpacity(0.25)
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    final linePaint = Paint()
      ..color      = color.withOpacity(opacity)
      ..strokeWidth = isActive ? 2.5 : 1.8;
    isHit
        ? _drawDashedLine(canvas, Offset(d.leftX(m), y), Offset(d.rightX(m), y), linePaint)
        : canvas.drawLine(Offset(d.leftX(m), y), Offset(d.rightX(m), y), linePaint);

    _paintLabelPill(canvas, d.leftX(m) + 6, y, label, price, color, isActive,
        suffix: lotLabel, strikethrough: isHit);

    _paintDragHandle(canvas, Offset(_multiHandleX(d, handle, m), y),
        color, isActive, isHovered, label);
  }

  void _paintLabelPill(
    Canvas canvas, double x, double y, String label, double price,
    Color color, bool isActive, {String? suffix, bool strikethrough = false}
  ) {
    final priceStr = '\$${price.toStringAsFixed(2)}';
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '$label  ',
          style: TextStyle(
            color:         color,
            fontSize:      10,
            fontWeight:    FontWeight.w800,
            letterSpacing: 0.5,
            decoration:    strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
        TextSpan(
          text: suffix != null ? '$priceStr  $suffix' : priceStr,
          style: TextStyle(
            color:      Colors.white,
            fontSize:   10,
            fontWeight: FontWeight.w600,
            decoration: strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
      ]),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final w    = tp.width + 16;
    const h    = 22.0;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - h / 2, w, h), const Radius.circular(5));

    canvas.drawRRect(rect, Paint()..color = _labelBg.withOpacity(isActive ? 0.98 : 0.88));
    canvas.drawRRect(rect, Paint()
      ..color      = color.withOpacity(isActive ? 0.9 : 0.45)
      ..strokeWidth = isActive ? 1.5 : 1.0
      ..style       = PaintingStyle.stroke);
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
        ..color      = color.withOpacity(0.18 * (1 - pulseValue))
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }

    canvas.drawCircle(center, radius + 2.5, Paint()..color = _labelBg);
    canvas.drawCircle(center, radius,       Paint()..color = color);

    final initials = label == 'ENTRY' ? 'E' : label;
    final tLabel = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color:         _labelBg,
          fontSize:      initials.length == 1 ? 12.0 : 9.0,
          fontWeight:    FontWeight.w900,
          letterSpacing: initials.length > 1 ? -0.5 : 0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tLabel.paint(canvas,
        Offset(center.dx - tLabel.width / 2, center.dy - tLabel.height / 2));
  }

  void _drawEdgeLine(Canvas canvas, double x, double topY, double botY, bool isActive) {
    canvas.drawLine(Offset(x, topY), Offset(x, botY), Paint()
      ..color      = Colors.black.withOpacity(0.3)
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawLine(Offset(x, topY), Offset(x, botY), Paint()
      ..color      = accentColor.withOpacity(isActive ? 1.0 : 0.5)
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

  void _paintRRBadge(Canvas canvas, MultiTpData d, ChartCoordinateMapper m) {
    final eY        = _priceToY(d.entryPrice);
    final topTpY    = _priceToY(d.tpLevels.last.price);
    final cx        = d.centerX(m);
    final cy        = (eY + topTpY) / 2;
    final modeColor = d.mode == RiskRatioMode.buy ? _entryBuyColor : _entrySellColor;
    final modeText  = d.mode == RiskRatioMode.buy ? '▲ LONG' : '▼ SHORT';

    final modeTp = TextPainter(
      text: TextSpan(text: modeText,
          style: TextStyle(color: modeColor, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final tpPainters = <TextPainter>[];
    double maxW = modeTp.width;
    for (final tp in d.tpLevels) {
      final col    = _tpColors[(tp.index - 1) % _tpColors.length];
      final badgeC = d.rrOf(tp) >= 1.5 ? col : Colors.orange;
      final p = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: '${tp.label}  ',
            style: TextStyle(
              color:      col.withOpacity(tp.isHit ? 0.4 : 1.0),
              fontSize:   11, fontWeight: FontWeight.w800, letterSpacing: 0.8,
              decoration: tp.isHit ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          TextSpan(
            text: '1:${d.rrOf(tp).toStringAsFixed(2)}',
            style: TextStyle(
              color:      badgeC.withOpacity(tp.isHit ? 0.3 : 1.0),
              fontSize:   13, fontWeight: FontWeight.w800, letterSpacing: 0.4,
              decoration: tp.isHit ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          TextSpan(
            text: '  ${tp.lotLabel}',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
          ),
        ]),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tpPainters.add(p);
      if (p.width > maxW) maxW = p.width;
    }

    const rowH = 20.0; const padX = 14.0; const padY = 8.0;
    final totalW = maxW + padX * 2 + 14;
    final totalH = modeTp.height + 4 + rowH * d.tpLevels.length + padY * 2;

    final lastBadgeC = d.rrOf(d.tpLevels.last) >= 1.5
        ? _tpColors[(d.tpLevels.last.index - 1) % _tpColors.length]
        : Colors.orange;
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: totalW, height: totalH),
        const Radius.circular(10));
    canvas.drawRRect(rect, Paint()..color = _labelBg.withOpacity(0.92));
    canvas.drawRRect(rect, Paint()
      ..shader = ui.Gradient.linear(
        rect.outerRect.topLeft, rect.outerRect.bottomRight,
        [modeColor.withOpacity(0.8), lastBadgeC.withOpacity(0.4)])
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke);

    var drawY = cy - totalH / 2 + padY;
    modeTp.paint(canvas, Offset(cx - modeTp.width / 2, drawY));
    drawY += modeTp.height + 4;
    canvas.drawLine(
      Offset(cx - totalW / 2 + padX, drawY - 2),
      Offset(cx + totalW / 2 - padX, drawY - 2),
      Paint()..color = Colors.white.withOpacity(0.07)..strokeWidth = 0.8,
    );

    for (var i = 0; i < tpPainters.length; i++) {
      final tp = d.tpLevels[i];
      canvas.drawCircle(
        Offset(cx - totalW / 2 + padX - 2, drawY + rowH / 2), 3.5,
        Paint()..color = _tpColors[i % _tpColors.length].withOpacity(tp.isHit ? 0.35 : 1.0),
      );
      tpPainters[i].paint(canvas,
          Offset(cx - totalW / 2 + padX + 8, drawY + (rowH - tpPainters[i].height) / 2));
      if (tp.isHit) {
        final checkP = TextPainter(
          text: TextSpan(text: '✓',
              style: TextStyle(color: _tpColors[i % _tpColors.length].withOpacity(0.6),
                  fontSize: 12, fontWeight: FontWeight.w900)),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        checkP.paint(canvas, Offset(
            cx + totalW / 2 - checkP.width - padX,
            drawY + (rowH - checkP.height) / 2));
      }
      drawY += rowH;
    }
  }

  void _paintMoveHandle(Canvas canvas, MultiTpData d, ChartCoordinateMapper m,
      double topY, double botY) {
    final cx       = d.centerX(m);
    final cy       = (topY + botY) / 2;
    final isActive = activeDragHandle == MultiTpDragHandle.wholeBox;
    final op       = isActive ? 1.0 : 0.45;
    for (var c = -1; c <= 1; c++) {
      for (var r = -1; r <= 1; r++) {
        canvas.drawCircle(
          Offset(cx + c * 5, cy + r * 5),
          isActive ? 2.5 : 1.8,
          Paint()..color = isActive
              ? accentColor.withOpacity(op)
              : Colors.white.withOpacity(op),
        );
      }
    }
  }

  void _paintTriggerDot(Canvas canvas, MultiTpData d, ChartCoordinateMapper m) {
    final tx  = m.candleIndexToX(d.triggerBarIndex!);
    final eY  = _priceToY(d.entryPrice);
    final col = d.mode == RiskRatioMode.buy ? _entryBuyColor : _entrySellColor;
    if (tradeActive) {
      canvas.drawCircle(Offset(tx, eY), 6 + pulseValue * 4, Paint()
        ..color      = col.withOpacity(0.25 * (1 - pulseValue))
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
    canvas.drawCircle(Offset(tx, eY), 5, Paint()..color = _labelBg);
    canvas.drawCircle(Offset(tx, eY), 4, Paint()..color = col);
    _drawDashedLine(canvas, Offset(tx, eY), Offset(d.leftX(m), eY),
        Paint()..color = col.withOpacity(0.22)..strokeWidth = 1.0);
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
      ..color      = color.withOpacity(opacity * 0.4)
      ..strokeWidth = width + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawLine(start, end, Paint()
      ..color      = color.withOpacity(opacity)
      ..strokeWidth = width);
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

  void _drawMinWidthHint(Canvas canvas, double lx, double rx, double y) {
    final tp = TextPainter(
      text: TextSpan(text: '← too narrow →',
          style: TextStyle(color: Colors.orange.withOpacity(0.7),
              fontSize: 10, fontWeight: FontWeight.w600)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((lx + rx) / 2 - tp.width / 2, y + 8));
  }

  @override
  bool shouldRepaint(MultiTpPainter old) {
    // FIX v3: mapper menggunakan == operator yang sudah implement equality
    // sehingga setiap perubahan offset/scale akan trigger repaint
    return old.data             != data             ||
        old.mapper           != mapper           ||   // ← equality via ==
        old.isDrawing        != isDrawing        ||
        old.drawStartPos     != drawStartPos     ||
        old.drawCurrentPos   != drawCurrentPos   ||
        old.activeDragHandle != activeDragHandle ||
        old.hoveredHandle    != hoveredHandle    ||
        old.pulseValue       != pulseValue       ||
        old.appearValue      != appearValue      ||
        old.tradeActive      != tradeActive;
  }
}