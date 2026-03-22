import 'package:flutter/material.dart';
import '../models/chart_state.dart';
import '../models/chart_theme.dart';
import '../hooks/crypto_data_hook.dart';
import '../candle/candle_normal.dart';
import '../interactive/risk_ratio_interactive.dart';
import '../controller/risk_ratio_button.dart';

/// Controller untuk mengelola state dan business logic chart
class ChartController extends ChangeNotifier {
  late CryptoDataHook cryptoHook;
  final ChartState state = ChartState();
  final List<String> availableTickers;
  final List<String> availableIntervals;
  
  ChartController({
    required this.availableTickers,
    required this.availableIntervals,
  }) {
    state.selectedTicker = availableTickers.first;
    state.selectedInterval = availableIntervals.first;
    _initializeCryptoHook();
  }

  void _initializeCryptoHook() {
    cryptoHook = CryptoDataHook(
      tickers: availableTickers,
      intervals: availableIntervals,
      autoUpdateInterval: 60,
    );
    
    cryptoHook.onDataUpdate = _handleDataUpdate;
    cryptoHook.onError = _handleError;
    cryptoHook.onAllDataReady = _handleAllDataReady;
    cryptoHook.startAdaptiveUpdate();
  }

  void _handleDataUpdate(String ticker, String interval, List<CryptoCandle> candlesData) {
    if (ticker == state.selectedTicker && interval == state.selectedInterval) {
      state.candles = candlesData;
      state.isLoading = false;
      notifyListeners();
    }
  }

  void _handleError(String ticker, String interval, String error) {
    debugPrint('⚠️ Error $ticker $interval: $error');
  }

  void _handleAllDataReady() {
    debugPrint('✅ All timeframes loaded');
  }

  void changeTicker(String newTicker) {
    state.selectedTicker = newTicker;
    state.isLoading = true;
    state.candles = [];
    state.selectedCandle = null;
    notifyListeners();

    final existingCandles = cryptoHook.getCandles(newTicker, state.selectedInterval);
    if (existingCandles != null && existingCandles.isNotEmpty) {
      state.candles = existingCandles;
      state.isLoading = false;
      notifyListeners();
    }
  }

  void changeInterval(String newInterval) {
    state.selectedInterval = newInterval;
    state.isLoading = true;
    state.candles = [];
    notifyListeners();

    final existingCandles = cryptoHook.getCandles(state.selectedTicker, newInterval);
    if (existingCandles != null && existingCandles.isNotEmpty) {
      state.candles = existingCandles;
      state.isLoading = false;
      notifyListeners();
    }
  }

  void selectCandle(CryptoCandle? candle) {
    state.selectedCandle = candle;
    notifyListeners();
  }

  void toggleVolume() {
    state.showVolume = !state.showVolume;
    notifyListeners();
  }

  void toggleGrid() {
    state.showGrid = !state.showGrid;
    notifyListeners();
  }

  void toggleCrosshair() {
    if (!state.isFibonacciMode && !state.isRiskRatioMode) {
      state.showCrosshair = !state.showCrosshair;
      notifyListeners();
    }
  }

  void toggleFibonacciMode() {
    state.isFibonacciMode = !state.isFibonacciMode;
    if (state.isFibonacciMode) state.isRiskRatioMode = false;
    notifyListeners();
  }

  void toggleRiskRatioMode() {
    state.isRiskRatioMode = !state.isRiskRatioMode;
    if (state.isRiskRatioMode) state.isFibonacciMode = false;
    notifyListeners();
  }

  void switchRiskRatioMode() {
    state.riskRatioMode = state.riskRatioMode == RiskRatioMode.buy 
        ? RiskRatioMode.sell 
        : RiskRatioMode.buy;
    notifyListeners();
  }

  void changeTheme(CandlestickStyle newTheme) {
    state.chartStyle = newTheme;
    notifyListeners();
  }

  // FIX: added missing updateScale method required by InteractiveCandlestickChart
  void updateScale(double newScale) {
    state.scale = newScale.clamp(0.5, 5.0);
    notifyListeners();
  }

  void updateOffset(Offset newOffset) {
    state.offset = newOffset;
    notifyListeners();
  }

  void updateOffsetY(double newOffsetY) {
    state.offsetY = newOffsetY;
    notifyListeners();
  }

  void resetZoomPan() {
    state.scale = 1.0;
    state.offset = Offset.zero;
    state.offsetY = 0.0;
    state.selectedCandle = null;
    notifyListeners();
  }
  
  double getMinPrice() {
    if (state.candles.isEmpty) return 0;
    return state.candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
  }
  
  double getMaxPrice() {
    if (state.candles.isEmpty) return 100;
    return state.candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
  }

  @override
  void dispose() {
    cryptoHook.dispose();
    super.dispose();
  }
}