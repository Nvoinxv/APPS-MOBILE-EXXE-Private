// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  bubble_filter_widget.dart  —  EXXE.LAB  ©                            ║
// ║                                                                         ║
// ║  Tugas: Render bubble sinyal SOP + label Kalman/pivot/arrow/retest     ║
// ║  Input: SignalBar / BrightSignalBar / LatestBarResponse dari hook      ║
// ║                                                                         ║
// ║  bubble_sizer.dart DIHAPUS — semua bagian uniknya sudah di-merge sini  ║
// ║                                                                         ║
// ║  PineScript reference:                                                  ║
// ║  plotshape(filtered_Buy_SOP,  color=lolos_long_col,  size=size.tiny)  ║
// ║  plotshape(filtered_Sell_SOP, color=lolos_short_col, size=size.tiny)  ║
// ║  plotshape(dark_Buy_Filtered,  color=normal_long_col,  size=size.tiny) ║
// ║  plotshape(dark_Sell_Filtered, color=normal_short_col, size=size.tiny) ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../Hooks_Strategy/base_signal.dart'; // SignalBar, BrightSignalBar, LatestBarResponse

// ══════════════════════════════════════════════════
// §1  PINE SIZE ENUM
//     Dari bubble_sizer — dipakai BubbleType + LabelSignalFactory
// ══════════════════════════════════════════════════

enum PineSize { auto, tiny, small, normal, large, huge }

extension PineSizeX on PineSize {
  double get pillHeight {
    switch (this) {
      case PineSize.auto:
      case PineSize.tiny:   return 20.0;
      case PineSize.small:  return 24.0;
      case PineSize.normal: return 30.0;
      case PineSize.large:  return 36.0;
      case PineSize.huge:   return 44.0;
    }
  }

  double get pillWidth {
    switch (this) {
      case PineSize.auto:
      case PineSize.tiny:   return 28.0;
      case PineSize.small:  return 34.0;
      case PineSize.normal: return 44.0;
      case PineSize.large:  return 52.0;
      case PineSize.huge:   return 64.0;
    }
  }

  double get fontSize {
    switch (this) {
      case PineSize.auto:
      case PineSize.tiny:   return 11.0;
      case PineSize.small:  return 13.0;
      case PineSize.normal: return 16.0;
      case PineSize.large:  return 20.0;
      case PineSize.huge:   return 26.0;
    }
  }

  String get label {
    switch (this) {
      case PineSize.auto:   return 'AUTO';
      case PineSize.tiny:   return 'TINY';
      case PineSize.small:  return 'SMALL';
      case PineSize.normal: return 'NORMAL';
      case PineSize.large:  return 'LARGE';
      case PineSize.huge:   return 'HUGE';
    }
  }
}

// ══════════════════════════════════════════════════
// §2  BUBBLE TYPE
//     4 jenis SOP sesuai PineScript PLOTS 1
//     + label types (kalman, pivot, arrow, retest)
// ══════════════════════════════════════════════════

enum BubbleType {
  // ── SOP Signals (dari hook) ──────────────────────
  filteredLong,   // filtered_Buy_SOP  → lolos_long_col  #c7f7ff
  filteredShort,  // filtered_Sell_SOP → lolos_short_col #ffc9c9
  darkLong,       // dark_Buy_Filtered → normal_long_col  #004e58 op86
  darkShort,      // dark_Sell_Filtered→ normal_short_col #5c0707 op88

  // ── Label Fixed-Size (dari LabelSignalFactory) ───
  // Tidak dari hook — ukuran fixed sesuai PineScript
  kalmanUp,       // label size=size.normal
  kalmanDown,     // label size=size.normal
  pivotLow,       // plotchar size=size.tiny location=belowbar
  pivotHigh,      // plotchar size=size.tiny location=abovebar
  arrowDir,       // label size=size.huge
  retestPlus,     // label size=size.normal location=belowbar
  retestX,        // label size=size.normal location=abovebar
}

extension BubbleTypeX on BubbleType {
  // ── Apakah sinyal SOP dari hook ──────────────────
  bool get isSopSignal =>
      this == BubbleType.filteredLong  ||
      this == BubbleType.filteredShort ||
      this == BubbleType.darkLong      ||
      this == BubbleType.darkShort;

  bool get isFiltered =>
      this == BubbleType.filteredLong ||
      this == BubbleType.filteredShort;

  // ── PineScript: location=belowbar / abovebar ─────
  bool get isBelowBar {
    switch (this) {
      case BubbleType.filteredLong:
      case BubbleType.darkLong:
      case BubbleType.pivotLow:
      case BubbleType.retestPlus:
        return true;
      default:
        return false;
    }
  }

