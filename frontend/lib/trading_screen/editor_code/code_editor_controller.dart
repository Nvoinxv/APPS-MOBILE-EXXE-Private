// =============================================================================
// code_editor_controller.dart
//
// Tanggung jawab:
//   - TextEditingController, FocusNode, ScrollControllers
//   - Sync gutter scroll ↔ code area (jumpTo = zero lag)
//   - Derived state: lineCount, activeLine, colIndex, lineHeight
//   - BreakpointState
//   - Find/replace match list
// =============================================================================

import 'package:flutter/material.dart';
import '../tradingview/line_number_gutter.dart';
import '../../../hooks/execute_hook.dart';
import '../output_console/console_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CodeEditorController
// ─────────────────────────────────────────────────────────────────────────────

class CodeEditorController extends ChangeNotifier {
  CodeEditorController({
    required String   initialText,
    ScrollController? gutterScrollController,
    ScrollController? codeScrollVController,
    ScrollController? codeScrollHController,
    required double   fontSize,
    required double   lineHeightFactor,
  })  : _fontSize         = fontSize,
        _lineHeightFactor = lineHeightFactor {

    _textCtrl   = TextEditingController(text: initialText);
    _focusNode  = FocusNode();

    _gutterCtrl      = gutterScrollController ?? (_ownGutter = ScrollController());
    _vertScrollCtrl  = codeScrollVController  ?? (_ownVert   = ScrollController());
    _horizScrollCtrl = codeScrollHController  ?? (_ownHoriz  = ScrollController());

    _textCtrl.addListener(_onTextChanged);
    _vertScrollCtrl.addListener(_syncGutter);
  }

  // ── Text & Focus ──────────────────────────────────────────────────────────
  late final TextEditingController _textCtrl;
  late final FocusNode             _focusNode;

  TextEditingController get textCtrl  => _textCtrl;
  FocusNode             get focusNode => _focusNode;

  // ── Scroll ────────────────────────────────────────────────────────────────
  late final ScrollController _gutterCtrl;
  late final ScrollController _vertScrollCtrl;
  late final ScrollController _horizScrollCtrl;

  ScrollController? _ownGutter;
  ScrollController? _ownVert;
  ScrollController? _ownHoriz;

  ScrollController get gutterCtrl      => _gutterCtrl;
  ScrollController get vertScrollCtrl  => _vertScrollCtrl;
  ScrollController get horizScrollCtrl => _horizScrollCtrl;

  // ── Sizing ────────────────────────────────────────────────────────────────
  double _fontSize;
  double _lineHeightFactor;

  double get fontSize         => _fontSize;
  double get lineHeightFactor => _lineHeightFactor;
  double get lineHeight       => _fontSize * _lineHeightFactor;

  void updateSizing(double fontSize, double lineHeightFactor) {
    if (_fontSize == fontSize && _lineHeightFactor == lineHeightFactor) return;
    _fontSize = fontSize; _lineHeightFactor = lineHeightFactor;
    notifyListeners();
  }

  // ── Derived state ─────────────────────────────────────────────────────────
  int _activeLineIndex = 0;
  int get activeLineIndex => _activeLineIndex;

  String get text      => _textCtrl.text;
  int    get lineCount => '\n'.allMatches(text).length + 1;
  int    get charCount => text.length;

  int get colIndex {
    final raw = _textCtrl.selection.baseOffset;
    if (raw < 0) return 0;
    final offset = raw.clamp(0, text.length);
    return offset - (text.substring(0, offset).lastIndexOf('\n') + 1);
  }

  Future<void> runCode(ConsoleState consoleState) async {
    final code = _textCtrl.text.trim();
    if (code.isEmpty) {
      consoleState.writeWarning('⚠  Nothing to run — editor is empty');
      return;
    }

    consoleState.startRun();

    final result = await ExecuteHook.runCode(code);

    consoleState.setResult(
      stdout:   result['stdout']    as String? ?? '',
      stderr:   result['stderr']    as String? ?? '',
      exitCode: result['exit_code'] as int?    ?? -1,
    );
  }

  // ── Breakpoints ───────────────────────────────────────────────────────────
  final BreakpointState breakpoints = BreakpointState();

  // ── Find/Replace matches ──────────────────────────────────────────────────
  List<TextRange> _matches      = [];
  int             _currentMatch = 0;

  List<TextRange> get matches      => _matches;
  int             get currentMatch => _currentMatch;

  void setMatches(List<TextRange> m, {int current = 0}) {
    _matches      = m;
    _currentMatch = m.isEmpty ? 0 : current.clamp(0, m.length - 1);
    notifyListeners();
  }

  void setCurrentMatch(int idx) {
    if (_matches.isEmpty) return;
    _currentMatch = idx % _matches.length;
    notifyListeners();
  }

  // ── Callbacks ke parent ───────────────────────────────────────────────────
  void Function(String text)?  onTextChanged;
  void Function(int lineIndex)? onActiveLineChanged;

  // ── Load teks baru (pindah tab/file) ─────────────────────────────────────
  void loadText(String newText) {
    if (_textCtrl.text == newText) return;
    _textCtrl.value = TextEditingValue(
      text:      newText,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _activeLineIndex = 0;
    notifyListeners();
  }

  // ── Scroll ke baris tertentu ──────────────────────────────────────────────
  void scrollToLine(int lineIdx,
      {Duration duration = const Duration(milliseconds: 200)}) {
    if (!_vertScrollCtrl.hasClients) return;
    final target = ((lineIdx * lineHeight) - 100)
        .clamp(0.0, _vertScrollCtrl.position.maxScrollExtent);
    _vertScrollCtrl.animateTo(target, duration: duration, curve: Curves.easeOut);
  }

  // ── Private ───────────────────────────────────────────────────────────────
  void _onTextChanged() {
    final raw    = _textCtrl.selection.baseOffset;
    final offset = raw < 0 ? 0 : raw.clamp(0, text.length);
    final line   = '\n'.allMatches(text.substring(0, offset)).length;

    if (line != _activeLineIndex) {
      _activeLineIndex = line;
      onActiveLineChanged?.call(line);
    }
    onTextChanged?.call(text);
    notifyListeners();
  }

  /// Gutter sync: jumpTo (bukan animateTo) supaya tidak ada delay visual
  void _syncGutter() {
    if (!_gutterCtrl.hasClients || !_vertScrollCtrl.hasClients) return;
    final offset = _vertScrollCtrl.offset;
    final max    = _gutterCtrl.position.maxScrollExtent;
    if ((_gutterCtrl.offset - offset).abs() > 0.5) {
      _gutterCtrl.jumpTo(offset.clamp(0.0, max));
    }
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _vertScrollCtrl.removeListener(_syncGutter);
    _textCtrl.dispose();
    _focusNode.dispose();
    breakpoints.dispose();
    _ownGutter?.dispose();
    _ownVert?.dispose();
    _ownHoriz?.dispose();
    super.dispose();
  }
}