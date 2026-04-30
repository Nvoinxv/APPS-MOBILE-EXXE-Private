import '../../../models/script_file.dart';
// =============================================================================
// editor_toolbar.dart
// Path: frontend/lib/trading_screen/tradingview/editor_toolbar.dart
//
// PATCH: Tambah optional `trailing` Widget param — dirender di ujung kanan
//        toolbar, setelah _RightSection. Dipakai oleh
//        tradingviewcodeeditor_screen untuk tombol Zen / Fullscreen.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../hooks/tradingview_hook.dart';
import '../../../pages/tradingview_pages.dart';
import '../../../style/apps_colors_tradingview.dart';
import '../output_console/console_state.dart';
import 'output_console_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EditorToolbar — main widget
// ─────────────────────────────────────────────────────────────────────────────

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.hook,
    required this.console,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomReset,
    this.onOpenSettings,
    this.trailing,         // ← NEW: optional widget di ujung kanan
    this.height = 40,
  });

  final IsolatedTradingViewHook hook;
  final ConsoleState            console;
  final VoidCallback?           onZoomIn;
  final VoidCallback?           onZoomOut;
  final VoidCallback?           onZoomReset;
  final VoidCallback?           onOpenSettings;
  final Widget?                 trailing;     // ← NEW
  final double                  height;

  // ── Convenience getters ───────────────────────────────────────────────────

  EditorChromeColors get _chrome => hook.editorTheme.chrome;
  EditorSyntaxColors get _syntax => hook.editorTheme.syntax;
  EditorPermission   get _perm   => hook.permission;
  ScriptFile?        get _active => hook.tabs.activeFile;
  bool               get _canEdit        => hook.canEditActive;
  bool               get _activeIsShared => hook.activeIsShared;
  bool               get _isRunning      => console.status == RunStatus.running;

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        hook.tabs,
        hook.editorTheme,
        console,
      ]),
      builder: (context, _) {
        final chrome = _chrome;
        final syntax = _syntax;

        return Container(
          height:  height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: chrome.toolbarBackground,
            border: Border(
              bottom: BorderSide(color: chrome.toolbarBorder, width: 1),
            ),
          ),
          child: Row(
            children: [

              // ── LEFT: File actions ────────────────────────────────────
              _LeftSection(
                hook:           hook,
                chrome:         chrome,
                syntax:         syntax,
                active:         _active,
                canEdit:        _canEdit,
                activeIsShared: _activeIsShared,
                onFormat:       () => _handleFormat(context),
              ),

              _ToolbarDivider(chrome: chrome),

              // ── CENTER: Run / Stop ────────────────────────────────────
              _CenterSection(
                hook:      hook,
                console:   console,
                chrome:    chrome,
                syntax:    syntax,
                active:    _active,
                isRunning: _isRunning,
                onRun:     () => _handleRun(context),
                onStop:    _handleStop,
              ),

              const Spacer(),

              // ── RIGHT: View / Admin actions ───────────────────────────
              _RightSection(
                hook:           hook,
                chrome:         chrome,
                syntax:         syntax,
                active:         _active,
                perm:           _perm,
                onZoomIn:       onZoomIn,
                onZoomOut:      onZoomOut,
                onZoomReset:    onZoomReset,
                onOpenSettings: onOpenSettings,
                onPublish:      () => _handlePublish(context),
              ),

              // ── TRAILING: extra widgets (zen/fullscreen buttons) ──────
              if (trailing != null) ...[
                _ToolbarDivider(chrome: chrome),
                trailing!,
              ],
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Action handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _handleFormat(BuildContext context) {
    final active = _active;
    if (active == null || !_canEdit) return;

    HapticFeedback.lightImpact();

    final formatted = _formatPython(active.content);
    if (formatted == active.content) {
      _showSnack(context, 'Already formatted', _chrome.consoleTextInfo);
      return;
    }

    hook.onCodeChanged(formatted);
    hook.tabs.updateActiveContent(formatted);
    _showSnack(context, 'Formatted', _chrome.consoleTextSuccess);
  }

  void _handleRun(BuildContext context) {
    final active = _active;
    if (active == null || _isRunning) return;

    HapticFeedback.mediumImpact();

    console.clear();
    console.setStatus(RunStatus.running);
    console.writeSystem('▶  Running ${active.name}...');
    console.writeSystem('─' * 48);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (console.status != RunStatus.running) return;
      _simulateExecution(active.content);
    });
  }

  void _simulateExecution(String source) {
    final printRegex = RegExp(r'''print\(([^)]+)\)''');
    final matches    = printRegex.allMatches(source);
    int   lineNum    = 0;

    if (matches.isEmpty) {
      console.writeInfo('No print() statements found.');
    } else {
      for (final m in matches) {
        lineNum++;
        final arg   = m.group(1) ?? '';
        final clean = arg.replaceAll(RegExp(r'''^['"]|['"]$'''), '');
        console.write('$clean');
      }
    }

    if (source.contains('if __name__')) {
      console.writeSystem('─' * 48);
      console.writeSuccess('✓  Script finished in ${_randomMs()}ms');
    } else {
      console.writeSystem('─' * 48);
      console.writeSuccess('✓  Done');
    }

    console.setStatus(RunStatus.done);
  }

  void _handleStop() {
    if (!_isRunning) return;
    HapticFeedback.heavyImpact();
    console.writeWarning('⚠  Execution stopped by user.');
    console.setStatus(RunStatus.error);
  }

  void _handlePublish(BuildContext context) {
    final active = _active;
    if (active == null || !_perm.canPublishShared) return;

    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (_) => _PublishDialog(
        file:   active,
        hook:   hook,
        chrome: _chrome,
        syntax: _syntax,
      ),
    );
  }

  String _formatPython(String source) {
    final lines   = source.split('\n');
    final result  = <String>[];
    bool  prevBlank = false;

    for (var line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        if (!prevBlank) result.add('');
        prevBlank = true;
        continue;
      }
      prevBlank = false;
      result.add(trimmed);
    }

    while (result.isNotEmpty && result.first.isEmpty) result.removeAt(0);
    while (result.isNotEmpty && result.last.isEmpty) result.removeLast();

    return '${result.join('\n')}\n';
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: color, fontSize: 12)),
        backgroundColor: _chrome.surface,
        behavior:        SnackBarBehavior.floating,
        shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _randomMs() => 120 + (DateTime.now().millisecond % 80);
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LeftSection
// ─────────────────────────────────────────────────────────────────────────────

