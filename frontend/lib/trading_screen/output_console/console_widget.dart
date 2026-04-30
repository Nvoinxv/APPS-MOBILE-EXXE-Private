// =============================================================================
// console_widgets.dart
// Path: frontend/lib/trading_screen/tradingview/console_widgets.dart
//
// Semua widget private untuk OutputConsolePanel.
// Import file ini dari output_console_panel.dart saja — jangan dari tempat lain.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../output_console/console_state.dart';
import '../../../style/apps_colors_tradingview.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  _ConsoleHeader
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleHeader extends StatelessWidget {
  final TabController     tabCtrl;
  final List<String>      tabs;
  final ConsoleState      console;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final bool              showTimestamps;
  final VoidCallback      onToggleTimestamps;
  final VoidCallback      onClear;
  final VoidCallback      onCopy;
  final bool              autoScroll;
  final VoidCallback      onToggleScroll;

  const ConsoleHeader({
    super.key,
    required this.tabCtrl,
    required this.tabs,
    required this.console,
    required this.chrome,
    required this.syntax,
    required this.showTimestamps,
    required this.onToggleTimestamps,
    required this.onClear,
    required this.onCopy,
    required this.autoScroll,
    required this.onToggleScroll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:     36,
      padding:    const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color:  chrome.toolbarBackground,
        border: Border(bottom: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Row(children: [
        Expanded(
          child: TabBar(
            controller:          tabCtrl,
            isScrollable:        true,
            tabAlignment:        TabAlignment.start,
            indicatorColor:      chrome.cursorColor,
            indicatorWeight:     2,
            indicatorSize:       TabBarIndicatorSize.label,
            labelStyle:          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
            unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            labelColor:          syntax.plain,
            unselectedLabelColor: syntax.plain.withOpacity(0.4),
            dividerColor:        Colors.transparent,
            padding:             EdgeInsets.zero,
            tabs: tabs.map((t) {
              if (t == 'Problems' && console.errorCount > 0) {
                return Tab(height: 36, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t), const SizedBox(width: 5),
                  ConsolePill(count: console.errorCount, color: chrome.consoleTextError, chrome: chrome),
                ]));
              }
              return Tab(text: t, height: 36);
            }).toList(),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ConsoleIconBtn(icon: Icons.filter_list_rounded,          chrome: chrome, syntax: syntax, active: console.filter != null, tooltip: 'Filter logs',                                    onTap: () => _showFilterMenu(context)),
          ConsoleIconBtn(icon: Icons.access_time_rounded,          chrome: chrome, syntax: syntax, active: showTimestamps,          tooltip: showTimestamps ? 'Hide timestamps' : 'Show timestamps', onTap: onToggleTimestamps),
          ConsoleIconBtn(icon: Icons.vertical_align_bottom_rounded, chrome: chrome, syntax: syntax, active: autoScroll,             tooltip: autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF', onTap: onToggleScroll),
          ConsoleIconBtn(icon: Icons.copy_outlined,                chrome: chrome, syntax: syntax,                                  tooltip: 'Copy all output',                                onTap: onCopy),
          ConsoleIconBtn(icon: Icons.delete_sweep_outlined,        chrome: chrome, syntax: syntax,                                  tooltip: 'Clear console',                                  onTap: onClear),
        ]),
      ]),
    );
  }

  void _showFilterMenu(BuildContext context) {
    const items = [
      ('All',     null),
      ('stdout',  LogLevel.stdout),
      ('stderr',  LogLevel.stderr),
      ('Info',    LogLevel.info),
      ('Success', LogLevel.success),
      ('Warning', LogLevel.warning),
      ('System',  LogLevel.system),
    ];
    showMenu<LogLevel?>(
      context:  context,
      position: const RelativeRect.fromLTRB(9999, 36, 0, 0),
      color:    chrome.surface,
      shape:    RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: chrome.gutterBorder),
      ),
      items: items.map((entry) {
        final isActive = console.filter == entry.$2;
        return PopupMenuItem<LogLevel?>(
          value:  entry.$2,
          height: 34,
          onTap:  () => console.setFilter(entry.$2),
          child: Row(children: [
            if (isActive)
              Icon(Icons.check_rounded, size: 13, color: chrome.cursorColor)
            else
              const SizedBox(width: 13),
            const SizedBox(width: 8),
            Text(
              entry.$1,
              style: TextStyle(
                color:      isActive ? chrome.cursorColor : syntax.plain.withOpacity(0.8),
                fontSize:   13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OutputTab — FIX: nampilkan output yang benar, bukan raw source
// ─────────────────────────────────────────────────────────────────────────────

class OutputTab extends StatelessWidget {
  final ConsoleState      console;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final ScrollController  scrollCtrl;
  final bool              showTimestamps;

  const OutputTab({
    super.key,
    required this.console,
    required this.chrome,
    required this.syntax,
    required this.scrollCtrl,
    required this.showTimestamps,
  });

  @override
  Widget build(BuildContext context) {
    final logs = console.logs;
    if (logs.isEmpty) {
      return EmptyConsole(chrome: chrome, syntax: syntax, status: console.status);
    }
    return ListView.builder(
      controller: scrollCtrl,
      padding:    const EdgeInsets.symmetric(vertical: 4),
      itemCount:  logs.length,
      itemBuilder: (_, i) => ConsoleLine(
        log:           logs[i],
        chrome:        chrome,
        syntax:        syntax,
        showTimestamp: showTimestamps,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ProblemsTab
// ─────────────────────────────────────────────────────────────────────────────

class ProblemsTab extends StatelessWidget {
  final ConsoleState      console;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  const ProblemsTab({
    super.key,
    required this.console,
    required this.chrome,
    required this.syntax,
  });

  @override
  Widget build(BuildContext context) {
    final problems = console.logs
        .where((l) => l.level == LogLevel.stderr || l.level == LogLevel.warning)
        .toList();

    if (problems.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline_rounded, size: 28, color: chrome.consoleTextSuccess.withOpacity(0.4)),
        const SizedBox(height: 8),
        Text('No problems detected', style: TextStyle(color: syntax.comment.withOpacity(0.4), fontSize: 12)),
      ]));
    }

    return ListView.builder(
      padding:     const EdgeInsets.symmetric(vertical: 4),
      itemCount:   problems.length,
      itemBuilder: (_, i) {
        final log     = problems[i];
        final isError = log.level == LogLevel.stderr;
        final color   = isError
            ? chrome.consoleTextError
            : chrome.consoleTextWarning ?? Colors.orange;
        return Container(
          margin:     const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
            border:       Border(left: BorderSide(color: color, width: 2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(log.message, style: TextStyle(color: color.withOpacity(0.9), fontSize: 12, fontFamily: 'monospace', height: 1.5))),
            Text('line ${log.lineNumber}', style: TextStyle(color: syntax.comment.withOpacity(0.4), fontSize: 10)),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TerminalTab
// ─────────────────────────────────────────────────────────────────────────────

class TerminalTab extends StatelessWidget {
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  const TerminalTab({super.key, required this.chrome, required this.syntax});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.terminal_rounded, size: 32, color: syntax.comment.withOpacity(0.2)),
      const SizedBox(height: 10),
      Text('Terminal', style: TextStyle(color: syntax.plain.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Coming soon', style: TextStyle(color: syntax.comment.withOpacity(0.25), fontSize: 11)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ConsoleLine — satu baris log dengan hover + copy
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleLine extends StatefulWidget {
  final ConsoleLog        log;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final bool              showTimestamp;

  const ConsoleLine({
    super.key,
    required this.log,
    required this.chrome,
    required this.syntax,
    required this.showTimestamp,
  });

  @override
  State<ConsoleLine> createState() => _ConsoleLineState();
}

class _ConsoleLineState extends State<ConsoleLine> {
  bool _isHovered = false;

  Color get _lineColor {
    switch (widget.log.level) {
      case LogLevel.stdout:  return widget.syntax.plain.withOpacity(0.85);
      case LogLevel.stderr:  return widget.chrome.consoleTextError;
      case LogLevel.info:    return widget.chrome.consoleTextInfo;
      case LogLevel.success: return widget.chrome.consoleTextSuccess;
      case LogLevel.warning: return widget.chrome.consoleTextWarning ?? Colors.orange;
      case LogLevel.system:  return widget.syntax.comment.withOpacity(0.5);
    }
  }

  IconData? get _levelIcon {
    switch (widget.log.level) {
      case LogLevel.stderr:  return Icons.error_outline_rounded;
      case LogLevel.info:    return Icons.info_outline_rounded;
      case LogLevel.success: return Icons.check_circle_outline_rounded;
      case LogLevel.warning: return Icons.warning_amber_rounded;
      case LogLevel.system:  return Icons.settings_ethernet_rounded;
      default:               return null;
    }
  }

  void _copyLine() {
    Clipboard.setData(ClipboardData(text: widget.log.message));
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final icon  = _levelIcon;
    final color = _lineColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onDoubleTap: _copyLine,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color:    _isHovered ? widget.chrome.surface.withOpacity(0.4) : Colors.transparent,
          padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Line number
            SizedBox(
              width: 36,
              child: Text(
                '${widget.log.lineNumber}',
                style:     TextStyle(color: widget.syntax.comment.withOpacity(0.25), fontSize: 11, fontFamily: 'monospace'),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            // Level icon
            if (icon != null) ...[
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 12, color: color)),
              const SizedBox(width: 6),
            ] else
              const SizedBox(width: 18),
            // Timestamp (optional)
            if (widget.showTimestamp) ...[
              Text(
                _timeStr(widget.log.timestamp),
                style: TextStyle(color: widget.syntax.comment.withOpacity(0.35), fontSize: 10.5, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
            ],
            // Message — SelectableText biar bisa di-select user
            Expanded(
              child: SelectableText(
                widget.log.message,
                style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace', height: 1.55),
              ),
            ),
            // Copy icon on hover
            if (_isHovered)
              GestureDetector(
                onTap: _copyLine,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.copy_outlined, size: 11, color: widget.syntax.comment.withOpacity(0.35)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  static String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${(dt.millisecond ~/ 10).toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  ConsoleStatusBar
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleStatusBar extends StatelessWidget {
  final ConsoleState      console;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;

  const ConsoleStatusBar({
    super.key,
    required this.console,
    required this.chrome,
    required this.syntax,
  });

  @override
  Widget build(BuildContext context) {
    final errors   = console.errorCount;
    final warnings = console.warningCount;
    return Container(
      height:     22,
      padding:    const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:  chrome.toolbarBackground,
        border: Border(top: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Row(children: [
        RunStatusDot(status: console.status, chrome: chrome),
        const SizedBox(width: 6),
        Text(
          _statusLabel(console.status),
          style: TextStyle(
            color:      _statusColor(console.status, chrome).withOpacity(0.7),
            fontSize:   10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        if (errors > 0) ...[
          Icon(Icons.error_outline_rounded, size: 10, color: chrome.consoleTextError),
          const SizedBox(width: 3),
          Text('$errors error${errors > 1 ? 's' : ''}', style: TextStyle(color: chrome.consoleTextError.withOpacity(0.7), fontSize: 10)),
          const SizedBox(width: 10),
        ],
        if (warnings > 0) ...[
          Icon(Icons.warning_amber_rounded, size: 10, color: chrome.consoleTextWarning ?? Colors.orange),
          const SizedBox(width: 3),
          Text('$warnings warning${warnings > 1 ? 's' : ''}', style: TextStyle(color: (chrome.consoleTextWarning ?? Colors.orange).withOpacity(0.7), fontSize: 10)),
          const SizedBox(width: 10),
        ],
        Text(
          '${console.logs.length} line${console.logs.length == 1 ? '' : 's'}',
          style: TextStyle(color: syntax.comment.withOpacity(0.35), fontSize: 10),
        ),
      ]),
    );
  }

  String _statusLabel(RunStatus s) {
    switch (s) {
      case RunStatus.idle:    return 'IDLE';
      case RunStatus.running: return 'RUNNING';
      case RunStatus.done:    return 'DONE';
      case RunStatus.error:   return 'ERROR';
    }
  }

  Color _statusColor(RunStatus s, EditorChromeColors c) {
    switch (s) {
      case RunStatus.idle:    return c.consoleTextInfo;
      case RunStatus.running: return c.cursorColor;
      case RunStatus.done:    return c.consoleTextSuccess;
      case RunStatus.error:   return c.consoleTextError;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RunStatusDot — animasi pulse saat running
// ─────────────────────────────────────────────────────────────────────────────

class RunStatusDot extends StatefulWidget {
  final RunStatus         status;
  final EditorChromeColors chrome;

  const RunStatusDot({super.key, required this.status, required this.chrome});

  @override
  State<RunStatusDot> createState() => _RunStatusDotState();
}

class _RunStatusDotState extends State<RunStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.status == RunStatus.running) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RunStatusDot old) {
    super.didUpdateWidget(old);
    if (widget.status == RunStatus.running) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
    }
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Color get _dotColor {
    switch (widget.status) {
      case RunStatus.idle:    return widget.chrome.consoleTextInfo;
      case RunStatus.running: return widget.chrome.cursorColor;
      case RunStatus.done:    return widget.chrome.consoleTextSuccess;
      case RunStatus.error:   return widget.chrome.consoleTextError;
    }
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _pulseAnim,
    child: Container(
      width:  6,
      height: 6,
      decoration: BoxDecoration(
        color:     _dotColor,
        shape:     BoxShape.circle,
        boxShadow: widget.status == RunStatus.running
            ? [BoxShadow(color: _dotColor.withOpacity(0.5), blurRadius: 4)]
            : null,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EmptyConsole
// ─────────────────────────────────────────────────────────────────────────────

class EmptyConsole extends StatelessWidget {
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final RunStatus         status;

  const EmptyConsole({
    super.key,
    required this.chrome,
    required this.syntax,
    required this.status,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight < 48) return const SizedBox.shrink();
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            status == RunStatus.running ? Icons.hourglass_top_rounded : Icons.terminal_rounded,
            size:  28,
            color: syntax.comment.withOpacity(0.2),
          ),
          const SizedBox(height: 8),
          Text(
            status == RunStatus.running
                ? 'Running script...'
                : 'Run a script to see output here',
            style: TextStyle(color: syntax.comment.withOpacity(0.35), fontSize: 12),
          ),
        ]),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ConsoleIconBtn
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleIconBtn extends StatefulWidget {
  final IconData          icon;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback      onTap;
  final String            tooltip;
  final bool              active;

  const ConsoleIconBtn({
    super.key,
    required this.icon,
    required this.chrome,
    required this.syntax,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  @override
  State<ConsoleIconBtn> createState() => _ConsoleIconBtnState();
}

class _ConsoleIconBtnState extends State<ConsoleIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.active || _hovered;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width:  24,
            height: 24,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? (widget.active ? widget.chrome.cursorColor.withOpacity(0.15) : widget.chrome.surface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size:  13,
              color: widget.active
                  ? widget.chrome.cursorColor
                  : (isHighlighted ? widget.syntax.plain : widget.syntax.plain.withOpacity(0.4)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ConsolePill — count badge di tab header
// ─────────────────────────────────────────────────────────────────────────────

class ConsolePill extends StatelessWidget {
  final int               count;
  final Color             color;
  final EditorChromeColors chrome;

  const ConsolePill({
    super.key,
    required this.count,
    required this.color,
    required this.chrome,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('$count', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}