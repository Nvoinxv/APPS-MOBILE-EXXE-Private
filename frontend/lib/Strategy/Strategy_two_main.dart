import 'package:flutter/material.dart';

// Config
import 'config/v1_setting_strateg_2.dart';

// Hooks Strategy
import 'Hooks_Strategy/base_signal.dart';

// Trade Setup Widget
import 'Engine_Execution/Trade_setup_Strategy_2.dart';

// Volume Bubble
import 'volume_module/Bubble_filter_Strategy_2.dart';

import 'utils/chart_utils.dart';

import '../hooks/crypto_data_hook.dart';

class MainStrategy extends StatefulWidget {
  final Size               chartSize;
  final double             minPrice;
  final double             maxPrice;
  final List<CryptoCandle> candles;

  // FIX v3: tiga parameter menggantikan mapper
  final int    totalCandles;
  final double scale;
  final double scrollOffset;

  // Strategy2 toggle — false = stop sinyal baru, trade lama tetap jalan
  final bool isSignalEnabled;

  const MainStrategy({
    Key? key,
    required this.chartSize,
    required this.minPrice,
    required this.maxPrice,
    required this.candles,
    required this.totalCandles,
    required this.scale,
    required this.scrollOffset,
    this.isSignalEnabled = true,
  }) : super(key: key);

  @override
  State<MainStrategy> createState() => MainStrategyState();
}

class MainStrategyState extends State<MainStrategy> {

  final _tradeKey = GlobalKey<TradeSetupWidgetState>();
  final _config   = kDefaultSettings;
  final _hook     = BaseSignalHook();

  final List<double> _closes = [];
  final List<double> _highs  = [];
  final List<double> _lows   = [];

  bool _hasActiveSetup = false;

  @override
  void dispose() {
    _hook.dispose();
    super.dispose();
  }

  bool get _shouldInterceptGesture {
    if (!_hasActiveSetup) return false;
    final state = _tradeKey.currentState;
    if (state == null) return false;
    return state.hasSlTrade || state.isMtpActive;
  }

  void _fillBuffers() {
    _closes
      ..clear()
      ..addAll(widget.candles.map((c) => c.close));
    _highs
      ..clear()
      ..addAll(widget.candles.map((c) => c.high));
    _lows
      ..clear()
      ..addAll(widget.candles.map((c) => c.low));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  A. FULL RUN — historical bars
  // ════════════════════════════════════════════════════════════════════════

  Future<void> runHistorical() async {
    // GUARD: stop sinyal baru kalau Strategy 2 dinonaktifkan
    if (!widget.isSignalEnabled) return;

    _fillBuffers();
    if (_closes.length < 10) return;

    final ohlc   = OHLCRequest(close: _closes, high: _highs, low: _lows);
    final result = await _hook.run(ohlc);

    if (mounted) {
      setState(() => _hasActiveSetup = result.signalBars.isNotEmpty);
    }

    _tradeKey.currentState?.processSignalBars(
      result.signalBars,
      allLows:  _lows,
      allHighs: _highs,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  B. BRIGHT ONLY — sinyal terang saja
  // ════════════════════════════════════════════════════════════════════════

  Future<void> runBrightSignals() async {
    // GUARD: stop sinyal baru kalau Strategy 2 dinonaktifkan
    if (!widget.isSignalEnabled) return;

    _fillBuffers();
    if (_closes.length < 10) return;

    final ohlc    = OHLCRequest(close: _closes, high: _highs, low: _lows);
    final brights = await _hook.runBright(ohlc);

    if (mounted) {
      setState(() => _hasActiveSetup = brights.isNotEmpty);
    }

    for (final bar in brights) {
      final idx = bar.barIndex;
      _tradeKey.currentState?.processFromBrightBar(
        bar,
        lows:  _lows.sublist(0, idx.clamp(0, _lows.length)),
        highs: _highs.sublist(0, idx.clamp(0, _highs.length)),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  C. LIVE TICK — polling per bar baru
  // ════════════════════════════════════════════════════════════════════════

  Future<void> tickLatestBar({
    required double currentHigh,
    required double currentLow,
  }) async {
    // Live tick tetap jalan — trade lama perlu diupdate terus
    _fillBuffers();
    if (_closes.length < 10) return;

    final ohlc   = OHLCRequest(close: _closes, high: _highs, low: _lows);
    final latest = await _hook.runLatest(ohlc);

    _tradeKey.currentState?.updateFromLatest(
      latest,
      high: currentHigh,
      low:  currentLow,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_shouldInterceptGesture,
      child: TradeSetupGestureRouter(
        tradeKey:    _tradeKey,
        isTradeMode: _hasActiveSetup,
        child: TradeSetupWidget(
          key:               _tradeKey,
          chartSize:         widget.chartSize,
          accentColor:       const Color(0xFF00C8FF),
          backgroundColor:   const Color(0xFF0A1520),
          textColor:         Colors.white,
          minPrice:          widget.minPrice,
          maxPrice:          widget.maxPrice,
          totalCandles:      widget.totalCandles,
          scale:             widget.scale,
          scrollOffset:      widget.scrollOffset,
          defaultRrRatio:    _config.rrRatio,
          defaultSlLookback: _config.slLookback,
          useBreakeven:      true,
          showSlTpMarkers:   true,
        ),
      ),
    );
  }
}