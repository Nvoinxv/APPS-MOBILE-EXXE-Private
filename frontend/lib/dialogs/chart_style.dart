// =============================================================================
// chart_style_state.dart
// Path: frontend/lib/dialogs/chart_style_state.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../candle/candle_normal.dart'; // CandleBodyStyle & CandleStyle sudah ada di sini

// ---------------------------------------------------------------------------
// Enum yang TIDAK ada di candle_normal.dart — definisikan di sini
// ---------------------------------------------------------------------------

enum ChartBackgroundMode {
  solidColor,
  gradient,
  image,
}

enum GridStyle {
  lines,
  dots,
  none,
}

// ---------------------------------------------------------------------------
// ChartStyleState
// ---------------------------------------------------------------------------

@immutable
class ChartStyleState {
  final Color             bullishColor;
  final Color             bearishColor;
  final double            candleOpacity;
  final CandleBodyStyle   bodyStyle;      // ← dari candle_normal.dart

  final bool              showWick;
  final double            wickOpacity;

  final ChartBackgroundMode backgroundMode;
  final Color               backgroundColor;
  final Color               backgroundGradientEnd;
  final String?             backgroundImagePath;
  final double              backgroundOpacity;

  final Color     gridColor;
  final double    gridOpacity;
  final GridStyle gridStyle;

  final Color  textColor;
  final Color  crosshairColor;
  final Color  overlayAccentColor;

  const ChartStyleState({
    this.bullishColor          = const Color(0xFF00D09C),
    this.bearishColor          = const Color(0xFFFF4D6D),
    this.candleOpacity         = 1.0,
    this.bodyStyle             = CandleBodyStyle.filled,
    this.showWick              = true,
    this.wickOpacity           = 0.85,
    this.backgroundMode        = ChartBackgroundMode.solidColor,
    this.backgroundColor       = const Color(0xFF0A0E17),
    this.backgroundGradientEnd = const Color(0xFF0D1B2A),
    this.backgroundImagePath   = null,
    this.backgroundOpacity     = 1.0,
    this.gridColor             = const Color(0xFF1A2332),
    this.gridOpacity           = 1.0,
    this.gridStyle             = GridStyle.lines,
    this.textColor             = const Color(0xFF8B93A7),
    this.crosshairColor        = const Color(0xFF00D09C),
    this.overlayAccentColor    = const Color(0xFF00D09C),
  });

  ChartStyleState copyWith({
    Color?               bullishColor,
    Color?               bearishColor,
    double?              candleOpacity,
    CandleBodyStyle?     bodyStyle,
    bool?                showWick,
    double?              wickOpacity,
    ChartBackgroundMode? backgroundMode,
    Color?               backgroundColor,
    Color?               backgroundGradientEnd,
    String?              backgroundImagePath,
    double?              backgroundOpacity,
    Color?               gridColor,
    double?              gridOpacity,
    GridStyle?           gridStyle,
    Color?               textColor,
    Color?               crosshairColor,
    Color?               overlayAccentColor,
  }) {
    return ChartStyleState(
      bullishColor:          bullishColor          ?? this.bullishColor,
      bearishColor:          bearishColor          ?? this.bearishColor,
      candleOpacity:         candleOpacity         ?? this.candleOpacity,
      bodyStyle:             bodyStyle             ?? this.bodyStyle,
      showWick:              showWick              ?? this.showWick,
      wickOpacity:           wickOpacity           ?? this.wickOpacity,
      backgroundMode:        backgroundMode        ?? this.backgroundMode,
      backgroundColor:       backgroundColor       ?? this.backgroundColor,
      backgroundGradientEnd: backgroundGradientEnd ?? this.backgroundGradientEnd,
      backgroundImagePath:   backgroundImagePath   ?? this.backgroundImagePath,
      backgroundOpacity:     backgroundOpacity     ?? this.backgroundOpacity,
      gridColor:             gridColor             ?? this.gridColor,
      gridOpacity:           gridOpacity           ?? this.gridOpacity,
      gridStyle:             gridStyle             ?? this.gridStyle,
      textColor:             textColor             ?? this.textColor,
      crosshairColor:        crosshairColor        ?? this.crosshairColor,
      overlayAccentColor:    overlayAccentColor    ?? this.overlayAccentColor,
    );
  }

