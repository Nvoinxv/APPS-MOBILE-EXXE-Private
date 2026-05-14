// =============================================================================
// hooks/execute_hook.dart
//
// Sync dengan backend:
//   POST /execute         → one-shot, return JSON
//   POST /execute/stream  → SSE streaming, output real-time line-by-line
//
// Payload: { "code": "...", "timeout": 10, "folder_id": "abc123" }
//
// FIX — Modular workspace support:
//   - Ganti cwd (path string) → folder_id (MongoDB folder _id).
//   - Backend fetch semua file dalam folder subtree dari DB,
//     tulis ke tempdir, lalu Python bisa resolve cross-file imports.
//   - folderIdFromWorkspace() helper: ambil parentFolderId dari file aktif,
//     lalu cari root ancestor-nya via WorkspaceState.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/script_file.dart';
import 'tradingview_hook.dart'; // WorkspaceState
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Helper: resolve root folder_id dari WorkspaceState + ScriptFile aktif
//
//  Backend butuh root folder_id (parent paling atas) supaya bisa fetch
//  semua file dalam subtree, termasuk sub-subfolder.
//
//  Contoh:
//    file "main.py" ada di folder "indikator_buat_uji_coba" (root)
//    → folder_id = id folder "indikator_buat_uji_coba"
//
//    file "TESTING_1.py" ada di subfolder "TESTING"
//    → walk up → root ancestor = "indikator_buat_uji_coba"
//    → folder_id = id folder "indikator_buat_uji_coba"
//
//  Return null kalau file di root workspace (tidak dalam folder apapun).
// ─────────────────────────────────────────────────────────────────────────────

String? folderIdFromWorkspace(WorkspaceState workspace, ScriptFile file) {
  final parentId = file.parentFolderId;
  if (parentId == null) return null;

  String  currentId = parentId;
  String? rootId;
  var     safety    = 0;

  while (safety++ < 20) {
    final folder = workspace.findFolder(currentId);
    if (folder == null) break;

    rootId = folder.id;

    if (folder.parentFolderId == null) break;  // sudah di root
    currentId = folder.parentFolderId!;
  }

  return rootId;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ExecuteHook
// ─────────────────────────────────────────────────────────────────────────────

class ExecuteHook {
  // ── One-shot (fallback / non-streaming) ────────────────────────────────────
  static Future<Map<String, dynamic>> runCode(
    String code, {
    int     timeout  = 10,
    String? folderId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/execute'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code':    code,
              'timeout': timeout,
              if (folderId != null) 'folder_id': folderId,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'stdout':    '',
          'stderr':    'Server error: ${response.statusCode}',
          'exit_code': -1,
        };
      }
    } on TimeoutException {
      return {
        'stdout':    '',
        'stderr':    '[Timeout] Server tidak merespons dalam 30 detik.',
        'exit_code': -1,
      };
    } catch (e) {
      return {
        'stdout':    '',
        'stderr':    'Connection failed: $e',
        'exit_code': -1,
      };
    }
  }

  // ── Streaming (main) ───────────────────────────────────────────────────────
  //
  // Contoh penggunaan:
  //   final folderId = folderIdFromWorkspace(workspace, activeFile);
  //   await ExecuteHook.runCodeStream(
  //     code:     activeFile.content,
  //     folderId: folderId,
  //     onData:   (type, data) => ...,
  //     onDone:   (code)       => ...,
  //     onError:  (err)        => ...,
  //   );
  //
  static Future<void> runCodeStream({
    required String code,
    required void Function(String type, String data) onData,
    required void Function(int exitCode) onDone,
    required void Function(String error) onError,
    int     timeout  = 15,
    String? folderId,
  }) async {
    final client = http.Client();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/execute/stream'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'code':    code,
        'timeout': timeout,
        if (folderId != null) 'folder_id': folderId,
      });

      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Gagal konek ke server'),
      );

      if (streamedResponse.statusCode != 200) {
        onError('Server error: ${streamedResponse.statusCode}');
        return;
      }

      final completer = Completer<void>();

      streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (!line.startsWith('data: ')) return;
              try {
                final json = jsonDecode(line.substring(6)) as Map<String, dynamic>;
                final type = json['type'] as String;
                final data = json['data'] as String;

                if (type == 'exit') {
                  onDone(int.tryParse(data) ?? -1);
                  if (!completer.isCompleted) completer.complete();
                } else {
                  onData(type, data);
                }
              } catch (_) {
                // skip malformed SSE line
              }
            },
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
            onError: (Object e) {
              onError('Stream error: $e');
              if (!completer.isCompleted) completer.complete();
            },
            cancelOnError: true,
          );

      await completer.future.timeout(
        Duration(seconds: timeout + 10),
        onTimeout: () {
          onError('[Timeout] Eksekusi melebihi batas waktu.');
        },
      );
    } on TimeoutException catch (e) {
      onError('[Timeout] ${e.message}');
    } catch (e) {
      onError('Connection failed: $e');
    } finally {
      client.close();
    }
  }
}