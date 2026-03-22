// ══════════════════════════════════════════════════════════════════════════════
// frontend/lib/interactive/strategy_interactive_2.dart
//
// Controller + Gate untuk Strategy 2.
// - Strategy2Controller : ChangeNotifier yang pegang state aktif/nonaktif
// - Strategy2Gate       : wrapper widget yang listen ke controller
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ── Controller ────────────────────────────────────────────────────────────────

class Strategy2Controller extends ChangeNotifier {
  bool _isActive;

  Strategy2Controller({bool initialActive = true})
      : _isActive = initialActive;

  bool get isActive => _isActive;

  void toggle() {
    _isActive = !_isActive;
    notifyListeners();
  }

  void setActive(bool value) {
    if (_isActive == value) return;
    _isActive = value;
    notifyListeners();
  }
}

// ── Gate ──────────────────────────────────────────────────────────────────────

class Strategy2Gate extends StatefulWidget {
  final Strategy2Controller controller;

  /// isSignalEnabled diteruskan ke MainStrategy.
  /// Trade lama tetap jalan; hanya sinyal BARU yang diblokir saat nonaktif.
  final Widget Function(bool isSignalEnabled) builder;

  const Strategy2Gate({
    Key? key,
    required this.controller,
    required this.builder,
  }) : super(key: key);

  @override
  State<Strategy2Gate> createState() => _Strategy2GateState();
}

class _Strategy2GateState extends State<Strategy2Gate> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) =>
      widget.builder(widget.controller.isActive);
}