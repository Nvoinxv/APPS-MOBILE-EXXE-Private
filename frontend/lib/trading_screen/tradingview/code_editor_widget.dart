// =============================================================================
// code_editor_widget.dart
//
// Tanggung jawab:
//   - Widget entry point
//   - Menyatukan CodeEditorController + CodeEditorInputHandler
//   - Build: FindReplacePanel, _EditorBody, EditorStatusBar
//   - Zoom state (lokal — tidak perlu controller)
//   - Theme/file-change listeners
//
// FIX v_click_natural:
//  - [FIXED] IntrinsicWidth tanpa ConstrainedBox → TextField hanya selebar
//            konten teks. Klik di area kosong sebelah kanan teks = klik di
//            luar TextField → cursor tidak muncul, terasa "kaku".
//            Fix: LayoutBuilder + ConstrainedBox(minWidth: viewportWidth)
//            supaya editor minimal selalu selebar area visible. Horizontal
//            scroll tetap bekerja karena IntrinsicWidth masih ada di dalam.
//
// FIX v_layout_safe (sebelumnya):
//  - [FIXED] FocusNode() dibuat di dalam build() → dipindah ke State field
//  - [FIXED] _ctrl.updateSizing() dipanggil di dalam builder callback
//            → dipindah ke didUpdateWidget
//
// FIX v_overflow:
//  - [FIXED] Expanded(_buildEditorBody) → Flexible(fit:tight) +
//            ConstrainedBox(minHeight:0).
//            Root cause: saat FindReplacePanel (≈88–100px) + EditorStatusBar
//            (22px) melebihi tinggi yang tersedia untuk CodeEditorWidget,
//            body mendapat tinggi negatif dari Expanded → RenderFlex
//            overflow "88 pixels on the bottom".
//            Flexible(fit:tight) berperilaku sama seperti Expanded (mengisi
//            sisa ruang) TAPI memperbolehkan body menyusut sampai 0 lewat
//            ConstrainedBox(minHeight:0) tanpa menyebabkan assert/overflow.
//
// FIX v_status_bar_guard:
//  - [FIXED] Column overflow 8.8px (h=13.2px) di line 186.
//            Root cause: EditorStatusBar height: 22px hardcoded. Saat
//            available height < 22px, Flexible(editor body) menyusut ke 0
//            tapi status bar masih minta 22px → overflow 8.8px persis.
//            Flexible+ConstrainedBox(minH:0) menangani body, tapi tidak
//            menangani status bar.
//            Fix: wrap Column dalam LayoutBuilder, guard jika
//            constraints.maxHeight < _kStatusBarH (22px) → return
//            ColoredBox(background). Pattern identik dengan semua guard
//            sebelumnya di file lain.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../hooks/tradingview_hook.dart';
import '../../pages/tradingview_pages.dart';
import '../../style/apps_colors_tradingview.dart';
import '../../utils/python_syntax_highlighter.dart';
import '../../models/script_folder.dart';

import '../editor_code/code_editor_controller.dart';
import '../editor_code/code_editor_highlight_layer.dart';
import '../editor_code/code_editor_input_handler.dart';
import '../editor_code/code_editor_panels.dart';

import 'line_number_gutter.dart';

class CodeEditorWidget extends StatefulWidget {
  const CodeEditorWidget({
    super.key,
    required this.hook,
    this.gutterScrollController,
    this.codeScrollVController,
    this.codeScrollHController,
    this.zoomDelta = 0,
    this.onCodeChanged,
    this.onActiveLineChanged,
  });