  // ── PineSize per type ────────────────────────────
  // SOP signals pakai tiny/normal sesuai signalClass dari hook
  // Label fixed-size sesuai PineScript
  PineSize get defaultPineSize {
    switch (this) {
      case BubbleType.filteredLong:
      case BubbleType.filteredShort: return PineSize.normal; // bright → normal
      case BubbleType.darkLong:
      case BubbleType.darkShort:     return PineSize.tiny;   // dark → tiny
      case BubbleType.kalmanUp:
      case BubbleType.kalmanDown:    return PineSize.normal; // PineScript: size=size.normal
      case BubbleType.pivotLow:
      case BubbleType.pivotHigh:     return PineSize.tiny;   // PineScript: size=size.tiny
      case BubbleType.arrowDir:      return PineSize.huge;   // PineScript: size=size.huge
      case BubbleType.retestPlus:
      case BubbleType.retestX:       return PineSize.normal; // PineScript: size=size.normal
    }
  }

  // ── Display text ─────────────────────────────────
  String get defaultText {
    switch (this) {
      case BubbleType.filteredLong:
      case BubbleType.darkLong:
      case BubbleType.kalmanUp:   return '🡹';
      case BubbleType.filteredShort:
      case BubbleType.darkShort:
      case BubbleType.kalmanDown: return '🢃';
      case BubbleType.pivotLow:   return '⥣';
      case BubbleType.pivotHigh:  return '⥥';
      case BubbleType.arrowDir:   return '⇒';
      case BubbleType.retestPlus: return '+';
      case BubbleType.retestX:    return 'x';
    }
  }

  // ── Colors ───────────────────────────────────────
  Color get bgColor {
    switch (this) {
      case BubbleType.filteredLong:  return const Color(0xFFC7F7FF);
      case BubbleType.filteredShort: return const Color(0xFFFFC9C9);
      case BubbleType.darkLong:      return const Color(0xFF004E58).withOpacity(0.14);
      case BubbleType.darkShort:     return const Color(0xFF5C0707).withOpacity(0.12);
      default:                       return Colors.transparent;
    }
  }

  Color get arrowColor {
    switch (this) {
      case BubbleType.filteredLong:
      case BubbleType.darkLong:
      case BubbleType.retestPlus:  return const Color(0xFF0085FA);
      case BubbleType.filteredShort:
      case BubbleType.darkShort:
      case BubbleType.retestX:     return const Color(0xFFFF0000);
      case BubbleType.kalmanUp:
      case BubbleType.pivotLow:
      case BubbleType.arrowDir:    return const Color(0xFF00BCD4);
      case BubbleType.kalmanDown:
      case BubbleType.pivotHigh:   return const Color(0xFFB2EBF2);
    }
  }

  Color get borderColor {
    switch (this) {
      case BubbleType.filteredLong:  return const Color(0xFF00C8FF).withOpacity(0.85);
      case BubbleType.filteredShort: return const Color(0xFFFF3D6B).withOpacity(0.85);
      case BubbleType.darkLong:      return const Color(0xFF004E58).withOpacity(0.35);
      case BubbleType.darkShort:     return const Color(0xFF5C0707).withOpacity(0.35);
      default:                       return Colors.transparent;
    }
  }

  String get label {
    switch (this) {
      case BubbleType.filteredLong:  return 'LONG SOP';
      case BubbleType.filteredShort: return 'SHORT SOP';
      case BubbleType.darkLong:      return 'LONG';
      case BubbleType.darkShort:     return 'SHORT';
      case BubbleType.kalmanUp:      return 'KALMAN UP';
      case BubbleType.kalmanDown:    return 'KALMAN DOWN';
      case BubbleType.pivotLow:      return 'PIVOT LOW';
      case BubbleType.pivotHigh:     return 'PIVOT HIGH';
      case BubbleType.arrowDir:      return 'ARROW';
      case BubbleType.retestPlus:    return 'RETEST BUY';
      case BubbleType.retestX:       return 'RETEST SELL';
    }
  }
}

// ══════════════════════════════════════════════════
// §3  SIGNAL BUBBLE MODEL
//     Satu model untuk semua jenis bubble
//     SOP signal dari hook + label fixed-size
// ══════════════════════════════════════════════════

class SignalBubble {
  final BubbleType type;
  final int        barIndex;
  final double     close;
  final double     high;
  final double     low;
  final PineSize   pineSize;      // override jika perlu, default dari type
  final String?    customText;    // untuk kalman (dengan harga), arrow (⇗/⇘/⇒)

  // State dari hook — untuk tooltip SOP signal
  // null untuk label fixed-size (kalman/pivot/arrow/retest)
  final double? trailingStop;
  final double? shortKalman;
  final double? longKalman;
  final bool?   trendUp;
  final double? midBands;

