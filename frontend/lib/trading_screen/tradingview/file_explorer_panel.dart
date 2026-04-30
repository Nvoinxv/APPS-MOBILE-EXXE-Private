// =============================================================================
// file_explorer_panel.dart
// Path: frontend/lib/trading_screen/tradingview/components/file_explorer_panel.dart
//
// FIX: Tambah scrollController optional param ke FileExplorerPanel.
//      Di-pass ke _FileTree → ListView.builder supaya controller dari parent
//      (tradingviewcodeeditor_screen) bisa manage scroll-nya sendiri.
//      Tidak ada logic lain yang diubah.
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

class FileExplorerPanel extends StatefulWidget {
  final IsolatedTradingViewHook hook;
  final double                  width;
  // FIX: optional — kalau parent pass controller-nya sendiri, pakai itu
  final ScrollController?       scrollController;

  const FileExplorerPanel({
    super.key,
    required this.hook,
    this.width            = 240,
    this.scrollController,   // ← FIX: tambah param ini
  });

  @override
  State<FileExplorerPanel> createState() => _FileExplorerPanelState();
}

class _FileExplorerPanelState extends State<FileExplorerPanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool   _showSearch  = false;
  late AnimationController _searchAnimCtrl;
  late Animation<double>   _searchAnim;

  IsolatedTradingViewHook get hook => widget.hook;
  EditorPermission        get perm => hook.permission;

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
    // FIX: TIDAK dispose widget.scrollController di sini —
    // owner-nya (tradingviewcodeeditor_screen) yang bertanggung jawab dispose
    super.dispose();
  }

  // ── Search toggle ─────────────────────────────────────────────────────────

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

  // ── New file dialog ───────────────────────────────────────────────────────

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

    if (name != null && name.trim().isNotEmpty) {
      final file = hook.workspace.addFileGuarded(parentFolderId, name.trim());
      if (file != null) {
        hook.openFile(file);
      } else {
        _showPermissionError('Cannot create file in shared folder');
      }
    }
  }

  // ── New folder dialog ─────────────────────────────────────────────────────

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

    if (name != null && name.trim().isNotEmpty) {
      if (parentFolderId != null) {
        hook.workspace.addFolder(parentFolderId, name.trim());
      } else {
        hook.workspace.addRootFolder(name.trim());
      }
    }
  }

  // ── Permission error snackbar ─────────────────────────────────────────────

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

  // ── Context menu handler ──────────────────────────────────────────────────

  Future<void> _handleContextMenu(
    BuildContext ctx,
    Offset globalPos,
    ScriptFile file,
  ) async {
    final ownerId   = hook.workspace.resolveOwnerId(file);
    final canEdit   = perm.canEdit(ownerId: ownerId);
    final canDelete = perm.canDelete(ownerId: ownerId);
    final canRename = perm.canRename(ownerId: ownerId);

    final action = await showContextMenuFile(
      context:   ctx,
      position:  globalPos,
      chrome:    hook.editorTheme.chrome,
      syntax:    hook.editorTheme.syntax,
      file:      file,
      canEdit:   canEdit,
      canDelete: canDelete,
      canRename: canRename,
      isAdmin:   perm.isAdmin,
      isShared:  hook.workspace.isSharedFile(file),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case ContextMenuAction.rename:        await _renameFile(file);
      case ContextMenuAction.delete:        await _confirmDelete(file);
      case ContextMenuAction.newFileHere:   await _showNewFileDialog(file.parentId);
      case ContextMenuAction.newFolderHere: await _showNewFolderDialog(file.parentId);
      case ContextMenuAction.publishShared: _publishToShared(file);
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

    if (newName != null && newName.trim().isNotEmpty) {
      final success = hook.workspace.renameFileGuarded(file.id, newName.trim());
      if (!success) _showPermissionError('Permission denied');
    }
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

    if (confirmed == true) hook.deleteFile(file.id);
  }

  void _publishToShared(ScriptFile file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${file.name}" published to shared indicators.',
          style: TextStyle(color: hook.editorTheme.chrome.consoleTextSuccess, fontSize: 12),
        ),
        backgroundColor: hook.editorTheme.chrome.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD — tidak ada perubahan selain pass scrollController ke _FileTree
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hook.workspace, hook.editorTheme]),
      builder: (context, _) {
        final chrome = hook.editorTheme.chrome;
        final syntax = hook.editorTheme.syntax;

        return SizedBox(
          width: widget.width,
          child: Container(
            decoration: BoxDecoration(
              color: chrome.sidebarBackground,
              border: Border(
                right: BorderSide(color: chrome.gutterBorder, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ExplorerHeader(
                  perm:           perm,
                  chrome:         chrome,
                  syntax:         syntax,
                  showSearch:     _showSearch,
                  onToggleSearch: _toggleSearch,
                  onNewFile: () => _showNewFileDialog(
                    hook.workspace.visibleRoots
                        .firstWhere((r) => r.id.contains(perm.userId),
                            orElse: () => hook.workspace.visibleRoots.first)
                        .id,
                  ),
                  onNewFolder: () => _showNewFolderDialog(null),
                ),

                SizeTransition(
                  sizeFactor: _searchAnim,
                  child: _SearchBar(
                    ctrl:      _searchCtrl,
                    chrome:    chrome,
                    syntax:    syntax,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),

                Divider(height: 1, color: chrome.gutterBorder),

                // FIX: pass widget.scrollController ke _FileTree
                Expanded(
                  child: _FileTree(
                    hook:             hook,
                    perm:             perm,
                    chrome:           chrome,
                    syntax:           syntax,
                    searchQuery:      _searchQuery,
                    scrollController: widget.scrollController,  // ← FIX
                    onOpenFile:       hook.openFile,
                    onContextMenu:    _handleContextMenu,
                    onNewFile:        _showNewFileDialog,
                    onNewFolder:      _showNewFolderDialog,
                  ),
                ),

                _ExplorerFooter(hook: hook, chrome: chrome, syntax: syntax),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExplorerHeader — tidak diubah
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
          Text(
            'EXPLORER',
            style: TextStyle(
              color: syntax.plain.withOpacity(0.45), fontSize: 9.5,
              fontWeight: FontWeight.w800, letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          _HeaderIconBtn(icon: showSearch ? Icons.search_off_rounded : Icons.search_rounded, chrome: chrome, syntax: syntax, onTap: onToggleSearch, tooltip: 'Search files'),
          if (perm.canCreate) ...[
            const SizedBox(width: 2),
            _HeaderIconBtn(icon: Icons.add_rounded, chrome: chrome, syntax: syntax, onTap: onNewFile, tooltip: 'New file'),
            const SizedBox(width: 2),
            _HeaderIconBtn(icon: Icons.create_new_folder_outlined, chrome: chrome, syntax: syntax, onTap: onNewFolder, tooltip: 'New folder'),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HeaderIconBtn — tidak diubah
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatefulWidget {
  final IconData icon; final EditorChromeColors chrome; final EditorSyntaxColors syntax;
  final VoidCallback onTap; final String tooltip;
  const _HeaderIconBtn({required this.icon, required this.chrome, required this.syntax, required this.onTap, required this.tooltip});
  @override State<_HeaderIconBtn> createState() => _HeaderIconBtnState();
}

class _HeaderIconBtnState extends State<_HeaderIconBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24, height: 24,
            decoration: BoxDecoration(color: _hovered ? widget.chrome.surface : Colors.transparent, borderRadius: BorderRadius.circular(4)),
            child: Icon(widget.icon, size: 14, color: _hovered ? widget.syntax.plain : widget.syntax.plain.withOpacity(0.45)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SearchBar — tidak diubah
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final ValueChanged<String>  onChanged;
  const _SearchBar({required this.ctrl, required this.chrome, required this.syntax, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: chrome.inputBackground ?? chrome.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: chrome.gutterBorder),
        ),
        child: Row(children: [
          const SizedBox(width: 8),
          Icon(Icons.search_rounded, size: 13, color: syntax.comment),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: ctrl, onChanged: onChanged, autofocus: true,
              style: TextStyle(color: syntax.plain, fontSize: 12),
              decoration: InputDecoration(hintText: 'Search files...', hintStyle: TextStyle(color: syntax.comment, fontSize: 12), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              cursorColor: chrome.cursorColor, cursorWidth: 1.5,
            ),
          ),
          if (ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () { ctrl.clear(); onChanged(''); },
              child: Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.close_rounded, size: 13, color: syntax.comment)),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FileTree — FIX: terima + pakai scrollController di ListView
// ─────────────────────────────────────────────────────────────────────────────

class _FileTree extends StatelessWidget {
  final IsolatedTradingViewHook hook;
  final EditorPermission        perm;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;
  final String                  searchQuery;
  // FIX: tambah param ini
  final ScrollController?       scrollController;
  final void Function(ScriptFile) onOpenFile;
  final Future<void> Function(BuildContext, Offset, ScriptFile) onContextMenu;
  final Future<void> Function(String)  onNewFile;
  final Future<void> Function(String?) onNewFolder;

  const _FileTree({
    required this.hook,
    required this.perm,
    required this.chrome,
    required this.syntax,
    required this.searchQuery,
    this.scrollController,       // ← FIX: optional, nullable
    required this.onOpenFile,
    required this.onContextMenu,
    required this.onNewFile,
    required this.onNewFolder,
  });

  bool _matchesSearch(ScriptFile file) {
    if (searchQuery.isEmpty) return true;
    return file.name.toLowerCase().contains(searchQuery.toLowerCase());
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

  @override
  Widget build(BuildContext context) {
    final visibleRoots = hook.workspace.visibleRoots;

    if (visibleRoots.isEmpty) {
      return _EmptyState(chrome: chrome, syntax: syntax);
    }

    final filtered = visibleRoots.where(_folderHasMatch).toList();

    if (filtered.isEmpty && searchQuery.isNotEmpty) {
      return _NoResultsState(query: searchQuery, chrome: chrome, syntax: syntax);
    }

    // FIX: pass scrollController ke ListView — kalau null Flutter pakai
    // PrimaryScrollController bawaan (behavior lama, tidak ada regression)
    return ListView.builder(
      controller: scrollController,     // ← FIX: satu-satunya perubahan di sini
      padding:    const EdgeInsets.only(top: 4, bottom: 16),
      itemCount:  filtered.length,
      itemBuilder: (context, i) {
        final root         = filtered[i];
        final isSharedRoot = root.id.contains(EditorPermission.sharedOwnerId);

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
          matchesSearch:  _matchesSearch,
          folderHasMatch: _folderHasMatch,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExplorerFooter — tidak diubah
// ─────────────────────────────────────────────────────────────────────────────

class _ExplorerFooter extends StatelessWidget {
  final IsolatedTradingViewHook hook;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;
  const _ExplorerFooter({required this.hook, required this.chrome, required this.syntax});

  @override
  Widget build(BuildContext context) {
    final roots      = hook.workspace.visibleRoots;
    final totalFiles = roots.fold<int>(0, (sum, r) => sum + r.totalFiles);
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
        Text('$totalFiles file${totalFiles == 1 ? '' : 's'}', style: TextStyle(color: syntax.comment.withOpacity(0.5), fontSize: 10)),
        const Spacer(),
        if (unsaved) ...[
          Container(width: 5, height: 5, decoration: BoxDecoration(color: chrome.cursorColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('unsaved', style: TextStyle(color: chrome.cursorColor.withOpacity(0.7), fontSize: 10)),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty states — tidak diubah
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final EditorChromeColors chrome; final EditorSyntaxColors syntax;
  const _EmptyState({required this.chrome, required this.syntax});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.folder_open_outlined, size: 32, color: syntax.comment.withOpacity(0.3)),
      const SizedBox(height: 8),
      Text('No files yet', style: TextStyle(color: syntax.comment.withOpacity(0.4), fontSize: 12)),
    ]),
  );
}

class _NoResultsState extends StatelessWidget {
  final String query; final EditorChromeColors chrome; final EditorSyntaxColors syntax;
  const _NoResultsState({required this.query, required this.chrome, required this.syntax});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 28, color: syntax.comment.withOpacity(0.3)),
      const SizedBox(height: 8),
      Text('No results for "$query"', style: TextStyle(color: syntax.comment.withOpacity(0.4), fontSize: 11), textAlign: TextAlign.center),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _NewItemDialog — tidak diubah
// ─────────────────────────────────────────────────────────────────────────────

class _NewItemDialog extends StatelessWidget {
  final String title, hint;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final TextEditingController ctrl;

  const _NewItemDialog({
    required this.title, required this.hint,
    required this.chrome, required this.syntax, required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: chrome.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: TextStyle(color: syntax.plain, fontSize: 15, fontWeight: FontWeight.w700)),
      content: Container(
        decoration: BoxDecoration(color: chrome.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: chrome.gutterBorder)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller:  ctrl,
          autofocus:   true,
          style:       TextStyle(color: syntax.plain, fontSize: 13),
          cursorColor: chrome.cursorColor,
          decoration:  InputDecoration(hintText: hint, hintStyle: TextStyle(color: syntax.comment, fontSize: 13), border: InputBorder.none, isDense: true),
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
          child: Text('Create', style: TextStyle(color: chrome.cursorColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}