// =============================================================================
// code_editor_highlight_layer.dart
//
// Tanggung jawab:
//   - CodeTextField: Stack TextField (transparan) + highlight overlay
//   - Debounce highlight 80ms untuk smooth typing
//   - HighlightLayer: panggil PythonSyntaxHighlighter v2 + inject match spans
//   - _FlatSpan helper untuk match injection
//
// FIX v_cursor_align:
//  - [ROOT CAUSE] Cursor `|` muncul di ATAS teks, bukan sejajar.
//    Penyebab: TextStyle(height: lineHeightFactor) di TextField menggeser
//    caret position yang dihitung Flutter ke atas. Flutter mendistribusikan
//    extra line height sebagai "leading" di atas ascent — cursor top ikut
//    dihitung dari sana, bukan dari font baseline natural.
//    Akibatnya: teks berada di baseline yang benar, tapi cursor muncul
//    ~(lineHeightFactor - 1) * fontSize / 2 pixel di atasnya.
//
//  - [FIX] Cabut `height` dari TextStyle di TextField.
//    Biarkan strutStyle(forceStrutHeight: true) yang mengendalikan line
//    spacing. Cursor akan lock ke font baseline natural (benar secara visual).
//    HighlightLayer ikut: baseStyle juga tidak boleh punya `height`, supaya
//    TextPainter overlay identik dengan TextField dan teks tetap align.
//
//  - [FIX] cursorHeight dibiarkan null — Flutter hitung dari font metrics
//    secara otomatis, lebih akurat dan tidak akan off-center kalau
//    lineHeight factor berubah.
//
//  - [KEPT] strutStyle dengan forceStrutHeight: true di-share ke keduanya
//    supaya line offsets di TextField dan HighlightLayer selalu identik.
//    Tanpa ini cursor drift accumulate seiring banyaknya baris.
//
//  - [KEPT] textHeightBehavior tidak diset di HighlightLayer
//    (default Flutter = sama dengan TextField).
//
// FIX v_click_natural (sebelumnya):
//  - [FIXED] mouseCursor: SystemMouseCursors.text
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import '../../style/apps_colors_tradingview.dart';
import '../../utils/python_syntax_highlighter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CodeTextField
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
    // [FIX] strutStyle di-share ke TextField DAN HighlightLayer.
    // forceStrutHeight: true → setiap baris persis fontSize * lineHeightFactor,
    // tidak ada variasi dari glyph metrics per-karakter.
    // leading: 0 → tidak ada extra space di luar definisi kita.
    // height di sini adalah lineHeightFactor (factor, bukan pixel).
    final sharedStrut = StrutStyle(
      fontFamily:       widget.typo.fontFamily,
      fontSize:         widget.fontSize,
      height:           widget.typo.lineHeight,
      leading:          0,
      forceStrutHeight: true,
    );

    return Stack(
      children: [
        // ── Layer 1: TextField transparan ────────────────────────────────────
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
          mouseCursor:       SystemMouseCursors.text,

          // [FIX] strutStyle yang enforce line height.
          strutStyle: sharedStrut,

          style: TextStyle(
            fontFamily:    widget.typo.fontFamily,
            fontSize:      widget.fontSize,
            // [FIX] `height` SENGAJA TIDAK DISET di TextStyle.
            //
            // Kalau height ada di TextStyle, Flutter menambahkan "leading"
            // di atas font ascent sebesar (height - 1) * fontSize / 2.
            // Flutter's getOffsetForCaret memasukkan leading ini ke dalam
            // perhitungan caret dy → cursor muncul lebih tinggi dari teks.
            //
            // Dengan height hanya di strutStyle (bukan TextStyle), Flutter
            // menggunakan font baseline natural untuk posisi caret → cursor
            // sejajar dengan teks.
            letterSpacing: widget.typo.letterSpacing,
            color:         Colors.transparent,
          ),

          cursorColor: widget.chrome.cursorColor,
          cursorWidth: 2.0,
          // [FIX] cursorHeight TIDAK diset (null).
          // Flutter otomatis hitung dari font metrics → lebih akurat,
          // tidak akan off-center kalau lineHeight factor berubah.

          decoration: const InputDecoration(
            border:         InputBorder.none,
            isDense:        true,
            contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            fillColor:      Colors.transparent,
            filled:         true,
          ),
        ),

        // ── Layer 2: Highlight overlay ───────────────────────────────────────
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: RepaintBoundary(
              child: HighlightLayer(
                source:       _displaySource,
                theme:        widget.theme,
                fontSize:     widget.fontSize,
                lineHeight:   widget.lineHeight,
                strutStyle:   sharedStrut,
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
    required this.strutStyle,
    required this.matches,
    required this.currentMatch,
    required this.chrome,
  });

  final String             source;
  final EditorThemeState   theme;
  final double             fontSize;
  final double             lineHeight;
  final StrutStyle         strutStyle;
  final List<TextRange>    matches;
  final int                currentMatch;
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) {
    // [FIX] baseStyle TIDAK punya height — sama seperti TextField style.
    // Kalau overlay punya height tapi TextField tidak, TextPainter keduanya
    // hitung line offsets beda → teks overlay geser dari cursor position.
    final baseStyle = theme.typography.baseStyle.copyWith(
      fontSize: fontSize,
      // height sengaja tidak diset di sini, strutStyle yang handle.
    );

    var highlighted = PythonSyntaxHighlighter.buildTextSpan(source, theme: theme);

    if (matches.isNotEmpty) {
      highlighted = _injectMatchHighlights(highlighted);
    }

    return Text.rich(
      highlighted,
      style:      baseStyle,
      strutStyle: strutStyle,
      softWrap:   false,
      overflow:   TextOverflow.visible,
      // textHeightBehavior tidak diset → default Flutter, sama dengan TextField.
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
        out.add(_FlatSpan(
          text:  txt,
          style: span.style,
          start: offset,
          end:   offset + txt.length,
        ));
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
//  _FlatSpan
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