  SignalBubble({
    required this.type,
    required this.barIndex,
    required this.close,
    required this.high,
    required this.low,
    PineSize? pineSize,
    this.customText,
    this.trailingStop,
    this.shortKalman,
    this.longKalman,
    this.trendUp,
    this.midBands,
  }) : pineSize = pineSize ?? type.defaultPineSize;

  String get displayText => customText ?? type.defaultText;

  double get pillH      => pineSize.pillHeight;
  double get pillW      => pineSize.pillWidth;
  double get fontSize   => pineSize.fontSize;
  double get opacity    => isFiltered ? 0.92 : 0.35;
  double get borderWidth => isFiltered ? 1.6 : 0.6;
  bool   get isFiltered => type.isFiltered;

  // ── Factory: SignalBar (hook.run()) ──────────────
  static List<SignalBubble> fromSignalBar(SignalBar bar) {
    final out = <SignalBubble>[];
    if (bar.brightBuy) {
      out.add(_makeSop(BubbleType.filteredLong, bar));
    } else if (bar.darkBuy) {
      out.add(_makeSop(BubbleType.darkLong, bar));
    }
    if (bar.brightSell) {
      out.add(_makeSop(BubbleType.filteredShort, bar));
    } else if (bar.darkSell) {
      out.add(_makeSop(BubbleType.darkShort, bar));
    }
    return out;
  }

  static List<SignalBubble> fromSignalBars(List<SignalBar> bars) =>
      bars.expand(fromSignalBar).toList();

  // ── Factory: BrightSignalBar (hook.runBright()) ──
  static SignalBubble fromBrightBar(BrightSignalBar bar) => _makeSopBright(bar);

  static List<SignalBubble> fromBrightBars(List<BrightSignalBar> bars) =>
      bars.map(fromBrightBar).toList();

  // ── Factory: LatestBarResponse (hook.runLatest()) ─
  // Dari bubble_sizer — sebelumnya tidak ada di bubble_filter
  static List<SignalBubble> fromLatestBar(LatestBarResponse bar) {
    final out = <SignalBubble>[];
    if (bar.brightBuy || bar.darkBuy) {
      out.add(SignalBubble(
        type:     bar.brightBuy ? BubbleType.filteredLong : BubbleType.darkLong,
        barIndex: bar.barIndex,
        close:    bar.close,
        high:     bar.close, // LatestBarResponse tidak expose high/low
        low:      bar.close,
      ));
    }
    if (bar.brightSell || bar.darkSell) {
      out.add(SignalBubble(
        type:     bar.brightSell ? BubbleType.filteredShort : BubbleType.darkShort,
        barIndex: bar.barIndex,
        close:    bar.close,
        high:     bar.close,
        low:      bar.close,
      ));
    }
    return out;
  }

  // ── Internal helpers ─────────────────────────────
  static SignalBubble _makeSop(BubbleType type, SignalBar bar) => SignalBubble(
    type:         type,
    barIndex:     bar.barIndex,
    close:        bar.close,
    high:         bar.high,
    low:          bar.low,
    trailingStop: bar.trailingStop,
    shortKalman:  bar.shortKalman,
    longKalman:   bar.longKalman,
    trendUp:      bar.trendUp,
    midBands:     bar.midBands,
  );

  static SignalBubble _makeSopBright(BrightSignalBar bar) => SignalBubble(
    type:         bar.isLong ? BubbleType.filteredLong : BubbleType.filteredShort,
    barIndex:     bar.barIndex,
    close:        bar.close,
    high:         bar.high,
    low:          bar.low,
    trailingStop: bar.trailingStop,
    shortKalman:  bar.shortKalman,
    longKalman:   bar.longKalman,
    trendUp: (bar.shortKalman ?? 0) > (bar.longKalman ?? 0),
    midBands:     bar.midBands,
  );
}

// ══════════════════════════════════════════════════
// §4  LABEL SIGNAL FACTORY
//     Dari bubble_sizer — untuk Kalman/pivot/arrow/retest
//     Tidak butuh hook data, ukuran fixed dari PineScript
// ══════════════════════════════════════════════════

class LabelSignalFactory {
  const LabelSignalFactory();

  /// Kalman UP — PineScript: label size=size.normal
  SignalBubble kalmanUp({required int barIndex, required double price}) =>
      SignalBubble(
        type:       BubbleType.kalmanUp,
        barIndex:   barIndex,
        close:      price,
        high:       price,
        low:        price,
        customText: '🡹\n${price.toStringAsFixed(1)}',
      );

  /// Kalman DOWN — PineScript: label size=size.normal
  SignalBubble kalmanDown({required int barIndex, required double price}) =>
      SignalBubble(
        type:       BubbleType.kalmanDown,
        barIndex:   barIndex,
        close:      price,
        high:       price,
        low:        price,
        customText: '${price.toStringAsFixed(1)}\n🢃',
      );

