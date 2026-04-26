// =============================================================================
// bar_style.dart
// Path: frontend/lib/dialogs/bar_style.dart
//
// Bertanggung jawab atas style SEMUA bar/panel di chart:
//   • Top control bar (ticker, interval selector)
//   • Price axis bar (kanan, label harga)
//   • Volume bar (bawah chart)
//   • Bottom control bar (tombol reset, tools, dll)
//   • Candle info panel (OHLCV strip)
//
// Semua bar punya state independen sehingga bisa diatur terpisah.
// =============================================================================

import 'package:flutter/material.dart';

// ── Bar opacity / visibility helper ──────────────────────────────────────────

/// Seberapa transparan background sebuah bar (0 = transparan penuh, 1 = solid)
typedef BarOpacity = double;

// ── Individual bar state ──────────────────────────────────────────────────────

@immutable
class SingleBarStyle {
  final Color       backgroundColor;
  final Color       borderColor;
  final Color       textColor;
  final Color       iconColor;
  final Color       accentColor;     // highlight / selected
  final double      backgroundOpacity;
  final double      borderOpacity;
  final double      borderWidth;
  final bool        showBorder;
  final double      blurRadius;      // frosted glass effect (0 = off)

  const SingleBarStyle({
    this.backgroundColor   = const Color(0xFF0A0E17),
    this.borderColor       = const Color(0xFF1E2333),
    this.textColor         = const Color(0xFF8B93A7),
    this.iconColor         = const Color(0xFF6B7280),
    this.accentColor       = const Color(0xFF00D09C),
    this.backgroundOpacity = 1.0,
    this.borderOpacity     = 1.0,
    this.borderWidth       = 1.0,
    this.showBorder        = true,
    this.blurRadius        = 0.0,
  });

  SingleBarStyle copyWith({
    Color?  backgroundColor,
    Color?  borderColor,
    Color?  textColor,
    Color?  iconColor,
    Color?  accentColor,
    double? backgroundOpacity,
    double? borderOpacity,
    double? borderWidth,
    bool?   showBorder,
    double? blurRadius,
  }) => SingleBarStyle(
    backgroundColor:   backgroundColor   ?? this.backgroundColor,
    borderColor:       borderColor       ?? this.borderColor,
    textColor:         textColor         ?? this.textColor,
    iconColor:         iconColor         ?? this.iconColor,
    accentColor:       accentColor       ?? this.accentColor,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    borderOpacity:     borderOpacity     ?? this.borderOpacity,
    borderWidth:       borderWidth       ?? this.borderWidth,
    showBorder:        showBorder        ?? this.showBorder,
    blurRadius:        blurRadius        ?? this.blurRadius,
  );

  // Resolved colors (with opacity applied)
  Color get resolvedBackground =>
      backgroundColor.withOpacity(backgroundOpacity.clamp(0.0, 1.0));
  Color get resolvedBorder =>
      borderColor.withOpacity((borderOpacity * (showBorder ? 1.0 : 0.0)).clamp(0.0, 1.0));
}

// ── Master bar style state ────────────────────────────────────────────────────

@immutable
class BarStyleState {
  final SingleBarStyle topBar;
  final SingleBarStyle priceAxis;
  final SingleBarStyle volumeBar;
  final SingleBarStyle bottomBar;
  final SingleBarStyle infoPanel;   // candle OHLCV strip

  const BarStyleState({
    this.topBar    = const SingleBarStyle(),
    this.priceAxis = const SingleBarStyle(
      backgroundColor: Color(0xFF0A0E17),
      borderColor:     Color(0xFF1E2333),
      textColor:       Color(0xFF8B93A7),
    ),
    this.volumeBar = const SingleBarStyle(
      backgroundColor: Color(0xFF0A0E17),
      borderColor:     Color(0xFF1E2333),
    ),
    this.bottomBar = const SingleBarStyle(
      backgroundColor: Color(0xFF0A0E17),
      borderColor:     Color(0xFF1E2333),
      textColor:       Color(0xFF8B93A7),
    ),
    this.infoPanel = const SingleBarStyle(
      backgroundColor: Color(0xFF0D1117),
      borderColor:     Color(0xFF1E2333),
      textColor:       Color(0xFFB2B5BE),
    ),
  });

