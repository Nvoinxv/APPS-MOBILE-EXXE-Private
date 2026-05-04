// =============================================================================
// console_state.dart
// Path: frontend/lib/trading_screen/output_console/console_state.dart
//
// CHANGES v_execute:
//  - [NEW] executeCode(String code) — one-shot method: startRun →
//          ExecuteHook.runCode → setResult. Dipanggil dari editor_toolbar
//          atau tradingviewcodeeditor_screen, bukan perlu manage state sendiri.
//  - [NEW] stopRun() — set status error + tulis warning buat Stop button.
//  - [KEPT] startRun(), setResult(), semua write helpers — tidak diubah.
//  - Import execute_hook.dart sudah ada sebelumnya, sekarang benar-benar dipakai.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../hooks/execute_hook.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────────────────────────────────────────

enum LogLevel  { stdout, stderr, info, success, warning, system }
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

  // ── Getters ────────────────────────────────────────────────────────────────

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

  // ── Write helpers — tidak diubah ───────────────────────────────────────────

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

  // ── State control — tidak diubah ──────────────────────────────────────────

  void setStatus(RunStatus s) {
    _status = s;
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    _lineCount = 0;
    _status    = RunStatus.idle;
    notifyListeners();
  }

  void startRun([String? fileName]) {
    clear();
    _status = RunStatus.running;
    writeSystem('▶  Running${fileName != null ? ' $fileName' : ' script'}...');
    writeSystem('─' * 48);
  }

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
    } else {
      writeInfo('(no output)');
    }

    if (stderr.trim().isNotEmpty) {
      writeSystem('─' * 48);
      for (final line in stderr.split('\n')) {
        if (line.isEmpty) continue;
        write(line, level: LogLevel.stderr);
      }
    }

    writeSystem('─' * 48);

    if (exitCode == 0) {
      writeSuccess('✓  Process exited with code 0');
      _status = RunStatus.done;
    } else {
      writeWarning('✗  Process exited with code $exitCode');
      _status = RunStatus.error;
    }

    notifyListeners();
  }

  // ── [NEW] stopRun — dipanggil dari Stop button ────────────────────────────
  //
  //  ExecuteHook tidak support cancel mid-flight (fire-and-forget HTTP),
  //  jadi kita set status error sekarang → guard di executeCode() cek
  //  isRunning sebelum setResult() → output tidak di-push setelah stop.
  // ─────────────────────────────────────────────────────────────────────────
  void stopRun() {
    if (_status != RunStatus.running) return;
    writeSystem('─' * 48);
    writeWarning('⚠  Execution stopped by user.');
    _status = RunStatus.error;
    notifyListeners();
  }

  // ── [NEW] executeCode — one-shot: startRun → ExecuteHook → setResult ─────
  //
  //  Usage di toolbar / screen:
  //
  //    await console.executeCode(activeFile.content, fileName: activeFile.name);
  //
  //  Method ini handle semua state transitions sendiri. Caller tidak perlu
  //  manggil startRun / setResult / setStatus secara manual.
  //
  //  Guard `isRunning` sebelum setResult() memastikan kalau stopRun()
  //  dipanggil saat awaiting, output tidak di-push ke console.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> executeCode(String code, {String? fileName}) async {
    // Guard: jangan double-run
    if (_status == RunStatus.running) return;

    // Guard: jangan run kode kosong
    if (code.trim().isEmpty) {
      writeWarning('Nothing to run — file is empty.');
      return;
    }

    // 1. Setup console
    startRun(fileName);

    try {
      // 2. Hit backend via ExecuteHook
      final result = await ExecuteHook.runCode(code);

      // 3. Guard: stop dipencet sebelum response balik
      if (!isRunning) return;

      // 4. Push hasil ke console
      setResult(
        stdout:   (result['stdout']    as String?) ?? '',
        stderr:   (result['stderr']    as String?) ?? '',
        exitCode: (result['exit_code'] as int?)    ?? -1,
      );
    } catch (e) {
      // 5. Network error / timeout
      if (isRunning) {
        writeSystem('─' * 48);
        writeError('ExecuteHook error: $e');
        _status = RunStatus.error;
        notifyListeners();
      }
    }
  }

  // ── Filter ─────────────────────────────────────────────────────────────────

  void setFilter(LogLevel? level) {
    _filter = level;
    notifyListeners();
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  String get allText => _logs
      .map((l) => '[${_timeStr(l.timestamp)}] ${l.message}')
      .join('\n');

  static String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}