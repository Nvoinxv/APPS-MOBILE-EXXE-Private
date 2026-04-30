// =============================================================================
// editor_tab_bar.dart
// Path: frontend/lib/trading_screen/tradingview/editor_tab_bar.dart
//
// Multi-tab bar untuk Python Script Editor.
// Sync dengan TabState dari tradingview_hook.dart.
//
// Features:
//   • Tab per open file dengan unsaved dot indicator
//   • Active tab highlight + left border accent
//   • Close button (hover-reveal) dengan unsaved confirm dialog
//   • Scroll horizontal kalau tab banyak
//   • Drag-to-reorder tab
//   • Keyboard shortcut hint (Ctrl+W close, Ctrl+Tab next)
//   • Read-only badge buat shared file (exclusive user)
//   • Double-click tab → rename file
//   • Right-click → tab context menu (close, close others, close all)
//   • File icon by extension
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../hooks/tradingview_hook.dart';
import '../../../pages/tradingview_pages.dart';
import '../../../style/apps_colors_tradingview.dart';
import '../../../models/script_folder.dart';
import '../../../models/script_file.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EditorTabBar  — main widget
// ─────────────────────────────────────────────────────────────────────────────

class EditorTabBar extends StatefulWidget {
  const EditorTabBar({
    super.key,
    required this.hook,
    this.height = 36,
  });

  final IsolatedTradingViewHook hook;
  final double                  height;

  @override
  State<EditorTabBar> createState() => _EditorTabBarState();
}

class _EditorTabBarState extends State<EditorTabBar> {
  final ScrollController _scrollCtrl = ScrollController();

  IsolatedTradingViewHook get hook   => widget.hook;
  EditorChromeColors      get chrome => hook.editorTheme.chrome;
  EditorSyntaxColors      get syntax => hook.editorTheme.syntax;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Scroll active tab into view ───────────────────────────────────────────

  void _scrollToActive() {
    final idx = hook.tabs.activeIndex;
    if (idx < 0 || !_scrollCtrl.hasClients) return;

    // Estimasi: setiap tab ~130px lebar
    const estimatedTabWidth = 130.0;
    final offset = (idx * estimatedTabWidth)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);