  /// Pivot low — PineScript: plotchar size=size.tiny location=belowbar
  SignalBubble? pivotLow({
    required bool   condition,
    required int    barIndex,
    required double high,
    required double low,
  }) {
    if (!condition) return null;
    return SignalBubble(
      type: BubbleType.pivotLow, barIndex: barIndex,
      close: low, high: high, low: low,
    );
  }

  /// Pivot high — PineScript: plotchar size=size.tiny location=abovebar
  SignalBubble? pivotHigh({
    required bool   condition,
    required int    barIndex,
    required double high,
    required double low,
  }) {
    if (!condition) return null;
    return SignalBubble(
      type: BubbleType.pivotHigh, barIndex: barIndex,
      close: high, high: high, low: low,
    );
  }

  /// Arrow direction — PineScript: label size=size.huge
  SignalBubble arrowDir({
    required int    barIndex,
    required double hl2,
    required double y2Fut,
    required double high,
    required double low,
  }) =>
      SignalBubble(
        type:       BubbleType.arrowDir,
        barIndex:   barIndex,
        close:      hl2,
        high:       high,
        low:        low,
        customText: hl2 > y2Fut ? '⇗' : hl2 < y2Fut ? '⇘' : '⇒',
      );

  /// Retest buy (+) — PineScript: label size=size.normal location=belowbar
  SignalBubble retestBuy({required int barIndex, required double high, required double low}) =>
      SignalBubble(
        type: BubbleType.retestPlus, barIndex: barIndex,
        close: low, high: high, low: low,
      );

  /// Retest sell (x) — PineScript: label size=size.normal location=abovebar
  SignalBubble retestSell({required int barIndex, required double high, required double low}) =>
      SignalBubble(
        type: BubbleType.retestX, barIndex: barIndex,
        close: high, high: high, low: low,
      );
}

// ══════════════════════════════════════════════════
// §5  BUBBLE FILTER WIDGET
// ══════════════════════════════════════════════════

class BubbleFilterWidget extends StatefulWidget {
  final Size   chartSize;
  final double minPrice;
  final double maxPrice;
  final int    totalCandles;
  final double scale;
  final double offset;
  final List<SignalBubble> signals;

  // Visibility toggles — sesuai plotshape visibility PineScript
  final bool showFilteredLong;
  final bool showFilteredShort;
  final bool showDarkLong;
  final bool showDarkShort;

  final void Function(SignalBubble)? onBubbleTap;

  const BubbleFilterWidget({
    Key? key,
    required this.chartSize,
    required this.minPrice,
    required this.maxPrice,
    required this.totalCandles,
    this.scale             = 1.0,
    this.offset            = 0.0,
    this.signals           = const [],
    this.showFilteredLong  = true,
    this.showFilteredShort = true,
    this.showDarkLong      = true,
    this.showDarkShort     = true,
    this.onBubbleTap,
  }) : super(key: key);

  @override
  State<BubbleFilterWidget> createState() => BubbleFilterWidgetState();
}

