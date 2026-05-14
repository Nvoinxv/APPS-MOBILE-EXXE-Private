// =============================================================================
// line_number_gutter.dart
// Path: frontend/lib/trading_screen/tradingview/line_number_gutter.dart
//
// FIX v_dispose_safe:
//  - [FIXED] _LineNumberGutterState: tambah override dispose() yang proper
//  - [FIXED] onFoldToggle closure di _buildList: setState dipanggil lewat
//            closure yang bisa ter-trigger setelah widget di-unmount
//            (misal: parent rebuild cepat saat fold di-tap). Fix dengan
//            cek `if (mounted)` sebelum setState di dalam closure.
//  - Semua logic, UI, dan widget lain tidak diubah sama sekali
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../style/apps_colors_tradingview.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL: BreakpointState
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
// ─────────────────────────────────────────────────────────────────────────────

class FoldRange {
  final int  startLine;
  final int  endLine;
  bool       isFolded;

  FoldRange({
    required this.startLine,
    required this.endLine,
    this.isFolded = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: LineNumberGutter
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

  final int              lineCount;
  final double           lineHeight;
  final double           fontSize;
  final ScrollController scrollController;
  final EditorThemeState? theme;
  final int?             activeLineIndex;
  final BreakpointState? breakpoints;
  final List<FoldRange>? foldRanges;
  final void Function(int lineIndex)? onBreakpointToggle;
  final void Function(FoldRange range)? onFoldToggle;
  final double           topPadding;
  final bool             showBreakpoints;
  final bool             showFoldArrows;
  final double?          width;

  @override
  State<LineNumberGutter> createState() => _LineNumberGutterState();
}

class _LineNumberGutterState extends State<LineNumberGutter> {

  EditorThemeState get _theme => widget.theme ?? EditorThemeState();

  double get _gutterWidth {
    if (widget.width != null) return widget.width!;
    final digits = widget.lineCount.toString().length;
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

  // [FIXED] dispose override yang proper
  // Meskipun State ini tidak punya resource yang di-own sendiri
  // (scrollController adalah external, breakpoints adalah external),
  // override ini penting sebagai safety net dan dokumentasi intent.
  // Juga memastikan super.dispose() dipanggil dengan benar.
  @override
  void dispose() {
    super.dispose();
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
      controller:  widget.scrollController,
      physics:     const NeverScrollableScrollPhysics(),
      padding:     EdgeInsets.only(top: widget.topPadding),
      itemCount:   widget.lineCount,
      itemExtent:  widget.lineHeight,
      itemBuilder: (_, i) => _GutterRow(
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
        // [FIXED] setState di closure ini bisa dipanggil setelah widget
        // di-unmount kalau parent rebuild sangat cepat saat fold di-tap.
        // Guard dengan `if (mounted)` sebelum setState.
        onFoldToggle: widget.onFoldToggle != null
            ? (range) {
                if (!mounted) return;
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

    if (isInFoldedRange) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height:  lineHeight,
      color:   isActive ? chrome.activeLineHighlight : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          if (showBreakpoints)
            _BreakpointDot(
              hasBreakpoint: hasBreakpoint,
              lineHeight:    lineHeight,
              accentColor:   chrome.consoleTextError,
              onTap:         onBreakpointToggle,
            ),

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

          if (showFoldArrows)
            _FoldArrow(
              foldRange:   foldRange,
              lineHeight:  lineHeight,
              accentColor: syntax.comment,
              onToggle:    onFoldToggle,
            ),

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: _AnimatedLineNumber
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
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: _BreakpointDot
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
            turns:    foldRange!.isFolded ? -0.25 : 0.0,
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