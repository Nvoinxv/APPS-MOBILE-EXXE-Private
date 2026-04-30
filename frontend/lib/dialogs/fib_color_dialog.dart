// =============================================================================
// fib_color_dialog.dart
// Path: frontend/lib/dialogs/fib_color_dialog.dart
//
// Dialog for editing per-level colors of a FibonacciOverlay.
// Called via FibColorDialog.show(ctx, levels: ..., onChanged: ...).
// =============================================================================

import 'package:flutter/material.dart';
import 'fib_level.dart';
import 'chart_style.dart';
import 'color_picker.dart';

class FibColorDialog {
  static Future<void> show(
    BuildContext context, {
    required List<FibLevel> levels,
    required ChartStyleState chartStyle,
    required void Function(List<FibLevel>) onChanged,
  }) {
    return showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      barrierColor:       Colors.black.withOpacity(0.6),
      builder: (_) => _FibColorSheet(
        levels:     levels,
        chartStyle: chartStyle,
        onChanged:  onChanged,
      ),
    );
  }
}

// ===========================================================================
// Sheet widget
// ===========================================================================

class _FibColorSheet extends StatefulWidget {
  final List<FibLevel>              levels;
  final ChartStyleState             chartStyle;
  final void Function(List<FibLevel>) onChanged;

  const _FibColorSheet({
    required this.levels,
    required this.chartStyle,
    required this.onChanged,
  });

  @override
  State<_FibColorSheet> createState() => _FibColorSheetState();
}

class _FibColorSheetState extends State<_FibColorSheet> {
  late List<FibLevel> _levels;

  static const _bg     = Color(0xFF0E1117);
  static const _border = Color(0xFF1E2333);
  static const _muted  = Color(0xFF6B7280);
  static const _text   = Color(0xFFE8EAF0);

  @override
  void initState() {
    super.initState();
    _levels = List.from(widget.levels);
  }

  void _update(int i, FibLevel updated) {
    setState(() => _levels[i] = updated);
    widget.onChanged(List.from(_levels));
  }

  void _resetAll() {
    setState(() => _levels = List.from(FibLevel.defaults));
    widget.onChanged(List.from(_levels));
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height:     screenH * 0.75,
      decoration: const BoxDecoration(
        color:        _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border:       Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(context),
          const Divider(color: _border, height: 1),
          Expanded(
            child: ListView.separated(
              padding:          const EdgeInsets.symmetric(vertical: 8),
              itemCount:        _levels.length,
              separatorBuilder: (_, __) => const Divider(color: _border, height: 1),
              itemBuilder:      (_, i) => _LevelRow(
                level:      _levels[i],
                accent:     widget.chartStyle.bullishColor,
                onChanged:  (updated) => _update(i, updated),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
        color: _muted.withOpacity(0.4), borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
    child: Row(
      children: [
        const Text('FIBONACCI COLORS', style: TextStyle(
          color: _text, fontSize: 13,
          fontWeight: FontWeight.w700, letterSpacing: 1.8,
        )),
        const Spacer(),
        TextButton(
          onPressed: _resetAll,
          child: const Text('Reset', style: TextStyle(color: _muted, fontSize: 12)),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

// ===========================================================================
// Per-level row
// ===========================================================================

class _LevelRow extends StatelessWidget {
  final FibLevel  level;
  final Color     accent;
  final void Function(FibLevel) onChanged;

  const _LevelRow({
    required this.level,
    required this.accent,
    required this.onChanged,
  });

  static const _muted = Color(0xFF6B7280);
  static const _text  = Color(0xFFB2B5BE);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Ratio label
          SizedBox(
            width: 52,
            child: Text(
              level.label,
              style: TextStyle(
                color:      level.lineColor,
                fontSize:   12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Line color swatch
          _ColorSwatch(
            label:    'Line',
            color:    level.lineColor,
            accent:   accent,
            onPicked: (c) => onChanged(level.copyWith(lineColor: c)),
          ),
          const SizedBox(width: 8),

          // Fill color swatch
          _ColorSwatch(
            label:    'Fill',
            color:    level.fillColor,
            accent:   accent,
            onPicked: (c) => onChanged(level.copyWith(fillColor: c)),
          ),

          const Spacer(),

          // Show label toggle
          _SmallSwitch(
            label:     'Label',
            value:     level.showLabel,
            color:     accent,
            onChanged: (v) => onChanged(level.copyWith(showLabel: v)),
          ),
          const SizedBox(width: 8),

          // Dashed toggle
          _SmallSwitch(
            label:     'Dash',
            value:     level.isDashed,
            color:     accent,
            onChanged: (v) => onChanged(level.copyWith(isDashed: v)),
          ),
        ],
      ),
    );
  }
}

// ── Small color swatch button ─────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final String              label;
  final Color               color;
  final Color               accent;
  final void Function(Color) onPicked;

  const _ColorSwatch({
    required this.label,
    required this.color,
    required this.accent,
    required this.onPicked,
  });

  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final picked = await FullColorPicker.show(context, initial: color);
            if (picked != null) onPicked(picked);
          },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:        color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.35), blurRadius: 5),
              ],
            ),
            child: Icon(
              Icons.colorize_rounded,
              size:  14,
              color: color.computeLuminance() > 0.4 ? Colors.black : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Compact toggle ────────────────────────────────────────────────────────────

class _SmallSwitch extends StatelessWidget {
  final String             label;
  final bool               value;
  final Color              color;
  final void Function(bool) onChanged;

  const _SmallSwitch({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
        Transform.scale(
          scale: 0.72,
          child: Switch(
            value:              value,
            onChanged:          onChanged,
            activeColor:        color,
            inactiveThumbColor: _muted,
            inactiveTrackColor: const Color(0xFF1E2333),
          ),
        ),
      ],
    );
  }
}