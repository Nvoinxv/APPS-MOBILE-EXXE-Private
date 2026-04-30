// =============================================================================
// output_console_panel.dart
// Path: frontend/lib/trading_screen/tradingview/output_console_panel.dart
//
// Panel utama output console.
//
// FIX ROOT CAUSE: stdout dari isolate/script runner harus di-pipe ke
//   console.write(line) — bukan print source code-nya.
//   Pastikan di script runner kamu capture stdout dengan:
//     - dart:io stdout override, atau
//     - intercept print() via Zone.runGuarded + ZoneSpecification(print: ...)
//   Contoh runner yang benar ada di komentar bawah.
//
// FIX scrollController: optional dari parent, fallback internal.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../hooks/tradingview_hook.dart';
import '../../../pages/tradingview_pages.dart';
import '../output_console/console_state.dart';
import '../output_console/console_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OutputConsolePanel
// ─────────────────────────────────────────────────────────────────────────────

class OutputConsolePanel extends StatefulWidget {
  final IsolatedTradingViewHook hook;
  final ConsoleState            console;

  /// Optional — kalau parent (e.g. TradingViewCodeEditorScreen) pass
  /// controller-nya sendiri (misalnya untuk DraggableScrollableSheet),
  /// pakai itu. Kalau tidak, fallback ke internal controller.
  final ScrollController? scrollController;

  const OutputConsolePanel({
    super.key,
    required this.hook,
    required this.console,
    this.scrollController,
  });

  @override
  State<OutputConsolePanel> createState() => _OutputConsolePanelState();
}

class _OutputConsolePanelState extends State<OutputConsolePanel>
    with SingleTickerProviderStateMixin {

  static const _tabs = ['Output', 'Problems', 'Terminal'];

  late TabController _tabCtrl;

  // Internal fallback — hanya dipakai kalau parent tidak pass scrollController
  final ScrollController _internalScrollCtrl = ScrollController();

  // Resolved getter: prefer parent, fallback internal
  ScrollController get _scrollCtrl =>
      widget.scrollController ?? _internalScrollCtrl;

  bool _autoScroll     = true;
  bool _showTimestamps = false;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    widget.console.addListener(_onConsoleUpdate);
    _scrollCtrl.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    // Hanya dispose internal controller — parent controller diurus pemiliknya
    _internalScrollCtrl.dispose();
    widget.console.removeListener(_onConsoleUpdate);
    super.dispose();
  }

  // ── scroll helpers ─────────────────────────────────────────────────────────

  void _onScrollChanged() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 32;
    if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
  }

  void _onConsoleUpdate() {
    if (!_autoScroll || !_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  // ── actions ────────────────────────────────────────────────────────────────

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: widget.console.allText));
    HapticFeedback.lightImpact();
    final chrome = widget.hook.editorTheme.chrome;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Output copied to clipboard',
          style: TextStyle(color: chrome.consoleTextSuccess, fontSize: 12),
        ),
        backgroundColor: chrome.surface,
        behavior: SnackBarBehavior.floating,
        shape:    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.console, widget.hook.editorTheme]),
      builder: (context, _) {
        final chrome = widget.hook.editorTheme.chrome;
        final syntax = widget.hook.editorTheme.syntax;
        final cons   = widget.console;

        return Container(
          decoration: BoxDecoration(
            color:  chrome.consoleBackground ?? chrome.background,
            border: Border(top: BorderSide(color: chrome.gutterBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header + tabs ──────────────────────────────────────────────
              ConsoleHeader(
                tabCtrl:            _tabCtrl,
                tabs:               _tabs,
                console:            cons,
                chrome:             chrome,
                syntax:             syntax,
                showTimestamps:     _showTimestamps,
                onToggleTimestamps: () => setState(() => _showTimestamps = !_showTimestamps),
                onClear:            cons.clear,
                onCopy:             _copyAll,
                autoScroll:         _autoScroll,
                onToggleScroll:     () => setState(() => _autoScroll = !_autoScroll),
              ),

              // ── Tab content ────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  physics:    const NeverScrollableScrollPhysics(),
                  children: [
                    OutputTab(
                      console:        cons,
                      chrome:         chrome,
                      syntax:         syntax,
                      scrollCtrl:     _scrollCtrl,
                      showTimestamps: _showTimestamps,
                    ),
                    ProblemsTab(console: cons, chrome: chrome, syntax: syntax),
                    TerminalTab(chrome: chrome, syntax: syntax),
                  ],
                ),
              ),

              // ── Status bar ─────────────────────────────────────────────────
              ConsoleStatusBar(console: cons, chrome: chrome, syntax: syntax),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
//  PETUNJUK FIX ROOT CAUSE — baca ini kalau output masih nampil aneh
// =============================================================================
//
//  Masalah di screenshot: output nampil f-string raw, bukan hasil evaluasinya.
//  Ini artinya script runner TIDAK capture stdout dengan benar.
//
//  SOLUSI — di script runner / isolate kamu, pakai Zone untuk intercept print:
//
//  ```dart
//  import 'dart:async';
//
//  Future<void> runWithCapturedOutput(
//    String script,
//    ConsoleState console,
//  ) async {
//    await runZoned(
//      () async {
//        // ... jalankan script Python via python_ffi / flutter_python / dll.
//        // stdout dari Python harus di-pipe ke sini
//      },
//      zoneSpecification: ZoneSpecification(
//        print: (self, parent, zone, line) {
//          // Semua print() dari dalam zone ini masuk ke console, bukan ke terminal
//          console.write(line, level: LogLevel.stdout);
//        },
//      ),
//    );
//  }
//  ```
//
//  Kalau kamu pakai Python via flutter_python / chaquopy / dll, pastikan
//  stdout redirect seperti ini sebelum exec script:
//
//  ```python
//  import sys, io
//  _buf = io.StringIO()
//  sys.stdout = _buf
//  # ... exec script user ...
//  output = _buf.getvalue()   # ← kirim ini ke Flutter via method channel
//  sys.stdout = sys.__stdout__
//  ```
//
//  Kalau sudah begini, `Signal: buy @ 125.00` akan nampil benar di console.
// =============================================================================