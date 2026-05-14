// =============================================================================
// console_state.dart
// Path: frontend/lib/trading_screen/output_console/console_state.dart
//
// FIX:
//  - [UPDATED] executeCode() — ganti param cwd (String?) → folderId (String?)
//    dan forward ke ExecuteHook.runCodeStream(folderId: folderId).
//    Sebelumnya pakai cwd tapi runCodeStream tidak punya param itu
//    → compile error: No named parameter with the name 'cwd'.
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

  // ── Write helpers ──────────────────────────────────────────────────────────

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

  // ── State control ──────────────────────────────────────────────────────────

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

  // ── stopRun ────────────────────────────────────────────────────────────────

  void stopRun() {
    if (_status != RunStatus.running) return;
    writeSystem('─' * 48);
    writeWarning('⚠  Execution stopped by user.');
    _status = RunStatus.error;
    notifyListeners();
  }

  // ── appendLine — bridge SSE type string → LogLevel ────────────────────────

  void appendLine({required String type, required String text}) {
    if (!isRunning) return;

    final level = switch (type) {
      'stdout' => LogLevel.stdout,
      'stderr' => LogLevel.stderr,
      'system' => LogLevel.system,
      _        => LogLevel.info,
    };

    write(text, level: level);
  }

  // ── setDone — finalize setelah stream exit event ───────────────────────────

  void setDone(int exitCode) {
    if (!isRunning) return;

    if (exitCode == 0) {
      writeSuccess('✓  Process exited with code 0');
      _status = RunStatus.done;
    } else {
      writeWarning('✗  Process exited with code $exitCode');
      _status = RunStatus.error;
    }

    notifyListeners();
  }

  // ── executeCode — FIX: ganti cwd → folderId ───────────────────────────────
  //
  //  Sebelumnya: param cwd (String?) → forward ke runCodeStream(cwd: cwd)
  //  → compile error karena runCodeStream tidak punya param 'cwd'.
  //
  //  Sekarang: param folderId (String?) → forward ke runCodeStream(folderId: folderId).
  //  folderId diisi oleh caller (_runCode di tradingviewcodeeditor_screen.dart)
  //  via folderIdFromWorkspace(hook.workspace, activeFile).
  //  Null kalau file tidak berada dalam folder manapun.
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> executeCode(
    String code, {
    String? fileName,
    String? folderId,   // ← FIX: was cwd (String?)
  }) async {
    if (_status == RunStatus.running) return;

    if (code.trim().isEmpty) {
      writeWarning('Nothing to run — file is empty.');
      return;
    }

    startRun(fileName);

    await ExecuteHook.runCodeStream(
      code:     code,
      folderId: folderId,  // ← FIX: was cwd
      onData: (type, data) {
        appendLine(type: type, text: data);
      },
      onDone: (exitCode) {
        setDone(exitCode);
      },
      onError: (error) {
        if (isRunning) {
          writeSystem('─' * 48);
          writeError(error);
          _status = RunStatus.error;
          notifyListeners();
        }
      },
    );
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