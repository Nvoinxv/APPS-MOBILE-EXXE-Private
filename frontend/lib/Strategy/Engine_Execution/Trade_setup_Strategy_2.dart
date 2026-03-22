// ══════════════════════════════════════════════════════════════════════════════
// Trade_setup_Strategy_2.dart  —  FIX v3: ganti `mapper` dengan
//                                 `totalCandles`, `scale`, `scrollOffset`
//                                 agar sinkron dengan API baru SL & MultiTP.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../utils/chart_utils.dart';
import 'Sl_Strategy_2.dart';
import 'Multi_TP_Stratgey_2.dart';
import '../Hooks_Strategy/base_signal.dart';

// ══════════════════════════════════════════════════════════════════════════════
// §1  ACTIVE WIDGET MODE
// ══════════════════════════════════════════════════════════════════════════════

enum TradeWidgetMode {
  none,
  stopLoss,
  multiTp,
  both,
}

// ══════════════════════════════════════════════════════════════════════════════
// §2  TRADE SETUP WIDGET
//
// FIX v3: ganti parameter `mapper` (nullable) dengan tiga parameter primitif:
//   - totalCandles  → jumlah candle total
//   - scale         → zoom level terkini (dari state.scale)
//   - scrollOffset  → pixel scroll offset terkini (dari state.offset.dx)
//
// Dengan ini, setiap kali parent rebuild karena pan/zoom, nilai terbaru
// langsung mengalir ke child widget, yang kemudian membuat mapper fresh
// sendiri tanpa bergantung pada object mapper yang bisa stale.
// ══════════════════════════════════════════════════════════════════════════════

class TradeSetupWidget extends StatefulWidget {
  final Size   chartSize;
  final Color  accentColor;
  final Color  backgroundColor;
  final Color  textColor;
  final double minPrice;
  final double maxPrice;

  // FIX v3: ganti `ChartCoordinateMapper? mapper` dengan tiga parameter ini
  final int    totalCandles;
  final double scale;
  final double scrollOffset;

  final double defaultRrRatio;
  final int    defaultSlLookback;
  final bool   useBreakeven;
  final bool   showSlTpMarkers;

  final int          defaultTpCount;
  final List<double> defaultRrMultipliers;
  final List<double> defaultLotPercentages;

  final TradeWidgetMode initialMode;

  final void Function(TradeSetup)?   onSlTradeOpened;
  final void Function(TradeSetup)?   onSlHit;
  final void Function(TradeSetup)?   onTpHit;
  final void Function(TradeSetup)?   onBreakevenApplied;
  final void Function(MultiTpData)?  onMultiTpOpened;
  final void Function(TradeHitResult, MultiTpData)? onMultiTpHit;

  const TradeSetupWidget({
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
    this.defaultRrRatio        = 2.0,
    this.defaultSlLookback     = 15,
    this.useBreakeven          = true,
    this.showSlTpMarkers       = true,
    this.defaultTpCount        = 3,
    this.defaultRrMultipliers  = const [1.0, 2.0, 3.0],
    this.defaultLotPercentages = const [25.0, 50.0, 25.0],
    this.initialMode           = TradeWidgetMode.both,
    this.onSlTradeOpened,
    this.onSlHit,
    this.onTpHit,
    this.onBreakevenApplied,
    this.onMultiTpOpened,
    this.onMultiTpHit,
  }) : super(key: key);

  @override
  State<TradeSetupWidget> createState() => TradeSetupWidgetState();
}

class TradeSetupWidgetState extends State<TradeSetupWidget> {
  final _slKey  = GlobalKey<StopLossInteractiveState>();
  final _mtpKey = GlobalKey<MultiTpRiskRatioInteractiveState>();

  TradeWidgetMode _mode = TradeWidgetMode.both;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════════════════

  void processSignalBar(
    SignalBar bar, {
    required List<double> lows,
    required List<double> highs,
  }) {
    if (!bar.brightBuy && !bar.brightSell) {
      _tickSlBar(bar.barIndex, high: bar.high, low: bar.low);
      _tickMtpBar(bar);
      return;
    }

    if (_isSlActive) {
      _slKey.currentState?.openTradeFromSignal(TradeSignalInput(
        direction:   bar.brightBuy ? 'long' : 'short',
        entryPrice:  bar.close,
        barIndex:    bar.barIndex,
        recentLows:  lows,
        recentHighs: highs,
      ));
    }

    if (_isMtpActive) {
      _mtpKey.currentState?.openFromSignalBar(bar, lows: lows, highs: highs);
    }
  }

  void processSignalBars(
    List<SignalBar> bars, {
    required List<double> allLows,
    required List<double> allHighs,
  }) {
    for (final bar in bars) {
      final end = bar.barIndex.clamp(0, allLows.length);
      processSignalBar(
        bar,
        lows:  allLows.sublist(0, end),
        highs: allHighs.sublist(0, end),
      );
    }
  }

  void processFromBrightBar(
    BrightSignalBar bar, {
    required List<double> lows,
    required List<double> highs,
  }) {
    if (_isSlActive) {
      _slKey.currentState?.openTradeFromSignal(TradeSignalInput(
        direction:    bar.isLong ? 'long' : 'short',
        entryPrice:   bar.close,
        barIndex:     bar.barIndex,
        recentLows:   lows,
        recentHighs:  highs,
        trailingStop: bar.trailingStop,
      ));
    }

    if (_isMtpActive) {
      _mtpKey.currentState?.openFromBrightBar(bar, lows: lows, highs: highs);
    }
  }

