// =============================================================================
// output_console_panel.dart
// Path: frontend/lib/trading_screen/tradingview/output_console_panel.dart
//
// FIX v_remove_terminal:
//  - [REMOVED] Tab 'Terminal' dihapus — tidak dipakai, diganti Output
//    sebagai tab utama untuk menampilkan hasil eksekusi Python.
//  - _tabs sekarang ['Output', 'Problems'] saja.
//  - TabBarView children dikurangi 1 (TerminalTab dihapus).
//  - TabController length diupdate dari 3 → 2.
//
// FIX v_overflow:
//  - [FIX] Seluruh build di-wrap LayoutBuilder sehingga panel selalu tahu
//    berapa tinggi yang BENAR-BENAR tersedia dari SizedBox(height: h) parent.
//  - [FIX] Container diberi clipBehavior: Clip.hardEdge sebagai safety-net
//    visual.
//  - [FIX] ConsoleStatusBar disembunyikan secara adaptif ketika availH ≤ 68px.
//  - [FIX] Expanded → Flexible(fit: FlexFit.tight) + ConstrainedBox(minHeight:0).
//
// FIX v_overflow_v2:
//  - [FIX] Root cause sebenarnya: Column dipaksa render di h=3.8px karena
//    threshold sebelumnya (68px) hanya menyembunyikan StatusBar, bukan
//    seluruh panel. ConsoleHeader sendiri butuh ~40px.
//  - [FIX] Tambah _kMinRenderH = 40.0 — di bawah nilai ini seluruh panel
//    diganti SizedBox.shrink() sehingga Column tidak pernah dipaksa layout
//    di ruang yang mustahil.
//  - [FIX] _statusBarHideThreshold dinaikkan 40→68 menjadi relatif terhadap
//    _kMinRenderH supaya logika lebih jelas.
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
  final ScrollController?       scrollController;

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

  static const _tabs = ['Output', 'Problems'];

  // [FIX v2] Minimum height untuk render panel sama sekali.
  // ConsoleHeader butuh ~36-40px. Di bawah nilai ini return SizedBox.shrink()
  // agar Column tidak pernah dipaksa layout di h < 40px (e.g. h=3.8px).
  static const double _kMinRenderH = 40.0;

  // [FIX] Threshold: di bawah nilai ini ConsoleStatusBar disembunyikan.
  // ConsoleHeader ≈ 40px + ConsoleStatusBar ≈ 22px + TabBarView min 1px = ~63px
  // Pakai 68 sebagai headroom.
  static const double _statusBarHideThreshold = 68.0;

  late TabController _tabCtrl;

  final ScrollController _internalScrollCtrl = ScrollController();

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
  void didUpdateWidget(OutputConsolePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // kalau parent ganti scrollController dari luar, re-attach listener
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScrollChanged);
      _internalScrollCtrl.removeListener(_onScrollChanged);
      _scrollCtrl.addListener(_onScrollChanged);
    }
  }


  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScrollChanged);   // FIX: remove dulu sebelum dispose
    widget.console.removeListener(_onConsoleUpdate);
    _tabCtrl.dispose();
    _internalScrollCtrl.dispose();
    super.dispose();
  }

  // ── scroll helpers ─────────────────────────────────────────────────────────

  void _onScrollChanged() {
  if (!mounted) return;                           // FIX: guard mounted
  if (!_scrollCtrl.hasClients) return;
  final atBottom = _scrollCtrl.position.pixels >=
      _scrollCtrl.position.maxScrollExtent - 32;
  if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
}

  void _onConsoleUpdate() {
  if (!_autoScroll || !_scrollCtrl.hasClients) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !_scrollCtrl.hasClients) return;  // FIX: double guard
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 120),
      curve:    Curves.easeOut,
    );
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final availH = constraints.maxHeight;

            // [FIX v2] Guard utama: kalau panel terlalu kecil untuk render
            // bahkan header sekalipun (e.g. h=3.8px saat di-drag), kembalikan
            // widget kosong. Column tidak akan pernah layout di ruang mustahil.
            if (availH < _kMinRenderH) return const SizedBox.shrink();

            final showStatusBar = availH > _statusBarHideThreshold;

            return Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color:  chrome.consoleBackground ?? chrome.background,
                border: Border(top: BorderSide(color: chrome.gutterBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header + tabs ──────────────────────────────────────────
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

                  // ── Tab content ────────────────────────────────────────────
                  // Flexible(fit: FlexFit.tight) + ConstrainedBox(minHeight: 0)
                  // → TabBarView bisa menyusut sampai 0 tanpa overflow assert.
                  Flexible(
                    fit: FlexFit.tight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 0),
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
                        ],
                      ),
                    ),
                  ),

                  // ── Status bar ─────────────────────────────────────────────
                  // Disembunyikan secara adaptif kalau availH terlalu kecil.
                  if (showStatusBar)
                    ConsoleStatusBar(console: cons, chrome: chrome, syntax: syntax),
                ],
              ),
            );
          },
        );
      },
    );
  }
}