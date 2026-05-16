// =============================================================================
// context_menu_file.dart
// Path: frontend/lib/trading_screen/tradingview/components/context_menu_file.dart
//
// Right-click / long-press context menu untuk file items.
// Permission-aware: menu items di-disable / hidden berdasarkan role.
//
// Menu items:
//   Open              → always visible
//   ─────────────────
//   Rename            → canRename
//   Delete            → canDelete (destructive, red)
//   ─────────────────
//   New File Here     → canEdit
//   New Folder Here   → canEdit
//   ─────────────────
//   Publish to Shared → admin only
//   Copy Path         → always visible
//
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../hooks/tradingview_hook.dart';
import '../../../style/apps_colors_tradingview.dart';
import '../../models/script_folder.dart';
import '../../models/script_file.dart';

// ── Action enum ───────────────────────────────────────────────────────────────

enum ContextMenuAction {
  rename,
  delete,
  newFileHere,
  newFolderHere,
  publishShared,
  copyPath,         // [UI SYNC] samain dengan folder context menu
}

// ─────────────────────────────────────────────────────────────────────────────
//  showContextMenuFile
//  Helper function — call ini buat tampilkan context menu
//
//  [FIX] Tambah parameter `resolvedPath` (optional, nullable).
//  Caller pass: workspace.getFilePath(file.id)
//  → hasilnya "test/test_1/main.py" bukan UUID/main.py
// ─────────────────────────────────────────────────────────────────────────────

Future<ContextMenuAction?> showContextMenuFile({
  required BuildContext        context,
  required Offset              position,
  required EditorChromeColors  chrome,
  required EditorSyntaxColors  syntax,
  required ScriptFile          file,
  required bool                canEdit,
  required bool                canDelete,
  required bool                canRename,
  required bool                isAdmin,
  required bool                isShared,
  String?                      resolvedPath,   // [FIX] path dengan nama folder asli
}) async {
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;

  HapticFeedback.mediumImpact();

  return showMenu<ContextMenuAction>(
    context:   context,
    position:  RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    color:     chrome.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side:         BorderSide(color: chrome.gutterBorder),
    ),
    elevation: 10,
    items: [
      // ── File info header (non-interactive) ───────────────────────────────
      PopupMenuItem<ContextMenuAction>(
        enabled: false,
        height:  36,
        child:   _FileInfoHeader(file: file, syntax: syntax, chrome: chrome),
      ),
      PopupMenuDivider(height: 1),

      // ── Rename ────────────────────────────────────────────────────────────
      if (canRename)
        PopupMenuItem<ContextMenuAction>(
          value:  ContextMenuAction.rename,
          height: 36,
          child:  _ContextMenuRow(
            icon:   Icons.drive_file_rename_outline_rounded,
            label:  'Rename',
            syntax: syntax,
          ),
        ),

      // ── Delete ────────────────────────────────────────────────────────────
      if (canDelete)
        PopupMenuItem<ContextMenuAction>(
          value:  ContextMenuAction.delete,
          height: 36,
          child:  _ContextMenuRow(
            icon:          Icons.delete_outline_rounded,
            label:         'Delete',
            syntax:        syntax,
            isDestructive: true,
            chrome:        chrome,
          ),
        ),

      // ── Separator (only if we showed edit items) ─────────────────────────
      if (canRename || canDelete) PopupMenuDivider(height: 1),

      // ── New File Here ─────────────────────────────────────────────────────
      if (canEdit)
        PopupMenuItem<ContextMenuAction>(
          value:  ContextMenuAction.newFileHere,
          height: 36,
          child:  _ContextMenuRow(
            icon:   Icons.add_circle_outline_rounded,
            label:  'New File Here',
            syntax: syntax,
          ),
        ),

      // ── New Folder Here ───────────────────────────────────────────────────
      if (canEdit)
        PopupMenuItem<ContextMenuAction>(
          value:  ContextMenuAction.newFolderHere,
          height: 36,
          child:  _ContextMenuRow(
            icon:   Icons.create_new_folder_outlined,
            label:  'New Folder Here',
            syntax: syntax,
          ),
        ),

      // ── Separator before admin actions ───────────────────────────────────
      if (isAdmin && !isShared) PopupMenuDivider(height: 1),

      // ── Publish to Shared (admin only) ───────────────────────────────────
      if (isAdmin && !isShared)
        PopupMenuItem<ContextMenuAction>(
          value:  ContextMenuAction.publishShared,
          height: 36,
          child:  _ContextMenuRow(
            icon:      Icons.publish_rounded,
            label:     'Publish to Shared',
            syntax:    syntax,
            isAccent:  true,
            chrome:    chrome,
          ),
        ),

      // ── Always: Copy path ─────────────────────────────────────────────────
      // [UI SYNC] Sekarang pakai PopupMenuItem dengan value (bukan enabled:false
      // inline widget) — konsisten dengan folder context menu.
      // Handling (SnackBar "Path copied: ...") dilakukan di _handleContextMenu.
      PopupMenuDivider(height: 1),
      PopupMenuItem<ContextMenuAction>(
        value:  ContextMenuAction.copyPath,
        height: 36,
        child:  _ContextMenuRow(
          icon:   Icons.content_copy_rounded,
          label:  'Copy Path',
          syntax: syntax,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FileInfoHeader — top of context menu
// ─────────────────────────────────────────────────────────────────────────────

class _FileInfoHeader extends StatelessWidget {
  final ScriptFile         file;
  final EditorSyntaxColors syntax;
  final EditorChromeColors chrome;

  const _FileInfoHeader({
    required this.file,
    required this.syntax,
    required this.chrome,
  });

  @override
  Widget build(BuildContext context) {
    final isShared = file.id.contains('admin_shared') ||
        file.parentId.contains('admin_shared');
    return Row(
      children: [
        Icon(
          Icons.code_rounded,
          size:  14,
          color: syntax.string.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              Text(
                file.name,
                style: TextStyle(
                  color:      syntax.plain,
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isShared)
                Text(
                  'Shared indicator',
                  style: TextStyle(
                    color:    chrome.consoleTextInfo.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        if (file.isModified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color:        chrome.cursorColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'unsaved',
              style: TextStyle(color: chrome.cursorColor, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ContextMenuRow
// ─────────────────────────────────────────────────────────────────────────────

class _ContextMenuRow extends StatelessWidget {
  final IconData           icon;
  final String             label;
  final EditorSyntaxColors syntax;
  final bool               isDestructive;
  final bool               isAccent;
  final EditorChromeColors? chrome;
  final String?            shortcut;

  const _ContextMenuRow({
    required this.icon,
    required this.label,
    required this.syntax,
    this.isDestructive = false,
    this.isAccent      = false,
    this.chrome,
    this.shortcut,
  });

  Color get _color {
    if (isDestructive) return chrome?.consoleTextError ?? Colors.red;
    if (isAccent)      return chrome?.consoleTextSuccess ?? Colors.green;
    return syntax.plain.withOpacity(0.85);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: _color, fontSize: 13),
          ),
        ),
        if (shortcut != null)
          Text(
            shortcut!,
            style: TextStyle(
              color:    syntax.comment.withOpacity(0.45),
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}