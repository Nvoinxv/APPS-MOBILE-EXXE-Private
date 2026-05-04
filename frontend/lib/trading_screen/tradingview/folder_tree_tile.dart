// =============================================================================
// folder_tree_tile.dart
// Path: frontend/lib/trading_screen/tradingview/components/folder_tree_tile.dart
//
// FIX BATCH 4: Tambah `onHoverFolder` & `onHoverFile` optional params untuk
//   path detection. MouseRegion di folder row & FileTile children memanggil
//   callback ini saat hover → _ActivePathBar di FileExplorerPanel update path.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../hooks/tradingview_hook.dart';
import '../../../pages/tradingview_pages.dart';
import '../../../style/apps_colors_tradingview.dart';
import '../../../models/script_file.dart';
import '../../../models/script_folder.dart';

import 'file_tile.dart';
import 'context_menu_file.dart';

class FolderTreeTile extends StatefulWidget {
  final ScriptFolder   folder;
  final int            depth;
  final bool           isShared;
  final EditorPermission        perm;
  final IsolatedTradingViewHook hook;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;
  final String                  searchQuery;
  final void Function(ScriptFile)                               onOpenFile;
  final Future<void> Function(BuildContext, Offset, ScriptFile) onContextMenu;
  final Future<void> Function(String)                           onNewFile;
  final Future<void> Function(String?)                          onNewFolder;
  final bool Function(ScriptFile)                               matchesSearch;
  final bool Function(ScriptFolder)                             folderHasMatch;

  // ── NEW BATCH 4: Path hover callbacks (optional — aman kalau null) ─────────
  final void Function(ScriptFolder?)? onHoverFolder;
  final void Function(ScriptFile?)?   onHoverFile;

  const FolderTreeTile({
    super.key,
    required this.folder,
    required this.depth,
    required this.isShared,
    required this.perm,
    required this.hook,
    required this.chrome,
    required this.syntax,
    required this.searchQuery,
    required this.onOpenFile,
    required this.onContextMenu,
    required this.onNewFile,
    required this.onNewFolder,
    required this.matchesSearch,
    required this.folderHasMatch,
    // optional — default null supaya backward-compatible
    this.onHoverFolder,
    this.onHoverFile,
  });

  @override
  State<FolderTreeTile> createState() => _FolderTreeTileState();
}

