// =============================================================================
// editor_tab_bar.dart
// Path: frontend/lib/trading_screen/tradingview/editor_tab_bar.dart
//
// Tab bar horizontal untuk open files di code editor.
// Dipanggil via prefix di tradingviewcodeeditor_screen.dart:
//   import 'tradingview/editor_tab_bar.dart' as tab_bar_lib;
//   tab_bar_lib.EditorTabBar(hook: hook)
//
// API dari TabState (tradingview_hook.dart):
//   hook.tabs.openTabs     → List<ScriptFile>   (getter: openTabs)
//   hook.tabs.activeFile   → ScriptFile?
//   hook.openFile(file)    → set active tab
//   hook.tabs.closeTab(id) → tutup tab
//   hook.tabs.reorder(a,b) → drag reorder
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../pages/tradingview_pages.dart';
import '../../../style/apps_colors_tradingview.dart';
import '../../../models/script_file.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EditorTabBar  ← top-level export
// ─────────────────────────────────────────────────────────────────────────────

class EditorTabBar extends StatelessWidget {
  const EditorTabBar({super.key, required this.hook});

  final IsolatedTradingViewHook hook;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hook.tabs, hook.editorTheme]),
      builder: (context, _) {
        final chrome = hook.editorTheme.chrome;
        final syntax = hook.editorTheme.syntax;
        final tabs   = hook.tabs.openTabs;

        if (tabs.isEmpty) {
          return _EmptyTabBar(chrome: chrome);
        }

        return Container(
          color: chrome.tabInactive,
          child: ReorderableListView.builder(
            scrollDirection:         Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              hook.tabs.reorder(
                oldIndex,
                newIndex > oldIndex ? newIndex - 1 : newIndex,
              );
            },
            itemCount:   tabs.length,
            itemBuilder: (context, i) {
              final file     = tabs[i];
              final isActive = file.id == hook.tabs.activeFile?.id;

              return ReorderableDragStartListener(
                key:   ValueKey(file.id),
                index: i,
                child: _EditorTab(
                  file:     file,
                  isActive: isActive,
                  chrome:   chrome,
                  syntax:   syntax,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    hook.openFile(file);
                  },
                  onClose: () {
                    HapticFeedback.lightImpact();
                    hook.tabs.closeTab(file.id);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EditorTab
// ─────────────────────────────────────────────────────────────────────────────

class _EditorTab extends StatefulWidget {
  const _EditorTab({
    required this.file,
    required this.isActive,
    required this.chrome,
    required this.syntax,
    required this.onTap,
    required this.onClose,
  });

  final ScriptFile         file;
  final bool               isActive;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;
  final VoidCallback       onClose;

  @override
  State<_EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<_EditorTab> {
  bool _hovered      = false;
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    final chrome   = widget.chrome;
    final syntax   = widget.syntax;
    final isActive = widget.isActive;
    final file     = widget.file;

    final labelColor = isActive
        ? syntax.plain
        : (_hovered
            ? syntax.plain.withOpacity(0.75)
            : chrome.lineNumberDefault);

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration:    const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
          padding:     const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive ? chrome.tabActive : Colors.transparent,
            border: Border(
              top: BorderSide(
                color: isActive ? chrome.cursorColor : Colors.transparent,
                width: 1.5,
              ),
              right: BorderSide(color: chrome.gutterBorder),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── File icon ────────────────────────────────────────────────
              Icon(
                file.isPython
                    ? Icons.code_rounded
                    : Icons.insert_drive_file_outlined,
                size:  12,
                color: isActive
                    ? chrome.cursorColor.withOpacity(0.7)
                    : chrome.lineNumberDefault.withOpacity(0.6),
              ),

              const SizedBox(width: 6),

              // ── File name ─────────────────────────────────────────────────
              Flexible(
                child: Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color:      labelColor,
                    fontSize:   12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // ── Unsaved dot / close button ────────────────────────────────
              SizedBox(
                width:  16,
                height: 16,
                child: file.isModified && !_hovered && !isActive
                    // dot — unsaved, tidak di-hover
                    ? Center(
                        child: Container(
                          width:  6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: chrome.cursorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    // close / dot button — saat hover atau active
                    : (_hovered || isActive)
                        ? MouseRegion(
                            cursor:  SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _closeHovered = true),
                            onExit:  (_) =>
                                setState(() => _closeHovered = false),
                            child: GestureDetector(
                              onTap:    widget.onClose,
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                decoration: BoxDecoration(
                                  color: _closeHovered
                                      ? chrome.surface
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  file.isModified
                                      ? Icons.circle
                                      : Icons.close_rounded,
                                  size:  file.isModified ? 7 : 12,
                                  color: _closeHovered
                                      ? syntax.plain
                                      : chrome.lineNumberDefault,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EmptyTabBar
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTabBar extends StatelessWidget {
  const _EmptyTabBar({required this.chrome});

  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color:     chrome.tabInactive,
      padding:   const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        'No file open',
        style: TextStyle(
          color:     chrome.lineNumberDefault.withOpacity(0.4),
          fontSize:  11,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}