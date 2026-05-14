import '../../models/script_file.dart';
// =============================================================================
// code_editor_panels.dart
//
// Tanggung jawab:
//   - FindReplacePanel
//   - EditorStatusBar
//   - NoFileOpen placeholder
//   - Small reusable widgets: PanelInput, PanelIconBtn, PanelTextBtn,
//     StatusText, StatusChip
//
// FIX overflow:
//   NoFileOpen Column sebelumnya pakai mainAxisSize: MainAxisSize.max
//   (default), menyebabkan overflow saat height < ~100px (icon 48 +
//   gap 12 + text 14 + gap 4 + text 12 + padding center).
//
//   Solusi:
//     1. Column pakai mainAxisSize: MainAxisSize.min.
//     2. LayoutBuilder guard — kalau availH < 110px, render versi compact
//        (teks saja, tanpa icon). Kalau < 40px, SizedBox.shrink().
//     3. ClipRect di luar Center sebagai hard-clip safety net.
//
//   FIX v2: Threshold icon dinaikkan dari 90px → 110px.
//     Root cause overflow 7.9px (h=93.1):
//       Threshold 90 lolos di h=93.1, tapi actual content icon block:
//         48 (icon) + 12 (gap) + ~18 ("No file open" fontSize 14) +
//         4 (gap) + ~16 ("Select a file" fontSize 12) ≈ 98px > 93.1px
//       → overflow 7.9px persis sesuai log.
//       Naik ke 110 memberi margin aman tanpa mengubah perilaku di normal
//       height (biasanya ratusan px).
// =============================================================================

import 'package:flutter/material.dart';
import '../../hooks/tradingview_hook.dart';
import '../../pages/tradingview_pages.dart';
import '../../style/apps_colors_tradingview.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FindReplacePanel
// ─────────────────────────────────────────────────────────────────────────────

class FindReplacePanel extends StatelessWidget {
  const FindReplacePanel({
    super.key,
    required this.findCtrl,
    required this.replaceCtrl,
    required this.showReplace,
    required this.caseSensitive,
    required this.wholeWord,
    required this.matchCount,
    required this.currentMatch,
    required this.chrome,
    required this.syntax,
    required this.isReadOnly,
    required this.onSearch,
    required this.onNext,
    required this.onPrev,
    required this.onReplaceOne,
    required this.onReplaceAll,
    required this.onClose,
    required this.onToggleCase,
    required this.onToggleWord,
    required this.onToggleReplace,
  });

