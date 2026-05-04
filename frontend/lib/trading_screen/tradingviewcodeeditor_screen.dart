// =============================================================================
// tradingviewcodeeditor_screen.dart — PATCH
//
// FIX 1 (_onNewFile): addFile() sekarang di-await dengan benar.
//        Sebelumnya: hook.openFile(hook.workspace.addFile(...))  ← Future
//        Sesudah:    final f = await hook.workspace.addFile(...); hook.openFile(f)
//
// FIX 2 (_onCreateNewIndicator): addFile() sekarang di-await dengan benar.
//        Method juga diubah jadi async.
//        Sebelumnya: final newFile = hook.workspace.addFile(...)  ← Future
//        Sesudah:    final newFile = await hook.workspace.addFile(...)
//
// Semua perubahan ditandai dengan komentar "// FIX" di inline.
// Bagian lain identik dengan versi sebelumnya.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../hooks/tradingview_hook.dart';
import '../../hooks/execute_hook.dart';
import '../../pages/tradingview_pages.dart';
import '../../style/apps_colors_tradingview.dart';
import '../../postingan/postingan_tradingview.dart';
import '../../models/script_file.dart';
import '../../models/script_folder.dart';

import 'output_console/console_state.dart';

import 'tradingview/line_number_gutter.dart';
import 'tradingview/code_editor_widget.dart';
import 'tradingview/file_explorer_panel.dart';
import 'tradingview/file_tile.dart';
import 'tradingview/folder_tree_tile.dart';
import 'tradingview/context_menu_file.dart';
import 'tradingview/editor_toolbar.dart';
import 'tradingview/editor_tab_bar.dart' as tab_bar_lib;
import 'tradingview/output_console_panel.dart';
import 'tradingview/resizable_divider.dart';

class TradingViewCodeEditorScreen extends StatefulWidget {
  const TradingViewCodeEditorScreen({super.key});

  @override
  State<TradingViewCodeEditorScreen> createState() =>
      _TradingViewCodeEditorScreenState();
}

