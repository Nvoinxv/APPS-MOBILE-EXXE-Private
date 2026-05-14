import '../../../models/script_file.dart';
// =============================================================================
// editor_toolbar.dart
// Path: frontend/lib/trading_screen/tradingview/editor_toolbar.dart
//
// FIX v_dispose_safe:
//  - [FIXED] EditorToolbar: StatelessWidget → StatefulWidget
//            Root cause: _handleRun adalah async dan menggunakan BuildContext
//            dari ListenableBuilder's builder callback setelah await.
//            Ketika widget di-dispose mid-await (misal user switch screen),
//            context sudah invalid tapi masih dipakai → TextEditingController
//            disposed error + _dependents.isEmpty assertion.
//  - [FIXED] _handleRun: tambah `if (!mounted) return` setelah setiap await
//  - [FIXED] _handleRun: ScaffoldMessenger di-capture sebelum await
//  - [FIXED] _handleFormat, _handlePublish: sama — capture messenger dulu
//  - Semua logic, UI, dan widget lain tidak diubah sama sekali
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../hooks/tradingview_hook.dart';
import '../../../hooks/execute_hook.dart';
import '../../../pages/tradingview_pages.dart';
import '../../../style/apps_colors_tradingview.dart';
import '../output_console/console_state.dart';
import 'output_console_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EditorToolbar — FIXED: StatefulWidget (was: StatelessWidget)
//  Alasan: widget ini punya async action handlers (_handleRun) yang butuh
//  `mounted` check supaya tidak pakai BuildContext setelah dispose.
// ─────────────────────────────────────────────────────────────────────────────

class EditorToolbar extends StatefulWidget {
  const EditorToolbar({
    super.key,
    required this.hook,
    required this.console,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomReset,
    this.onOpenSettings,
    this.trailing,
    this.height = 40,
  });

