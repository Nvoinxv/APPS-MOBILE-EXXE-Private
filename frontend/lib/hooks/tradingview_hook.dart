// =============================================================================
// tradingview_hook.dart
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../style/apps_colors_tradingview.dart';
import '../models/script_file.dart';
import '../models/script_folder.dart';
import '../utils/auth_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  _TvApi
// ─────────────────────────────────────────────────────────────────────────────

class _TvApi {

  static Future<Map<String, dynamic>> getWorkspace() async {
    final res = await AuthStorage.get('/tradingview/workspace');
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Load folder + file milik satu indicator spesifik
  static Future<Map<String, dynamic>> getIndicatorWorkspace(
      String indicatorId) async {
    final res = await AuthStorage.get(
        '/tradingview/indicators/$indicatorId/workspace');
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<http.Response> _delete(String path) async {
    final token = await AuthStorage.getToken();
    final uri   = Uri.parse('$TestingUrlExternal$path');
    var response = await http.delete(
      uri,
      headers: {
        'Content-Type':  'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 401) {
      final refreshed = await AuthStorage.refreshAccessToken();
      if (refreshed) {
        final newToken = await AuthStorage.getToken();
        response = await http.delete(
          uri,
          headers: {
            'Content-Type':  'application/json',
            if (newToken != null) 'Authorization': 'Bearer $newToken',
          },
        );
      }
    }
    return response;
  }

  static Future<Map<String, dynamic>> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final res = await AuthStorage.post(
      '/tradingview/workspace/folders',
      body: {'name': name, 'parent_folder_id': parentFolderId},
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateFolder(
    String folderId, {
    String? name,
    bool?   isExpanded,
  }) async {
    final body = <String, dynamic>{};
    if (name       != null) body['name']        = name;
    if (isExpanded != null) body['is_expanded'] = isExpanded;
    final res = await AuthStorage.patch(
      '/tradingview/workspace/folders/$folderId',
      body: body,
    );
    _checkStatus(res);
  }

  static Future<void> deleteFolder(String folderId) async {
    final res = await _delete('/tradingview/workspace/folders/$folderId');
    _checkStatus(res);
  }

  static Future<Map<String, dynamic>> createFile({
    required String name,
    required String content,
    String? parentFolderId,
  }) async {
    final res = await AuthStorage.post(
      '/tradingview/workspace/files',
      body: {
        'name':             name,
        'content':          content,
        'parent_folder_id': parentFolderId,
      },
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateFile(
    String fileId, {
    String? name,
    String? content,
  }) async {
    final body = <String, dynamic>{};
    if (name    != null) body['name']    = name;
    if (content != null) body['content'] = content;
    final res = await AuthStorage.patch(
      '/tradingview/workspace/files/$fileId',
      body: body,
    );
    _checkStatus(res);
  }

  static Future<void> saveFile(String fileId) async {
    final res = await AuthStorage.post(
      '/tradingview/workspace/files/$fileId/save',
    );
    _checkStatus(res);
  }

  static Future<void> deleteFile(String fileId) async {
    final res = await _delete('/tradingview/workspace/files/$fileId');
    _checkStatus(res);
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Model parsers
// ─────────────────────────────────────────────────────────────────────────────

ScriptFile _fileFromJson(Map<String, dynamic> j) {
  final rawParent = j['parent_folder_id'] as String?;
  final id        = (j['id'] ?? j['_id'])?.toString();
  assert(id != null, 'File JSON missing id: $j');
  return ScriptFile(
    id:             id ?? '',
    name:           j['name']    as String,
    content:        j['content'] as String? ?? '',
    parentFolderId: (rawParent == null || rawParent.isEmpty) ? null : rawParent,
    isShared:       j['is_shared'] as bool? ?? false,
    createdAt:      DateTime.parse(j['created_at'] as String),
    updatedAt:      DateTime.parse(j['updated_at'] as String),
  );
}

ScriptFolder _folderFromJson(Map<String, dynamic> j) {
  final rawParent = j['parent_folder_id'] as String?;
  final id        = (j['id'] ?? j['_id'])?.toString();
  assert(id != null, 'Folder JSON missing id: $j');
  return ScriptFolder(
    id:             id ?? '',
    name:           j['name'] as String,
    parentFolderId: (rawParent == null || rawParent.isEmpty) ? null : rawParent,
    isExpanded:     j['is_expanded']  as bool? ?? true,
    isIndicator:    j['is_indicator'] as bool? ?? false,
    isShared:       j['is_shared']    as bool? ?? false,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ID Generator
// ─────────────────────────────────────────────────────────────────────────────

int _counter = 0;
String _tempId() =>
    'tmp_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';

// ─────────────────────────────────────────────────────────────────────────────
//  WorkspaceState
// ─────────────────────────────────────────────────────────────────────────────

class WorkspaceState extends ChangeNotifier {
  final List<ScriptFile>   _files   = [];
  final List<ScriptFolder> _folders = [];

  bool    _isLoading = false;
  String? _error;

  bool    get isLoading => _isLoading;
  String? get error     => _error;

  List<ScriptFile>   get files   => List.unmodifiable(_files);
  List<ScriptFolder> get folders => List.unmodifiable(_folders);

  List<ScriptFolder> get rootFolders =>
      _folders.where((f) => f.parentFolderId == null).toList();

  List<ScriptFile> get rootFiles =>
      _files.where((f) => f.parentFolderId == null).toList();

  List<ScriptFile> filesInFolder(String folderId) =>
      _files.where((f) => f.parentFolderId == folderId).toList();

  List<ScriptFolder> subFoldersOf(String folderId) =>
      _folders.where((f) => f.parentFolderId == folderId).toList();

  ScriptFile? findFile(String fileId) {
    try { return _files.firstWhere((f) => f.id == fileId); }
    catch (_) { return null; }
  }

  ScriptFolder? findFolder(String folderId) {
    try { return _folders.firstWhere((f) => f.id == folderId); }
    catch (_) { return null; }
  }

  List<ScriptFolder> buildFolderTree({String? parentFolderId}) {
    return _folders
        .where((f) => f.parentFolderId == parentFolderId)
        .map((folder) => folder.copyWith(
              files:      filesInFolder(folder.id),
              subFolders: buildFolderTree(parentFolderId: folder.id),
            ))
        .toList();
  }

  List<String> _buildFolderSegments(String folderId) {
    final segments  = <String>[];
    String? current = folderId;
    var safetyLimit = 20;
    while (current != null && safetyLimit-- > 0) {
      final folder = findFolder(current);
      if (folder == null) break;
      segments.insert(0, folder.name);
      current = folder.parentFolderId;
    }
    return segments;
  }

  String getFilePath(String fileId) {
    final file = findFile(fileId);
    if (file == null) return '';
    final segs = <String>[];
    if (file.parentFolderId != null) {
      segs.addAll(_buildFolderSegments(file.parentFolderId!));
    }
    segs.add(file.name);
    return segs.join('/');
  }

  String getFolderPath(String folderId) =>
      findFolder(folderId) == null
          ? ''
          : _buildFolderSegments(folderId).join('/');

  List<String> getFilePathSegments(String fileId) {
    final file = findFile(fileId);
    if (file == null) return [];
    final segs = <String>[];
    if (file.parentFolderId != null) {
      segs.addAll(_buildFolderSegments(file.parentFolderId!));
    }
    segs.add(file.name);
    return segs;
  }

  List<String> getFolderPathSegments(String folderId) =>
      findFolder(folderId) == null ? [] : _buildFolderSegments(folderId);

  void _syncFolderFiles(String? folderId) {
    if (folderId == null) return;
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    _folders[idx] = _folders[idx].copyWith(
      files: _files.where((f) => f.parentFolderId == folderId).toList(),
    );
  }

  void _syncFolderChildren(String? parentFolderId) {
    if (parentFolderId == null) return;
    final idx = _folders.indexWhere((f) => f.id == parentFolderId);
    if (idx == -1) return;
    _folders[idx] = _folders[idx].copyWith(
      subFolders:
          _folders.where((f) => f.parentFolderId == parentFolderId).toList(),
    );
  }

  void loadLocalData({
    required List<ScriptFolder> folders,
    required List<ScriptFile>   files,
  }) {
    _folders
      ..clear()
      ..addAll(folders);
    _files
      ..clear()
      ..addAll(files);
    for (final f in _folders) {
      _syncFolderFiles(f.id);
      _syncFolderChildren(f.id);
    }
    notifyListeners();
  }

  // ── Protected: fetch workspace indicator spesifik ────────────────────────
  // Dipanggil IsolatedWorkspaceState saat indicatorId != null.
  @protected
  Future<Map<String, dynamic>> fetchIndicatorWorkspace(String indicatorId) =>
      _TvApi.getIndicatorWorkspace(indicatorId);

  // ── Protected: apply raw JSON ke _folders/_files ─────────────────────────
  // IsolatedWorkspaceState panggil ini setelah fetchIndicatorWorkspace.
  @protected
  Future<void> applyServerData(Map<String, dynamic> data) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final rawFolders =
          (data['folders'] as List? ?? []).cast<Map<String, dynamic>>();
      final rawFiles =
          (data['files'] as List? ?? []).cast<Map<String, dynamic>>();

      debugPrint('[WS applyServerData] folders=${rawFolders.length} files=${rawFiles.length}');

      _folders
        ..clear()
        ..addAll(rawFolders.map(_folderFromJson));
      _files
        ..clear()
        ..addAll(rawFiles.map(_fileFromJson));

      for (final f in _folders) {
        _syncFolderFiles(f.id);
        _syncFolderChildren(f.id);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── loadFromServer: workspace umum ───────────────────────────────────────
  Future<void> loadFromServer() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final data       = await _TvApi.getWorkspace();
      final rawFolders = (data['folders'] as List).cast<Map<String, dynamic>>();
      final rawFiles   = (data['files']   as List).cast<Map<String, dynamic>>();

      debugPrint('[WS] folders=${rawFolders.length} files=${rawFiles.length}');

      _folders
        ..clear()
        ..addAll(rawFolders.map(_folderFromJson));
      _files
        ..clear()
        ..addAll(rawFiles.map(_fileFromJson));

      for (final f in _folders) {
        _syncFolderFiles(f.id);
        _syncFolderChildren(f.id);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleFolder(String folderId) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    final newExpanded = !_folders[idx].isExpanded;
    _folders[idx] = _folders[idx].toggled();
    notifyListeners();
    _TvApi.updateFolder(folderId, isExpanded: newExpanded).catchError((_) {});
  }

  Future<ScriptFolder> addFolder(String parentFolderId, String name) async {
    final tempId = _tempId();
    final temp = ScriptFolder(
      id:             tempId,
      name:           name,
      parentFolderId: parentFolderId,
      isExpanded:     true,
    );
    _folders.add(temp);
    _syncFolderChildren(parentFolderId);
    notifyListeners();

    try {
      final json   = await _TvApi.createFolder(
          name: name, parentFolderId: parentFolderId);
      final realId = json['id'] as String;
      final idx    = _folders.indexWhere((f) => f.id == tempId);
      if (idx != -1) {
        _folders[idx] = _folderFromJson(json);
        _syncFolderChildren(parentFolderId);
        notifyListeners();
      }
      return _folders.firstWhere((f) => f.id == realId, orElse: () => temp);
    } catch (e) {
      _folders.removeWhere((f) => f.id == tempId);
      _syncFolderChildren(parentFolderId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addRootFolder(String name) async {
    final tempId = _tempId();
    final temp   = ScriptFolder(id: tempId, name: name, isExpanded: true);
    _folders.add(temp);
    notifyListeners();

    try {
      final json = await _TvApi.createFolder(name: name);
      final idx  = _folders.indexWhere((f) => f.id == tempId);
      if (idx != -1) {
        _folders[idx] = _folderFromJson(json);
        notifyListeners();
      }
    } catch (e) {
      _folders.removeWhere((f) => f.id == tempId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    final oldFolder = _folders[idx];
    _folders[idx] = oldFolder.copyWith(name: newName);
    _syncFolderChildren(oldFolder.parentFolderId);
    notifyListeners();

    try {
      await _TvApi.updateFolder(folderId, name: newName);
    } catch (e) {
      _folders[idx] = oldFolder;
      _syncFolderChildren(oldFolder.parentFolderId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteFolder(String folderId) async {
    final folder = findFolder(folderId);
    if (folder == null) return;
    final parentId = folder.parentFolderId;
    final toDelete = _collectFolderIds(folderId);

    final removedFolders =
        _folders.where((f) => toDelete.contains(f.id)).toList();
    final removedFiles = _files
        .where((f) =>
            f.parentFolderId != null && toDelete.contains(f.parentFolderId))
        .toList();

    _folders.removeWhere((f) => toDelete.contains(f.id));
    _files.removeWhere(
        (f) => f.parentFolderId != null && toDelete.contains(f.parentFolderId));
    _syncFolderChildren(parentId);
    notifyListeners();

    try {
      await _TvApi.deleteFolder(folderId);
    } catch (e) {
      _folders.addAll(removedFolders);
      _files.addAll(removedFiles);
      _syncFolderChildren(parentId);
      notifyListeners();
      rethrow;
    }
  }

  Set<String> _collectFolderIds(String folderId) {
    final result = <String>{folderId};
    for (final sub in _folders.where((f) => f.parentFolderId == folderId)) {
      result.addAll(_collectFolderIds(sub.id));
    }
    return result;
  }

  Future<ScriptFile> addFile(String parentFolderId, String name) async {
    final tempId   = _tempId();
    final now      = DateTime.now();
    final resolved = name.endsWith('.py') ? name : '$name.py';
    final temp = ScriptFile(
      id:             tempId,
      name:           resolved,
      content:        '',
      parentFolderId: parentFolderId,
      createdAt:      now,
      updatedAt:      now,
    );
    _files.add(temp);
    _syncFolderFiles(parentFolderId);
    notifyListeners();

    try {
      final json   = await _TvApi.createFile(
          name: resolved, content: '', parentFolderId: parentFolderId);
      final realId = json['id'] as String;
      final idx    = _files.indexWhere((f) => f.id == tempId);
      if (idx != -1) {
        _files[idx] = _fileFromJson(json);
        _syncFolderFiles(parentFolderId);
        notifyListeners();
      }
      return _files.firstWhere((f) => f.id == realId, orElse: () => temp);
    } catch (e) {
      _files.removeWhere((f) => f.id == tempId);
      _syncFolderFiles(parentFolderId);
      notifyListeners();
      rethrow;
    }
  }

  void updateFileContent(String fileId, String content) {
    final idx = _files.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    final parentId = _files[idx].parentFolderId;
    _files[idx] = _files[idx].withContent(content);
    _syncFolderFiles(parentId);
    notifyListeners();
  }

  Future<void> saveFile(String fileId) async {
    final idx = _files.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    final parentId = _files[idx].parentFolderId;
    final content  = _files[idx].content;
    _files[idx] = _files[idx].asSaved();
    _syncFolderFiles(parentId);
    notifyListeners();

    try {
      await _TvApi.updateFile(fileId, content: content);
      await _TvApi.saveFile(fileId);
    } catch (e) {
      final i = _files.indexWhere((f) => f.id == fileId);
      if (i != -1) {
        _files[i] = _files[i].withContent(content);
        _syncFolderFiles(parentId);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> renameFile(String fileId, String newName) async {
    final idx = _files.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    final oldFile  = _files[idx];
    final parentId = oldFile.parentFolderId;
    final resolved = newName.endsWith('.py') ? newName : '$newName.py';
    _files[idx] = oldFile.copyWith(name: resolved);
    _syncFolderFiles(parentId);
    notifyListeners();

    try {
      await _TvApi.updateFile(fileId, name: resolved);
    } catch (e) {
      _files[idx] = oldFile;
      _syncFolderFiles(parentId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteFile(String fileId) async {
    final idx = _files.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    final removed  = _files[idx];
    final parentId = removed.parentFolderId;
    _files.removeAt(idx);
    _syncFolderFiles(parentId);
    notifyListeners();

    try {
      await _TvApi.deleteFile(fileId);
    } catch (e) {
      _files.insert(idx, removed);
      _syncFolderFiles(parentId);
      notifyListeners();
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TabState
// ─────────────────────────────────────────────────────────────────────────────

class TabState extends ChangeNotifier {
  final List<ScriptFile> _openTabs = [];
  ScriptFile? _activeFile;

  List<ScriptFile> get openTabs          => List.unmodifiable(_openTabs);
  ScriptFile?      get activeFile        => _activeFile;
  bool             get hasOpenTab        => _openTabs.isNotEmpty;
  bool             get hasUnsavedChanges => _openTabs.any((t) => t.isModified);

  int get activeIndex => _activeFile == null
      ? -1
      : _openTabs.indexWhere((t) => t.id == _activeFile!.id);

  void openFile(ScriptFile file) {
    final existingIdx = _openTabs.indexWhere((t) => t.id == file.id);
    if (existingIdx == -1) {
      _openTabs.add(file);
      _activeFile = file;
    } else {
      _activeFile = _openTabs[existingIdx];
    }
    notifyListeners();
  }

  void setActiveByIndex(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    _activeFile = _openTabs[index];
    notifyListeners();
  }

  void closeTab(String fileId) {
    final idx = _openTabs.indexWhere((t) => t.id == fileId);
    if (idx == -1) return;
    _openTabs.removeAt(idx);
    if (_activeFile?.id == fileId) {
      _activeFile = _openTabs.isEmpty
          ? null
          : _openTabs[(idx - 1).clamp(0, _openTabs.length - 1)];
    }
    notifyListeners();
  }

  void closeAll() {
    _openTabs.clear();
    _activeFile = null;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final item = _openTabs.removeAt(oldIndex);
    _openTabs.insert(newIndex, item);
    notifyListeners();
  }

  void updateActiveContent(String content) {
    final idx = _activeFile == null
        ? -1
        : _openTabs.indexWhere((t) => t.id == _activeFile!.id);
    if (idx == -1) return;
    _openTabs[idx] = _openTabs[idx].withContent(content);
    _activeFile    = _openTabs[idx];
    notifyListeners();
  }

  void markSaved(String fileId) {
    final idx = _openTabs.indexWhere((t) => t.id == fileId);
    if (idx == -1) return;
    _openTabs[idx] = _openTabs[idx].asSaved();
    if (_activeFile?.id == fileId) _activeFile = _openTabs[idx];
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EditorThemeHookState
// ─────────────────────────────────────────────────────────────────────────────

class EditorThemeHookState extends ChangeNotifier {
  EditorThemeState _theme;

  EditorThemeHookState({EditorThemeState? initial})
      : _theme = initial ?? EditorThemeState();

  EditorThemeState    get theme        => _theme;
  EditorSyntaxColors  get syntax       => _theme.syntax;
  EditorChromeColors  get chrome       => _theme.chrome;
  EditorTypography    get typography   => _theme.typography;
  EditorThemePreset   get activePreset => _theme.activePreset;

  void applyTheme(EditorThemeState newTheme)    { _theme = newTheme;                            notifyListeners(); }
  void applyPreset(EditorThemePreset preset)    { _theme = EditorThemeState.fromPreset(preset); notifyListeners(); }
  void updateSyntax(EditorSyntaxColors syntax)  { _theme = _theme.copyWith(syntax: syntax);     notifyListeners(); }
  void updateChrome(EditorChromeColors chrome)  { _theme = _theme.copyWith(chrome: chrome);     notifyListeners(); }
  void updateTypography(EditorTypography typo)  { _theme = _theme.copyWith(typography: typo);   notifyListeners(); }
  void updateBackgroundOpacity(double opacity)  { _theme = _theme.copyWith(backgroundOpacity: opacity);            notifyListeners(); }
  void updateBackgroundImage(String? path)      { _theme = _theme.copyWith(backgroundImagePath: path);             notifyListeners(); }
  void updateBackgroundGradientEnd(Color color) { _theme = _theme.copyWith(backgroundGradientEnd: color);          notifyListeners(); }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TradingViewHook — backward-compat facade
// ─────────────────────────────────────────────────────────────────────────────

class TradingViewHook {
  late final WorkspaceState       workspace;
  late final TabState             tabs;
  late final EditorThemeHookState editorTheme;

  void Function(String message)? onError;

  TradingViewHook({this.onError}) {
    workspace   = WorkspaceState();
    tabs        = TabState();
    editorTheme = EditorThemeHookState();
  }

  Future<void> init() async {
    try {
      await workspace.loadFromServer();
      _openDefaultFile();
    } catch (e) {
      onError?.call('Gagal memuat workspace: $e');
    }
  }

  void _openDefaultFile() {
    try {
      final main = workspace.files.firstWhere((f) => f.name == 'main.py');
      tabs.openFile(main);
    } catch (_) {
      if (workspace.files.isNotEmpty) tabs.openFile(workspace.files.first);
    }
  }

  void openFile(ScriptFile file) => tabs.openFile(file);

  Future<void> saveActiveFile() async {
    final active = tabs.activeFile;
    if (active == null) return;
    try {
      await workspace.saveFile(active.id);
      tabs.markSaved(active.id);
    } catch (e) {
      onError?.call('Gagal menyimpan file: $e');
    }
  }

  void onCodeChanged(String newContent) {
    final active = tabs.activeFile;
    if (active == null) return;
    workspace.updateFileContent(active.id, newContent);
    tabs.updateActiveContent(newContent);
  }

  Future<void> deleteFile(String fileId) async {
    tabs.closeTab(fileId);
    try {
      await workspace.deleteFile(fileId);
    } catch (e) {
      onError?.call('Gagal menghapus file: $e');
    }
  }

  Future<ScriptFile> createFile(String parentFolderId, String name) async {
    try {
      final file = await workspace.addFile(parentFolderId, name);
      tabs.openFile(file);
      return file;
    } catch (e) {
      onError?.call('Gagal membuat file: $e');
      rethrow;
    }
  }

  Future<void> createFolder(String parentFolderId, String name) async {
    try {
      await workspace.addFolder(parentFolderId, name);
    } catch (e) {
      onError?.call('Gagal membuat folder: $e');
    }
  }

  Future<void> renameFile(String fileId, String newName) async {
    try {
      await workspace.renameFile(fileId, newName);
      final updated = workspace.findFile(fileId);
      if (updated != null && tabs.openTabs.any((t) => t.id == fileId)) {
        tabs.openFile(updated);
      }
    } catch (e) {
      onError?.call('Gagal rename file: $e');
    }
  }

  Future<void> renameFolder(String folderId, String newName) async {
    try {
      await workspace.renameFolder(folderId, newName);
    } catch (e) {
      onError?.call('Gagal rename folder: $e');
    }
  }

  Future<void> deleteFolder(String folderId) async {
    final affectedIds =
        workspace.filesInFolder(folderId).map((f) => f.id).toList();
    for (final id in affectedIds) tabs.closeTab(id);
    try {
      await workspace.deleteFolder(folderId);
    } catch (e) {
      onError?.call('Gagal menghapus folder: $e');
    }
  }

  void dispose() {
    workspace.dispose();
    tabs.dispose();
    editorTheme.dispose();
  }
}