  BarStyleState copyWith({
    SingleBarStyle? topBar,
    SingleBarStyle? priceAxis,
    SingleBarStyle? volumeBar,
    SingleBarStyle? bottomBar,
    SingleBarStyle? infoPanel,
  }) => BarStyleState(
    topBar:    topBar    ?? this.topBar,
    priceAxis: priceAxis ?? this.priceAxis,
    volumeBar: volumeBar ?? this.volumeBar,
    bottomBar: bottomBar ?? this.bottomBar,
    infoPanel: infoPanel ?? this.infoPanel,
  );

  // ── Presets ──────────────────────────────────────────────────────────────────

  static const BarStyleState defaultStyle = BarStyleState();

  static const BarStyleState transparent = BarStyleState(
    topBar:    SingleBarStyle(backgroundColor: Colors.transparent, backgroundOpacity: 0.0, showBorder: false),
    priceAxis: SingleBarStyle(backgroundColor: Colors.transparent, backgroundOpacity: 0.0, showBorder: false, textColor: Color(0xFF8B93A7)),
    volumeBar: SingleBarStyle(backgroundColor: Colors.transparent, backgroundOpacity: 0.0, showBorder: false),
    bottomBar: SingleBarStyle(backgroundColor: Colors.transparent, backgroundOpacity: 0.0, showBorder: false),
    infoPanel: SingleBarStyle(backgroundColor: Colors.transparent, backgroundOpacity: 0.0, showBorder: false, textColor: Color(0xFFB2B5BE)),
  );

  static const BarStyleState frostedGlass = BarStyleState(
    topBar:    SingleBarStyle(backgroundColor: Color(0xFF1A1E2C), backgroundOpacity: 0.7, blurRadius: 12, borderColor: Color(0xFF2A2E3D)),
    priceAxis: SingleBarStyle(backgroundColor: Color(0xFF1A1E2C), backgroundOpacity: 0.7, blurRadius: 12, borderColor: Color(0xFF2A2E3D)),
    volumeBar: SingleBarStyle(backgroundColor: Color(0xFF1A1E2C), backgroundOpacity: 0.6, blurRadius: 8),
    bottomBar: SingleBarStyle(backgroundColor: Color(0xFF1A1E2C), backgroundOpacity: 0.7, blurRadius: 12, borderColor: Color(0xFF2A2E3D)),
    infoPanel: SingleBarStyle(backgroundColor: Color(0xFF1A1E2C), backgroundOpacity: 0.7, blurRadius: 8, textColor: Color(0xFFB2B5BE)),
  );

  static const BarStyleState neon = BarStyleState(
    topBar:    SingleBarStyle(backgroundColor: Color(0xFF0A0E17), borderColor: Color(0xFF00FF88), accentColor: Color(0xFF00FF88), textColor: Color(0xFF00FF88)),
    priceAxis: SingleBarStyle(backgroundColor: Color(0xFF0A0E17), borderColor: Color(0xFF1A2332), textColor: Color(0xFF00FF88)),
    volumeBar: SingleBarStyle(backgroundColor: Color(0xFF0A0E17), borderColor: Color(0xFF1A2332)),
    bottomBar: SingleBarStyle(backgroundColor: Color(0xFF0A0E17), borderColor: Color(0xFF00FF88), accentColor: Color(0xFF00FF88), iconColor: Color(0xFF00FF88)),
    infoPanel: SingleBarStyle(backgroundColor: Color(0xFF0D0208), borderColor: Color(0xFF00FF88), textColor: Color(0xFF00FF88)),
  );

