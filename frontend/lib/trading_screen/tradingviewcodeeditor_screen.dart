// =============================================================================
// tradingviewcodeeditor_screen.dart
// FIX _onIndicatorEdit:
//   Pass editorContent: const TradingViewCodeEditorScreen() ke TradingViewPages.
//   _TradingViewShell render widget itu → full editor dengan FILES tab +
//   folder tree dari backend. Sebelumnya tidak dipass → render _EditorReadyState
//   (text editor polos tanpa file explorer sidebar).
//
// FIX _runCode:
//   Resolve cwd dari WorkspaceState via cwdFromWorkspace() dan pass ke
//   _console.executeCode(). Tanpa ini, Python subprocess tidak tau di mana
//   modul lokal berada → ModuleNotFoundError: No module named 'X'.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../hooks/tradingview_hook.dart';
import '../../hooks/indikator_hook.dart';
import '../../utils/auth_storage.dart';
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

  late final ValueNotifier<double> _explorerWidth = ValueNotifier(240);
  late final ValueNotifier<double> _consoleHeight = ValueNotifier(180);

  bool   _consoleExpanded = true;
  bool   _explorerVisible = true;
  bool   _zenMode         = false;
  bool   _fullscreen      = false;
  double _zoomDelta       = 0;

  static const double _minExplorer     = 160;
  static const double _maxExplorer     = 400;
  static const double _minConsole      = 120;
  static const double _maxConsole      = 400;
  static const double _kFixedOverhead  = 36.0 + 26.0 + 6.0;
  static const double _kExplorerTabH   = 32.0;
  static const double _kZenMinH        = 36.0;
  static const double _kToolbarH       = 40.0;

  final ConsoleState     _console            = ConsoleState();
  final BreakpointState  _breakpoints        = BreakpointState();
  final ScrollController _gutterScrollCtrl   = ScrollController();
  final ScrollController _codeScrollVCtrl    = ScrollController();
  final ScrollController _codeScrollHCtrl    = ScrollController();
  final ScrollController _consoleScrollCtrl  = ScrollController();
  final ScrollController _explorerScrollCtrl = ScrollController();

  int?   _activeLineIndex;
  int    _lineCount = 1;

  bool    _showIndicators      = false;
  String? _selectedIndicatorId;

  List<IndicatorMeta> _indicators        = [];
  bool                _indicatorsLoading = false;

  bool _syncingGutter     = false;
  bool _gutterSyncPending = false;

  @override
  void initState() {
    super.initState();
    _codeScrollVCtrl.addListener(_syncGutterToCode);
    _loadIndicators();
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
    if (_syncingGutter || _gutterSyncPending) return;
    if (!_codeScrollVCtrl.hasClients) return;

    _gutterSyncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gutterSyncPending = false;
      if (!mounted || _syncingGutter) return;
      if (!_codeScrollVCtrl.hasClients || !_gutterScrollCtrl.hasClients) return;
      if (!_codeScrollVCtrl.position.hasContentDimensions) return;
      if (!_gutterScrollCtrl.position.hasContentDimensions) return;

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
    });
  }

  IsolatedTradingViewHook get _hook  => IsolatedHookProvider.of(context);
  EditorThemeState        get _theme => _hook.editorTheme.theme;

  ScriptFile? _getActiveFile(IsolatedTradingViewHook hook) =>
      hook.tabs.activeFile;

  List<IndicatorMeta> _buildIndicators(IsolatedTradingViewHook hook) {
    final files   = hook.workspace.files;
    final folders = hook.workspace.folders;
    final userId  = hook.permission.userId ?? 'user';

    final result          = <IndicatorMeta>[];
    final assignedFileIds = <String>{};

    final rootFolders = folders.where((f) => f.parentFolderId == null).toList();

    for (final folder in rootFolders) {
      final folderFiles = files
          .where((f) =>
              f.parentFolderId == folder.id && !f.id.startsWith('tmp_'))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      ScriptFile? entryFile;
      for (final name in ['main.py', 'main.pine', 'main.js']) {
        try {
          entryFile = folderFiles.firstWhere(
            (f) => f.name.toLowerCase() == name,
          );
          break;
        } catch (_) {}
      }
      entryFile ??= folderFiles.isNotEmpty ? folderFiles.first : null;

      for (final f in folderFiles) {
        assignedFileIds.add(f.id);
      }

      final haystack  = '${folder.name} ${entryFile?.name ?? ''}'.toLowerCase();
      final category  = _resolveCategory(haystack);
      final ownership = (entryFile?.isShared ?? false)
          ? IndicatorOwnership.shared
          : IndicatorOwnership.personal;

      final updatedAt = entryFile?.updatedAt ??
          (folderFiles.isNotEmpty
              ? folderFiles
                  .reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b)
                  .updatedAt
              : DateTime.now());

      final previewCode =
          entryFile?.content.split('\n').take(8).join('\n') ?? '';

      final String description;
      if (folderFiles.isEmpty) {
        description = 'Empty indicator — no files yet';
      } else if (folderFiles.length == 1) {
        description = folderFiles.first.name;
      } else {
        description =
            '${folderFiles.length} files · ${folderFiles.map((f) => f.name).join(', ')}';
      }

      final tags       = entryFile != null ? [_langTag(entryFile.language)] : <String>[];
      final linkedFile = entryFile ??
          ScriptFile(
            id:             folder.id,
            name:           '${folder.name}.py',
            content:        '',
            createdAt:      updatedAt,
            updatedAt:      updatedAt,
            parentFolderId: folder.id,
          );

      result.add(IndicatorMeta(
        id:          folder.id,
        name:        folder.name,
        description: description,
        category:    category,
        ownership:   ownership,
        authorId:    userId,
        authorLabel: 'You',
        tags:        tags,
        previewCode: previewCode,
        linkedFile:  linkedFile,
        updatedAt:   updatedAt,
      ));
    }

    for (final file in files) {
      if (file.id.startsWith('tmp_'))        continue;
      if (assignedFileIds.contains(file.id)) continue;
      if (file.parentFolderId != null)       continue;

      String displayName = file.name;
      for (final ext in ['.py', '.pine', '.js']) {
        if (displayName.endsWith(ext)) {
          displayName = displayName.substring(0, displayName.length - ext.length);
          break;
        }
      }

      result.add(IndicatorMeta(
        id:          file.id,
        name:        displayName,
        description: file.name,
        category:    _resolveCategory(file.name.toLowerCase()),
        ownership:   file.isShared
            ? IndicatorOwnership.shared
            : IndicatorOwnership.personal,
        authorId:    userId,
        authorLabel: 'You',
        tags:        [_langTag(file.language)],
        previewCode: file.content.split('\n').take(8).join('\n'),
        linkedFile:  file,
        updatedAt:   file.updatedAt,
      ));
    }

    result.sort((a, b) {
      if (a.isShared != b.isShared) return a.isShared ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return result;
  }

  IndicatorCategory _resolveCategory(String haystack) {
    if (_containsAny(haystack, ['rsi', 'macd', 'momentum', 'stoch', 'cci'])) {
      return IndicatorCategory.momentum;
    } else if (_containsAny(haystack, ['ema', 'sma', 'trend', 'moving'])) {
      return IndicatorCategory.trend;
    } else if (_containsAny(haystack, ['atr', 'bollinger', 'volatil', 'bb'])) {
      return IndicatorCategory.volatility;
    } else if (_containsAny(haystack, ['volume', 'vwap', 'obv'])) {
      return IndicatorCategory.volume;
    }
    return IndicatorCategory.custom;
  }

  bool _containsAny(String haystack, List<String> keywords) =>
      keywords.any((k) => haystack.contains(k));

  String _langTag(ScriptLanguage lang) {
    switch (lang) {
      case ScriptLanguage.python:     return 'Python';
      case ScriptLanguage.pinescript: return 'Pine Script';
      case ScriptLanguage.javascript: return 'JavaScript';
    }
  }

  Future<void> _loadIndicators() async {
    if (!mounted) return;
    setState(() => _indicatorsLoading = true);
    final token  = await AuthStorage.getToken() ?? '';
    final result = await Indicator_Exclusive_Hook.GetAllIndicators();
    if (!mounted) return;
    setState(() {
      _indicatorsLoading = false;
      if (result['success'] == true) {
        _indicators = result['data'] as List<IndicatorMeta>;
      }
    });
  }

  // ── FIX: _runCode ─────────────────────────────────────────────────────────
  //
  // Sebelumnya: cwd tidak pernah dipass ke _console.executeCode()
  // → Python subprocess tidak tau di mana modul lokal berada
  // → ModuleNotFoundError: No module named 'X'
  //
  // Sekarang: cwdFromWorkspace() resolve folder path dari WorkspaceState
  // berdasarkan parentFolderId file aktif, lalu diforward ke executeCode().
  // File di root → cwd null → backend pakai default working directory.
  
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
 
    // Resolve root folder_id dari workspace.
    // null kalau file tidak berada dalam folder manapun.
    final folderId = activeFile != null
        ? folderIdFromWorkspace(hook.workspace, activeFile)  // ← FIX: was cwdFromWorkspace
        : null;
 
    await _console.executeCode(
      code,
      fileName: activeFile?.name,
      folderId: folderId,   // ← FIX: was cwd
    );
 
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

  void _onCodeChanged(String content) {
    final count = '\n'.allMatches(content).length + 1;
    if (count != _lineCount) _lineCount = count;
  }

  void _onActiveLineChanged(int lineIndex) {
    if (lineIndex != _activeLineIndex) _activeLineIndex = lineIndex;
  }

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
            syntax.plain.withValues(alpha: 0.8), chrome),
        _menuItem('rename', Icons.edit_outlined,          'Rename',
            syntax.plain.withValues(alpha: 0.8), chrome),
        _menuItem('delete', Icons.delete_outline_rounded, 'Delete',
            chrome.consoleTextError,              chrome),
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

  Future<void> _showRenameDialog(ScriptFile file) async {
    final newName = await _showNameDialog(
      title:        'Rename File',
      hint:         'filename.py',
      hook:         _hook,
      confirmLabel: 'Rename',
      initialValue: file.name,
    );
    if (newName != null && newName.isNotEmpty) {
      _hook.workspace.renameFile(file.id, newName);
    }
  }

  Future<void> _onNewFile(String parentFolderId) async {
    final name = await _showNameDialog(
      title:        'New File',
      hint:         'filename.py',
      hook:         _hook,
      confirmLabel: 'Create',
    );
    if (name != null && name.isNotEmpty) {
      final f = await _hook.workspace.addFile(parentFolderId, name);
      _hook.openFile(f);
    }
  }

  Future<void> _onNewFolder(String? parentFolderId) async {
    final name = await _showNameDialog(
      title:        'New Folder',
      hint:         'folder name',
      hook:         _hook,
      confirmLabel: 'Create',
    );
    if (name != null && name.isNotEmpty) {
      if (parentFolderId != null) {
        _hook.workspace.addFolder(parentFolderId, name);
      } else {
        _hook.workspace.addRootFolder(name);
      }
    }
  }

  Future<String?> _showNameDialog({
    required String                  title,
    required String                  hint,
    required IsolatedTradingViewHook hook,
    required String                  confirmLabel,
    String                           initialValue = '',
  }) async {
    final ctrl   = TextEditingController(text: initialValue);
    String? result;
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
            if (v.isNotEmpty) result = v;
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
              if (v.isNotEmpty) result = v;
              Navigator.pop(context);
            },
            child: Text(confirmLabel,
                style: TextStyle(color: chrome.cursorColor)),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    return result;
  }

  bool _matchesSearch(ScriptFile file)      => true;
  bool _folderHasMatch(ScriptFolder folder) => true;

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

  Future<void> _onIndicatorDelete(IndicatorMeta ind) async {
    final token  = await AuthStorage.getToken() ?? '';
    final result = await Indicator_Exclusive_Hook.DeleteIndicator(
      token:       token,
      indicatorId: ind.id,
    );
    if (result['success'] == true) {
      if (_selectedIndicatorId == ind.id) {
        setState(() => _selectedIndicatorId = null);
      }
      _loadIndicators();
    }
  }

  void _onIndicatorEdit(IndicatorMeta ind) async {
    final token  = await AuthStorage.getToken() ?? '';
    final userId = _hook.permission.userId;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradingViewPages(
          token:         token,
          userId:        userId,
          indicatorId:   ind.id,
          editorContent: const TradingViewCodeEditorScreen(),
        ),
      ),
    );
  }

  Future<void> _onCreateNewIndicator() async {
    final hook = _hook;

    final indicatorName = await _showNameDialog(
      title:        'New Indicator',
      hint:         'indicator name (e.g. RSI Custom)',
      hook:         hook,
      confirmLabel: 'Create',
    );

    if (indicatorName == null || indicatorName.isEmpty) return;

    try {
      await hook.workspace.addRootFolder(indicatorName);

      final newFolder = hook.workspace.folders.lastWhere(
        (f) => f.name == indicatorName && f.parentFolderId == null,
      );

      final newFile = await hook.workspace.addFile(newFolder.id, 'main.py');
      hook.openFile(newFile);

    } catch (e) {
      debugPrint('[_onCreateNewIndicator] error: $e');
    } finally {
      if (mounted) {
        setState(() => _showIndicators = false);
        _loadIndicators();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hook   = _hook;
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;
    final bool isZen = _zenMode;

    final editorBody = ColoredBox(
      color: chrome.background,
      child: ListenableBuilder(
        listenable: Listenable.merge([hook.editorTheme, hook.workspace]),
        builder: (context, _) {
          if (hook.workspace.isLoading) {
            return _LoadingView(chrome: chrome);
          }

          if (hook.workspace.error != null) {
            return _ErrorView(
              error:   hook.workspace.error!,
              chrome:  chrome,
              syntax:  syntax,
              onRetry: () => hook.workspace.loadFromServer(),
            );
          }

          final liveIndicators = _indicators;

          return LayoutBuilder(
            builder: (context, lc) {
              final double availH = lc.maxHeight;
              final double tH = availH.clamp(0.0, _kToolbarH);
              final double eH = (availH - tH).clamp(0.0, double.infinity);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  SizedBox(
                    height: tH,
                    child: ClipRect(
                      child: EditorToolbar(
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
                  ),

                  if (eH > 0)
                    SizedBox(
                      height: eH,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          if (_explorerVisible && !_zenMode) ...[
                            ValueListenableBuilder<double>(
                              valueListenable: _explorerWidth,
                              builder: (_, expW, __) => LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxHeight < _kExplorerTabH) {
                                    return SizedBox(
                                      width:  expW,
                                      height: constraints.maxHeight,
                                      child:  ColoredBox(color: chrome.sidebarBackground),
                                    );
                                  }

                                  return SizedBox(
                                    width: expW,
                                    child: ClipRect(
                                      child: Column(
                                        children: [
                                          _ExplorerTabSwitcher(
                                            showIndicators: _showIndicators,
                                            chrome:         chrome,
                                            syntax:         syntax,
                                            onToggle: (v) {
                                              setState(() => _showIndicators = v);
                                              if (v) _loadIndicators();
                                            },
                                          ),
                                          Expanded(
                                            child: _showIndicators
                                                ? IndicatorListView(
                                                    indicators:  liveIndicators,
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
                                  );
                                },
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

                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double minRequired =
                                    isZen ? _kZenMinH : _kFixedOverhead;
                                if (constraints.maxHeight < minRequired) {
                                  return ColoredBox(color: chrome.background);
                                }

                                final double dynamicMaxConsole =
                                    (constraints.maxHeight - _kFixedOverhead)
                                        .clamp(0.0, _maxConsole);

                                return Column(
                                  children: [

                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 36,
                                        maxHeight: 36,
                                      ),
                                      child: ClipRect(
                                        child: Row(
                                          children: [
                                            if (!_zenMode)
                                              _ExplorerToggle(
                                                isVisible: _explorerVisible,
                                                chrome:    chrome,
                                                onTap: () => setState(() =>
                                                    _explorerVisible = !_explorerVisible),
                                              ),
                                            Expanded(
                                              child: tab_bar_lib.EditorTabBar(hook: hook),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

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

                                    if (!_zenMode) ...[
                                      ResizableDivider(
                                        axis:   Axis.horizontal,
                                        chrome: chrome,
                                        onDrag: (delta) {
                                          _consoleHeight.value =
                                              (_consoleHeight.value - delta)
                                                  .clamp(_minConsole, dynamicMaxConsole);
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
                                            height: h.clamp(0.0, dynamicMaxConsole),
                                            child: ClipRect(
                                              child: OutputConsolePanel(
                                                hook:             hook,
                                                console:          _console,
                                                scrollController: _consoleScrollCtrl,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );

    final shortcutWrapper = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          final active = _hook.tabs.activeFile;
          if (active != null && _hook.canEditActive && active.isModified) {
            _hook.saveActiveFile();
          }
        },
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () {
          setState(() => _zoomDelta = (_zoomDelta + 1).clamp(-6.0, 14.0));
        },
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () {
          setState(() => _zoomDelta = (_zoomDelta - 1).clamp(-6.0, 14.0));
        },
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): () {
          setState(() => _zoomDelta = 0);
        },
      },
      child: Focus(
        autofocus: true,
        child: editorBody,
      ),
    );

    if (_fullscreen) {
      return Stack(
        children: [
          const SizedBox.expand(),
          Positioned.fill(
            child: Material(color: Colors.transparent, child: shortcutWrapper),
          ),
        ],
      );
    }

    return shortcutWrapper;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LoadingView
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final EditorChromeColors chrome;
  const _LoadingView({required this.chrome});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color:       chrome.cursorColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading workspace...',
          style: TextStyle(color: chrome.lineNumberDefault, fontSize: 13),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ErrorView
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String             error;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onRetry;

  const _ErrorView({
    required this.error,
    required this.chrome,
    required this.syntax,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 32, color: chrome.consoleTextError),
          const SizedBox(height: 12),
          Text(
            'Failed to load workspace',
            style: TextStyle(
              color:      syntax.plain,
              fontSize:   14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style:     TextStyle(color: syntax.comment, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines:  3,
            overflow:  TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon:  Icon(Icons.refresh_rounded, size: 16, color: chrome.cursorColor),
            label: Text('Retry', style: TextStyle(color: chrome.cursorColor)),
          ),
        ],
      ),
    ),
  );
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
        duration: const Duration(milliseconds: 150),
        width:  28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive
              ? chrome.cursorColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: chrome.cursorColor.withValues(alpha: 0.4))
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
        Expanded(
          child: _Tab(
            label:    'FILES',
            isActive: !showIndicators,
            chrome:   chrome,
            syntax:   syntax,
            onTap:    () => onToggle(false),
          ),
        ),
        Expanded(
          child: _Tab(
            label:    'INDICATORS',
            isActive:  showIndicators,
            chrome:    chrome,
            syntax:    syntax,
            onTap:     () => onToggle(true),
          ),
        ),
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
          overflow: TextOverflow.ellipsis,
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
            ? chrome.cursorColor.withValues(alpha: 0.7)
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
        child: ClipRect(
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    style: TextStyle(
                      color:    chrome.lineNumberDefault,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}