    _scrollCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve:    Curves.easeOut,
    );
  }

  // ── Close tab dengan unsaved check ───────────────────────────────────────

  Future<void> _closeTab(ScriptFile file) async {
    if (file.isModified) {
      final action = await _showUnsavedDialog(file);
      if (action == _UnsavedAction.cancel) return;
      if (action == _UnsavedAction.save) {
        hook.saveActiveFile();
      }
    }
    hook.tabs.closeTab(file.id);
  }

  Future<_UnsavedAction?> _showUnsavedDialog(ScriptFile file) {
    return showDialog<_UnsavedAction>(
      context: context,
      builder: (_) => _UnsavedTabDialog(
        file:   file,
        chrome: chrome,
        syntax: syntax,
      ),
    );
  }

  // ── Tab context menu ──────────────────────────────────────────────────────

  void _showTabContextMenu(BuildContext context, Offset pos, ScriptFile file) {
    showMenu<_TabMenuAction>(
      context:  context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color:    chrome.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: chrome.gutterBorder),
      ),
      items: [
        _menuItem(_TabMenuAction.close,      Icons.close_rounded,           'Close',            syntax.plain),
        _menuItem(_TabMenuAction.closeOthers, Icons.close_fullscreen_rounded,'Close Others',     syntax.plain),
        _menuItem(_TabMenuAction.closeAll,   Icons.clear_all_rounded,       'Close All',        syntax.plain),
        if (hook.canEditActive)
          _menuItem(_TabMenuAction.save,     Icons.save_outlined,           'Save',             chrome.cursorColor),
        if (hook.permission.isAdmin && hook.workspace.isSharedFile(file) == false)
          _menuItem(_TabMenuAction.publish,  Icons.public_rounded,          'Publish to Shared', chrome.consoleTextSuccess),
      ],
    ).then((action) {
      if (action == null) return;
      switch (action) {
        case _TabMenuAction.close:
          _closeTab(file);
        case _TabMenuAction.closeOthers:
          final others = hook.tabs.openTabs
              .where((t) => t.id != file.id)
              .toList();
          for (final t in others) hook.tabs.closeTab(t.id);
        case _TabMenuAction.closeAll:
          hook.tabs.closeAll();
        case _TabMenuAction.save:
          hook.saveActiveFile();
        case _TabMenuAction.publish:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"${file.name}" published to shared.',
                style: TextStyle(color: chrome.consoleTextSuccess, fontSize: 12),
              ),
              backgroundColor: chrome.surface,
              behavior:        SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    });
  }

  PopupMenuItem<_TabMenuAction> _menuItem(
    _TabMenuAction value,
    IconData       icon,
    String         label,
    Color          color,
  ) => PopupMenuItem<_TabMenuAction>(
    value:  value,
    height: 36,
    child: Row(
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.75)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    ),
  );

  // ── Rename via double-tap ─────────────────────────────────────────────────

  Future<void> _renameTab(ScriptFile file) async {
    if (!hook.canEditActive) return;
    final ctrl = TextEditingController(text: file.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(
        ctrl:   ctrl,
        chrome: chrome,
        syntax: syntax,
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      hook.workspace.renameFileGuarded(file.id, newName.trim());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hook.tabs, hook.editorTheme]),
      builder: (context, _) {
        final tabs = hook.tabs.openTabs;

        // Scroll ke tab active setelah build
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: chrome.tabInactive,
            border: Border(
              bottom: BorderSide(color: chrome.tabBorder, width: 1),
            ),
          ),
          child: tabs.isEmpty
              ? _EmptyTabHint(chrome: chrome, syntax: syntax)
              : Row(
                  children: [
                    // ── Scrollable tab list ─────────────────────────────
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: _scrollCtrl,
                        scrollDirection:  Axis.horizontal,
                        buildDefaultDragHandles: false,
                        onReorder: (oldIdx, newIdx) {
                          // Adjust Flutter's off-by-one pada reorder
                          final adjusted = newIdx > oldIdx
                              ? newIdx - 1
                              : newIdx;
                          setState(() {
                            final list = List<ScriptFile>.from(tabs);
                            final item = list.removeAt(oldIdx);
                            list.insert(adjusted, item);
                            // Sync ke TabState
                            hook.tabs.reorder(oldIdx, adjusted);
                          });
                        },
                        itemCount: tabs.length,
                        itemBuilder: (ctx, i) {
                          final file     = tabs[i];
                          final isActive = file.id == hook.tabs.activeFile?.id;
                          final isShared = hook.workspace.isSharedFile(file);
                          final isReadOnly = isShared && !hook.permission.isAdmin;

                          return ReorderableDragStartListener(
                            key:   ValueKey(file.id),
                            index: i,
                            child: _TabItem(
                              file:        file,
                              isActive:    isActive,
                              isReadOnly:  isReadOnly,
                              chrome:      chrome,
                              syntax:      syntax,
                              onTap: () => hook.tabs.setActiveByIndex(i),
                              onClose:     () => _closeTab(file),
                              onDoubleTap: () => _renameTab(file),
                              onContextMenu: (pos) =>
                                  _showTabContextMenu(ctx, pos, file),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Trailing: tab count + overflow indicator ────────
                    if (tabs.length > 1)
                      _TabCountBadge(
                        count:  tabs.length,
                        chrome: chrome,
                        syntax: syntax,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TabItem  — satu tab
// ─────────────────────────────────────────────────────────────────────────────

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.file,
    required this.isActive,
    required this.isReadOnly,
    required this.chrome,
    required this.syntax,
    required this.onTap,
    required this.onClose,
    required this.onDoubleTap,
    required this.onContextMenu,
  });

  final ScriptFile         file;
  final bool               isActive;
  final bool               isReadOnly;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;
  final VoidCallback       onClose;
  final VoidCallback       onDoubleTap;
  final void Function(Offset) onContextMenu;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _activeCtrl;
  late Animation<double>   _activeAnim;

  @override
  void initState() {
    super.initState();
    _activeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 150),
      value:    widget.isActive ? 1.0 : 0.0,
    );
    _activeAnim = CurvedAnimation(
      parent: _activeCtrl,
      curve:  Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(_TabItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      widget.isActive ? _activeCtrl.forward() : _activeCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _activeCtrl.dispose();
    super.dispose();
  }

  // ── File icon ─────────────────────────────────────────────────────────────

  IconData get _icon {
    if (widget.file.isPython) return Icons.code_rounded;
    switch (widget.file.extension) {
      case 'json': return Icons.data_object_rounded;
      case 'md':   return Icons.description_outlined;
      default:     return Icons.insert_drive_file_outlined;
    }
  }

  Color get _iconColor {
    if (!widget.file.isPython) return widget.syntax.comment.withOpacity(0.5);
    if (widget.isReadOnly)     return widget.chrome.consoleTextInfo.withOpacity(0.6);
    return widget.syntax.string.withOpacity(widget.isActive ? 0.85 : 0.55);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final syntax = widget.syntax;
    final file   = widget.file;

    return GestureDetector(
      onTap:              widget.onTap,
      onDoubleTap:        widget.onDoubleTap,
      onSecondaryTapUp:   (d) => widget.onContextMenu(d.globalPosition),
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox;
        widget.onContextMenu(box.localToGlobal(Offset(box.size.width / 2, box.size.height)));
      },
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit:  (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: _activeAnim,
          builder: (_, __) {
            final bgColor = Color.lerp(
              chrome.tabInactive,
              chrome.tabActive,
              _activeAnim.value,
            )!;
            final accentOpacity = _activeAnim.value;

            return Container(
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 180),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  // Left accent bar pada active tab
                  left: BorderSide(
                    color: chrome.cursorColor.withOpacity(accentOpacity * 0.8),
                    width: 2,
                  ),
                  right: BorderSide(color: chrome.tabBorder, width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // File icon
                    Icon(_icon, size: 13, color: _iconColor),
                    const SizedBox(width: 6),

                    // File name
                    Flexible(
                      child: Text(
                        file.name,
                        overflow:   TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isActive
                              ? syntax.plain
                              : syntax.plain.withOpacity(0.5),
                          fontSize:   12,
                          fontWeight: widget.isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontStyle: widget.isReadOnly
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Read-only lock badge
                    if (widget.isReadOnly)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size:  10,
                          color: chrome.consoleTextInfo.withOpacity(0.45),
                        ),
                      ),

                    // Unsaved dot / close button
                    SizedBox(
                      width: 16, height: 16,
                      child: _TabTrailing(
                        isModified: file.isModified,
                        isHovered:  _isHovered || widget.isActive,
                        chrome:     chrome,
                        onClose:    widget.onClose,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TabTrailing  — unsaved dot OR close button, depends on state
// ─────────────────────────────────────────────────────────────────────────────

class _TabTrailing extends StatefulWidget {
  const _TabTrailing({
    required this.isModified,
    required this.isHovered,
    required this.chrome,
    required this.onClose,
  });

  final bool               isModified;
  final bool               isHovered;
  final EditorChromeColors chrome;
  final VoidCallback       onClose;

  @override
  State<_TabTrailing> createState() => _TabTrailingState();
}

class _TabTrailingState extends State<_TabTrailing> {
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    // Show close button on hover, unsaved dot otherwise
    final showClose = widget.isHovered;

    if (!showClose && !widget.isModified) return const SizedBox.shrink();

    if (!showClose && widget.isModified) {
      // Just the unsaved dot
      return Center(
        child: Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color:  widget.chrome.cursorColor,
            shape:  BoxShape.circle,
          ),
        ),
      );
    }

    // Close button (with unsaved dot inside if modified)
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onClose();
      },
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _closeHovered = true),
        onExit:  (_) => setState(() => _closeHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 16, height: 16,
          decoration: BoxDecoration(
            color:        _closeHovered
                ? widget.chrome.consoleTextError.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: widget.isModified && !_closeHovered
                ? Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color:  widget.chrome.cursorColor,
                      shape:  BoxShape.circle,
                    ),
                  )
                : Icon(
                    Icons.close_rounded,
                    size:  11,
                    color: _closeHovered
                        ? widget.chrome.consoleTextError
                        : widget.chrome.lineNumberDefault,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TabCountBadge  — total open tabs indicator di ujung kanan
// ─────────────────────────────────────────────────────────────────────────────

class _TabCountBadge extends StatelessWidget {
  const _TabCountBadge({
    required this.count,
    required this.chrome,
    required this.syntax,
  });

  final int                count;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color:  chrome.tabInactive,
        border: Border(left: BorderSide(color: chrome.tabBorder)),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        chrome.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color:      syntax.comment.withOpacity(0.6),
              fontSize:   10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EmptyTabHint  — placeholder kalau belum ada tab yang terbuka
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTabHint extends StatelessWidget {
  const _EmptyTabHint({required this.chrome, required this.syntax});

  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Open a file from the explorer →',
        style: TextStyle(
          color:    syntax.comment.withOpacity(0.3),
          fontSize: 11,
          fontStyle: FontStyle.italic,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _UnsavedTabDialog  — confirm dialog sebelum close tab yang belum di-save
// ─────────────────────────────────────────────────────────────────────────────

enum _UnsavedAction { save, discard, cancel }
enum _TabMenuAction { close, closeOthers, closeAll, save, publish }

class _UnsavedTabDialog extends StatelessWidget {
  const _UnsavedTabDialog({
    required this.file,
    required this.chrome,
    required this.syntax,
  });

  final ScriptFile         file;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: chrome.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: Text(
      'Unsaved Changes',
      style: TextStyle(
        color:      syntax.plain,
        fontSize:   15,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: Text(
      '"${file.name}" has unsaved changes.\nDo you want to save before closing?',
      style: TextStyle(
        color:  syntax.comment,
        fontSize: 13,
        height:   1.5,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, _UnsavedAction.cancel),
        child: Text('Cancel',  style: TextStyle(color: syntax.comment, fontSize: 13)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _UnsavedAction.discard),
        child: Text('Discard', style: TextStyle(color: chrome.consoleTextError, fontSize: 13)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _UnsavedAction.save),
        child: Text(
          'Save',
          style: TextStyle(
            color:      chrome.cursorColor,
            fontSize:   13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _RenameDialog  — double-tap tab → rename file inline
// ─────────────────────────────────────────────────────────────────────────────

class _RenameDialog extends StatelessWidget {
  const _RenameDialog({
    required this.ctrl,
    required this.chrome,
    required this.syntax,
  });

  final TextEditingController ctrl;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: chrome.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: Text(
      'Rename File',
      style: TextStyle(
        color:      syntax.plain,
        fontSize:   15,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: Container(
      decoration: BoxDecoration(
        color:        chrome.background,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: chrome.gutterBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller:   ctrl,
        autofocus:    true,
        style:        TextStyle(color: syntax.plain, fontSize: 13),
        cursorColor:  chrome.cursorColor,
        cursorWidth:  1.5,
        decoration: InputDecoration(
          border:    InputBorder.none,
          isDense:   true,
          hintText:  'filename.py',
          hintStyle: TextStyle(color: syntax.comment, fontSize: 13),
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
          'Rename',
          style: TextStyle(
            color:      chrome.cursorColor,
            fontSize:   13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}