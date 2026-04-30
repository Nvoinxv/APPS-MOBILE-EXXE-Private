// =============================================================================
// console_state.dart
// Path: frontend/lib/trading_screen/tradingview/console_state.dart
//
// Model + state untuk output console panel.
// Dipisah dari UI supaya mudah di-test dan di-maintain.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../hooks/execute_hook.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────────────────────────────────────────

enum LogLevel { stdout, stderr, info, success, warning, system }

enum RunStatus { idle, running, done, error }

// ─────────────────────────────────────────────────────────────────────────────
//  ConsoleLog — satu baris log
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleLog {
  final String   message;
  final LogLevel level;
  final DateTime timestamp;
  final int      lineNumber;

  const ConsoleLog({
    required this.message,
    required this.level,
    required this.timestamp,
    required this.lineNumber,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ConsoleState — ChangeNotifier, di-listen oleh OutputConsolePanel
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleState extends ChangeNotifier {
  final List<ConsoleLog> _logs      = [];
  RunStatus              _status    = RunStatus.idle;
  int                    _lineCount = 0;
  LogLevel?              _filter;

  RunStatus get status    => _status;
  LogLevel? get filter    => _filter;
  bool      get isRunning => _status == RunStatus.running;
  bool      get isEmpty   => _logs.isEmpty;

  List<ConsoleLog> get logs {
    if (_filter == null) return List.unmodifiable(_logs);
    return _logs.where((l) => l.level == _filter).toList();
  }

  int get errorCount   => _logs.where((l) => l.level == LogLevel.stderr).length;
  int get warningCount => _logs.where((l) => l.level == LogLevel.warning).length;

  // ── write helpers ──────────────────────────────────────────────────────────

  void write(String message, {LogLevel level = LogLevel.stdout}) {
    for (final line in message.split('\n')) {
      if (line.isEmpty) continue;
      _logs.add(ConsoleLog(
        message:    line,
        level:      level,
        timestamp:  DateTime.now(),
        lineNumber: ++_lineCount,
      ));
    }
    notifyListeners();
  }

  void writeInfo(String msg)    => write(msg, level: LogLevel.info);
  void writeError(String msg)   => write(msg, level: LogLevel.stderr);
  void writeSuccess(String msg) => write(msg, level: LogLevel.success);
  void writeWarning(String msg) => write(msg, level: LogLevel.warning);
  void writeSystem(String msg)  => write(msg, level: LogLevel.system);

  // ── state control ──────────────────────────────────────────────────────────

  void setStatus(RunStatus status) {
    _status = status;
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    _lineCount = 0;
    _status    = RunStatus.idle;
    notifyListeners();
  }

  /// Dipanggil sebelum kirim request ke backend
  void startRun() {
    clear();
    _status = RunStatus.running;
    writeSystem('▶  Running script...');
    notifyListeners();
  }

  /// Dipanggil setelah dapat response dari backend
  void setResult({
    required String stdout,
    required String stderr,
    required int    exitCode,
  }) {
    if (stdout.trim().isNotEmpty) {
      for (final line in stdout.split('\n')) {
        if (line.isEmpty) continue;
        write(line, level: LogLevel.stdout);
      }
    }

    if (stderr.trim().isNotEmpty) {
      for (final line in stderr.split('\n')) {
        if (line.isEmpty) continue;
        write(line, level: LogLevel.stderr);
      }
    }

    if (exitCode == 0) {
      writeSuccess('✓  Exited with code 0');
      _status = RunStatus.done;
    } else {
      writeSystem('✗  Exited with code $exitCode');
      _status = RunStatus.error;
    }

    notifyListeners();
  }

  void setFilter(LogLevel? level) {
    _filter = level;
    notifyListeners();
  }

  // ── export ─────────────────────────────────────────────────────────────────

  String get allText => _logs
      .map((l) => '[${_timeStr(l.timestamp)}] ${l.message}')
      .join('\n');

  static String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}