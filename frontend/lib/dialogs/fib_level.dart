import 'package:flutter/material.dart';

// ===========================================================================
// FibLevel — konfigurasi warna/style per level Fibonacci (ala TradingView)
// File ini berdiri sendiri, tidak ada dependency ke widget lain.
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
    lineColor: lineColor ?? this.lineColor,
    fillColor: fillColor ?? this.fillColor,
    lineWidth: lineWidth ?? this.lineWidth,
    showLabel: showLabel ?? this.showLabel,
    isDashed:  isDashed  ?? this.isDashed,
  );

  /// Default TradingView-style Fibonacci levels.
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