// =============================================================================
// line_number_gutter.dart
// Path: frontend/lib/trading_screen/tradingview/line_number_gutter.dart
//
// Standalone line number gutter widget — berdiri sendiri, tidak coupling
// ke code editor widget manapun. Cukup pass lineCount + activeLineIndex.
//
// Features:
//   • Active line highlight
//   • Breakpoint dot (tap untuk toggle)
//   • Folding arrow (opsional, untuk collapsible block)
//   • Smooth scroll sync via ScrollController
//   • Animasi active line transition
//   • Theming penuh dari EditorThemeState
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../style/apps_colors_tradingview.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL: BreakpointState
//  Track baris mana aja yang ada breakpoint-nya
// ─────────────────────────────────────────────────────────────────────────────

class BreakpointState extends ChangeNotifier {
  final Set<int> _breakpoints = {};

  Set<int> get all => Set.unmodifiable(_breakpoints);

  bool has(int line) => _breakpoints.contains(line);

  void toggle(int line) {
    if (_breakpoints.contains(line)) {
      _breakpoints.remove(line);
    } else {
      _breakpoints.add(line);
    }
    notifyListeners();
  }

  void clear() {
    _breakpoints.clear();
    notifyListeners();
  }

  void remove(int line) {
    _breakpoints.remove(line);
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL: FoldRange
//  Range baris yang bisa di-fold (collapsible block)
// ─────────────────────────────────────────────────────────────────────────────

class FoldRange {
  final int  startLine; // 0-based, baris pertama block (def, class, if, dll)
  final int  endLine;   // 0-based, baris terakhir block
  bool       isFolded;

  FoldRange({
    required this.startLine,
    required this.endLine,
    this.isFolded = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: LineNumberGutter
//  Core widget — berdiri sendiri, sync scroll via controller
// ─────────────────────────────────────────────────────────────────────────────

class LineNumberGutter extends StatefulWidget {
  const LineNumberGutter({
    super.key,
    required this.lineCount,
    required this.lineHeight,
    required this.fontSize,
    required this.scrollController,
    this.theme,
    this.activeLineIndex,
    this.breakpoints,
    this.foldRanges,
    this.onBreakpointToggle,
    this.onFoldToggle,
    this.topPadding   = 12.0,
    this.showBreakpoints = true,
    this.showFoldArrows  = true,
    this.width,
  });

  /// Total baris kode
  final int lineCount;

  /// Tinggi satu baris (harus sama dengan editor) — fontSize * lineHeight
  final double lineHeight;

  /// Font size angka baris
  final double fontSize;

  /// ScrollController yang dishare dengan code editor biar scroll sync
  final ScrollController scrollController;

  /// EditorThemeState — kalau null pakai default TradingView dark
  final EditorThemeState? theme;

  /// Index baris yang aktif (0-based) — untuk highlight
  final int? activeLineIndex;

  /// Breakpoint state — kalau null fitur breakpoint di-disable
  final BreakpointState? breakpoints;

  /// Fold ranges — kalau null fitur fold arrow di-disable
  final List<FoldRange>? foldRanges;

  /// Callback saat breakpoint di-toggle
  final void Function(int lineIndex)? onBreakpointToggle;

  /// Callback saat fold di-toggle
  final void Function(FoldRange range)? onFoldToggle;

  /// Padding atas — harus sama dengan code editor
  final double topPadding;

  /// Toggle visibility fitur
  final bool showBreakpoints;
  final bool showFoldArrows;

  /// Override lebar gutter. Kalau null, auto dari digit count
  final double? width;

  @override
  State<LineNumberGutter> createState() => _LineNumberGutterState();
}

class _LineNumberGutterState extends State<LineNumberGutter> {

  // ── Computed ──────────────────────────────────────────────────────────────

  EditorThemeState get _theme => widget.theme ?? EditorThemeState();

  /// Lebar angka terpanjang + padding + breakpoint dot area + fold arrow area
  double get _gutterWidth {
    if (widget.width != null) return widget.width!;
    final digits = widget.lineCount.toString().length;
    // setiap digit ~8px + base padding 24 + 14 (dot) + 14 (arrow)
    double w = digits * 8.0 + 24.0;
    if (widget.showBreakpoints) w += 14.0;
    if (widget.showFoldArrows)  w += 14.0;
    return w.clamp(44.0, 88.0);
  }

  FoldRange? _foldAt(int lineIndex) {
    if (widget.foldRanges == null) return null;
    for (final r in widget.foldRanges!) {
      if (r.startLine == lineIndex) return r;
    }
    return null;
  }

  bool _isInFoldedRange(int lineIndex) {
    if (widget.foldRanges == null) return false;
    for (final r in widget.foldRanges!) {
      if (r.isFolded && lineIndex > r.startLine && lineIndex <= r.endLine) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final chrome = _theme.chrome;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _gutterWidth,
      decoration: BoxDecoration(
        color: chrome.gutterBackground,
        border: Border(
          right: BorderSide(color: chrome.gutterBorder, width: 1),
        ),
      ),
      child: _buildContent(chrome),
    );
  }

  Widget _buildContent(EditorChromeColors chrome) {
    final breakpoints = widget.breakpoints;

    if (breakpoints != null) {
      return ListenableBuilder(
        listenable: breakpoints,
        builder: (_, __) => _buildList(chrome),
      );
    }
    return _buildList(chrome);
  }

  Widget _buildList(EditorChromeColors chrome) {
    return ListView.builder(
      controller:   widget.scrollController,
      physics:      const NeverScrollableScrollPhysics(), // scroll dikontrol editor
      padding:      EdgeInsets.only(top: widget.topPadding),
      itemCount:    widget.lineCount,
      itemExtent:   widget.lineHeight, // fixed height buat performa
      itemBuilder:  (_, i) => _GutterRow(
        lineIndex:       i,
        lineHeight:      widget.lineHeight,
        fontSize:        widget.fontSize,
        isActive:        i == widget.activeLineIndex,
        hasBreakpoint:   widget.breakpoints?.has(i) ?? false,
        foldRange:       widget.showFoldArrows ? _foldAt(i) : null,
        isInFoldedRange: _isInFoldedRange(i),
        theme:           _theme,
        showBreakpoints: widget.showBreakpoints,
        showFoldArrows:  widget.showFoldArrows,
        onBreakpointToggle: widget.onBreakpointToggle != null
            ? () {
                HapticFeedback.selectionClick();
                widget.breakpoints?.toggle(i);
                widget.onBreakpointToggle!(i);
              }
            : null,
        onFoldToggle: widget.onFoldToggle != null
            ? (range) {
                setState(() => range.isFolded = !range.isFolded);
                widget.onFoldToggle!(range);
              }
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: _GutterRow
//  Satu baris di gutter — angka + breakpoint dot + fold arrow
// ─────────────────────────────────────────────────────────────────────────────

class _GutterRow extends StatelessWidget {
  const _GutterRow({
    required this.lineIndex,
    required this.lineHeight,
    required this.fontSize,
    required this.isActive,
    required this.hasBreakpoint,
    required this.theme,
    required this.showBreakpoints,
    required this.showFoldArrows,
    this.foldRange,
    this.isInFoldedRange = false,
    this.onBreakpointToggle,
    this.onFoldToggle,
  });

  final int             lineIndex;
  final double          lineHeight;
  final double          fontSize;
  final bool            isActive;
  final bool            hasBreakpoint;
  final FoldRange?      foldRange;
  final bool            isInFoldedRange;
  final EditorThemeState theme;
  final bool            showBreakpoints;
  final bool            showFoldArrows;
  final VoidCallback?   onBreakpointToggle;
  final void Function(FoldRange)? onFoldToggle;

  @override
  Widget build(BuildContext context) {
    final chrome = theme.chrome;
    final syntax = theme.syntax;

    // Baris yang di dalam folded range — hide
    if (isInFoldedRange) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height:  lineHeight,
      color:   isActive ? chrome.activeLineHighlight : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── Breakpoint dot ───────────────────────────────────────────────
          if (showBreakpoints)
            _BreakpointDot(
              hasBreakpoint: hasBreakpoint,
              lineHeight:    lineHeight,
              accentColor:   chrome.consoleTextError,
              onTap:         onBreakpointToggle,
            ),

          // ── Line number ──────────────────────────────────────────────────
          Expanded(
            child: _AnimatedLineNumber(
              lineNumber: lineIndex + 1,
              isActive:   isActive,
              fontSize:   fontSize,
              lineHeight: lineHeight,
              fontFamily: theme.typography.fontFamily,
              activeColor:  chrome.lineNumberActive,
              defaultColor: hasBreakpoint
                  ? chrome.consoleTextError.withOpacity(0.9)
                  : chrome.lineNumberDefault,
            ),
          ),

          // ── Fold arrow ───────────────────────────────────────────────────
          if (showFoldArrows)
            _FoldArrow(
              foldRange:   foldRange,
              lineHeight:  lineHeight,
              accentColor: syntax.comment,
              onToggle:    onFoldToggle,
            ),

          // ── Right padding ─────────────────────────────────────────────────
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: _AnimatedLineNumber
//  Angka baris dengan animasi warna saat active berubah
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedLineNumber extends StatelessWidget {
  const _AnimatedLineNumber({
    required this.lineNumber,
    required this.isActive,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.activeColor,
    required this.defaultColor,
  });

  final int    lineNumber;
  final bool   isActive;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final Color  activeColor;
  final Color  defaultColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: isActive ? defaultColor : activeColor,
        end:   isActive ? activeColor  : defaultColor,
      ),
      duration: const Duration(milliseconds: 120),
      builder: (_, color, __) => Text(
        '$lineNumber',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily:  fontFamily,
          fontSize:    fontSize,
          height:      lineHeight / fontSize,
          color:       color ?? defaultColor,
          fontWeight:  isActive ? FontWeight.w600 : FontWeight.w400,
          // tabular numbers biar ga geser-geser
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: _BreakpointDot
//  Dot merah kecil di kiri gutter — tap untuk toggle breakpoint
// ─────────────────────────────────────────────────────────────────────────────

class _BreakpointDot extends StatelessWidget {
  const _BreakpointDot({
    required this.hasBreakpoint,
    required this.lineHeight,
    required this.accentColor,
    this.onTap,
  });

  final bool         hasBreakpoint;
  final double       lineHeight;
  final Color        accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width:  14,
        height: lineHeight,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width:  hasBreakpoint ? 8 : 4,
            height: hasBreakpoint ? 8 : 4,
            decoration: BoxDecoration(
              color: hasBreakpoint
                  ? accentColor
                  : accentColor.withOpacity(0.0),
              shape: BoxShape.circle,
              boxShadow: hasBreakpoint
                  ? [BoxShadow(
                      color:      accentColor.withOpacity(0.5),
                      blurRadius: 6,
                    )]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: _FoldArrow
//  Chevron kecil di kanan gutter — muncul kalau baris adalah start of block
// ─────────────────────────────────────────────────────────────────────────────

class _FoldArrow extends StatelessWidget {
  const _FoldArrow({
    required this.lineHeight,
    required this.accentColor,
    this.foldRange,
    this.onToggle,
  });

  final double                    lineHeight;
  final Color                     accentColor;
  final FoldRange?                foldRange;
  final void Function(FoldRange)? onToggle;

  @override
  Widget build(BuildContext context) {
    // Kalau baris ini bukan start of fold range, return empty space biar alignment tetap
    if (foldRange == null) {
      return SizedBox(width: 14, height: lineHeight);
    }

    return GestureDetector(
      onTap: () {
        if (onToggle != null) onToggle!(foldRange!);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width:  14,
        height: lineHeight,
        child: Center(
          child: AnimatedRotation(
            turns:    foldRange!.isFolded ? -0.25 : 0.0, // 0° = down, -90° = right (folded)
            duration: const Duration(milliseconds: 150),
            curve:    Curves.easeOut,
            child: Icon(
              Icons.expand_more_rounded,
              size:  12,
              color: accentColor.withOpacity(0.55),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: LineNumberGutterSimple
//  Versi sederhana tanpa breakpoint dan fold — drop-in buat read-only views
// ─────────────────────────────────────────────────────────────────────────────

class LineNumberGutterSimple extends StatelessWidget {
  const LineNumberGutterSimple({
    super.key,
    required this.lineCount,
    required this.lineHeight,
    required this.fontSize,
    this.theme,
    this.activeLineIndex,
    this.topPadding = 12.0,
  });

  final int              lineCount;
  final double           lineHeight;
  final double           fontSize;
  final EditorThemeState? theme;
  final int?             activeLineIndex;
  final double           topPadding;

  @override
  Widget build(BuildContext context) {
    final t      = theme ?? EditorThemeState();
    final chrome = t.chrome;
    final digits = lineCount.toString().length;
    final width  = (digits * 8.0 + 28.0).clamp(36.0, 72.0);

    return Container(
      width: width,
      color: chrome.gutterBackground,
      padding: EdgeInsets.only(top: topPadding, left: 6, right: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: chrome.gutterBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(lineCount, (i) {
          final isActive = i == activeLineIndex;
          return Container(
            height: lineHeight,
            color:  isActive ? chrome.activeLineHighlight : Colors.transparent,
            alignment: Alignment.centerRight,
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontFamily:   t.typography.fontFamily,
                fontSize:     fontSize,
                height:       lineHeight / fontSize,
                color:        isActive
                    ? chrome.lineNumberActive
                    : chrome.lineNumberDefault,
                fontWeight:   isActive ? FontWeight.w600 : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: LineNumberGutterOverlay
//  Overlay variant — buat dipakai di atas Stack, bukan di Row.
//  Berguna kalau editor pakai CustomScrollView atau Sliver.
// ─────────────────────────────────────────────────────────────────────────────

class LineNumberGutterOverlay extends StatelessWidget {
  const LineNumberGutterOverlay({
    super.key,
    required this.lineCount,
    required this.lineHeight,
    required this.fontSize,
    required this.scrollController,
    this.theme,
    this.activeLineIndex,
    this.topPadding = 12.0,
    this.left       = 0,
    this.top        = 0,
  });

  final int               lineCount;
  final double            lineHeight;
  final double            fontSize;
  final ScrollController  scrollController;
  final EditorThemeState? theme;
  final int?              activeLineIndex;
  final double            topPadding;
  final double            left;
  final double            top;

  @override
  Widget build(BuildContext context) {
    final t      = theme ?? EditorThemeState();
    final digits = lineCount.toString().length;
    final width  = (digits * 8.0 + 28.0).clamp(36.0, 72.0);

    return Positioned(
      left: left,
      top:  top,
      child: SizedBox(
        width: width,
        child: LineNumberGutter(
          lineCount:        lineCount,
          lineHeight:       lineHeight,
          fontSize:         fontSize,
          scrollController: scrollController,
          theme:            t,
          activeLineIndex:  activeLineIndex,
          topPadding:       topPadding,
          showBreakpoints:  false,
          showFoldArrows:   false,
          width:            width,
        ),
      ),
    );
  }
}