  static const BarStyleState tradingView = BarStyleState(
    topBar:    SingleBarStyle(backgroundColor: Color(0xFF1E222D), borderColor: Color(0xFF2A2E39), textColor: Color(0xFFB2B5BE), accentColor: Color(0xFF26A69A)),
    priceAxis: SingleBarStyle(backgroundColor: Color(0xFF1E222D), borderColor: Color(0xFF2A2E39), textColor: Color(0xFFB2B5BE)),
    volumeBar: SingleBarStyle(backgroundColor: Color(0xFF1E222D), borderColor: Color(0xFF2A2E39)),
    bottomBar: SingleBarStyle(backgroundColor: Color(0xFF1E222D), borderColor: Color(0xFF2A2E39), textColor: Color(0xFFB2B5BE), accentColor: Color(0xFF26A69A)),
    infoPanel: SingleBarStyle(backgroundColor: Color(0xFF1A1E2C), borderColor: Color(0xFF2A2E39), textColor: Color(0xFFB2B5BE)),
  );

  static const BarStyleState light = BarStyleState(
    topBar:    SingleBarStyle(backgroundColor: Color(0xFFFAFAFA), borderColor: Color(0xFFE0E0E0), textColor: Color(0xFF333333), iconColor: Color(0xFF555555), accentColor: Color(0xFF26A69A)),
    priceAxis: SingleBarStyle(backgroundColor: Color(0xFFF5F5F5), borderColor: Color(0xFFE0E0E0), textColor: Color(0xFF555555)),
    volumeBar: SingleBarStyle(backgroundColor: Color(0xFFF0F0F0), borderColor: Color(0xFFE0E0E0)),
    bottomBar: SingleBarStyle(backgroundColor: Color(0xFFFAFAFA), borderColor: Color(0xFFE0E0E0), textColor: Color(0xFF333333), iconColor: Color(0xFF555555), accentColor: Color(0xFF26A69A)),
    infoPanel: SingleBarStyle(backgroundColor: Color(0xFFF5F5F5), borderColor: Color(0xFFE0E0E0), textColor: Color(0xFF333333)),
  );
}

// ── Preset list ───────────────────────────────────────────────────────────────

class BarStylePreset {
  final String       name;
  final BarStyleState state;
  const BarStylePreset({required this.name, required this.state});

  static List<BarStylePreset> all() => const [
    BarStylePreset(name: 'Default',      state: BarStyleState.defaultStyle),
    BarStylePreset(name: 'Transparent',  state: BarStyleState.transparent),
    BarStylePreset(name: 'Frosted Glass',state: BarStyleState.frostedGlass),
    BarStylePreset(name: 'Neon',         state: BarStyleState.neon),
    BarStylePreset(name: 'TradingView',  state: BarStyleState.tradingView),
    BarStylePreset(name: 'Light',        state: BarStyleState.light),
  ];
}

// ── BarContainer widget ───────────────────────────────────────────────────────
// Widget helper biar gampang apply SingleBarStyle ke Container manapun.
// Otomatis handle blur (frosted glass) kalau blurRadius > 0.

import 'dart:ui' as ui;

class BarContainer extends StatelessWidget {
  final SingleBarStyle style;
  final Widget         child;
  final EdgeInsetsGeometry? padding;
  final Border?         overrideBorder;   // override border direction (atas/bawah/dll)

  const BarContainer({
    super.key,
    required this.style,
    required this.child,
    this.padding,
    this.overrideBorder,
  });

  @override
  Widget build(BuildContext context) {
    final base = Container(
      padding: padding,
      decoration: BoxDecoration(
        color:  style.resolvedBackground,
        border: overrideBorder ?? (style.showBorder
            ? Border.all(color: style.resolvedBorder, width: style.borderWidth)
            : null),
      ),
      child: child,
    );

    if (style.blurRadius > 0) {
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: style.blurRadius, sigmaY: style.blurRadius,
          ),
          child: base,
        ),
      );
    }
    return base;
  }
}