class _FolderTreeTileState extends State<FolderTreeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandCtrl;
  late Animation<double>   _expandAnim;
  bool _isHovered   = false;
  bool _isRenaming  = false;
  late TextEditingController _renameCtrl;
  late FocusNode _renameFocus;

  // ── Helpers ───────────────────────────────────────────────────────────────

  ScriptFolder get folder  => widget.folder;
  bool get isExpanded      => folder.isExpanded;
  bool get isSearching     => widget.searchQuery.isNotEmpty;
  bool get isShared        => widget.isShared;
  bool get canModifyFolder => widget.perm.isAdmin || !isShared;

  double get _indent => widget.depth * 12.0 + 8.0;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _expandCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 180),
      value:    folder.isExpanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOut);

    _renameCtrl  = TextEditingController(text: folder.name);
    _renameFocus = FocusNode();

    _renameFocus.addListener(() {
      if (!_renameFocus.hasFocus && _isRenaming) _commitRename();
    });
  }

  @override
  void didUpdateWidget(FolderTreeTile old) {
    super.didUpdateWidget(old);
    if (isSearching && widget.folderHasMatch(folder) && !folder.isExpanded) {
      _expandCtrl.forward();
    }
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _renameCtrl.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  // ── Toggle expand ─────────────────────────────────────────────────────────

  void _toggle() {
    HapticFeedback.selectionClick();
    widget.hook.workspace.toggleFolder(folder.id);
    if (folder.isExpanded) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  void _startRename() {
    if (!canModifyFolder) return;
    setState(() => _isRenaming = true);
    _renameCtrl.text = folder.name;
    _renameCtrl.selection = TextSelection(
      baseOffset:   0,
      extentOffset: folder.name.length,
    );
    Future.microtask(() => _renameFocus.requestFocus());
  }

  void _commitRename() {
    final newName = _renameCtrl.text.trim();
    if (newName.isNotEmpty && newName != folder.name) {
      widget.hook.workspace.renameFolder(folder.id, newName);
    }
    setState(() => _isRenaming = false);
  }

  // ── Context menu for folder ───────────────────────────────────────────────

  Future<void> _showFolderContextMenu(BuildContext ctx, Offset pos) async {
    final action = await showFolderContextMenu(
      context:   ctx,
      position:  pos,
      chrome:    widget.chrome,
      syntax:    widget.syntax,
      folder:    folder,
      canCreate: widget.perm.canCreate,
      canRename: canModifyFolder,
      canDelete: canModifyFolder && folder.parentId != null,
      isAdmin:   widget.perm.isAdmin,
      isShared:  isShared,
    );

    if (action == null || !mounted) return;

    switch (action) {
      case FolderContextAction.newFile:
        await widget.onNewFile(folder.id);
      case FolderContextAction.newFolder:
        await widget.onNewFolder(folder.id);
      case FolderContextAction.rename:
        _startRename();
      case FolderContextAction.delete:
        await _confirmDeleteFolder();
      case FolderContextAction.copyPath:
        await _copyFolderPath();
    }
  }

  Future<void> _copyFolderPath() async {
    final path = widget.hook.workspace.getFolderPath(folder.id);
    if (path.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_outline_rounded, size: 13,
              color: widget.chrome.consoleTextSuccess),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Path copied: $path',
              style: TextStyle(color: widget.chrome.consoleTextSuccess, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        backgroundColor: widget.chrome.surface,
        behavior:  SnackBarBehavior.floating,
        shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration:  const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeleteFolder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: widget.chrome.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Folder',
          style: TextStyle(
            color:      widget.syntax.plain,
            fontSize:   15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete "${folder.name}" and all its contents?\nThis cannot be undone.',
          style: TextStyle(
            color:    widget.syntax.comment,
            fontSize: 13,
            height:   1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: widget.syntax.comment)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: widget.chrome.consoleTextError)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.hook.workspace.deleteFolder(folder.id);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final syntax = widget.syntax;

    final filteredFiles = isSearching
        ? folder.files.where(widget.matchesSearch).toList()
        : folder.files;

    final filteredSubs = isSearching
        ? folder.subFolders.where(widget.folderHasMatch).toList()
        : folder.subFolders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Folder row ─────────────────────────────────────────────────────
        GestureDetector(
          onTap:       _toggle,
          onDoubleTap: _startRename,
          onSecondaryTapUp: (details) =>
              _showFolderContextMenu(context, details.globalPosition),
          child: MouseRegion(
            cursor:  SystemMouseCursors.click,
            // FIX BATCH 4: fire hover callbacks untuk path detection
            onEnter: (_) {
              setState(() => _isHovered = true);
              widget.onHoverFolder?.call(folder);
            },
            onExit: (_) {
              setState(() => _isHovered = false);
              widget.onHoverFolder?.call(null);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height:   28,
              padding:  EdgeInsets.only(left: _indent, right: 6),
              color:    _isHovered ? chrome.surface.withOpacity(0.6) : Colors.transparent,
              child: Row(
                children: [
                  // Arrow
                  AnimatedRotation(
                    turns:    isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size:  15,
                      color: syntax.plain.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Folder icon
                  Icon(
                    isShared
                        ? Icons.folder_shared_outlined
                        : (isExpanded
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined),
                    size:  15,
                    color: isShared
                        ? chrome.consoleTextInfo.withOpacity(0.7)
                        : syntax.keyword.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),

                  // Name (or rename field)
                  Expanded(
                    child: _isRenaming
                        ? TextField(
                            controller:  _renameCtrl,
                            focusNode:   _renameFocus,
                            style:       TextStyle(color: syntax.plain, fontSize: 12),
                            cursorColor: chrome.cursorColor,
                            decoration:  const InputDecoration(
                              border:         InputBorder.none,
                              isDense:        true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _commitRename(),
                          )
                        : Text(
                            folder.name,
                            style: TextStyle(
                              color:      isShared
                                  ? syntax.plain.withOpacity(0.75)
                                  : syntax.plain.withOpacity(0.85),
                              fontSize:   12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),

                  // Shared badge
                  if (isShared) ...[
                    const SizedBox(width: 4),
                    _SharedBadge(chrome: chrome),
                  ],

                  // Search match count badge
                  if (isSearching && widget.folderHasMatch(folder)) ...[
                    const SizedBox(width: 4),
                    _CountBadge(count: filteredFiles.length, chrome: chrome),
                  ],

                  // Action buttons (visible on hover)
                  if (_isHovered && !_isRenaming && widget.perm.canCreate) ...[
                    const SizedBox(width: 2),
                    _FolderActionBtn(
                      icon:   Icons.add_rounded,
                      chrome: chrome,
                      syntax: syntax,
                      onTap:  () => widget.onNewFile(folder.id),
                    ),
                    _FolderActionBtn(
                      icon:   Icons.more_horiz_rounded,
                      chrome: chrome,
                      syntax: syntax,
                      onTap:  () {
                        final box = context.findRenderObject() as RenderBox;
                        final pos = box.localToGlobal(Offset.zero);
                        _showFolderContextMenu(context, pos + const Offset(80, 14));
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Children (animated expand) ─────────────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Files — teruskan onHoverFile ke setiap FileTile
              ...filteredFiles.map((file) => FileTile(
                file:          file,
                depth:         widget.depth + 1,
                isActive:      widget.hook.tabs.activeFile?.id == file.id,
                isShared:      isShared,
                perm:          widget.perm,
                chrome:        chrome,
                syntax:        syntax,
                onTap:         () => widget.onOpenFile(file),
                onContextMenu: (pos) => widget.onContextMenu(context, pos, file),
                searchQuery:   widget.searchQuery,
                // FIX BATCH 4: teruskan hover callback
                onHoverFile:   widget.onHoverFile,
              )),

              // Subfolders (recursive) — teruskan kedua callbacks
              ...filteredSubs.map((sub) => FolderTreeTile(
                folder:         sub,
                depth:          widget.depth + 1,
                isShared:       isShared,
                perm:           widget.perm,
                hook:           widget.hook,
                chrome:         chrome,
                syntax:         syntax,
                searchQuery:    widget.searchQuery,
                onOpenFile:     widget.onOpenFile,
                onContextMenu:  widget.onContextMenu,
                onNewFile:      widget.onNewFile,
                onNewFolder:    widget.onNewFolder,
                matchesSearch:  widget.matchesSearch,
                folderHasMatch: widget.folderHasMatch,
                // FIX BATCH 4: propagate ke nested tiles
                onHoverFolder:  widget.onHoverFolder,
                onHoverFile:    widget.onHoverFile,
              )),

              // Empty folder hint
              if (folder.files.isEmpty && folder.subFolders.isEmpty)
                Padding(
                  padding: EdgeInsets.only(left: _indent + 28, top: 2, bottom: 4),
                  child: Text(
                    'Empty folder',
                    style: TextStyle(
                      color:    syntax.comment.withOpacity(0.35),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FolderActionBtn
// ─────────────────────────────────────────────────────────────────────────────

class _FolderActionBtn extends StatefulWidget {
  final IconData           icon;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;

  const _FolderActionBtn({
    required this.icon,
    required this.chrome,
    required this.syntax,
    required this.onTap,
  });

  @override
  State<_FolderActionBtn> createState() => _FolderActionBtnState();
}

class _FolderActionBtnState extends State<_FolderActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 20, height: 20,
          decoration: BoxDecoration(
            color:        _hovered ? widget.chrome.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(
            widget.icon,
            size:  13,
            color: widget.syntax.plain.withOpacity(_hovered ? 0.9 : 0.55),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Badges
// ─────────────────────────────────────────────────────────────────────────────

class _SharedBadge extends StatelessWidget {
  final EditorChromeColors chrome;
  const _SharedBadge({required this.chrome});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color:        chrome.consoleTextInfo.withOpacity(0.10),
      borderRadius: BorderRadius.circular(3),
      border:       Border.all(color: chrome.consoleTextInfo.withOpacity(0.25)),
    ),
    child: Text(
      'shared',
      style: TextStyle(
        color:         chrome.consoleTextInfo.withOpacity(0.8),
        fontSize:      8,
        fontWeight:    FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  final int count;
  final EditorChromeColors chrome;
  const _CountBadge({required this.count, required this.chrome});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color:        chrome.cursorColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$count',
      style: TextStyle(
        color:      chrome.cursorColor,
        fontSize:   9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Folder context menu helper
// ─────────────────────────────────────────────────────────────────────────────

enum FolderContextAction { newFile, newFolder, rename, delete, copyPath }

Future<FolderContextAction?> showFolderContextMenu({
  required BuildContext        context,
  required Offset              position,
  required EditorChromeColors  chrome,
  required EditorSyntaxColors  syntax,
  required ScriptFolder        folder,
  required bool                canCreate,
  required bool                canRename,
  required bool                canDelete,
  required bool                isAdmin,
  required bool                isShared,
}) async {
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;

  return showMenu<FolderContextAction>(
    context:  context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    color:    chrome.surface,
    shape:    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side:         BorderSide(color: chrome.gutterBorder),
    ),
    elevation: 8,
    items: [
      if (canCreate) ...[
        PopupMenuItem(
          value: FolderContextAction.newFile,
          height: 36,
          child: _MenuRow(icon: Icons.add_rounded, label: 'New File', syntax: syntax),
        ),
        PopupMenuItem(
          value: FolderContextAction.newFolder,
          height: 36,
          child: _MenuRow(icon: Icons.create_new_folder_outlined, label: 'New Folder', syntax: syntax),
        ),
        const PopupMenuDivider(height: 1),
      ],
      if (canRename)
        PopupMenuItem(
          value: FolderContextAction.rename,
          height: 36,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Rename', syntax: syntax),
        ),
      if (canDelete)
        PopupMenuItem(
          value: FolderContextAction.delete,
          height: 36,
          child: _MenuRow(
            icon:          Icons.delete_outline_rounded,
            label:         'Delete',
            syntax:        syntax,
            isDestructive: true,
            chrome:        chrome,
          ),
        ),
      const PopupMenuDivider(height: 1),
      PopupMenuItem(
        value: FolderContextAction.copyPath,
        height: 36,
        child: _MenuRow(icon: Icons.content_copy_rounded, label: 'Copy Path', syntax: syntax),
      ),
    ],
  );
}

class _MenuRow extends StatelessWidget {
  final IconData            icon;
  final String              label;
  final EditorSyntaxColors  syntax;
  final bool                isDestructive;
  final EditorChromeColors? chrome;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.syntax,
    this.isDestructive = false,
    this.chrome,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? (chrome?.consoleTextError ?? Colors.red)
        : syntax.plain.withOpacity(0.8);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}