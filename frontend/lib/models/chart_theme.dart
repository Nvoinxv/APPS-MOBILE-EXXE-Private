import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';
import '../candle/candle_normal.dart';

/// Preset themes untuk chart
class ChartTheme {
  /// Futuristic dark theme dengan neon green accents
  static CandlestickStyle futuristic() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF00FF88), // Neon green
      bearishColor: const Color(0xFFFF0066), // Neon pink/red
      backgroundColor: const Color(0xFF0A0E17), // Deep space black
      gridColor: const Color(0xFF1A2332), // Dark blue-gray
      textColor: const Color(0xFF8B93A7), // Muted gray-blue
      crosshairColor: const Color(0xFF00FF88).withOpacity(0.3),
      selectedColor: const Color(0xFF00FFFF), // Cyan highlight
    );
  }
  
  /// TradingView style theme
  static CandlestickStyle tradingView() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF26A69A),
      bearishColor: const Color(0xFFEF5350),
      backgroundColor: const Color(0xFF1E222D),
      gridColor: const Color(0xFF2A2E39),
      textColor: const Color(0xFFB2B5BE),
      crosshairColor: const Color(0xFF787B86).withOpacity(0.3),
      selectedColor: const Color(0xFF2962FF),
    );
  }
  
  /// Classic dark theme
  static CandlestickStyle dark() {
    return CandlestickStyle(
      bullishColor: Colors.green,
      bearishColor: Colors.red,
      backgroundColor: Colors.black,
      gridColor: const Color(0xFF2D2D2D),
      textColor: Colors.white70,
      crosshairColor: Colors.white30,
      selectedColor: Colors.blue,
    );
  }
  
  /// Light theme
  static CandlestickStyle light() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF26A69A),
      bearishColor: const Color(0xFFEF5350),
      backgroundColor: Colors.white,
      gridColor: const Color(0xFFE0E0E0),
      textColor: Colors.black87,
      crosshairColor: Colors.black26,
      selectedColor: const Color(0xFF2196F3),
    );
  }
  
  /// Blue ocean theme
  static CandlestickStyle blue() {
    return CandlestickStyle(
      bullishColor: Colors.blue,
      bearishColor: Colors.orange,
      backgroundColor: const Color(0xFF0D1B2A),
      gridColor: const Color(0xFF1B263B),
      textColor: const Color(0xFFE0E1DD),
      crosshairColor: Colors.blueAccent.withOpacity(0.3),
      selectedColor: Colors.cyanAccent,
    );
  }
  
  /// Purple galaxy theme
  static CandlestickStyle purple() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF9C27B0),
      bearishColor: const Color(0xFFE91E63),
      backgroundColor: const Color(0xFF120E21),
      gridColor: const Color(0xFF2A1F3D),
      textColor: const Color(0xFFB39DDB),
      crosshairColor: const Color(0xFF9C27B0).withOpacity(0.3),
      selectedColor: const Color(0xFFBA68C8),
    );
  }
  
  /// Matrix green theme
  static CandlestickStyle matrix() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF00FF41),
      bearishColor: const Color(0xFFFF0041),
      backgroundColor: const Color(0xFF000000),
      gridColor: const Color(0xFF001a00),
      textColor: const Color(0xFF00FF41),
      crosshairColor: const Color(0xFF00FF41).withOpacity(0.3),
      selectedColor: const Color(0xFF00FF41),
    );
  }
  
  /// All available themes
  static Map<String, CandlestickStyle> get allThemes => {
    'Futuristic': futuristic(),
    'TradingView': tradingView(),
    'Dark': dark(),
    'Light': light(),
    'Blue': blue(),
    'Purple': purple(),
    'Matrix': matrix(),
  };
}