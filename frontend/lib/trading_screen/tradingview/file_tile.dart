// =============================================================================
// file_tile.dart
// Path: frontend/lib/trading_screen/tradingview/components/file_tile.dart
//
// FIX BATCH 4: Tambah `onHoverFile` optional param untuk path detection.
//   Wire ke MouseRegion onEnter/onExit yang sudah ada — null-safe, zero
//   breaking change ke caller lama yang belum pass param ini.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../hooks/tradingview_hook.dart';
import '../../../pages/tradingview_pages.dart';
import '../../../models/script_folder.dart';
import '../../../models/script_file.dart';
import '../../../style/apps_colors_tradingview.dart';

class FileTile extends StatefulWidget {
  final ScriptFile         file;
  final int                depth;
  final bool               isActive;
  final bool               isShared;
  final EditorPermission   perm;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;
  final void Function(Offset globalPos) onContextMenu;
  final String             searchQuery;
  // BATCH 4: path detection — optional, backward-compatible
  final void Function(ScriptFile?)? onHoverFile;

  const FileTile({
    super.key,
    required this.file,
    required this.depth,
    required this.isActive,
    required this.isShared,
    required this.perm,
    required this.chrome,
    required this.syntax,
    required this.onTap,
    required this.onContextMenu,
    required this.searchQuery,
    this.onHoverFile, // optional
  });

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  bool _isHovered = false;

  bool get isReadOnly => widget.isShared && !widget.perm.isAdmin;
  double get _indent  => (widget.depth * 12.0) + 8.0;

  Color get _bgColor {
    if (widget.isActive) return widget.chrome.cursorColor.withOpacity(0.12);
    if (_isHovered)      return widget.chrome.surface.withOpacity(0.5);
    return Colors.transparent;
  }

  Color get _borderColor {
    if (widget.isActive) return widget.chrome.cursorColor.withOpacity(0.4);
    return Colors.transparent;
  }

  IconData get _fileIcon {
    if (widget.file.isPython) return Icons.code_rounded;
    switch (widget.file.extension) {
      case 'json': return Icons.data_object_rounded;
      case 'md':   return Icons.description_outlined;
      case 'txt':  return Icons.text_snippet_outlined;
      default:     return Icons.insert_drive_file_outlined;
    }
  }

  Color get _fileIconColor {
    if (widget.file.isPython) {
      return isReadOnly
          ? widget.chrome.consoleTextInfo.withOpacity(0.55)
          : widget.syntax.string.withOpacity(0.7);
    }
    return widget.syntax.comment.withOpacity(0.6);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onSecondaryTapUp: (details) =>
          widget.onContextMenu(details.globalPosition),
      onLongPress: () {
        final box    = context.findRenderObject() as RenderBox;
        final center = box.localToGlobal(
          Offset(box.size.width / 2, box.size.height / 2),
        );
        widget.onContextMenu(center);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // BATCH 4: fire onHoverFile di onEnter/onExit yang sudah ada
        onEnter: (_) {
          setState(() => _isHovered = true);
          widget.onHoverFile?.call(widget.file);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          widget.onHoverFile?.call(null);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height:   27,
          padding:  EdgeInsets.only(left: _indent, right: 6),
          decoration: BoxDecoration(
            color: _bgColor,
            border: Border(
              left: BorderSide(color: _borderColor, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(_fileIcon, size: 14, color: _fileIconColor),
              const SizedBox(width: 6),

              Expanded(
                child: widget.searchQuery.isNotEmpty
                    ? _HighlightedText(
                        text:      widget.file.name,
                        query:     widget.searchQuery,
                        baseStyle: _nameStyle,
                        chrome:    widget.chrome,
                      )
                    : Text(
                        widget.file.name,
                        style:    _nameStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isReadOnly)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size:  10,
                        color: widget.chrome.consoleTextInfo.withOpacity(0.4),
                      ),
                    ),

                  if (widget.file.isModified)
                    Container(
                      width:  6, height: 6,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: widget.chrome.cursorColor,
                        shape: BoxShape.circle,
                      ),
                    ),

                  if (_isHovered && !widget.isActive)
                    Text(
                      _formatTime(widget.file.lastModified),
                      style: TextStyle(
                        color:    widget.syntax.comment.withOpacity(0.4),
                        fontSize: 9.5,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _nameStyle => TextStyle(
    color:      widget.isActive
        ? widget.syntax.plain
        : (isReadOnly
            ? widget.syntax.plain.withOpacity(0.55)
            : widget.syntax.plain.withOpacity(0.75)),
    fontSize:   12,
    fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
    fontStyle:  isReadOnly ? FontStyle.italic : FontStyle.normal,
  );

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours   < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HighlightedText
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String             text;
  final String             query;
  final TextStyle          baseStyle;
  final EditorChromeColors chrome;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.chrome,
  });

  @override
  Widget build(BuildContext context) {
    final lower      = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lower.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(text, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final before = text.substring(0, matchIndex);
    final match  = text.substring(matchIndex, matchIndex + query.length);
    final after  = text.substring(matchIndex + query.length);

    return Text.rich(
      TextSpan(children: [
        TextSpan(text: before, style: baseStyle),
        TextSpan(
          text:  match,
          style: baseStyle.copyWith(
            color:           chrome.cursorColor,
            fontWeight:      FontWeight.w700,
            backgroundColor: chrome.cursorColor.withOpacity(0.15),
          ),
        ),
        TextSpan(text: after, style: baseStyle),
      ]),
      overflow: TextOverflow.ellipsis,
    );
  }
}