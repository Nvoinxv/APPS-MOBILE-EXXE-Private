// =============================================================================
// code_editor_input_handler.dart
//
// Tanggung jawab:
//   - Semua keyboard shortcut (Ctrl+S/F/H/D//, Tab, Enter, autopair, dll)
//   - Arrow key awareness (handled by Flutter TextField natively — kita TIDAK
//     override arrow keys, biarkan TextField yang handle supaya cursor 60fps)
//   - Edit helpers: insertText, removeIndent, handleEnter, toggleComment,
//     duplicateLine, autoPair, skipClose
//   - Find/Replace logic: updateMatches, next/prev, replaceOne, replaceAll
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'code_editor_controller.dart';

class CodeEditorInputHandler {
  CodeEditorInputHandler({
    required this.controller,
    required this.isReadOnly,
    required this.onFindOpen,
    required this.onFindClose,
    required this.onSave,
    required this.onShowReplace,
    required this.onZoomChange,
    required this.onFindUpdate,
  });

  final CodeEditorController controller;
  final bool Function()      isReadOnly;

  // Callbacks ke widget
  final void Function({bool showReplace}) onFindOpen;
  final VoidCallback                      onFindClose;
  final VoidCallback                      onSave;
  final VoidCallback                      onShowReplace;
  final void Function(double delta)       onZoomChange;
  final VoidCallback                      onFindUpdate;

  // Find state (dikelola di sini, widget baca via controller.matches)
  final TextEditingController findCtrl    = TextEditingController();
  final TextEditingController replaceCtrl = TextEditingController();
  bool caseSensitive = false;
  bool wholeWord     = false;

  // ── Keyboard entry point ──────────────────────────────────────────────────

  /// Return true jika event sudah di-handle (supaya widget bisa ignore ke TextField)
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final ctrl  = HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key   = event.logicalKey;