  factory ChartStyleState.neon() => const ChartStyleState(
    bullishColor:          Color(0xFF00FF88),
    bearishColor:          Color(0xFFFF0066),
    backgroundColor:       Color(0xFF0A0E17),
    backgroundGradientEnd: Color(0xFF0D1422),
    gridColor:             Color(0xFF1A2332),
    textColor:             Color(0xFF8B93A7),
    crosshairColor:        Color(0xFF00FF88),
    overlayAccentColor:    Color(0xFF00FF88),
  );

  factory ChartStyleState.tradingView() => const ChartStyleState(
    bullishColor:          Color(0xFF26A69A),
    bearishColor:          Color(0xFFEF5350),
    backgroundColor:       Color(0xFF1E222D),
    backgroundGradientEnd: Color(0xFF1A1E2C),
    gridColor:             Color(0xFF2A2E39),
    textColor:             Color(0xFFB2B5BE),
    crosshairColor:        Color(0xFF26A69A),
    overlayAccentColor:    Color(0xFF26A69A),
  );

  factory ChartStyleState.ocean() => const ChartStyleState(
    bullishColor:          Color(0xFF06FFA5),
    bearishColor:          Color(0xFFFF5F6D),
    backgroundColor:       Color(0xFF011627),
    backgroundGradientEnd: Color(0xFF041E34),
    gridColor:             Color(0xFF1F4788),
    textColor:             Color(0xFFB8C5D6),
    crosshairColor:        Color(0xFF06FFA5),
    overlayAccentColor:    Color(0xFF06FFA5),
  );

  factory ChartStyleState.matrix() => const ChartStyleState(
    bullishColor:          Color(0xFF00FF41),
    bearishColor:          Color(0xFFFF0040),
    backgroundColor:       Color(0xFF0D0208),
    backgroundGradientEnd: Color(0xFF020802),
    gridColor:             Color(0xFF003B00),
    textColor:             Color(0xFF008F11),
    crosshairColor:        Color(0xFF00FF41),
    overlayAccentColor:    Color(0xFF00FF41),
  );

  factory ChartStyleState.sunset() => const ChartStyleState(
    bullishColor:          Color(0xFFFFC837),
    bearishColor:          Color(0xFFFF6B35),
    backgroundColor:       Color(0xFF1A1A2E),
    backgroundGradientEnd: Color(0xFF16213E),
    gridColor:             Color(0xFF2A2A4A),
    textColor:             Color(0xFFEEEEEE),
    crosshairColor:        Color(0xFFFFC837),
    overlayAccentColor:    Color(0xFFFFC837),
  );

  factory ChartStyleState.light() => const ChartStyleState(
    bullishColor:          Color(0xFF26A69A),
    bearishColor:          Color(0xFFEF5350),
    backgroundColor:       Color(0xFFFAFAFA),
    backgroundGradientEnd: Color(0xFFF0F4FF),
    gridColor:             Color(0xFFE0E0E0),
    textColor:             Color(0xFF333333),
    crosshairColor:        Color(0xFF26A69A),
    overlayAccentColor:    Color(0xFF26A69A),
  );
}

class ChartStylePreset {
  final String          name;
  final ChartStyleState state;

  const ChartStylePreset({required this.name, required this.state});

  static List<ChartStylePreset> all() => [
    ChartStylePreset(name: 'Neon',        state: ChartStyleState.neon()),
    ChartStylePreset(name: 'TradingView', state: ChartStyleState.tradingView()),
    ChartStylePreset(name: 'Ocean',       state: ChartStyleState.ocean()),
    ChartStylePreset(name: 'Matrix',      state: ChartStyleState.matrix()),
    ChartStylePreset(name: 'Sunset',      state: ChartStyleState.sunset()),
    ChartStylePreset(name: 'Light',       state: ChartStyleState.light()),
  ];
}