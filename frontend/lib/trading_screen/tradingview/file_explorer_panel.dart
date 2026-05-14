// =============================================================================
// file_explorer_panel.dart
// FIX OVERFLOW v7 — FINAL:
//
//  Root cause overflow v6:
//    Semua guard sebelumnya (canShowFooter, canShowSearch, dll) berhasil
//    menekan elemen opsional, tapi TIDAK ada guard untuk header itu sendiri.
//    Ketika availH = 34.8px dan _kHeaderH = 38px, Column selalu mencoba
//    render header 38px di dalam container 34.8px → overflow 3.2px persis
//    sesuai error log. treeH di-clamp ke 0 sehingga kontribusinya nol,
//    tapi header tetap overflow.
//
//  Solusi v7 (surgical, single change):
//    Tambah early return SATU BLOK setelah treeH dihitung (di dalam
//    ListenableBuilder), sebelum SizedBox + Column di-render:
//
//      if (availH < _kHeaderH) {
//        return SizedBox(
//          width:  widget.width,
//          height: availH,
//          child: ColoredBox(color: chrome.sidebarBackground),
//        );
//      }
//
//    Kalau ruang < 38px, return ColoredBox tipis saja — tidak ada Column,
//    tidak ada header, tidak ada overflow assertion.
//
//  Semua fix dari v4–v6 tetap dipertahankan.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../hooks/tradingview_hook.dart';
import '../../../pages/tradingview_pages.dart';
import '../../../style/apps_colors_tradingview.dart';
import '../../../models/script_folder.dart';
import '../../../models/script_file.dart';

import 'folder_tree_tile.dart';
import 'file_tile.dart';
import 'context_menu_file.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PathHoverNotifier
// ─────────────────────────────────────────────────────────────────────────────

class _PathHoverNotifier extends ValueNotifier<List<String>?> {
  _PathHoverNotifier() : super(null);
}

// ─────────────────────────────────────────────────────────────────────────────
//  FileExplorerPanel
// ─────────────────────────────────────────────────────────────────────────────

class FileExplorerPanel extends StatefulWidget {
  final IsolatedTradingViewHook hook;
  final double                  width;
  final ScrollController?       scrollController;

  const FileExplorerPanel({
    super.key,
    required this.hook,
    this.width            = 240,
    this.scrollController,
  });

  @override
  State<FileExplorerPanel> createState() => _FileExplorerPanelState();
}