    // ── Global shortcuts (berlaku meski readOnly) ──────────────────────────
    if (ctrl && key == LogicalKeyboardKey.keyS) {
      onSave();
      HapticFeedback.lightImpact();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyF) {
      onFindOpen(showReplace: false);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyH) {
      onFindOpen(showReplace: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      onFindClose();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.equal) {
      onZoomChange(1);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.minus) {
      onZoomChange(-1);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.digit0) {
      onZoomChange(double.nan); // signal reset
      return KeyEventResult.handled;
    }

    // ── Arrow keys: JANGAN di-override — biarkan Flutter TextField handle ──
    // Ini kunci supaya cursor movement terasa native seperti VSCode

    if (isReadOnly()) return KeyEventResult.ignored;

    // ── Edit shortcuts ─────────────────────────────────────────────────────
    if (key == LogicalKeyboardKey.tab && !shift) {
      insertText('    ');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab && shift) {
      removeIndent();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      handleEnter();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.slash) {
      toggleLineComment();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyD) {
      duplicateLine();
      return KeyEventResult.handled;
    }

    // ── Auto-pair ──────────────────────────────────────────────────────────
    if (!ctrl) {
      const openPairs = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'"};
      final ch        = event.character;

      if (ch != null && openPairs.containsKey(ch)) {
        return handleAutoPair(ch, openPairs[ch]!);
      }
      if (ch != null && (')]}'.contains(ch) || ch == '"' || ch == "'")) {
        if (skipIfNextIs(ch)) return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  // ── Edit helpers ──────────────────────────────────────────────────────────

  void insertText(String text) {
    final tc    = controller.textCtrl;
    final sel   = tc.selection;
    final old   = tc.text;
    final start = sel.start.clamp(0, old.length);
    final end   = sel.end.clamp(0, old.length);
    tc.value = TextEditingValue(
      text:      old.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void removeIndent() {
    final tc        = controller.textCtrl;
    final sel       = tc.selection;
    final text      = tc.text;
    final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;
    final prefix    = text.substring(lineStart, sel.start);

    if (prefix.startsWith('    ')) {
      final newText = text.replaceRange(lineStart, lineStart + 4, '');
      tc.value = TextEditingValue(
        text:      newText,
        selection: TextSelection.collapsed(
            offset: (sel.start - 4).clamp(lineStart, newText.length)),
      );
    } else if (prefix.startsWith(' ')) {
      final spaces  = prefix.length - prefix.trimLeft().length;
      final remove  = spaces.clamp(0, 4);
      final newText = text.replaceRange(lineStart, lineStart + remove, '');
      tc.value = TextEditingValue(
        text:      newText,
        selection: TextSelection.collapsed(
            offset: (sel.start - remove).clamp(lineStart, newText.length)),
      );
    }
  }

  void handleEnter() {
    final tc        = controller.textCtrl;
    final text      = tc.text;
    final offset    = tc.selection.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    final lineText  = text.substring(lineStart, offset);
    final indent    = lineText.length - lineText.trimLeft().length;
    var   indentStr = ' ' * indent;
    if (lineText.trimRight().endsWith(':')) indentStr += '    ';
    insertText('\n$indentStr');
  }

  void toggleLineComment() {
    final tc        = controller.textCtrl;
    final text      = tc.text;
    final sel       = tc.selection;
    final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;
    final lineEnd   = text.indexOf('\n', sel.start);
    final end       = lineEnd == -1 ? text.length : lineEnd;
    final line      = text.substring(lineStart, end);

    final String newLine;
    final int    delta;
    if (line.trimLeft().startsWith('# ')) {
      final idx = line.indexOf('# ');
      newLine = line.replaceFirst('# ', '', idx); delta = -2;
    } else if (line.trimLeft().startsWith('#')) {
      final idx = line.indexOf('#');
      newLine = line.replaceFirst('#', '', idx);  delta = -1;
    } else {
      final idx = line.length - line.trimLeft().length;
      newLine = line.replaceRange(idx, idx, '# '); delta = 2;
    }

    final newText = text.replaceRange(lineStart, end, newLine);
    tc.value = TextEditingValue(
      text:      newText,
      selection: TextSelection.collapsed(
          offset: (sel.baseOffset + delta).clamp(0, newText.length)),
    );
  }

  void duplicateLine() {
    final tc        = controller.textCtrl;
    final text      = tc.text;
    final sel       = tc.selection;
    final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;
    final lineEnd   = text.indexOf('\n', sel.start);
    final end       = lineEnd == -1 ? text.length : lineEnd;
    final line      = text.substring(lineStart, end);
    final newText   = text.replaceRange(end, end, '\n$line');
    tc.value = TextEditingValue(
      text:      newText,
      selection: TextSelection.collapsed(
          offset: end + 1 + (sel.start - lineStart)),
    );
  }

  KeyEventResult handleAutoPair(String open, String close) {
    final tc    = controller.textCtrl;
    final sel   = tc.selection;
    final text  = tc.text;
    final start = sel.start.clamp(0, text.length);
    final end   = sel.end.clamp(0, text.length);

    if (start != end) {
      // Wrap selection dengan pair
      final selected = text.substring(start, end);
      final newText  = text.replaceRange(start, end, '$open$selected$close');
      tc.value = TextEditingValue(
        text:      newText,
        selection: TextSelection(
          baseOffset:   start + 1,
          extentOffset: start + 1 + selected.length,
        ),
      );
      return KeyEventResult.handled;
    }

    final newText = text.replaceRange(start, start, '$open$close');
    tc.value = TextEditingValue(
      text:      newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
    return KeyEventResult.handled;
  }

  bool skipIfNextIs(String char) {
    final tc   = controller.textCtrl;
    final pos  = tc.selection.baseOffset;
    final text = tc.text;
    if (pos >= 0 && pos < text.length && text[pos] == char) {
      tc.selection = TextSelection.collapsed(offset: pos + 1);
      return true;
    }
    return false;
  }

  // ── Find & Replace ────────────────────────────────────────────────────────

  void updateMatches() {
    final query = findCtrl.text;
    if (query.isEmpty) { controller.setMatches([]); return; }

    final text   = controller.text;
    final source = caseSensitive ? text  : text.toLowerCase();
    final q      = caseSensitive ? query : query.toLowerCase();
    final results = <TextRange>[];
    int   start   = 0;

    while (true) {
      final idx = source.indexOf(q, start);
      if (idx == -1) break;
      if (wholeWord) {
        final before = idx > 0 ? source[idx - 1] : ' ';
        final after  = idx + q.length < source.length ? source[idx + q.length] : ' ';
        if (RegExp(r'[a-zA-Z0-9_]').hasMatch(before) ||
            RegExp(r'[a-zA-Z0-9_]').hasMatch(after)) {
          start = idx + 1; continue;
        }
      }
      results.add(TextRange(start: idx, end: idx + q.length));
      start = idx + 1;
    }

    final current = controller.currentMatch.clamp(0, results.isEmpty ? 0 : results.length - 1);
    controller.setMatches(results, current: current);
    if (results.isNotEmpty) _scrollToMatch(current);
    onFindUpdate();
  }

  void nextMatch() {
    if (controller.matches.isEmpty) return;
    final idx = (controller.currentMatch + 1) % controller.matches.length;
    controller.setCurrentMatch(idx);
    _scrollToMatch(idx);
  }

  void prevMatch() {
    if (controller.matches.isEmpty) return;
    final idx = (controller.currentMatch - 1 + controller.matches.length) %
                 controller.matches.length;
    controller.setCurrentMatch(idx);
    _scrollToMatch(idx);
  }

  void _scrollToMatch(int idx) {
    if (idx >= controller.matches.length) return;
    final match  = controller.matches[idx];
    final text   = controller.text;
    final before = text.substring(0, match.start.clamp(0, text.length));
    final line   = '\n'.allMatches(before).length;
    controller.scrollToLine(line);

    controller.textCtrl.selection =
        TextSelection(baseOffset: match.start, extentOffset: match.end);
  }

  void replaceOne() {
    if (controller.matches.isEmpty || isReadOnly()) return;
    final match   = controller.matches[controller.currentMatch];
    final replace = replaceCtrl.text;
    controller.textCtrl.text =
        controller.text.replaceRange(match.start, match.end, replace);
    updateMatches();
  }

  void replaceAll() {
    if (controller.matches.isEmpty || isReadOnly()) return;
    final q       = caseSensitive ? findCtrl.text : findCtrl.text.toLowerCase();
    final newText = controller.text.replaceAll(q, replaceCtrl.text);
    controller.textCtrl.text = newText;
    controller.setMatches([]);
  }

  void dispose() {
    findCtrl.dispose();
    replaceCtrl.dispose();
  }
}