  void updateFromLatest(
    LatestBarResponse bar, {
    required double high,
    required double low,
  }) {
    _slKey.currentState?.extendToBar(bar.barIndex);
    _slKey.currentState?.processBar(high: high, low: low);

    final hit = _mtpKey.currentState?.updateWithLatestBar(
      bar, high: high, low: low,
    );
    if (hit != null && !hit.isNone) {
      final d = _mtpKey.currentState?.data;
      if (d != null) widget.onMultiTpHit?.call(hit, d);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PUBLIC CONTROLS
  // ══════════════════════════════════════════════════════════════════════

  void setMode(TradeWidgetMode mode) => setState(() => _mode = mode);
  void clearAll() {
    _slKey.currentState?.clearTrade();
    _mtpKey.currentState?.clearData();
  }
  void applyBreakeven()   => _slKey.currentState?.applyBreakevenManual();
  void addTpLevel({double rrMultiplier = 4.0, double lotPct = 10.0}) =>
      _mtpKey.currentState?.addTpLevel(rrMultiplier: rrMultiplier, lotPct: lotPct);
  void removeTpLevel()    => _mtpKey.currentState?.removeTpLevel();
  void toggleMultiTpLock()=> _mtpKey.currentState?.toggleLock();

  bool        get hasSlTrade      => _slKey.currentState?.hasTrade        ?? false;
  bool        get isSlTradeActive => _slKey.currentState?.isTradeActive    ?? false;
  TradeSetup? get currentSlTrade  => _slKey.currentState?.currentTrade;

  bool         get hasMultiTp     => _mtpKey.currentState?.data       != null;
  bool         get isMtpActive    => _mtpKey.currentState?.tradeActive ?? false;
  MultiTpData? get currentMtpData => _mtpKey.currentState?.data;

  TradeWidgetMode get mode => _mode;

  bool get _isSlActive  =>
      _mode == TradeWidgetMode.stopLoss || _mode == TradeWidgetMode.both;
  bool get _isMtpActive =>
      _mode == TradeWidgetMode.multiTp  || _mode == TradeWidgetMode.both;

  void _tickSlBar(int barIndex, {required double high, required double low}) {
    if (!_isSlActive) return;
    _slKey.currentState?.extendToBar(barIndex);
    _slKey.currentState?.processBar(high: high, low: low);
  }

  void _tickMtpBar(SignalBar bar) {
    if (!_isMtpActive) return;
    final hit = _mtpKey.currentState?.updateWithSignalBar(bar);
    if (hit != null && !hit.isNone) {
      final d = _mtpKey.currentState?.data;
      if (d != null) widget.onMultiTpHit?.call(hit, d);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX v3: pass totalCandles, scale, scrollOffset langsung ke child.
    // Saat parent rebuild (pan/zoom), nilai terbaru mengalir ke sini,
    // child membuat mapper fresh → posisi UI sinkron dengan candle.
    return Stack(
      children: [
        if (_isMtpActive)
          MultiTpGestureRouter(
            rrKey:           _mtpKey,
            isRiskRatioMode: _mode == TradeWidgetMode.multiTp,
            child: MultiTpRiskRatioInteractive(
              key:                   _mtpKey,
              chartSize:             widget.chartSize,
              accentColor:           widget.accentColor,
              backgroundColor:       widget.backgroundColor,
              textColor:             widget.textColor,
              minPrice:              widget.minPrice,
              maxPrice:              widget.maxPrice,
              // FIX v3: tiga parameter baru menggantikan mapper
              totalCandles:          widget.totalCandles,
              scale:                 widget.scale,
              scrollOffset:          widget.scrollOffset,
              slLookback:            widget.defaultSlLookback,
              defaultTpCount:        widget.defaultTpCount,
              defaultRrMultipliers:  widget.defaultRrMultipliers,
              defaultLotPercentages: widget.defaultLotPercentages,
              useBreakeven:          widget.useBreakeven,
            ),
          ),

        if (_isSlActive)
          StopLossGestureRouter(
            slKey:    _slKey,
            isSlMode: _mode == TradeWidgetMode.stopLoss,
            child: StopLossInteractive(
              key:             _slKey,
              chartSize:       widget.chartSize,
              accentColor:     widget.accentColor,
              backgroundColor: widget.backgroundColor,
              textColor:       widget.textColor,
              minPrice:        widget.minPrice,
              maxPrice:        widget.maxPrice,
              // FIX v3: tiga parameter baru menggantikan mapper
              totalCandles:    widget.totalCandles,
              scale:           widget.scale,
              scrollOffset:    widget.scrollOffset,
              slLookback:      widget.defaultSlLookback,
              rrRatio:         widget.defaultRrRatio,
              useBreakeven:    widget.useBreakeven,
              onTradeOpened:       widget.onSlTradeOpened,
              onSlHit:             widget.onSlHit,
              onTpHit:             widget.onTpHit,
              onBreakevenApplied:  widget.onBreakevenApplied,
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §3  TRADE SETUP GESTURE ROUTER
// ══════════════════════════════════════════════════════════════════════════════

class TradeSetupGestureRouter extends StatefulWidget {
  final GlobalKey<TradeSetupWidgetState> tradeKey;
  final bool   isTradeMode;
  final Widget child;

  const TradeSetupGestureRouter({
    Key? key,
    required this.tradeKey,
    required this.isTradeMode,
    required this.child,
  }) : super(key: key);

  @override
  State<TradeSetupGestureRouter> createState() => _TradeSetupGestureRouterState();
}

class _TradeSetupGestureRouterState extends State<TradeSetupGestureRouter> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}