class BubbleFilterWidgetState extends State<BubbleFilterWidget>
    with TickerProviderStateMixin {

  final List<SignalBubble> _signals = [];
  bool _showFilteredLong  = true;
  bool _showFilteredShort = true;
  bool _showDarkLong      = true;
  bool _showDarkShort     = true;

  SignalBubble? _tapped;
  AnimationController? _pulseCtrl;
  AnimationController? _popCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _popAnim;

  @override
  void initState() {
    super.initState();
    _signals.addAll(widget.signals);
    _showFilteredLong  = widget.showFilteredLong;
    _showFilteredShort = widget.showFilteredShort;
    _showDarkLong      = widget.showDarkLong;
    _showDarkShort     = widget.showDarkShort;

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut);
    _popAnim   = CurvedAnimation(parent: _popCtrl!,   curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    _popCtrl?.dispose();
    super.dispose();
  }

  // ── Public API ────────────────────────────────────────────────────────

  void addSignal(SignalBubble s)           => setState(() => _signals.add(s));
  void addSignals(List<SignalBubble> list) => setState(() => _signals.addAll(list));
  void clearSignals()                      => setState(() { _signals.clear(); _tapped = null; });

  void setVisibility({bool? filteredLong, bool? filteredShort, bool? darkLong, bool? darkShort}) {
    setState(() {
      if (filteredLong  != null) _showFilteredLong  = filteredLong;
      if (filteredShort != null) _showFilteredShort = filteredShort;
      if (darkLong      != null) _showDarkLong      = darkLong;
      if (darkShort     != null) _showDarkShort     = darkShort;
    });
  }

  // Stats
  int get filteredLongs  => _signals.where((s) => s.type == BubbleType.filteredLong).length;
  int get filteredShorts => _signals.where((s) => s.type == BubbleType.filteredShort).length;
  int get darkLongs      => _signals.where((s) => s.type == BubbleType.darkLong).length;
  int get darkShorts     => _signals.where((s) => s.type == BubbleType.darkShort).length;

  // ── Visibility filter ─────────────────────────────────────────────────
  // Non-SOP types (kalman/pivot/arrow/retest) selalu visible

  bool _visible(SignalBubble s) {
    switch (s.type) {
      case BubbleType.filteredLong:  return _showFilteredLong;
      case BubbleType.filteredShort: return _showFilteredShort;
      case BubbleType.darkLong:      return _showDarkLong;
      case BubbleType.darkShort:     return _showDarkShort;
      default:                       return true;
    }
  }

  // ── Coordinate helpers (satu tempat, tidak duplikat ke painter) ───────

  double get _cw => widget.chartSize.width / (widget.totalCandles / widget.scale);
  double _xOf(int bar)      => (bar - widget.offset) * _cw;
  double _yOf(double price) {
    final range = widget.maxPrice - widget.minPrice;
    if (range == 0) return widget.chartSize.height / 2;
    return widget.chartSize.height * (1 - (price - widget.minPrice) / range);
  }
  double _anchorY(SignalBubble s) =>
      s.type.isBelowBar ? _yOf(s.low) : _yOf(s.high);

  // ── Hit test ──────────────────────────────────────────────────────────

  SignalBubble? _hitTest(Offset pos) {
    for (final s in _signals.reversed) {
      if (!_visible(s)) continue;
      final x  = _xOf(s.barIndex);
      final cy = s.type.isBelowBar
          ? _anchorY(s) + 8 + s.pillH / 2
          : _anchorY(s) - 8 - s.pillH / 2;
      if ((pos.dx - x).abs() < s.pillW / 2 + 6 &&
          (pos.dy - cy).abs() < s.pillH / 2 + 6) return s;
    }
    return null;
  }

  void _handleTap(Offset pos) {
    final hit = _hitTest(pos);
    setState(() => _tapped = hit);
    if (hit != null) {
      _popCtrl?.forward(from: 0);
      widget.onBubbleTap?.call(hit);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _popAnim]),
      builder: (ctx, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) => _handleTap(d.localPosition),
        child: CustomPaint(
          painter: _BubbleFilterPainter(
            signals:      _signals.where(_visible).toList(),
            tapped:       _tapped,
            chartSize:    widget.chartSize,
            minPrice:     widget.minPrice,
            maxPrice:     widget.maxPrice,
            totalCandles: widget.totalCandles,
            scale:        widget.scale,
            offset:       widget.offset,
            pulseValue:   _pulseAnim.value,
            popValue:     _popAnim.value,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// §6  PAINTER
//     Satu painter untuk semua jenis bubble
//     (SOP + kalman/pivot/arrow/retest)
// ══════════════════════════════════════════════════

class _BubbleFilterPainter extends CustomPainter {
  final List<SignalBubble> signals;
  final SignalBubble?      tapped;
  final Size               chartSize;
  final double             minPrice;
  final double             maxPrice;
  final int                totalCandles;
  final double             scale;
  final double             offset;
  final double             pulseValue;
  final double             popValue;

  _BubbleFilterPainter({
    required this.signals,
    required this.tapped,
    required this.chartSize,
    required this.minPrice,
    required this.maxPrice,
    required this.totalCandles,
    required this.scale,
    required this.offset,
    required this.pulseValue,
    required this.popValue,
  });

  static const _tooltipBg = Color(0xFF0D1B2A);

  double get _cw => chartSize.width / (totalCandles / scale);
  double _xOf(int bar)      => (bar - offset) * _cw;
  double _yOf(double price) {
    final range = maxPrice - minPrice;
    if (range == 0) return chartSize.height / 2;
    return chartSize.height * (1 - (price - minPrice) / range);
  }
  double _anchorY(SignalBubble s) =>
      s.type.isBelowBar ? _yOf(s.low) : _yOf(s.high);

  @override
  void paint(Canvas canvas, Size size) {
    // Urutan render: dark dulu → filtered di atas (sama dengan PineScript)
    // Label fixed-size (kalman/pivot/arrow/retest) paling atas
    final dark    = signals.where((s) => s.type.isSopSignal && !s.isFiltered).toList();
    final bright  = signals.where((s) => s.type.isSopSignal &&  s.isFiltered).toList();
    final labels  = signals.where((s) => !s.type.isSopSignal).toList();
    for (final s in dark)   _paintBubble(canvas, s);
    for (final s in bright) _paintBubble(canvas, s);
    for (final s in labels) _paintBubble(canvas, s);
    if (tapped != null) _paintTooltip(canvas, tapped!);
  }

  void _paintBubble(Canvas canvas, SignalBubble s) {
    final x          = _xOf(s.barIndex);
    final ancY       = _anchorY(s);
    final isFiltered = s.isFiltered;
    final isTapped   = tapped == s;
    const gap        = 8.0;

    final cy = s.type.isBelowBar
        ? ancY + gap + s.pillH / 2
        : ancY - gap - s.pillH / 2;

    final sc = isTapped ? (0.9 + 0.15 * popValue) : 1.0;

    // Pulse glow — filtered SOP only
    if (isFiltered) {
      final alpha = 0.18 * (0.6 + 0.4 * pulseValue);
      canvas.drawCircle(
        Offset(x, cy),
        s.pillW / 2 + 6 + pulseValue * 5,
        Paint()
          ..color      = s.type.borderColor.withOpacity(alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + pulseValue * 4),
      );
    }

    canvas.save();
    canvas.translate(x, cy);
    canvas.scale(sc, sc);
    canvas.translate(-x, -cy);

    final rRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, cy), width: s.pillW, height: s.pillH),
      Radius.circular(s.pillH / 2.5),
    );

    // Shadow — filtered only
    if (isFiltered) {
      canvas.drawRRect(rRect,
          Paint()
            ..color      = s.type.borderColor.withOpacity(0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    // Background
    canvas.drawRRect(rRect,
        Paint()..color = s.type.bgColor.withOpacity(s.opacity));

    // Border
    canvas.drawRRect(rRect,
        Paint()
          ..color      = s.type.borderColor
          ..strokeWidth = s.borderWidth
          ..style       = PaintingStyle.stroke);

    // Text
    final tp = TextPainter(
      text: TextSpan(
        text: s.displayText,
        style: TextStyle(
          color:      s.type.arrowColor.withOpacity(s.opacity),
          fontSize:   s.fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, cy - tp.height / 2));

    // "SOP" tag — filtered SOP only
    if (isFiltered && s.type.isSopSignal) {
      final tag = TextPainter(
        text: TextSpan(
          text: 'SOP',
          style: TextStyle(
            color:         s.type.arrowColor.withOpacity(0.85),
            fontSize:      7.5,
            fontWeight:    FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final tagY = s.type.isBelowBar
          ? cy - s.pillH / 2 - tag.height - 2
          : cy + s.pillH / 2 + 2;
      tag.paint(canvas, Offset(x - tag.width / 2, tagY));
    }

    _paintPointer(canvas, x, cy, s.pillH, s.type.isBelowBar,
        s.type.borderColor, s.type.bgColor.withOpacity(s.opacity), isFiltered);

    canvas.restore();
  }

  void _paintPointer(Canvas canvas, double x, double cy, double h,
      bool isUp, Color border, Color bg, bool isFiltered) {
    const pw = 7.0;
    const ph = 6.0;
    final path = Path();
    if (isUp) {
      final tipY = cy - h / 2;
      path.moveTo(x, tipY - ph);
      path.lineTo(x - pw, tipY);
      path.lineTo(x + pw, tipY);
    } else {
      final tipY = cy + h / 2;
      path.moveTo(x, tipY + ph);
      path.lineTo(x - pw, tipY);
      path.lineTo(x + pw, tipY);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = bg);
    canvas.drawPath(path,
        Paint()
          ..color      = border
          ..strokeWidth = isFiltered ? 1.4 : 0.8
          ..style       = PaintingStyle.stroke
          ..strokeJoin  = StrokeJoin.round);
  }

  void _paintTooltip(Canvas canvas, SignalBubble s) {
    final x     = _xOf(s.barIndex);
    final ancY  = _anchorY(s);
    final bubCy = s.type.isBelowBar
        ? ancY + 8 + s.pillH / 2
        : ancY - 8 - s.pillH / 2;

    double tx = x + 14;
    const tw  = 200.0;
    if (tx + tw > chartSize.width) tx = x - tw - 14;

    final rows = <Map<String, dynamic>>[
      {'k': 'Signal',   'v': s.type.label,  'c': s.type.arrowColor},
      {'k': 'Size',     'v': s.pineSize.label, 'c': const Color(0xFF00C8FF)},
      {'k': 'Filter',   'v': s.isFiltered ? 'LOLOS ✓' : 'GAGAL ✗',
       'c': s.isFiltered ? const Color(0xFF00E5A0) : const Color(0xFF888888)},
      {'k': 'Close',    'v': s.close.toStringAsFixed(2), 'c': Colors.white},
      if (s.trailingStop != null)
        {'k': 'ATR Stop', 'v': s.trailingStop!.toStringAsFixed(2), 'c': const Color(0xFFFFD700)},
      if (s.midBands != null)
        {'k': 'Mid Band', 'v': s.midBands!.toStringAsFixed(2),     'c': const Color(0xFF9D9D9D)},
      if (s.shortKalman != null)
        {'k': 'K.Short',  'v': s.shortKalman!.toStringAsFixed(2),  'c': const Color(0xFF00BCD4)},
      if (s.longKalman != null)
        {'k': 'K.Long',   'v': s.longKalman!.toStringAsFixed(2),   'c': const Color(0xFFB2EBF2)},
      if (s.trendUp != null)
        {'k': 'Trend',    'v': s.trendUp! ? 'BULLISH ▲' : 'BEARISH ▼',
         'c': s.trendUp! ? const Color(0xFF00E5A0) : const Color(0xFFFF6B35)},
    ];

    const rowH   = 19.0;
    const padX   = 12.0;
    const padY   = 8.0;
    final totalH = rows.length * rowH + padY * 2 + rowH + 4;

    double ty = (s.type.isBelowBar ? ancY + 38 : ancY - totalH - 8)
        .clamp(8, chartSize.height - totalH - 8);

    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty, tw, totalH), const Radius.circular(8));

    canvas.drawRRect(rect,
        Paint()
          ..color      = Colors.black.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(rect, Paint()..color = _tooltipBg.withOpacity(0.96));
    canvas.drawRRect(rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.outerRect.topLeft, rect.outerRect.bottomRight,
            [s.type.borderColor.withOpacity(0.8), s.type.arrowColor.withOpacity(0.3)])
          ..strokeWidth = 1.5
          ..style       = PaintingStyle.stroke);

    var drawY = ty + padY;

    _txt(canvas, '${s.type.defaultText}  ${s.type.label}',
        Offset(tx + padX, drawY),
        color: s.type.arrowColor, size: 11.5, bold: true);
    drawY += rowH + 2;

    canvas.drawLine(Offset(tx + padX, drawY - 2), Offset(tx + tw - padX, drawY - 2),
        Paint()..color = Colors.white.withOpacity(0.07)..strokeWidth = 0.8);

    for (final row in rows) {
      _txt(canvas, '${row['k']}',
          Offset(tx + padX, drawY + (rowH - 9) / 2),
          color: Colors.white.withOpacity(0.38), size: 9);
      _txt(canvas, '${row['v']}',
          Offset(tx + tw - padX, drawY + (rowH - 10) / 2),
          color: row['c'] as Color, size: 10, bold: true, right: true);
      drawY += rowH;
    }

    final path = Path()
      ..moveTo(x, bubCy)
      ..quadraticBezierTo((x + tx) / 2, bubCy, tx, ty + totalH / 2);
    canvas.drawPath(path,
        Paint()
          ..color      = s.type.borderColor.withOpacity(0.35)
          ..strokeWidth = 1.0
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round);
  }

  void _txt(Canvas canvas, String text, Offset pos, {
    required Color  color,
    required double size,
    bool bold  = false,
    bool right = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text,
          style: TextStyle(color: color, fontSize: size,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, right ? Offset(pos.dx - tp.width, pos.dy) : pos);
  }

  @override
  bool shouldRepaint(_BubbleFilterPainter old) =>
      old.signals.length != signals.length ||
      old.tapped         != tapped         ||
      old.pulseValue     != pulseValue      ||
      old.popValue       != popValue;
}

// ══════════════════════════════════════════════════
// §7  LEGEND / FILTER TOGGLE BAR
// ══════════════════════════════════════════════════

class BubbleFilterLegend extends StatelessWidget {
  final bool showFilteredLong;
  final bool showFilteredShort;
  final bool showDarkLong;
  final bool showDarkShort;
  final void Function(BubbleType, bool) onToggle;

  const BubbleFilterLegend({
    Key? key,
    required this.showFilteredLong,
    required this.showFilteredShort,
    required this.showDarkLong,
    required this.showDarkShort,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        const Color(0xFF0A1520).withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip('🡹 SOP Long',  const Color(0xFFC7F7FF), const Color(0xFF0085FA), showFilteredLong,
              () => onToggle(BubbleType.filteredLong,  !showFilteredLong)),
          const SizedBox(width: 8),
          _Chip('🢃 SOP Short', const Color(0xFFFFC9C9), const Color(0xFFFF0000), showFilteredShort,
              () => onToggle(BubbleType.filteredShort, !showFilteredShort)),
          const SizedBox(width: 8),
          _Chip('🡹 Filtered',  const Color(0xFF004E58).withOpacity(0.25),
              const Color(0xFF0085FA).withOpacity(0.55), showDarkLong,
              () => onToggle(BubbleType.darkLong, !showDarkLong)),
          const SizedBox(width: 8),
          _Chip('🢃 Filtered',  const Color(0xFF5C0707).withOpacity(0.25),
              const Color(0xFFFF0000).withOpacity(0.55), showDarkShort,
              () => onToggle(BubbleType.darkShort, !showDarkShort)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String       label;
  final Color        bg;
  final Color        textCol;
  final bool         active;
  final VoidCallback onTap;

  const _Chip(this.label, this.bg, this.textCol, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      opacity:  active ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: textCol.withOpacity(active ? 0.7 : 0.3),
            width: active ? 1.3 : 0.8,
          ),
        ),
        child: Text(label,
            style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.w800)),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// §8  SIGNAL COUNTER BADGE
// ══════════════════════════════════════════════════

class SignalCounterBadge extends StatelessWidget {
  final int filteredLongs;
  final int filteredShorts;
  final int darkLongs;
  final int darkShorts;

  const SignalCounterBadge({
    Key? key,
    required this.filteredLongs,
    required this.filteredShorts,
    required this.darkLongs,
    required this.darkShorts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = filteredLongs + filteredShorts + darkLongs + darkShorts;
    final lolos = filteredLongs + filteredShorts;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        const Color(0xFF0A1520).withOpacity(0.93),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('EXXE ALGO  $total signals',
              style: const TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          const SizedBox(height: 6),
          Container(height: 0.6, color: Colors.white.withOpacity(0.07)),
          const SizedBox(height: 6),
          _Row('🡹 SOP Long',  filteredLongs,  const Color(0xFFC7F7FF), const Color(0xFF0085FA)),
          _Row('🢃 SOP Short', filteredShorts, const Color(0xFFFFC9C9), const Color(0xFFFF0000)),
          _Row('🡹 Filtered',  darkLongs,      const Color(0xFF004E58).withOpacity(0.3), const Color(0xFF0085FA).withOpacity(0.55)),
          _Row('🢃 Filtered',  darkShorts,     const Color(0xFF5C0707).withOpacity(0.3), const Color(0xFFFF0000).withOpacity(0.55)),
          const SizedBox(height: 6),
          Container(height: 0.6, color: Colors.white.withOpacity(0.07)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lolos Filter',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
              Text(
                total == 0 ? '-' : '${((lolos / total) * 100).toStringAsFixed(0)}%  ($lolos/$total)',
                style: const TextStyle(color: Color(0xFF00E5A0),
                    fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int    count;
  final Color  bg;
  final Color  textCol;

  const _Row(this.label, this.count, this.bg, this.textCol);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
            child: Center(child: Text(
              label.contains('🡹') ? '🡹' : '🢃',
              style: TextStyle(color: textCol, fontSize: 8, fontWeight: FontWeight.w900),
            )),
          ),
          const SizedBox(width: 6),
          Text(label.replaceAll('🡹 ', '').replaceAll('🢃 ', ''),
              style: TextStyle(color: Colors.white.withOpacity(0.55),
                  fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
        Text('$count', style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// §9  CONTOH PEMAKAIAN
// ══════════════════════════════════════════════════

/*
  final hook      = BaseSignalHook();
  final labels    = LabelSignalFactory();
  final bubbleKey = GlobalKey<BubbleFilterWidgetState>();

  // Stack di chart:
  BubbleFilterWidget(key: bubbleKey, chartSize: size,
    minPrice: _min, maxPrice: _max, totalCandles: _total,
    scale: _scale, offset: _offset)

  // ── Full run → semua bar sinyal ──────────────────
  final result = await hook.run(OHLCRequest(close:[...], high:[...], low:[...]));
  bubbleKey.currentState?.addSignals(SignalBubble.fromSignalBars(result.signalBars));

  // ── Bright only → trade setup ────────────────────
  final brights = await hook.runBright(ohlcReq);
  bubbleKey.currentState?.addSignals(SignalBubble.fromBrightBars(brights));

  // ── Live polling → latest bar ────────────────────
  final latest = await hook.runLatest(ohlcReq);
  bubbleKey.currentState?.addSignals(SignalBubble.fromLatestBar(latest));

  // ── Label fixed-size (tidak butuh hook) ──────────
  bubbleKey.currentState?.addSignal(
    labels.kalmanUp(barIndex: barIndex, price: shortKalman));
  bubbleKey.currentState?.addSignal(
    labels.arrowDir(barIndex: barIndex, hl2: hl2, y2Fut: y2Fut, high: high, low: low));

  // ── Toggle visibility ────────────────────────────
  bubbleKey.currentState?.setVisibility(darkLong: false, darkShort: false);
*/