  final TextEditingController findCtrl, replaceCtrl;
  final bool                  showReplace, caseSensitive, wholeWord, isReadOnly;
  final int                   matchCount, currentMatch;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final void Function(String) onSearch;
  final VoidCallback          onNext, onPrev, onReplaceOne, onReplaceAll;
  final VoidCallback          onClose, onToggleCase, onToggleWord, onToggleReplace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color:  chrome.toolbarBackground,
        border: Border(bottom: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PanelIconBtn(
                icon:    showReplace ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color:   syntax.comment,
                onTap:   onToggleReplace,
                tooltip: showReplace ? 'Hide replace' : 'Show replace',
              ),
              const SizedBox(width: 6),
              Expanded(
                child: PanelInput(
                  ctrl:      findCtrl,
                  hint:      'Find',
                  chrome:    chrome,
                  syntax:    syntax,
                  onChanged: onSearch,
                  autofocus: true,
                  suffix: matchCount > 0
                      ? Text('${currentMatch + 1}/$matchCount',
                          style: TextStyle(
                            color:    syntax.comment.withValues(alpha: 0.55),
                            fontSize: 10,
                          ))
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              PanelIconBtn(
                icon:    Icons.text_fields_rounded,
                color:   caseSensitive ? chrome.cursorColor : syntax.comment,
                onTap:   onToggleCase,
                tooltip: 'Case sensitive',
                active:  caseSensitive,
              ),
              PanelIconBtn(
                icon:    Icons.border_outer_rounded,
                color:   wholeWord ? chrome.cursorColor : syntax.comment,
                onTap:   onToggleWord,
                tooltip: 'Whole word',
                active:  wholeWord,
              ),
              const SizedBox(width: 4),
              PanelIconBtn(
                icon:    Icons.keyboard_arrow_up_rounded,
                color:   syntax.plain,
                onTap:   onPrev,
                tooltip: 'Previous match',
              ),
              PanelIconBtn(
                icon:    Icons.keyboard_arrow_down_rounded,
                color:   syntax.plain,
                onTap:   onNext,
                tooltip: 'Next match',
              ),
              const SizedBox(width: 4),
              PanelIconBtn(
                icon:    Icons.close_rounded,
                color:   syntax.comment,
                onTap:   onClose,
                tooltip: 'Close (Esc)',
              ),
            ],
          ),
          if (showReplace && !isReadOnly) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: PanelInput(
                    ctrl:      replaceCtrl,
                    hint:      'Replace',
                    chrome:    chrome,
                    syntax:    syntax,
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: 4),
                PanelTextBtn(label: 'Replace', color: chrome.cursorColor, onTap: onReplaceOne, chrome: chrome),
                const SizedBox(width: 4),
                PanelTextBtn(label: 'All',     color: chrome.cursorColor, onTap: onReplaceAll, chrome: chrome),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EditorStatusBar
// ─────────────────────────────────────────────────────────────────────────────

class EditorStatusBar extends StatelessWidget {
  const EditorStatusBar({
    super.key,
    required this.active,
    required this.activeLineIdx,
    required this.colIdx,
    required this.lineCount,
    required this.charCount,
    required this.isReadOnly,
    required this.zoomDelta,
    required this.effectiveFontSize,
    required this.chrome,
    required this.syntax,
    required this.onResetZoom,
  });

  final ScriptFile            active;
  final int                   activeLineIdx, colIdx, lineCount, charCount;
  final bool                  isReadOnly;
  final double                zoomDelta, effectiveFontSize;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final VoidCallback          onResetZoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:  chrome.toolbarBackground,
        border: Border(top: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Row(
        children: [
          StatusChip(label: 'Python', color: syntax.keyword, chrome: chrome),
          const SizedBox(width: 8),
          if (isReadOnly)
            StatusChip(label: 'READ ONLY', color: chrome.consoleTextInfo, chrome: chrome),
          const Spacer(),
          StatusText(text: 'Ln ${activeLineIdx + 1}, Col ${colIdx + 1}', syntax: syntax),
          const SizedBox(width: 12),
          StatusText(text: '$lineCount lines', syntax: syntax),
          const SizedBox(width: 12),
          StatusText(text: '$charCount chars', syntax: syntax),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: zoomDelta != 0 ? onResetZoom : null,
            child: StatusText(
              text:  '${effectiveFontSize.toStringAsFixed(0)}px'
                     '${zoomDelta != 0 ? " (reset)" : ""}',
              syntax: syntax,
              color: zoomDelta != 0 ? chrome.cursorColor.withValues(alpha: 0.7) : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NoFileOpen
//
//  FIX v2: Threshold icon dinaikkan 90 → 110px.
//    Actual content dengan icon:
//      48 (icon) + 12 (gap) + ~18 (text fontSize 14) + 4 + ~16 (text fontSize 12)
//      ≈ 98px. Threshold 90 lolos di h=93.1 → overflow 7.9px.
//      Threshold 110 memberi margin 12px di atas konten aktual.
//
//  Guard tiers:
//    - h >= 110 → full (icon + 2 teks)
//    - h >= 40  → compact (2 teks saja, tanpa icon)
//    - h <  40  → SizedBox.shrink()
//  ClipRect sebagai hard-clip safety net.
// ─────────────────────────────────────────────────────────────────────────────

class NoFileOpen extends StatelessWidget {
  const NoFileOpen({super.key, required this.chrome, required this.syntax});
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  @override
  Widget build(BuildContext context) => Container(
    color: chrome.background,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        // Terlalu sempit — tidak render apapun.
        if (h < 40) return const SizedBox.shrink();

        return ClipRect(
          child: Center(
            child: Column(
              mainAxisSize:      MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // FIX v2: threshold dinaikkan 90 → 110.
                // Konten icon block ≈ 98px; threshold 110 memberi margin aman.
                if (h >= 110) ...[
                  Icon(
                    Icons.code_rounded,
                    size:  48,
                    color: syntax.comment.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'No file open',
                  style: TextStyle(
                    color:      syntax.comment.withValues(alpha: 0.35),
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a file from the explorer',
                  style: TextStyle(
                    color:    syntax.comment.withValues(alpha: 0.2),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class PanelInput extends StatelessWidget {
  const PanelInput({
    super.key,
    required this.ctrl,
    required this.hint,
    required this.chrome,
    required this.syntax,
    required this.onChanged,
    this.autofocus = false,
    this.suffix,
  });

  final TextEditingController ctrl;
  final String                hint;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final void Function(String) onChanged;
  final bool                  autofocus;
  final Widget?               suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: TextField(
      controller:  ctrl,
      autofocus:   autofocus,
      onChanged:   onChanged,
      style:       TextStyle(color: syntax.plain, fontSize: 12),
      cursorColor: chrome.cursorColor,
      cursorWidth: 1.5,
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(color: syntax.comment, fontSize: 12),
        filled:    true,
        fillColor: chrome.inputBackground,
        isDense:   true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 8), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(maxHeight: 28),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: chrome.gutterBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: chrome.gutterBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: chrome.cursorColor.withValues(alpha: 0.6))),
      ),
    ),
  );
}

class PanelIconBtn extends StatefulWidget {
  const PanelIconBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final String       tooltip;
  final bool         active;

  @override
  State<PanelIconBtn> createState() => _PanelIconBtnState();
}

class _PanelIconBtnState extends State<PanelIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width:  26, height: 26,
          decoration: BoxDecoration(
            color:        widget.active || _hovered
                ? widget.color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, size: 14, color: widget.color),
        ),
      ),
    ),
  );
}

class PanelTextBtn extends StatelessWidget {
  const PanelTextBtn({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    required this.chrome,
  });

  final String             label;
  final Color              color;
  final VoidCallback       onTap;
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}

class StatusText extends StatelessWidget {
  const StatusText({super.key, required this.text, required this.syntax, this.color});
  final String             text;
  final EditorSyntaxColors syntax;
  final Color?             color;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: color ?? syntax.comment.withValues(alpha: 0.45), fontSize: 10.5));
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, required this.chrome});
  final String             label;
  final Color              color;
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(4),
      border:       Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(label,
        style: TextStyle(
          color:         color,
          fontSize:      9,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.8,
        )),
  );
}