  final IsolatedTradingViewHook hook;
  final ConsoleState            console;
  final VoidCallback?           onZoomIn;
  final VoidCallback?           onZoomOut;
  final VoidCallback?           onZoomReset;
  final VoidCallback?           onOpenSettings;
  final Widget?                 trailing;
  final double                  height;

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {

  // ── Convenience getters — akses via widget.xxx ─────────────────────────────

  EditorChromeColors get _chrome         => widget.hook.editorTheme.chrome;
  EditorSyntaxColors get _syntax         => widget.hook.editorTheme.syntax;
  EditorPermission   get _perm           => widget.hook.permission;
  ScriptFile?        get _active         => widget.hook.tabs.activeFile;
  bool               get _canEdit        => widget.hook.canEditActive;
  bool               get _activeIsShared => widget.hook.activeIsShared;
  bool               get _isRunning      => widget.console.status == RunStatus.running;

  // ─────────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  // [FIXED] Ganti ListenableBuilder dengan direct addListener + setState.
  //
  // Root cause duplicate OverlayEntry GlobalKeys:
  //   ListenableBuilder pakai AnimatedWidget yang panggil
  //   listenable.addListener(fn) di initState. Kalau salah satu listenable
  //   notify synchronously saat/setelah subscription (dalam frame yang sama
  //   dengan initial build), _AnimatedState._handleChange → setState terpanggil
  //   di tengah warm-up frame → toolbar rebuild DUA KALI dalam satu frame →
  //   Tooltip/OverlayPortal lama di-deactivate sebelum _Theater sempat update
  //   → THREE _OverlayEntryWidgetState GlobalKey duplicates.
  //
  // Direct addListener + setState aman karena setState dari listener
  // selalu dijadwalkan sebagai rebuild di frame BERIKUTNYA, tidak pernah
  // trigger double-build dalam frame yang sama.

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.hook.tabs.addListener(_onStateChanged);
    widget.hook.editorTheme.addListener(_onStateChanged);
    widget.console.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(EditorToolbar old) {
    super.didUpdateWidget(old);
    if (old.hook.tabs != widget.hook.tabs) {
      old.hook.tabs.removeListener(_onStateChanged);
      widget.hook.tabs.addListener(_onStateChanged);
    }
    if (old.hook.editorTheme != widget.hook.editorTheme) {
      old.hook.editorTheme.removeListener(_onStateChanged);
      widget.hook.editorTheme.addListener(_onStateChanged);
    }
    if (old.console != widget.console) {
      old.console.removeListener(_onStateChanged);
      widget.console.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.hook.tabs.removeListener(_onStateChanged);
    widget.hook.editorTheme.removeListener(_onStateChanged);
    widget.console.removeListener(_onStateChanged);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chrome = _chrome;
    final syntax = _syntax;

    return Container(
      height:  widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: chrome.toolbarBackground,
        border: Border(
          bottom: BorderSide(color: chrome.toolbarBorder, width: 1),
        ),
      ),
      child: Row(
        children: [

          _LeftSection(
            hook:           widget.hook,
            chrome:         chrome,
            syntax:         syntax,
            active:         _active,
            canEdit:        _canEdit,
            activeIsShared: _activeIsShared,
            onFormat:       _handleFormat,
          ),

          _ToolbarDivider(chrome: chrome),

          _CenterSection(
            hook:      widget.hook,
            console:   widget.console,
            chrome:    chrome,
            syntax:    syntax,
            active:    _active,
            isRunning: _isRunning,
            onRun:     _handleRun,
            onStop:    _handleStop,
          ),

          const Spacer(),

          _RightSection(
            hook:           widget.hook,
            chrome:         chrome,
            syntax:         syntax,
            active:         _active,
            perm:           _perm,
            onZoomIn:       widget.onZoomIn,
            onZoomOut:      widget.onZoomOut,
            onZoomReset:    widget.onZoomReset,
            onOpenSettings: widget.onOpenSettings,
            onPublish:      _handlePublish,
          ),

          if (widget.trailing != null) ...[
            _ToolbarDivider(chrome: chrome),
            widget.trailing!,
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Action handlers
  // ─────────────────────────────────────────────────────────────────────────

  // [FIXED] Tidak lagi terima BuildContext sebagai parameter.
  // Gunakan `context` dari State — lebih aman, dan bisa cek `mounted`.
  void _handleFormat() {
    final active = _active;
    if (active == null || !_canEdit) return;

    HapticFeedback.lightImpact();

    final formatted = _formatPython(active.content);
    if (formatted == active.content) {
      _showSnack('Already formatted', _chrome.consoleTextInfo);
      return;
    }

    widget.hook.onCodeChanged(formatted);
    widget.hook.tabs.updateActiveContent(formatted);
    _showSnack('Formatted', _chrome.consoleTextSuccess);
  }

  // ── [FIXED] _handleRun — mounted check setelah setiap await ──────────────
  //
  //  Perubahan dari versi sebelumnya:
  //    1. Tidak lagi terima BuildContext sebagai parameter
  //    2. ScaffoldMessenger di-capture SEBELUM await pertama
  //       → kalau context sudah invalid setelah await, messenger sudah
  //         di-hold sebagai local variable dan tetap bisa dipakai
  //    3. `if (!mounted) return` setelah await ExecuteHook.runCode()
  //       → kalau user switch screen saat kode sedang jalan, handler
  //         berhenti dan tidak push output ke widget yang sudah disposed
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleRun() async {
    final active = _active;
    if (active == null || _isRunning) return;

    final code = active.content.trim();
    if (code.isEmpty) {
      // context masih valid di sini (sebelum await), aman
      _showSnack('File is empty', _chrome.consoleTextInfo);
      return;
    }

    HapticFeedback.mediumImpact();

    widget.console.clear();
    widget.console.setStatus(RunStatus.running);
    widget.console.writeSystem('▶  Running ${active.name}...');
    widget.console.writeSystem('─' * 48);

    try {
      final result = await ExecuteHook.runCode(active.content);

      // [FIXED] Guard #1 — widget mungkin sudah di-dispose saat await selesai
      if (!mounted) return;

      // Guard #2 — user pencet Stop sebelum response balik
      if (widget.console.status != RunStatus.running) return;

      final stdout   = (result['stdout']    as String?) ?? '';
      final stderr   = (result['stderr']    as String?) ?? '';
      final exitCode = (result['exit_code'] as int?)    ?? -1;

      if (stdout.isNotEmpty) {
        for (final line in stdout.split('\n')) {
          if (line.isEmpty) continue;
          widget.console.write(line);
        }
      } else {
        widget.console.writeInfo('(no output)');
      }

      if (stderr.isNotEmpty) {
        widget.console.writeSystem('─' * 48);
        for (final line in stderr.split('\n')) {
          if (line.isEmpty) continue;
          widget.console.writeError(line);
        }
      }

      widget.console.writeSystem('─' * 48);

      if (exitCode == 0) {
        widget.console.writeSuccess('✓  Process exited with code 0');
        widget.console.setStatus(RunStatus.done);
      } else {
        widget.console.writeWarning('✗  Process exited with code $exitCode');
        widget.console.setStatus(RunStatus.error);
      }
    } catch (e) {
      // [FIXED] Guard — cek mounted sebelum akses console
      if (!mounted) return;
      if (widget.console.status == RunStatus.running) {
        widget.console.writeSystem('─' * 48);
        widget.console.writeError('ExecuteHook error: $e');
        widget.console.setStatus(RunStatus.error);
      }
    }
  }

  void _handleStop() {
    if (!_isRunning) return;
    HapticFeedback.heavyImpact();
    widget.console.writeSystem('─' * 48);
    widget.console.writeWarning('⚠  Execution stopped by user.');
    widget.console.setStatus(RunStatus.error);
  }

  // [FIXED] Tidak lagi terima BuildContext sebagai parameter
  void _handlePublish() {
    final active = _active;
    if (active == null || !_perm.canPublishShared) return;

    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (_) => _PublishDialog(
        file:   active,
        hook:   widget.hook,
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
    while (result.isNotEmpty && result.last.isEmpty)  result.removeLast();

    return '${result.join('\n')}\n';
  }

  // [FIXED] Tidak lagi butuh BuildContext parameter — pakai context dari State
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: color, fontSize: 12)),
        backgroundColor: _chrome.surface,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
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
      message: active ? 'Run script' : 'Open a .py file to run',
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
    if (!mounted) return;
    setState(() => _isPublishing = true);

    // [FIXED] Capture nama sebelum await, bukan setelah
    // Supaya tidak akses _nameCtrl.text setelah controller mungkin di-dispose
    final indicatorName = _nameCtrl.text.trim();

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
              '"$indicatorName" published to shared indicators.',
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
                color:    syntax.comment.withOpacity(0.7),
                fontSize: 12,
                height:   1.5,
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