  final IsolatedTradingViewHook        hook;
  final ScrollController?              gutterScrollController;
  final ScrollController?              codeScrollVController;
  final ScrollController?              codeScrollHController;
  final double                         zoomDelta;
  final void Function(String content)? onCodeChanged;
  final void Function(int lineIndex)?  onActiveLineChanged;

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {

  // ── Local state ───────────────────────────────────────────────────────────
  double _zoomFontSize    = 0;
  bool   _showFindReplace = false;
  bool   _showReplace     = false;

  // ── Sub-objects ───────────────────────────────────────────────────────────
  late CodeEditorController   _ctrl;
  late CodeEditorInputHandler _input;

  final FocusNode _editorFocusNode = FocusNode()..skipTraversal = true;

  // ── Constants ─────────────────────────────────────────────────────────────
  // [FIX v_status_bar_guard] Tinggi minimum: EditorStatusBar height = 22px.
  // Guard threshold untuk mencegah overflow saat panel sangat kecil.
  static const double _kStatusBarH = 22.0;

  // ── Theme shortcuts ───────────────────────────────────────────────────────
  IsolatedTradingViewHook get hook       => widget.hook;
  EditorChromeColors      get chrome     => hook.editorTheme.chrome;
  EditorSyntaxColors      get syntax     => hook.editorTheme.syntax;
  EditorTypography        get typo       => hook.editorTheme.typography;
  bool                    get isReadOnly => !hook.canEditActive;

  double get _effectiveFontSize =>
      (typo.fontSize + _zoomFontSize + widget.zoomDelta).clamp(8.0, 32.0);
  double get _lineHeight => _effectiveFontSize * typo.lineHeight;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _ctrl = CodeEditorController(
      initialText:             hook.tabs.activeFile?.content ?? '',
      gutterScrollController:  widget.gutterScrollController,
      codeScrollVController:   widget.codeScrollVController,
      codeScrollHController:   widget.codeScrollHController,
      fontSize:                _effectiveFontSize,
      lineHeightFactor:        typo.lineHeight,
    );

    _ctrl.onTextChanged = (text) {
      widget.onCodeChanged?.call(text);
      hook.onCodeChanged(text);
    };
    _ctrl.onActiveLineChanged = widget.onActiveLineChanged;

    _input = CodeEditorInputHandler(
      controller:    _ctrl,
      isReadOnly:    () => isReadOnly,
      onSave:        hook.saveActiveFile,
      onFindOpen:    ({bool showReplace = false}) => setState(() {
        _showFindReplace = true;
        _showReplace     = showReplace;
      }),
      onFindClose:   () => setState(() {
        _showFindReplace = false;
        _ctrl.setMatches([]);
      }),
      onShowReplace: () => setState(() => _showReplace = !_showReplace),
      onZoomChange:  (delta) => setState(() {
        if (delta.isNaN) {
          _zoomFontSize = 0;
        } else {
          _zoomFontSize = (_zoomFontSize + delta).clamp(-6.0, 14.0);
        }
      }),
      onFindUpdate:  () => setState(() {}),
    );

    hook.tabs.addListener(_onActiveFileChanged);
    hook.editorTheme.addListener(_onThemeChanged);
  }

  @override
  void didUpdateWidget(CodeEditorWidget old) {
    super.didUpdateWidget(old);

    final newSize = _effectiveFontSize;
    final newLH   = typo.lineHeight;
    if (old.zoomDelta != widget.zoomDelta ||
        old.hook.editorTheme.typography.fontSize != newSize) {
      _ctrl.updateSizing(newSize, newLH);
    }
  }

  @override
  void dispose() {
    hook.tabs.removeListener(_onActiveFileChanged);
    hook.editorTheme.removeListener(_onThemeChanged);
    _editorFocusNode.dispose();
    _ctrl.dispose();
    _input.dispose();
    super.dispose();
  }

  // ── Listeners ─────────────────────────────────────────────────────────────
  void _onActiveFileChanged() {
    final active = hook.tabs.activeFile;
    _ctrl.loadText(active?.content ?? '');
  }