class _TradingViewCodeEditorScreenState
    extends State<TradingViewCodeEditorScreen> {

  // ── Layout ValueNotifiers ──────────────────────────────────────────────────

  late final ValueNotifier<double> _explorerWidth  = ValueNotifier(240);
  late final ValueNotifier<double> _consoleHeight  = ValueNotifier(180);

  // ── Bool state ─────────────────────────────────────────────────────────────

  bool   _consoleExpanded = true;
  bool   _explorerVisible = true;
  bool   _zenMode         = false;
  bool   _fullscreen      = false;
  double _zoomDelta       = 0;

  static const double _minExplorer = 160;
  static const double _maxExplorer = 400;
  static const double _minConsole  = 80;
  static const double _maxConsole  = 400;

  // ── Controllers ────────────────────────────────────────────────────────────

  final ConsoleState     _console            = ConsoleState();
  final BreakpointState  _breakpoints        = BreakpointState();
  final ScrollController _gutterScrollCtrl   = ScrollController();
  final ScrollController _codeScrollVCtrl    = ScrollController();
  final ScrollController _codeScrollHCtrl    = ScrollController();
  final ScrollController _consoleScrollCtrl  = ScrollController();
  final ScrollController _explorerScrollCtrl = ScrollController();

  // ── Editor state ───────────────────────────────────────────────────────────

  int?   _activeLineIndex;
  int    _lineCount = 1;

  // ── Indicator panel ────────────────────────────────────────────────────────

  bool                _showIndicators      = false;
  String?             _selectedIndicatorId;
  List<IndicatorMeta> _indicators          = const [];

  // ── Scroll sync guard ──────────────────────────────────────────────────────

  bool _syncingGutter = false;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _codeScrollVCtrl.addListener(_syncGutterToCode);
  }

  @override
  void dispose() {
    _codeScrollVCtrl.removeListener(_syncGutterToCode);
    _explorerWidth.dispose();
    _consoleHeight.dispose();
    _gutterScrollCtrl.dispose();
    _codeScrollVCtrl.dispose();
    _codeScrollHCtrl.dispose();
    _consoleScrollCtrl.dispose();
    _explorerScrollCtrl.dispose();
    _console.dispose();
    _breakpoints.dispose();
    super.dispose();
  }

  void _syncGutterToCode() {
    if (_syncingGutter) return;
    if (!_codeScrollVCtrl.hasClients || !_gutterScrollCtrl.hasClients) return;
    if (!_codeScrollVCtrl.position.hasContentDimensions)               return;
    if (!_gutterScrollCtrl.position.hasContentDimensions)              return;

    final offset = _codeScrollVCtrl.offset;
    if (_gutterScrollCtrl.offset == offset) return;

    _syncingGutter = true;
    try {
      _gutterScrollCtrl.jumpTo(
        offset.clamp(0.0, _gutterScrollCtrl.position.maxScrollExtent),
      );
    } finally {
      _syncingGutter = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Getters
  // ═══════════════════════════════════════════════════════════════════════════

  IsolatedTradingViewHook get _hook  => IsolatedHookProvider.of(context);
  EditorThemeState        get _theme => _hook.editorTheme.theme;

  ScriptFile? _getActiveFile(IsolatedTradingViewHook hook) {
    try {
      // ignore: avoid_dynamic_calls
      return (hook.workspace as dynamic).activeFile as ScriptFile?;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Run / Stop code
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _runCode() async {
    if (_console.isRunning) return;

    final hook       = _hook;
    final activeFile = _getActiveFile(hook);
    final code       = activeFile?.content ?? '';

    setState(() => _consoleExpanded = true);

    if (code.trim().isEmpty) {
      _console.writeWarning('Nothing to run — active file is empty.');
      return;
    }

    await _console.executeCode(code, fileName: activeFile?.name);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScrollCtrl.hasClients) {
        _consoleScrollCtrl.animateTo(
          _consoleScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  void _stopCode() => _console.stopRun();

  // ═══════════════════════════════════════════════════════════════════════════
  //  Zen / Fullscreen
  // ═══════════════════════════════════════════════════════════════════════════

  void _toggleZen() {
    setState(() {
      _zenMode         = !_zenMode;
      _explorerVisible = !_zenMode;
      _consoleExpanded = !_zenMode;
    });
    HapticFeedback.mediumImpact();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    HapticFeedback.mediumImpact();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Editor callbacks
  // ═══════════════════════════════════════════════════════════════════════════

  void _onCodeChanged(String content) {
    final count = '\n'.allMatches(content).length + 1;
    if (count != _lineCount) setState(() => _lineCount = count);
  }

  void _onActiveLineChanged(int lineIndex) {
    if (lineIndex != _activeLineIndex) {
      setState(() => _activeLineIndex = lineIndex);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  File context menu
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onFileContextMenu(
    BuildContext ctx,
    Offset globalPos,
    ScriptFile file,
  ) async {
    final hook   = _hook;
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;

    final action = await showMenu<String>(
      context:  ctx,
      position: RelativeRect.fromRect(
        globalPos & const Size(1, 1),
        Offset.zero &
            (Overlay.of(ctx).context.findRenderObject()! as RenderBox).size,
      ),
      color: chrome.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side:         BorderSide(color: chrome.gutterBorder),
      ),
      elevation: 8,
      items: [
        _menuItem('open',   Icons.open_in_new_rounded,   'Open',
            syntax.plain.withOpacity(0.8), chrome),
        _menuItem('rename', Icons.edit_outlined,          'Rename',
            syntax.plain.withOpacity(0.8), chrome),
        _menuItem('delete', Icons.delete_outline_rounded, 'Delete',
            chrome.consoleTextError,       chrome),
      ],
    );

    if (action == null || !mounted) return;
    switch (action) {
      case 'open':   hook.openFile(file);
      case 'rename': _showRenameDialog(file);
      case 'delete': hook.deleteFile(file.id);
    }
  }

  PopupMenuItem<String> _menuItem(
    String value, IconData icon, String label,
    Color color, EditorChromeColors chrome,
  ) =>
      PopupMenuItem(
        value:  value,
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  //  Dialogs
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showRenameDialog(ScriptFile file) async {
    final ctrl = TextEditingController(text: file.name);
    await _showNameDialog(
      title:        'Rename File',
      hint:         'filename.py',
      ctrl:         ctrl,
      hook:         _hook,
      confirmLabel: 'Rename',
      onConfirm:    (val) => _hook.workspace.renameFile(file.id, val),
    );
    ctrl.dispose();
  }

  // FIX: _onNewFile sekarang async dan addFile() di-await dengan benar.
  // Sebelumnya: hook.openFile(hook.workspace.addFile(...))  ← SALAH, Future bukan ScriptFile
  // Sesudah: final f = await hook.workspace.addFile(...); hook.openFile(f)
  Future<void> _onNewFile(String parentFolderId) async {
    final ctrl = TextEditingController();
    await _showNameDialog(
      title:        'New File',
      hint:         'filename.py',
      ctrl:         ctrl,
      hook:         _hook,
      confirmLabel: 'Create',
      onConfirm: (val) async {
        // FIX: await addFile() agar ScriptFile (bukan Future<ScriptFile>) yang dikirim ke openFile
        final f = await _hook.workspace.addFile(parentFolderId, val);
        _hook.openFile(f);
      },
    );
    ctrl.dispose();
  }

  Future<void> _onNewFolder(String? parentFolderId) async {
    final ctrl = TextEditingController();
    await _showNameDialog(
      title:        'New Folder',
      hint:         'folder name',
      ctrl:         ctrl,
      hook:         _hook,
      confirmLabel: 'Create',
      onConfirm: (val) {
        if (parentFolderId != null) {
          _hook.workspace.addFolder(parentFolderId, val);
        } else {
          _hook.workspace.addRootFolder(val);
        }
      },
    );
    ctrl.dispose();
  }

  Future<void> _showNameDialog({
    required String                  title,
    required String                  hint,
    required TextEditingController   ctrl,
    required IsolatedTradingViewHook hook,
    required String                  confirmLabel,
    // FIX: onConfirm kini menerima FutureOr agar bisa async (untuk _onNewFile)
    required dynamic Function(String) onConfirm,
  }) async {
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: chrome.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(
            color: syntax.plain, fontSize: 15, fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller:  ctrl,
          autofocus:   true,
          style:       TextStyle(color: syntax.plain, fontSize: 13),
          cursorColor: chrome.cursorColor,
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: TextStyle(color: syntax.comment),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: chrome.gutterBorder)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: chrome.cursorColor)),
          ),
          onSubmitted: (val) {
            final v = val.trim();
            if (v.isNotEmpty) onConfirm(v);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: syntax.comment)),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) onConfirm(v);
              Navigator.pop(context);
            },
            child: Text(
              confirmLabel,
              style: TextStyle(color: chrome.cursorColor),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(ScriptFile file)      => true;
  bool _folderHasMatch(ScriptFolder folder) => true;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Indicator helpers
  // ═══════════════════════════════════════════════════════════════════════════

  void _onIndicatorSelect(IndicatorMeta ind) {
    _hook.openFile(ind.linkedFile);
    setState(() => _selectedIndicatorId = ind.id);
  }

  void _onIndicatorPreview(IndicatorMeta ind) {
    final hook = _hook;
    IndicatorPreviewSheet.show(
      context,
      indicator:  ind,
      permission: hook.permission,
      theme:      _theme,
      hook:       hook,
      onUse: () => setState(() => _selectedIndicatorId = ind.id),
    );
  }

  void _onIndicatorDelete(IndicatorMeta ind) {
    _hook.deleteFile(ind.linkedFile.id);
    setState(() {
      _indicators = _indicators.where((i) => i.id != ind.id).toList();
      if (_selectedIndicatorId == ind.id) _selectedIndicatorId = null;
    });
  }

  void _onIndicatorEdit(IndicatorMeta ind) {
    _hook.openFile(ind.linkedFile);
    setState(() {
      _selectedIndicatorId = ind.id;
      _showIndicators      = false;
    });
  }

  // FIX: _onCreateNewIndicator sekarang async karena addFile() perlu di-await.
  // Sebelumnya: final newFile = hook.workspace.addFile(...)  ← Future, crash di openFile()
  // Sesudah:    final newFile = await hook.workspace.addFile(...)
  Future<void> _onCreateNewIndicator() async {
    final hook = _hook;

    // Cari folder personal (non-shared), fallback ke root pertama
    final roots = hook.workspace.buildFolderTree();
    if (roots.isEmpty) {
      // Belum ada folder — buat dulu, lalu tunggu selesai
      await hook.workspace.addRootFolder('My Indicators');
    }

    final updatedRoots = hook.workspace.buildFolderTree();
    if (updatedRoots.isEmpty) return;

    ScriptFolder targetFolder;
    try {
      targetFolder = updatedRoots.firstWhere(
        (r) => !r.id.contains(EditorPermission.sharedOwnerId),
      );
    } catch (_) {
      targetFolder = updatedRoots.first;
    }

    // FIX: await addFile() agar newFile adalah ScriptFile, bukan Future<ScriptFile>
    final newFile = await hook.workspace.addFile(
      targetFolder.id,
      'untitled_indicator.py',
    );

    // Buka di editor — sekarang newFile adalah ScriptFile yang valid
    hook.openFile(newFile);

    // Switch ke FILES tab supaya explorer keliatan, bukan INDICATORS
    if (mounted) setState(() => _showIndicators = false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final hook   = _hook;
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;

    final editorBody = ColoredBox(
      color: chrome.background,
      child: ListenableBuilder(
        listenable: hook.editorTheme,
        builder: (context, _) => Column(
          children: [

            // ── Toolbar ────────────────────────────────────────────────────
            ListenableBuilder(
              listenable: _console,
              builder: (_, __) => EditorToolbar(
                hook:        hook,
                console:     _console,
                onZoomIn:    () => setState(() =>
                    _zoomDelta = (_zoomDelta + 1).clamp(-6.0, 14.0)),
                onZoomOut:   () => setState(() =>
                    _zoomDelta = (_zoomDelta - 1).clamp(-6.0, 14.0)),
                onZoomReset: () => setState(() => _zoomDelta = 0),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeButton(
                      tooltip:  _zenMode ? 'Exit Zen Mode' : 'Zen Mode',
                      icon:     _zenMode
                          ? Icons.blur_off_rounded
                          : Icons.center_focus_strong_rounded,
                      isActive: _zenMode,
                      chrome:   chrome,
                      onTap:    _toggleZen,
                    ),
                    const SizedBox(width: 2),
                    _ModeButton(
                      tooltip:  _fullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                      icon:     _fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      isActive: _fullscreen,
                      chrome:   chrome,
                      onTap:    _toggleFullscreen,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── Explorer ──────────────────────────────────────────────
                  if (_explorerVisible && !_zenMode) ...[
                    ValueListenableBuilder<double>(
                      valueListenable: _explorerWidth,
                      builder: (_, expW, __) => SizedBox(
                        width: expW,
                        child: Column(
                          children: [
                            _ExplorerTabSwitcher(
                              showIndicators: _showIndicators,
                              chrome:         chrome,
                              syntax:         syntax,
                              onToggle: (v) =>
                                  setState(() => _showIndicators = v),
                            ),
                            Expanded(
                              child: _showIndicators
                                  ? IndicatorListView(
                                      indicators:  _indicators,
                                      permission:  hook.permission,
                                      theme:       _theme,
                                      selectedId:  _selectedIndicatorId,
                                      onSelect:    _onIndicatorSelect,
                                      onDelete:    _onIndicatorDelete,
                                      onEdit:      _onIndicatorEdit,
                                      onCreateNew: _onCreateNewIndicator,
                                    )
                                  : FileExplorerPanel(
                                      hook:             hook,
                                      width:            expW,
                                      scrollController: _explorerScrollCtrl,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ResizableDivider(
                      axis:   Axis.vertical,
                      chrome: chrome,
                      onDrag: (delta) {
                        _explorerWidth.value =
                            (_explorerWidth.value + delta)
                                .clamp(_minExplorer, _maxExplorer);
                      },
                    ),
                  ],

                  // ── Editor column ─────────────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [

                        // ── Tab bar ──────────────────────────────────────────
                        SizedBox(
                          height: 36,
                          child: Row(
                            children: [
                              if (!_zenMode)
                                _ExplorerToggle(
                                  isVisible: _explorerVisible,
                                  chrome:    chrome,
                                  onTap: () => setState(() =>
                                      _explorerVisible = !_explorerVisible),
                                ),
                              Expanded(child: tab_bar_lib.EditorTabBar(hook: hook)),
                            ],
                          ),
                        ),

                        // ── Code editor ──────────────────────────────────────
                        Expanded(
                          child: CodeEditorWidget(
                            hook:                   hook,
                            gutterScrollController: _gutterScrollCtrl,
                            codeScrollVController:  _codeScrollVCtrl,
                            codeScrollHController:  _codeScrollHCtrl,
                            onCodeChanged:          _onCodeChanged,
                            onActiveLineChanged:    _onActiveLineChanged,
                            zoomDelta:              _zoomDelta,
                          ),
                        ),

                        // ── Console ──────────────────────────────────────────
                        if (!_zenMode) ...[
                          ResizableDivider(
                            axis:   Axis.horizontal,
                            chrome: chrome,
                            onDrag: (delta) {
                              _consoleHeight.value =
                                  (_consoleHeight.value - delta)
                                      .clamp(_minConsole, _maxConsole);
                            },
                            child: _ConsoleToggleBar(
                              chrome:          chrome,
                              console:         _console,
                              consoleExpanded: _consoleExpanded,
                              onToggle: () => setState(() =>
                                  _consoleExpanded = !_consoleExpanded),
                            ),
                          ),
                          if (_consoleExpanded)
                            ValueListenableBuilder<double>(
                              valueListenable: _consoleHeight,
                              builder: (_, h, __) => SizedBox(
                                height: h,
                                child: OutputConsolePanel(
                                  hook:             hook,
                                  console:          _console,
                                  scrollController: _consoleScrollCtrl,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (_fullscreen) {
      return Stack(
        children: [
          const SizedBox.expand(),
          Positioned.fill(
            child: Material(color: Colors.transparent, child: editorBody),
          ),
        ],
      );
    }

    return editorBody;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ModeButton
// ─────────────────────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.tooltip,
    required this.icon,
    required this.isActive,
    required this.chrome,
    required this.onTap,
  });

  final String             tooltip;
  final IconData           icon;
  final bool               isActive;
  final EditorChromeColors chrome;
  final VoidCallback       onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message:      tooltip,
    waitDuration: const Duration(milliseconds: 600),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:    const Duration(milliseconds: 150),
        width:  28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive
              ? chrome.cursorColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: chrome.cursorColor.withOpacity(0.4))
              : null,
        ),
        child: Icon(
          icon,
          size:  15,
          color: isActive ? chrome.cursorColor : chrome.lineNumberDefault,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExplorerTabSwitcher
// ─────────────────────────────────────────────────────────────────────────────

class _ExplorerTabSwitcher extends StatelessWidget {
  const _ExplorerTabSwitcher({
    required this.showIndicators,
    required this.chrome,
    required this.syntax,
    required this.onToggle,
  });

  final bool                showIndicators;
  final EditorChromeColors  chrome;
  final EditorSyntaxColors  syntax;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    decoration: BoxDecoration(
      color:  chrome.toolbarBackground,
      border: Border(bottom: BorderSide(color: chrome.gutterBorder)),
    ),
    child: Row(
      children: [
        _Tab(label: 'FILES',      isActive: !showIndicators,
            chrome: chrome, syntax: syntax, onTap: () => onToggle(false)),
        _Tab(label: 'INDICATORS', isActive:  showIndicators,
            chrome: chrome, syntax: syntax, onTap: () => onToggle(true)),
      ],
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.isActive,
    required this.chrome,
    required this.syntax,
    required this.onTap,
  });

  final String             label;
  final bool               isActive;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding:  const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isActive ? chrome.cursorColor : Colors.transparent,
            width: 1.5,
          ),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color:         isActive ? chrome.cursorColor : chrome.lineNumberDefault,
            fontSize:      9.5,
            fontWeight:    FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExplorerToggle
// ─────────────────────────────────────────────────────────────────────────────

class _ExplorerToggle extends StatelessWidget {
  const _ExplorerToggle({
    required this.isVisible,
    required this.chrome,
    required this.onTap,
  });

  final bool               isVisible;
  final EditorChromeColors chrome;
  final VoidCallback       onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      width: 36,
      color: chrome.tabInactive,
      child: Icon(
        isVisible ? Icons.folder_open_rounded : Icons.folder_outlined,
        size:  15,
        color: isVisible
            ? chrome.cursorColor.withOpacity(0.7)
            : chrome.lineNumberDefault,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ConsoleToggleBar
// ─────────────────────────────────────────────────────────────────────────────

class _ConsoleToggleBar extends StatelessWidget {
  const _ConsoleToggleBar({
    required this.chrome,
    required this.console,
    required this.consoleExpanded,
    required this.onToggle,
  });

  final EditorChromeColors chrome;
  final ConsoleState       console;
  final bool               consoleExpanded;
  final VoidCallback       onToggle;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: console,
    builder: (_, __) => GestureDetector(
      onTap: onToggle,
      child: Container(
        height:  26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color:  chrome.toolbarBackground,
          border: Border(top: BorderSide(color: chrome.gutterBorder)),
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns:    consoleExpanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.expand_less_rounded,
                  size: 14, color: chrome.lineNumberDefault),
            ),
            const SizedBox(width: 6),
            Text(
              'OUTPUT',
              style: TextStyle(
                color:         chrome.lineNumberDefault,
                fontSize:      9.5,
                fontWeight:    FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            if (console.isRunning) ...[
              const SizedBox(width: 8),
              SizedBox(
                width:  10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color:       chrome.cursorColor,
                ),
              ),
            ],
            const Spacer(),
            if (console.errorCount > 0) ...[
              Icon(Icons.error_outline_rounded,
                  size: 10, color: chrome.consoleTextError),
              const SizedBox(width: 3),
              Text(
                '${console.errorCount}',
                style: TextStyle(
                  color:      chrome.consoleTextError,
                  fontSize:   10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${console.logs.length} lines',
              style: TextStyle(color: chrome.lineNumberDefault, fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}