class _LeftSection extends StatelessWidget {
  const _LeftSection({
    required this.hook,
    required this.chrome,
    required this.syntax,
    required this.active,
    required this.canEdit,
    required this.activeIsShared,
    required this.onFormat,
  });

  final IsolatedTradingViewHook hook;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;
  final ScriptFile?             active;
  final bool                    canEdit;
  final bool                    activeIsShared;
  final VoidCallback            onFormat;

  bool get _hasUnsaved => active?.isModified ?? false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolbarBtn(
          label:   'Save',
          icon:    Icons.save_outlined,
          chrome:  chrome,
          syntax:  syntax,
          enabled: canEdit && _hasUnsaved,
          accent:  _hasUnsaved ? chrome.cursorColor : null,
          tooltip: canEdit
              ? (_hasUnsaved ? 'Save (Ctrl+S)' : 'No changes')
              : 'Read-only file',
          onTap: canEdit && _hasUnsaved
              ? () {
                  HapticFeedback.lightImpact();
                  hook.saveActiveFile();
                }
              : null,
          badge: _hasUnsaved ? _UnsavedBadge(chrome: chrome) : null,
        ),
        const SizedBox(width: 2),
        _ToolbarBtn(
          label:   'Format',
          icon:    Icons.auto_fix_high_rounded,
          chrome:  chrome,
          syntax:  syntax,
          enabled: canEdit && active != null,
          tooltip: canEdit ? 'Format Python (trim whitespace)' : 'Read-only file',
          onTap:   canEdit && active != null ? onFormat : null,
        ),
        if (activeIsShared && !hook.permission.isAdmin) ...[
          const SizedBox(width: 6),
          _ReadOnlyPill(chrome: chrome),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CenterSection
// ─────────────────────────────────────────────────────────────────────────────

class _CenterSection extends StatelessWidget {
  const _CenterSection({
    required this.hook,
    required this.console,
    required this.chrome,
    required this.syntax,
    required this.active,
    required this.isRunning,
    required this.onRun,
    required this.onStop,
  });

  final IsolatedTradingViewHook hook;
  final ConsoleState            console;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;
  final ScriptFile?             active;
  final bool                    isRunning;
  final VoidCallback            onRun;
  final VoidCallback            onStop;

  bool get _hasPython => active?.isPython ?? false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        if (!isRunning)
          _RunButton(
            enabled: _hasPython && active != null,
            chrome:  chrome,
            onTap:   _hasPython ? onRun : null,
          ),
        if (isRunning)
          _StopButton(chrome: chrome, onTap: onStop),
        const SizedBox(width: 4),
        _RunStatusLabel(
          status: console.status,
          chrome: chrome,
          syntax: syntax,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _RightSection
// ─────────────────────────────────────────────────────────────────────────────

class _RightSection extends StatelessWidget {
  const _RightSection({
    required this.hook,
    required this.chrome,
    required this.syntax,
    required this.active,
    required this.perm,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onOpenSettings,
    required this.onPublish,
  });

  final IsolatedTradingViewHook hook;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;
  final ScriptFile?             active;
  final EditorPermission        perm;
  final VoidCallback?           onZoomIn;
  final VoidCallback?           onZoomOut;
  final VoidCallback?           onZoomReset;
  final VoidCallback?           onOpenSettings;
  final VoidCallback            onPublish;

  bool get _canPublish =>
      perm.canPublishShared &&
      active != null &&
      !hook.workspace.isSharedFile(active!);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canPublish) ...[
          _ToolbarBtn(
            label:   'Publish',
            icon:    Icons.public_rounded,
            chrome:  chrome,
            syntax:  syntax,
            enabled: true,
            accent:  chrome.consoleTextSuccess,
            tooltip: 'Publish to shared indicators',
            onTap:   onPublish,
          ),
          _ToolbarDivider(chrome: chrome),
        ],
        _IconBtn(
          icon:    Icons.remove_rounded,
          chrome:  chrome,
          syntax:  syntax,
          tooltip: 'Zoom out (Ctrl+-)',
          onTap:   onZoomOut,
        ),
        _IconBtn(
          icon:    Icons.add_rounded,
          chrome:  chrome,
          syntax:  syntax,
          tooltip: 'Zoom in (Ctrl+=)',
          onTap:   onZoomIn,
        ),
        if (onZoomReset != null)
          _IconBtn(
            icon:    Icons.fit_screen_rounded,
            chrome:  chrome,
            syntax:  syntax,
            tooltip: 'Reset zoom (Ctrl+0)',
            onTap:   onZoomReset,
          ),
        _ToolbarDivider(chrome: chrome),
        _IconBtn(
          icon:    Icons.tune_rounded,
          chrome:  chrome,
          syntax:  syntax,
          tooltip: 'Editor settings',
          onTap:   onOpenSettings,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ToolbarBtn
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatefulWidget {
  const _ToolbarBtn({
    required this.label,
    required this.icon,
    required this.chrome,
    required this.syntax,
    required this.enabled,
    required this.tooltip,
    this.accent,
    this.onTap,
    this.badge,
  });

  final String             label;
  final IconData           icon;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final bool               enabled;
  final String             tooltip;
  final Color?             accent;
  final VoidCallback?      onTap;
  final Widget?            badge;

  @override
  State<_ToolbarBtn> createState() => _ToolbarBtnState();
}

class _ToolbarBtnState extends State<_ToolbarBtn> {
  bool _hovered = false;

  Color get _iconColor {
    if (!widget.enabled) return widget.syntax.comment.withOpacity(0.3);
    if (widget.accent != null) return widget.accent!;
    return _hovered
        ? widget.syntax.plain
        : widget.syntax.plain.withOpacity(0.6);
  }

  Color get _bgColor {
    if (!widget.enabled || !_hovered) return Colors.transparent;
    if (widget.accent != null) return widget.accent!.withOpacity(0.10);
    return widget.chrome.surface;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:  widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height:   28,
            padding:  const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color:        _bgColor,
              borderRadius: BorderRadius.circular(6),
              border: widget.accent != null && widget.enabled
                  ? Border.all(
                      color: widget.accent!.withOpacity(_hovered ? 0.5 : 0.25),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(widget.icon, size: 14, color: _iconColor),
                    if (widget.badge != null)
                      Positioned(
                        top:   -3,
                        right: -3,
                        child: widget.badge!,
                      ),
                  ],
                ),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    color:      _iconColor,
                    fontSize:   11,
                    fontWeight: widget.accent != null && widget.enabled
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _IconBtn
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.chrome,
    required this.syntax,
    required this.tooltip,
    this.onTap,
    this.accentColor,
  });

  final IconData           icon;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final String             tooltip;
  final VoidCallback?      onTap;
  final Color?             accentColor;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ??
        ((_hovered && widget.onTap != null)
            ? widget.syntax.plain
            : widget.syntax.plain.withOpacity(0.45));

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:  widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _hovered && widget.onTap != null
                  ? widget.chrome.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _RunButton
// ─────────────────────────────────────────────────────────────────────────────

class _RunButton extends StatefulWidget {
  const _RunButton({
    required this.enabled,
    required this.chrome,
    required this.onTap,
  });

  final bool               enabled;
  final EditorChromeColors chrome;
  final VoidCallback?      onTap;

  @override
  State<_RunButton> createState() => _RunButtonState();
}

class _RunButtonState extends State<_RunButton> {
  bool _hovered = false;

  static const Color _green = Color(0xFF00D09C);

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    final color  = active ? _green : _green.withOpacity(0.3);

    return Tooltip(
      message: active ? 'Run script (Python simulate)' : 'Open a .py file to run',
      child: MouseRegion(
        cursor: active
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: active ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height:   28,
            padding:  const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active && _hovered
                  ? _green.withOpacity(0.18)
                  : _green.withOpacity(active ? 0.10 : 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withOpacity(active ? (_hovered ? 0.6 : 0.35) : 0.15),
              ),
              boxShadow: active && _hovered
                  ? [BoxShadow(color: _green.withOpacity(0.15), blurRadius: 8)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 15, color: color),
                const SizedBox(width: 4),
                Text(
                  'Run',
                  style: TextStyle(
                    color:      color,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _StopButton
// ─────────────────────────────────────────────────────────────────────────────

class _StopButton extends StatefulWidget {
  const _StopButton({required this.chrome, required this.onTap});
  final EditorChromeColors chrome;
  final VoidCallback       onTap;

  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = widget.chrome.consoleTextError;

    return Tooltip(
      message: 'Stop execution',
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: FadeTransition(
            opacity: _pulseAnim,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height:   28,
              padding:  const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color:        _hovered
                    ? red.withOpacity(0.18)
                    : red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: red.withOpacity(_hovered ? 0.7 : 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, size: 14, color: red),
                  const SizedBox(width: 4),
                  Text(
                    'Stop',
                    style: TextStyle(
                      color:      red,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _RunStatusLabel
// ─────────────────────────────────────────────────────────────────────────────

class _RunStatusLabel extends StatelessWidget {
  const _RunStatusLabel({
    required this.status,
    required this.chrome,
    required this.syntax,
  });

  final RunStatus          status;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  @override
  Widget build(BuildContext context) {
    if (status == RunStatus.idle) return const SizedBox.shrink();

    String label;
    Color  color;

    switch (status) {
      case RunStatus.running:
        label = 'Running…';
        color = chrome.cursorColor;
      case RunStatus.done:
        label = 'Done';
        color = chrome.consoleTextSuccess;
      case RunStatus.error:
        label = 'Stopped';
        color = chrome.consoleTextError;
      case RunStatus.idle:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label,
        style: TextStyle(
          color:     color.withOpacity(0.75),
          fontSize:  10.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ToolbarDivider
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider({required this.chrome});
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Container(
      width:  1,
      height: 18,
      color:  chrome.gutterBorder.withOpacity(0.7),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ReadOnlyPill
// ─────────────────────────────────────────────────────────────────────────────

class _ReadOnlyPill extends StatelessWidget {
  const _ReadOnlyPill({required this.chrome});
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color:        chrome.consoleTextInfo.withOpacity(0.08),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: chrome.consoleTextInfo.withOpacity(0.25)),
    ),
    child: Text(
      'READ ONLY',
      style: TextStyle(
        color:         chrome.consoleTextInfo,
        fontSize:      8.5,
        fontWeight:    FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _UnsavedBadge
// ─────────────────────────────────────────────────────────────────────────────

class _UnsavedBadge extends StatelessWidget {
  const _UnsavedBadge({required this.chrome});
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) => Container(
    width:  6, height: 6,
    decoration: BoxDecoration(
      color:  chrome.cursorColor,
      shape:  BoxShape.circle,
      boxShadow: [
        BoxShadow(color: chrome.cursorColor.withOpacity(0.5), blurRadius: 4),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _PublishDialog
// ─────────────────────────────────────────────────────────────────────────────

class _PublishDialog extends StatefulWidget {
  const _PublishDialog({
    required this.file,
    required this.hook,
    required this.chrome,
    required this.syntax,
  });

  final ScriptFile              file;
  final IsolatedTradingViewHook hook;
  final EditorChromeColors      chrome;
  final EditorSyntaxColors      syntax;

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.file.name.replaceAll('.py', ''),
    );
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() => _isPublishing = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.public_rounded,
                size: 14, color: widget.chrome.consoleTextSuccess),
            const SizedBox(width: 8),
            Text(
              '"${_nameCtrl.text.trim()}" published to shared indicators.',
              style: TextStyle(
                color:    widget.chrome.consoleTextSuccess,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: widget.chrome.surface,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final syntax = widget.syntax;

    return AlertDialog(
      backgroundColor: chrome.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.public_rounded, size: 18, color: chrome.consoleTextSuccess),
          const SizedBox(width: 8),
          Text(
            'Publish Indicator',
            style: TextStyle(
              color:      syntax.plain,
              fontSize:   16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will make the indicator visible to all Exclusive users.',
              style: TextStyle(
                color:  syntax.comment.withOpacity(0.7),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'INDICATOR NAME',
              style: TextStyle(
                color:         syntax.comment.withOpacity(0.5),
                fontSize:      9.5,
                fontWeight:    FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            _DialogInput(
              ctrl:   _nameCtrl,
              hint:   'e.g. RSI Momentum Strategy',
              chrome: chrome,
              syntax: syntax,
            ),
            const SizedBox(height: 12),
            Text(
              'DESCRIPTION (optional)',
              style: TextStyle(
                color:         syntax.comment.withOpacity(0.5),
                fontSize:      9.5,
                fontWeight:    FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            _DialogInput(
              ctrl:     _descCtrl,
              hint:     'What does this indicator do?',
              chrome:   chrome,
              syntax:   syntax,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:        chrome.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: chrome.gutterBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.code_rounded,
                      size: 13, color: syntax.string.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Text(
                    widget.file.name,
                    style: TextStyle(
                      color:      syntax.plain.withOpacity(0.7),
                      fontSize:   12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.file.content.split('\n').length} lines',
                    style: TextStyle(
                      color:    syntax.comment.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPublishing ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: syntax.comment, fontSize: 13)),
        ),
        TextButton(
          onPressed: _isPublishing ? null : _publish,
          child: _isPublishing
              ? SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: chrome.consoleTextSuccess,
                  ),
                )
              : Text(
                  'Publish',
                  style: TextStyle(
                    color:      chrome.consoleTextSuccess,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DialogInput
// ─────────────────────────────────────────────────────────────────────────────

class _DialogInput extends StatelessWidget {
  const _DialogInput({
    required this.ctrl,
    required this.hint,
    required this.chrome,
    required this.syntax,
    this.maxLines = 1,
  });

  final TextEditingController ctrl;
  final String                hint;
  final EditorChromeColors    chrome;
  final EditorSyntaxColors    syntax;
  final int                   maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller:  ctrl,
    maxLines:    maxLines,
    style:       TextStyle(color: syntax.plain, fontSize: 13),
    cursorColor: chrome.cursorColor,
    cursorWidth: 1.5,
    decoration: InputDecoration(
      hintText:       hint,
      hintStyle:      TextStyle(color: syntax.comment, fontSize: 13),
      filled:         true,
      fillColor:      chrome.background,
      isDense:        true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   BorderSide(color: chrome.gutterBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   BorderSide(color: chrome.gutterBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: chrome.cursorColor.withOpacity(0.6)),
      ),
    ),
  );
}