  void _onThemeChanged() => setState(() {});

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hook.tabs, hook.editorTheme, _ctrl, _ctrl.breakpoints]),
      builder: (context, _) {
        final active = hook.tabs.activeFile;
        if (active == null) return NoFileOpen(chrome: chrome, syntax: syntax);

        // [FIX v_status_bar_guard] Wrap Column dalam LayoutBuilder untuk guard.
        // EditorStatusBar = 22px hardcoded. Saat h < 22, status bar saja
        // sudah melebihi available height → Column overflow. Guard: return
        // ColoredBox tanpa Column. Pattern sama dengan semua fix sebelumnya.
        return LayoutBuilder(
          builder: (context, lc) {
            if (lc.maxHeight < _kStatusBarH) {
              return ColoredBox(color: chrome.background);
            }

            return Column(
              children: [
                if (_showFindReplace)
                  FindReplacePanel(
                    findCtrl:        _input.findCtrl,
                    replaceCtrl:     _input.replaceCtrl,
                    showReplace:     _showReplace,
                    caseSensitive:   _input.caseSensitive,
                    wholeWord:       _input.wholeWord,
                    matchCount:      _ctrl.matches.length,
                    currentMatch:    _ctrl.currentMatch,
                    chrome:          chrome,
                    syntax:          syntax,
                    isReadOnly:      isReadOnly,
                    onSearch:        (_) => _input.updateMatches(),
                    onNext:          _input.nextMatch,
                    onPrev:          _input.prevMatch,
                    onReplaceOne:    _input.replaceOne,
                    onReplaceAll:    _input.replaceAll,
                    onClose:         () => setState(() {
                      _showFindReplace = false;
                      _ctrl.setMatches([]);
                    }),
                    onToggleCase: () => setState(() {
                      _input.caseSensitive = !_input.caseSensitive;
                      _input.updateMatches();
                    }),
                    onToggleWord: () => setState(() {
                      _input.wholeWord = !_input.wholeWord;
                      _input.updateMatches();
                    }),
                    onToggleReplace: () => setState(() => _showReplace = !_showReplace),
                  ),

                // [FIX v_overflow] Flexible(tight) + ConstrainedBox(minH:0)
                // supaya editor body boleh menyusut ke 0 tanpa overflow assert.
                Flexible(
                  fit: FlexFit.tight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 0),
                    child: _buildEditorBody(),
                  ),
                ),

                EditorStatusBar(
                  active:            active,
                  activeLineIdx:     _ctrl.activeLineIndex,
                  colIdx:            _ctrl.colIndex,
                  lineCount:         _ctrl.lineCount,
                  charCount:         _ctrl.charCount,
                  isReadOnly:        isReadOnly,
                  zoomDelta:         _zoomFontSize + widget.zoomDelta,
                  effectiveFontSize: _effectiveFontSize,
                  chrome:            chrome,
                  syntax:            syntax,
                  onResetZoom:       () => setState(() => _zoomFontSize = 0),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEditorBody() {
    return Container(
      color: chrome.background,
      child: Focus(
        focusNode:  _editorFocusNode,
        onKeyEvent: _input.handleKeyEvent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LineNumberGutter(
              lineCount:        _ctrl.lineCount,
              lineHeight:       _lineHeight,
              fontSize:         _effectiveFontSize,
              scrollController: _ctrl.gutterCtrl,
              theme:            hook.editorTheme.theme,
              activeLineIndex:  _ctrl.activeLineIndex,
              breakpoints:      _ctrl.breakpoints,
              showBreakpoints:  true,
              showFoldArrows:   true,
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Scrollbar(
                  controller:      _ctrl.vertScrollCtrl,
                  thumbVisibility: true,
                  thickness:       6,
                  radius:          const Radius.circular(3),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      controller:      _ctrl.vertScrollCtrl,
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        controller:      _ctrl.horizScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                            minHeight: constraints.maxHeight.clamp(0.0, double.maxFinite),
                          ),
                          child: IntrinsicWidth(
                            child: CodeTextField(
                              textCtrl:     _ctrl.textCtrl,
                              focusNode:    _ctrl.focusNode,
                              isReadOnly:   isReadOnly,
                              theme:        hook.editorTheme.theme,
                              chrome:       chrome,
                              typo:         typo,
                              fontSize:     _effectiveFontSize,
                              lineHeight:   _lineHeight,
                              matches:      _ctrl.matches,
                              currentMatch: _ctrl.currentMatch,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}