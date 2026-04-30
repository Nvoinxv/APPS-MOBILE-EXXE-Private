// =============================================================================
// code_editor_highlight_layer.dart
//
// Tanggung jawab:
//   - _CodeTextField: Stack TextField (transparan) + highlight overlay
//   - Debounce highlight 80ms untuk smooth typing
//   - _HighlightLayer: panggil PythonSyntaxHighlighter v2 + inject match spans
//   - _FlatSpan helper untuk match injection
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import '../../style/apps_colors_tradingview.dart';
import '../../utils/python_syntax_highlighter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CodeTextField — smooth typing via 80ms debounce pada highlight overlay
// ─────────────────────────────────────────────────────────────────────────────

class CodeTextField extends StatefulWidget {
  const CodeTextField({
    super.key,
    required this.textCtrl,
    required this.focusNode,
    required this.isReadOnly,
    required this.theme,
    required this.chrome,
    required this.typo,
    required this.fontSize,
    required this.lineHeight,
    required this.matches,
    required this.currentMatch,
  });

  final TextEditingController textCtrl;
  final FocusNode             focusNode;
  final bool                  isReadOnly;
  final EditorThemeState      theme;
  final EditorChromeColors    chrome;
  final EditorTypography      typo;
  final double                fontSize;
  final double                lineHeight;
  final List<TextRange>       matches;
  final int                   currentMatch;

  @override
  State<CodeTextField> createState() => _CodeTextFieldState();
}

class _CodeTextFieldState extends State<CodeTextField> {
  String _displaySource = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _displaySource = widget.textCtrl.text;
    widget.textCtrl.addListener(_scheduleHighlight);
  }

  @override
  void didUpdateWidget(CodeTextField old) {
    super.didUpdateWidget(old);
    if (old.textCtrl != widget.textCtrl) {
      old.textCtrl.removeListener(_scheduleHighlight);
      widget.textCtrl.addListener(_scheduleHighlight);
      _displaySource = widget.textCtrl.text;
    }
    // Match/theme/font berubah → langsung update tanpa debounce
    if (old.matches  != widget.matches  ||
        old.theme    != widget.theme    ||
        old.fontSize != widget.fontSize) {
      _applyHighlight();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.textCtrl.removeListener(_scheduleHighlight);
    super.dispose();
  }

  void _scheduleHighlight() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), _applyHighlight);
  }

  void _applyHighlight() {
    if (!mounted) return;
    setState(() => _displaySource = widget.textCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: TextField transparan — cursor + selection selalu 60fps
        TextField(
          controller:        widget.textCtrl,
          focusNode:         widget.focusNode,
          readOnly:          widget.isReadOnly,
          maxLines:          null,
          expands:           false,
          keyboardType:      TextInputType.multiline,
          textInputAction:   TextInputAction.newline,
          autocorrect:       false,
          enableSuggestions: false,
          smartDashesType:   SmartDashesType.disabled,
          smartQuotesType:   SmartQuotesType.disabled,
          // ── Kunci VSCode-feel: biarkan Flutter handle semua selection/cursor ──
          // Jangan override dengan custom scroll — TextField sudah handle
          // Ctrl+arrow, Shift+arrow, Home, End secara native
          style: TextStyle(
            fontFamily:    widget.typo.fontFamily,
            fontSize:      widget.fontSize,
            height:        widget.typo.lineHeight,
            letterSpacing: widget.typo.letterSpacing,
            color:         Colors.transparent, // teks asli transparan
          ),
          cursorColor:  widget.chrome.cursorColor,
          cursorWidth:  2.0,
          cursorHeight: widget.fontSize,
          // Gunakan default selectionControls supaya Shift+arrow bekerja native
          decoration: const InputDecoration(
            border:         InputBorder.none,
            isDense:        true,
            contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            fillColor:      Colors.transparent,
            filled:         true,
          ),
        ),

        // Layer 2: Highlight overlay — debounced, tidak blocking input
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: RepaintBoundary(
              child: HighlightLayer(
                source:       _displaySource,
                theme:        widget.theme,
                fontSize:     widget.fontSize,
                lineHeight:   widget.lineHeight,
                matches:      widget.matches,
                currentMatch: widget.currentMatch,
                chrome:       widget.chrome,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HighlightLayer
// ─────────────────────────────────────────────────────────────────────────────

class HighlightLayer extends StatelessWidget {
  const HighlightLayer({
    super.key,
    required this.source,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.matches,
    required this.currentMatch,
    required this.chrome,
  });

  final String             source;
  final EditorThemeState   theme;
  final double             fontSize;
  final double             lineHeight;
  final List<TextRange>    matches;
  final int                currentMatch;
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) {
    final baseStyle = theme.typography.baseStyle.copyWith(
      fontSize: fontSize,
      height:   lineHeight / fontSize,
    );

    var highlighted = PythonSyntaxHighlighter.buildTextSpan(source, theme: theme);

    if (matches.isNotEmpty) {
      highlighted = _injectMatchHighlights(highlighted);
    }

    return Text.rich(
      highlighted,
      style:    baseStyle,
      softWrap: false,
      overflow: TextOverflow.visible,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }

  TextSpan _injectMatchHighlights(TextSpan original) {
    final spans     = <TextSpan>[];
    final flatSpans = <_FlatSpan>[];
    _flatten(original, flatSpans);

    for (final flat in flatSpans) {
      bool hasMatch = false;

      for (int mi = 0; mi < matches.length; mi++) {
        final m = matches[mi];
        if (m.end <= flat.start || m.start >= flat.end) continue;
        hasMatch = true;

        if (flat.start < m.start) {
          spans.add(TextSpan(
            text:  source.substring(flat.start, m.start.clamp(flat.start, flat.end)),
            style: flat.style,
          ));
        }

        final mS = m.start.clamp(flat.start, flat.end);
        final mE = m.end.clamp(flat.start, flat.end);

        spans.add(TextSpan(
          text:  source.substring(mS, mE),
          style: (flat.style ?? const TextStyle()).copyWith(
            backgroundColor: mi == currentMatch
                ? chrome.cursorColor.withOpacity(0.35)
                : chrome.matchHighlight,
          ),
        ));

        if (m.end < flat.end) {
          spans.add(TextSpan(
            text:  source.substring(m.end.clamp(flat.start, flat.end), flat.end),
            style: flat.style,
          ));
        }
        break;
      }

      if (!hasMatch) spans.add(TextSpan(text: flat.text, style: flat.style));
    }

    return TextSpan(children: spans);
  }

  int _flatten(InlineSpan span, List<_FlatSpan> out, [int offset = 0]) {
    if (span is TextSpan) {
      final txt = span.text ?? '';
      if (txt.isNotEmpty) {
        out.add(_FlatSpan(text: txt, style: span.style, start: offset, end: offset + txt.length));
        offset += txt.length;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        offset = _flatten(child, out, offset);
      }
    }
    return offset;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FlatSpan — helper untuk flatten TextSpan tree
// ─────────────────────────────────────────────────────────────────────────────

class _FlatSpan {
  const _FlatSpan({
    required this.text,
    required this.style,
    required this.start,
    required this.end,
  });
  final String     text;
  final TextStyle? style;
  final int        start;
  final int        end;
}