class _FileExplorerPanelState extends State<FileExplorerPanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl  = TextEditingController();
  final _PathHoverNotifier    _hoveredPath = _PathHoverNotifier();

  String _searchQuery = '';
  bool   _showSearch  = false;
  late AnimationController _searchAnimCtrl;
  late Animation<double>   _searchAnim;

  IsolatedTradingViewHook get hook => widget.hook;
  EditorPermission        get perm => hook.permission;

  // Tinggi eksplisit setiap fixed child.
  static const double _kHeaderH  = 38.0;
  static const double _kSearchH  = 42.0;
  static const double _kPathBarH = 26.0;
  static const double _kDividerH =  1.0;
  static const double _kFooterH  = 24.0;

  // Threshold gate elemen opsional.
  static const double _kMinForFooter  = _kHeaderH + _kFooterH + 1;
  static const double _kMinForPathBar = _kMinForFooter + _kPathBarH + _kDividerH;
  static const double _kMinForSearch  = _kMinForPathBar + _kSearchH + 1;

  @override
  void initState() {
    super.initState();
    _searchAnimCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _searchAnim = CurvedAnimation(
      parent: _searchAnimCtrl,
      curve:  Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchAnimCtrl.dispose();
    _hoveredPath.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (_showSearch) {
      _searchAnimCtrl.forward();
    } else {
      _searchAnimCtrl.reverse();
      _searchCtrl.clear();
      setState(() => _searchQuery = '');
    }
  }

  bool _isSharedFolder(String? folderId) {
    if (folderId == null) return false;
    final sharedId = EditorPermission.sharedOwnerId ?? '';
    if (sharedId.isEmpty) return false;
    return folderId.contains(sharedId);
  }

  int _countFiles(ScriptFolder folder) {
    return folder.files.length +
        folder.subFolders.fold<int>(
          0,
          (sum, sub) => sum + _countFiles(sub),
        );
  }

  ScriptFolder? _resolveDefaultFolder() {
    final roots = hook.workspace.buildFolderTree();
    if (roots.isEmpty) return null;
    try {
      return roots.firstWhere(
        (r) => !r.id.contains(EditorPermission.sharedOwnerId ?? ''),
      );
    } catch (_) {
      return roots.first;
    }
  }

  Future<void> _showNewFileDialog(String parentFolderId) async {
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;
    final ctrl   = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewItemDialog(
        title: 'New File', hint: 'filename.py',
        chrome: chrome, syntax: syntax, ctrl: ctrl,
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    if (!perm.canCreate) {
      _showPermissionError('Permission denied: cannot create file here');
      return;
    }

    final file = await hook.workspace.addFile(parentFolderId, name.trim());
    hook.openFile(file);
  }

  Future<void> _showNewFolderDialog(String? parentFolderId) async {
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;
    final ctrl   = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewItemDialog(
        title: 'New Folder', hint: 'folder_name',
        chrome: chrome, syntax: syntax, ctrl: ctrl,
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    if (parentFolderId != null) {
      await hook.workspace.addFolder(parentFolderId, name.trim());
    } else {
      await hook.workspace.addRootFolder(name.trim());
    }
  }

  void _showPermissionError(String msg) {
    final chrome = hook.editorTheme.chrome;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg, style: TextStyle(color: chrome.consoleTextError, fontSize: 12)),
        backgroundColor: chrome.surface,
        behavior:        SnackBarBehavior.floating,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration:        const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyPathToClipboard(String path) async {
    if (path.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    final chrome = hook.editorTheme.chrome;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_outline_rounded, size: 13,
              color: chrome.consoleTextSuccess),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Path copied: $path',
              style: TextStyle(color: chrome.consoleTextSuccess, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        backgroundColor: chrome.surface,
        behavior:  SnackBarBehavior.floating,
        shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration:  const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleContextMenu(
    BuildContext ctx,
    Offset globalPos,
    ScriptFile file,
    String resolvedPath,
  ) async {
    final isInShared = _isSharedFolder(file.parentFolderId);

    final canEdit   = !isInShared || perm.isAdmin;
    final canDelete = !isInShared || perm.isAdmin;
    final canRename = !isInShared || perm.isAdmin;

    final action = await showContextMenuFile(
      context:      ctx,
      position:     globalPos,
      chrome:       hook.editorTheme.chrome,
      syntax:       hook.editorTheme.syntax,
      file:         file,
      canEdit:      canEdit,
      canDelete:    canDelete,
      canRename:    canRename,
      isAdmin:      perm.isAdmin,
      isShared:     isInShared,
      resolvedPath: resolvedPath,
    );

    if (action == null || !mounted) return;

    switch (action) {
      case ContextMenuAction.rename:
        await _renameFile(file);
      case ContextMenuAction.delete:
        await _confirmDelete(file);
      case ContextMenuAction.newFileHere:
        await _showNewFileDialog(file.parentFolderId ?? '');
      case ContextMenuAction.newFolderHere:
        await _showNewFolderDialog(file.parentFolderId);
      case ContextMenuAction.publishShared:
        _publishToShared(file);
      case ContextMenuAction.copyPath:
        await _copyPathToClipboard(resolvedPath);
    }
  }

  Future<void> _renameFile(ScriptFile file) async {
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;
    final ctrl   = TextEditingController(text: file.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _NewItemDialog(
        title: 'Rename File', hint: file.name,
        chrome: chrome, syntax: syntax, ctrl: ctrl,
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;

    final isInShared = _isSharedFolder(file.parentFolderId);
    if (isInShared && !perm.isAdmin) {
      _showPermissionError('Permission denied: cannot rename shared file');
      return;
    }

    await hook.workspace.renameFile(file.id, newName.trim());
  }

  Future<void> _confirmDelete(ScriptFile file) async {
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: chrome.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete File',
            style: TextStyle(color: syntax.plain, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${file.name}"? This action cannot be undone.',
          style: TextStyle(color: syntax.comment, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: syntax.comment)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: chrome.consoleTextError)),
          ),
        ],
      ),
    );

    if (confirmed == true) await hook.deleteFile(file.id);
  }

  void _publishToShared(ScriptFile file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${file.name}" published to shared indicators.',
          style: TextStyle(
            color: hook.editorTheme.chrome.consoleTextSuccess,
            fontSize: 12,
          ),
        ),
        backgroundColor: hook.editorTheme.chrome.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final availH = outerConstraints.maxHeight;

        final canShowFooter  = availH >= _kMinForFooter;
        final canShowPathBar = availH >= _kMinForPathBar;
        final canShowSearch  = _showSearch && availH >= _kMinForSearch;

        return ListenableBuilder(
          listenable: Listenable.merge([hook.workspace, hook.editorTheme, hook.tabs]),
          builder: (context, _) {
            final chrome = hook.editorTheme.chrome;
            final syntax = hook.editorTheme.syntax;

            // ── FIX v7: hard guard ─────────────────────────────────────────
            // Kalau ruang < header height (38px), Column pasti overflow krn
            // header itu sendiri sudah melebihi availH. Return ColoredBox
            // tipis — tidak ada Column, tidak ada assertion.
            if (availH < _kHeaderH) {
              return SizedBox(
                width:  widget.width,
                height: availH,
                child: ColoredBox(color: chrome.sidebarBackground),
              );
            }
            // ──────────────────────────────────────────────────────────────

            final activeFile     = hook.tabs.activeFile;
            final activeSegments = activeFile != null
                ? hook.workspace.getFilePathSegments(activeFile.id)
                : null;

            final resolvedSegments = _hoveredPath.value ?? activeSegments;
            final hasPathSegments  = canShowPathBar &&
                resolvedSegments != null &&
                resolvedSegments.isNotEmpty;

            double fixedH = _kHeaderH;
            if (canShowSearch)   fixedH += _kSearchH;
            if (hasPathSegments) fixedH += _kPathBarH + _kDividerH;
            if (canShowFooter)   fixedH += _kFooterH;

            // Clamp ke 0 — tidak pernah negatif.
            final treeH = (availH - fixedH).clamp(0.0, double.infinity);

            return SizedBox(
              width:  widget.width,
              height: availH,
              child: ClipRect(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: chrome.sidebarBackground,
                    border: Border(
                      right: BorderSide(color: chrome.gutterBorder, width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Header ─────────────────────────────────────────
                      _ExplorerHeader(
                        perm:           perm,
                        chrome:         chrome,
                        syntax:         syntax,
                        showSearch:     _showSearch,
                        onToggleSearch: _toggleSearch,
                        onNewFile: () {
                          final defaultFolder = _resolveDefaultFolder();
                          if (defaultFolder != null) {
                            _showNewFileDialog(defaultFolder.id);
                          }
                        },
                        onNewFolder: () => _showNewFolderDialog(null),
                      ),

                      // ── Search bar ─────────────────────────────────────
                      if (canShowSearch)
                        SizeTransition(
                          sizeFactor:    _searchAnim,
                          axisAlignment: -1,
                          child: _SearchBar(
                            ctrl:      _searchCtrl,
                            chrome:    chrome,
                            syntax:    syntax,
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),

                      // ── Path bar + divider ─────────────────────────────
                      if (hasPathSegments)
                        _ActivePathBar(
                          segments:   resolvedSegments!,
                          chrome:     chrome,
                          syntax:     syntax,
                          onCopyPath: _copyPathToClipboard,
                        ),
                      if (hasPathSegments)
                        Divider(height: _kDividerH, color: chrome.gutterBorder),

                      // ── File tree ──────────────────────────────────────
                      SizedBox(
                        height: treeH,
                        child: ClipRect(
                          child: _FileTree(
                            hook:                hook,
                            perm:                perm,
                            chrome:              chrome,
                            syntax:              syntax,
                            searchQuery:         _searchQuery,
                            scrollController:    widget.scrollController,
                            hoveredPathNotifier: _hoveredPath,
                            onOpenFile:          hook.openFile,
                            onContextMenu:       _handleContextMenu,
                            onNewFile:           _showNewFileDialog,
                            onNewFolder:         _showNewFolderDialog,
                          ),
                        ),
                      ),

                      // ── Footer ─────────────────────────────────────────
                      if (canShowFooter)
                        _ExplorerFooter(
                          hook:       hook,
                          chrome:     chrome,
                          syntax:     syntax,
                          countFiles: _countFiles,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExplorerHeader
// ─────────────────────────────────────────────────────────────────────────────

class _ExplorerHeader extends StatelessWidget {
  final EditorPermission   perm;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final bool               showSearch;
  final VoidCallback       onToggleSearch;
  final VoidCallback       onNewFile;
  final VoidCallback       onNewFolder;

  const _ExplorerHeader({
    required this.perm,
    required this.chrome,
    required this.syntax,
    required this.showSearch,
    required this.onToggleSearch,
    required this.onNewFile,
    required this.onNewFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              'EXPLORER',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: syntax.plain.withOpacity(0.45), fontSize: 9.5,
                fontWeight: FontWeight.w800, letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderIconBtn(
                icon:    showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                chrome:  chrome, syntax: syntax,
                onTap:   onToggleSearch, tooltip: 'Search files',
              ),
              if (perm.canCreate) ...[
                const SizedBox(width: 2),
                _HeaderIconBtn(icon: Icons.add_rounded, chrome: chrome, syntax: syntax, onTap: onNewFile, tooltip: 'New file'),
                const SizedBox(width: 2),
                _HeaderIconBtn(icon: Icons.create_new_folder_outlined, chrome: chrome, syntax: syntax, onTap: onNewFolder, tooltip: 'New folder'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HeaderIconBtn
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatefulWidget {
  final IconData           icon;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;
  final String             tooltip;

  const _HeaderIconBtn({
    required this.icon,
    required this.chrome,
    required this.syntax,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_HeaderIconBtn> createState() => _HeaderIconBtnState();
}

class _HeaderIconBtnState extends State<_HeaderIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: _hovered ? widget.chrome.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size:  14,
              color: _hovered
                  ? widget.syntax.plain
                  : widget.syntax.plain.withOpacity(0.45),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SearchBar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final ValueChanged<String>  onChanged;

  const _SearchBar({
    required this.ctrl,
    required this.chrome,
    required this.syntax,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color:        chrome.inputBackground ?? chrome.surface,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: chrome.gutterBorder),
        ),
        child: Row(children: [
          const SizedBox(width: 8),
          Icon(Icons.search_rounded, size: 13, color: syntax.comment),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller:  ctrl,
              onChanged:   onChanged,
              autofocus:   true,
              style:       TextStyle(color: syntax.plain, fontSize: 12),
              decoration: InputDecoration(
                hintText:       'Search files...',
                hintStyle:      TextStyle(color: syntax.comment, fontSize: 12),
                border:         InputBorder.none,
                isDense:        true,
                contentPadding: EdgeInsets.zero,
              ),
              cursorColor: chrome.cursorColor,
              cursorWidth: 1.5,
            ),
          ),
          if (ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () { ctrl.clear(); onChanged(''); },
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.close_rounded, size: 13, color: syntax.comment),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ActivePathBar
// ─────────────────────────────────────────────────────────────────────────────

class _ActivePathBar extends StatelessWidget {
  final List<String>                  segments;
  final EditorChromeColors            chrome;
  final EditorSyntaxColors            syntax;
  final Future<void> Function(String) onCopyPath;

  const _ActivePathBar({
    required this.segments,
    required this.chrome,
    required this.syntax,
    required this.onCopyPath,
  });

  @override
  Widget build(BuildContext context) {
    final fullPath = segments.join('/');
    final isFile   = segments.last.contains('.');

    return ClipRect(
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: chrome.surface.withOpacity(0.5),
          border: Border(
            bottom: BorderSide(color: chrome.gutterBorder.withOpacity(0.5)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isFile ? Icons.insert_drive_file_outlined : Icons.folder_outlined,
              size:  11,
              color: isFile
                  ? chrome.cursorColor.withOpacity(0.7)
                  : syntax.comment.withOpacity(0.6),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _BreadcrumbRow(
                segments: segments,
                chrome:   chrome,
                syntax:   syntax,
              ),
            ),
            _CopyPathButton(
              path:   fullPath,
              chrome: chrome,
              syntax: syntax,
              onTap:  () => onCopyPath(fullPath),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _BreadcrumbRow
// ─────────────────────────────────────────────────────────────────────────────

class _BreadcrumbRow extends StatelessWidget {
  final List<String>       segments;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  const _BreadcrumbRow({
    required this.segments,
    required this.chrome,
    required this.syntax,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(width: 3),
              Text(
                '›',
                style: TextStyle(
                  color:    syntax.comment.withOpacity(0.4),
                  fontSize: 10,
                  height:   1,
                ),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              segments[i],
              style: TextStyle(
                color: i == segments.length - 1
                    ? syntax.plain.withOpacity(0.85)
                    : syntax.comment.withOpacity(0.55),
                fontSize:   10,
                fontWeight: i == segments.length - 1
                    ? FontWeight.w500
                    : FontWeight.w400,
                fontFamily: 'monospace',
                letterSpacing: 0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CopyPathButton
// ─────────────────────────────────────────────────────────────────────────────

class _CopyPathButton extends StatefulWidget {
  final String             path;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;

  const _CopyPathButton({
    required this.path,
    required this.chrome,
    required this.syntax,
    required this.onTap,
  });

  @override
  State<_CopyPathButton> createState() => _CopyPathButtonState();
}

class _CopyPathButtonState extends State<_CopyPathButton> {
  bool _hovered = false;
  bool _copied  = false;

  Future<void> _handleTap() async {
    widget.onTap();
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _copied ? 'Copied!' : 'Copy path',
      preferBelow: false,
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.chrome.cursorColor.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Icon(
              _copied ? Icons.check_rounded : Icons.content_copy_rounded,
              size:  10,
              color: _copied
                  ? widget.chrome.consoleTextSuccess
                  : _hovered
                      ? widget.chrome.cursorColor
                      : widget.syntax.comment.withOpacity(0.45),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FileTree
// ─────────────────────────────────────────────────────────────────────────────

class _FileTree extends StatelessWidget {
  final IsolatedTradingViewHook hook;
  final EditorPermission        perm;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;
  final String                  searchQuery;
  final ScrollController?       scrollController;
  final _PathHoverNotifier      hoveredPathNotifier;
  final void Function(ScriptFile)                                        onOpenFile;
  final Future<void> Function(BuildContext, Offset, ScriptFile, String)  onContextMenu;
  final Future<void> Function(String)                                    onNewFile;
  final Future<void> Function(String?)                                   onNewFolder;

  const _FileTree({
    required this.hook,
    required this.perm,
    required this.chrome,
    required this.syntax,
    required this.searchQuery,
    required this.hoveredPathNotifier,
    this.scrollController,
    required this.onOpenFile,
    required this.onContextMenu,
    required this.onNewFile,
    required this.onNewFolder,
  });

  bool _matchesSearch(ScriptFile file) {
    if (searchQuery.isEmpty) return true;
    final query    = searchQuery.toLowerCase();
    final fileName = file.name.toLowerCase();
    return fileName.contains(query);
  }

  bool _folderHasMatch(ScriptFolder folder) {
    if (searchQuery.isEmpty) return true;
    for (final f in folder.files) {
      if (_matchesSearch(f)) return true;
    }
    for (final sub in folder.subFolders) {
      if (_folderHasMatch(sub)) return true;
    }
    return false;
  }

  void _onHoverFile(ScriptFile? file) {
    if (file == null) {
      hoveredPathNotifier.value = null;
    } else {
      hoveredPathNotifier.value = hook.workspace.getFilePathSegments(file.id);
    }
  }

  void _onHoverFolder(ScriptFolder? folder) {
    if (folder == null) {
      hoveredPathNotifier.value = null;
    } else {
      hoveredPathNotifier.value = hook.workspace.getFolderPathSegments(folder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRoots = hook.workspace.buildFolderTree();

    if (allRoots.isEmpty) {
      return _EmptyState(chrome: chrome, syntax: syntax);
    }

    final filtered = searchQuery.isEmpty
        ? allRoots
        : allRoots.where((f) => _folderHasMatch(f)).toList();

    if (filtered.isEmpty && searchQuery.isNotEmpty) {
      return _NoResultsState(query: searchQuery, chrome: chrome, syntax: syntax);
    }

    return MouseRegion(
      onExit: (_) => hoveredPathNotifier.value = null,
      child: ListView.builder(
        controller: scrollController,
        padding:    const EdgeInsets.only(top: 4, bottom: 16),
        itemCount:  filtered.length,
        itemBuilder: (context, i) {
          final root = filtered[i];

          final sharedId     = EditorPermission.sharedOwnerId ?? '';
          final isSharedRoot = sharedId.isNotEmpty && root.id.contains(sharedId);

          return FolderTreeTile(
            folder:         root,
            depth:          0,
            isShared:       isSharedRoot,
            perm:           perm,
            hook:           hook,
            chrome:         chrome,
            syntax:         syntax,
            searchQuery:    searchQuery,
            onOpenFile:     onOpenFile,
            onContextMenu:  onContextMenu,
            onNewFile:      onNewFile,
            onNewFolder:    onNewFolder,
            matchesSearch:  (f) => _matchesSearch(f),
            folderHasMatch: (f) => _folderHasMatch(f),
            onHoverFolder:  (f) => _onHoverFolder(f),
            onHoverFile:    (f) => _onHoverFile(f),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExplorerFooter
// ─────────────────────────────────────────────────────────────────────────────

class _ExplorerFooter extends StatelessWidget {
  final IsolatedTradingViewHook    hook;
  final EditorChromeColors         chrome;
  final EditorSyntaxColors         syntax;
  final int Function(ScriptFolder) countFiles;

  const _ExplorerFooter({
    required this.hook,
    required this.chrome,
    required this.syntax,
    required this.countFiles,
  });

  @override
  Widget build(BuildContext context) {
    final roots      = hook.workspace.buildFolderTree();
    final totalFiles = roots.fold<int>(0, (sum, r) => sum + countFiles(r));
    final unsaved    = hook.tabs.hasUnsavedChanges;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color:  chrome.toolbarBackground,
        border: Border(top: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Row(children: [
        Icon(Icons.folder_outlined, size: 10, color: syntax.comment.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(
          '$totalFiles file${totalFiles == 1 ? '' : 's'}',
          style: TextStyle(color: syntax.comment.withOpacity(0.5), fontSize: 10),
        ),
        const Spacer(),
        if (unsaved) ...[
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: chrome.cursorColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            'unsaved',
            style: TextStyle(color: chrome.cursorColor.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty states
//
//  v6: Column mainAxisSize.min, threshold 120px / 100px, ClipRect.
//  v7: tidak ada perubahan di sini — guard sudah di level build().
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  const _EmptyState({required this.chrome, required this.syntax});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight < 120) return const SizedBox.shrink();
      return ClipRect(
        child: Center(
          child: Column(
            mainAxisSize:      MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size:  32,
                color: syntax.comment.withOpacity(0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'No files yet',
                style: TextStyle(
                  color:    syntax.comment.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NoResultsState extends StatelessWidget {
  final String             query;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  const _NoResultsState({
    required this.query,
    required this.chrome,
    required this.syntax,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight < 100) return const SizedBox.shrink();
      return ClipRect(
        child: Center(
          child: Column(
            mainAxisSize:      MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size:  28,
                color: syntax.comment.withOpacity(0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'No results for "$query"',
                style:     TextStyle(
                  color:    syntax.comment.withOpacity(0.4),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _NewItemDialog
// ─────────────────────────────────────────────────────────────────────────────

class _NewItemDialog extends StatelessWidget {
  final String                title;
  final String                hint;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final TextEditingController ctrl;

  const _NewItemDialog({
    required this.title,
    required this.hint,
    required this.chrome,
    required this.syntax,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: chrome.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: TextStyle(color: syntax.plain, fontSize: 15, fontWeight: FontWeight.w700),
      ),
      content: Container(
        decoration: BoxDecoration(
          color:        chrome.background,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: chrome.gutterBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller:  ctrl,
          autofocus:   true,
          style:       TextStyle(color: syntax.plain, fontSize: 13),
          cursorColor: chrome.cursorColor,
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: TextStyle(color: syntax.comment, fontSize: 13),
            border:    InputBorder.none,
            isDense:   true,
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: syntax.comment, fontSize: 13)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: Text(
            'Create',
            style: TextStyle(color: chrome.cursorColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}