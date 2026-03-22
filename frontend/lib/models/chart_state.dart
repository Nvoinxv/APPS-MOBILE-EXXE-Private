import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';
import '../controller/risk_ratio_button.dart';
import 'chart_theme.dart';
import '../hooks/crypto_data_hook.dart';

/// Model untuk menyimpan semua state chart
class ChartState {
  // Selected Data
  String selectedTicker = 'BTC-USDT';
  String selectedInterval = '15m';

  // Candle Data
  List<CryptoCandle> candles = [];
  CryptoCandle? selectedCandle;

  // Chart Style
  CandlestickStyle chartStyle = ChartTheme.futuristic();

  // Display Settings
  bool showVolume = true;
  bool showGrid = true;
  bool showCrosshair = true;
  bool isLoading = true;

  // Crosshair
  Offset? crosshairPosition;
  String? crosshairPriceLabel;
  String? crosshairTimeLabel;

  // Drawing Modes
  bool isFibonacciMode = false;
  bool isRiskRatioMode = false;
  RiskRatioMode riskRatioMode = RiskRatioMode.buy;

  // Zoom & Pan
  double scale = 1.0;
  double previousScale = 1.0;
  Offset offset = Offset.zero;
  Offset previousOffset = Offset.zero;

  double offsetY = 0.0;
  double previousOffsetY = 0.0;
  
  double verticalOffset = 0.0;
  double previousVerticalOffset = 0.0;

  // Computed Properties
  bool get isInDrawingMode => isFibonacciMode || isRiskRatioMode;
  bool get canShowCrosshair => showCrosshair && !isInDrawingMode;
  bool get hasCandles => candles.isNotEmpty;
  CryptoCandle? get latestCandle => hasCandles ? candles.last : null;
}