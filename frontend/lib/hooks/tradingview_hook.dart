// =============================================================================
// tradingview_hook.dart
// Path: frontend/lib/hooks/tradingview_hook.dart
//
// Local state manager untuk Python Script Editor.
// Model ScriptFile & ScriptFolder sudah dipisah ke:
//   → lib/trading_screen/models/script_file.dart
//   → lib/trading_screen/models/script_folder.dart
//
// WorkspaceState sekarang pakai flat list — relasi parent/child
// lewat parentFolderId, bukan nested object.
// =============================================================================

import 'package:flutter/material.dart';
import '../style/apps_colors_tradingview.dart';
import '../models/script_file.dart';
import '../models/script_folder.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ID Generator — private, hanya dipakai di file ini
// ─────────────────────────────────────────────────────────────────────────────

int _counter = 0;
String _uid() =>
    'node_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';

// ─────────────────────────────────────────────────────────────────────────────
//  STATE: WorkspaceState
//  Flat list of ScriptFile & ScriptFolder.
//  Relasi parent/child via parentFolderId.
// ─────────────────────────────────────────────────────────────────────────────

class WorkspaceState extends ChangeNotifier {
  final List<ScriptFile>   _files;
  final List<ScriptFolder> _folders;

  WorkspaceState({
    List<ScriptFile>?   files,
    List<ScriptFolder>? folders,
  })  : _files   = files   ?? [],
        _folders = folders ?? [] {
    if (_files.isEmpty && _folders.isEmpty) _initDefault();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<ScriptFile>   get files   => List.unmodifiable(_files);
  List<ScriptFolder> get folders => List.unmodifiable(_folders);

  /// Root folders — tidak punya parent
  List<ScriptFolder> get rootFolders =>
      _folders.where((f) => f.parentFolderId == null).toList();

  /// Files langsung di root (tidak dalam folder manapun)
  List<ScriptFile> get rootFiles =>
      _files.where((f) => f.parentFolderId == null).toList();

  /// Files dalam folder tertentu
  List<ScriptFile> filesInFolder(String folderId) =>
      _files.where((f) => f.parentFolderId == folderId).toList();

  /// Subfolders dalam folder tertentu
  List<ScriptFolder> subFolders(String folderId) =>
      _folders.where((f) => f.parentFolderId == folderId).toList();

  /// Cari file by id
  ScriptFile? findFile(String fileId) {
    try {
      return _files.firstWhere((f) => f.id == fileId);
    } catch (_) {
      return null;
    }
  }

  /// Cari folder by id
  ScriptFolder? findFolder(String folderId) {
    try {
      return _folders.firstWhere((f) => f.id == folderId);
    } catch (_) {
      return null;
    }
  }

  // ── Default workspace ─────────────────────────────────────────────────────

  void _initDefault() {
    final rootId       = _uid();
    final stratId      = _uid();
    final indicatorId  = _uid();
    final now          = DateTime.now();

    _folders.addAll([
      ScriptFolder(id: rootId,      name: 'workspace',   isExpanded: true),
      ScriptFolder(id: stratId,     name: 'strategies',  parentFolderId: rootId),
      ScriptFolder(id: indicatorId, name: 'indicators',  parentFolderId: rootId),
    ]);

    _files.add(ScriptFile(
      id:             _uid(),
      name:           'main.py',
      content:        _defaultPythonScript(),
      parentFolderId: rootId,
      createdAt:      now,
      updatedAt:      now,
    ));
  }

  static String _defaultPythonScript() => '''# EXXE.LAB — Python Script Editor
def calculate_signal(close: list, period: int = 14) -> float:
    if len(close) < period:
        return 0.0

    gains, losses = [], []
    for i in range(1, period + 1):
        diff = close[-i] - close[-i - 1]
        if diff > 0: gains.append(diff)
        else:        losses.append(abs(diff))

    avg_gain = sum(gains)  / period if gains  else 0.0
    avg_loss = sum(losses) / period if losses else 0.0

    if avg_loss == 0:
        return 100.0

    rs  = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi


if __name__ == "__main__":
    prices = [100, 102, 101, 105, 107, 106, 110, 108, 112, 115,
              114, 116, 118, 117, 120, 119]
    signal = calculate_signal(prices)
    print(f"Signal value: {signal:.2f}")
''';

  // ── Folder operations ─────────────────────────────────────────────────────

  void toggleFolder(String folderId) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    _folders[idx] = _folders[idx].toggled();
    notifyListeners();
  }

  void addRootFolder(String name) {
    _folders.add(ScriptFolder(id: _uid(), name: name, isExpanded: true));
    notifyListeners();
  }

  void addFolder(String parentFolderId, String name) {
    _folders.add(ScriptFolder(
      id:             _uid(),
      name:           name,
      parentFolderId: parentFolderId,
      isExpanded:     true,
    ));
    notifyListeners();
  }

  void renameFolder(String folderId, String newName) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    _folders[idx] = _folders[idx].copyWith(name: newName);
    notifyListeners();
  }

  /// Hapus folder + semua subfolder + semua file di dalamnya (rekursif)
  void deleteFolder(String folderId) {
    final toDelete = _collectFolderIds(folderId);
    _folders.removeWhere((f) => toDelete.contains(f.id));
    _files.removeWhere((f) =>
        f.parentFolderId != null && toDelete.contains(f.parentFolderId));
    notifyListeners();
  }

  Set<String> _collectFolderIds(String folderId) {
    final result = <String>{folderId};
    for (final sub in _folders.where((f) => f.parentFolderId == folderId)) {
      result.addAll(_collectFolderIds(sub.id));
    }
    return result;
  }

  // ── File operations ───────────────────────────────────────────────────────

  ScriptFile addFile(String parentFolderId, String name) {
    final now      = DateTime.now();
    final resolved = name.endsWith('.py') ? name : '$name.py';
    final newFile  = ScriptFile(
      id:             _uid(),
      name:           resolved,
      content:        '',
      parentFolderId: parentFolderId,
      createdAt:      now,
      updatedAt:      now,
    );
    _files.add(newFile);
    notifyListeners();
    return newFile;
  }

  void updateFileContent(String fileId, String content) {
    final idx = _files.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    _files[idx] = _files[idx].withContent(content);
    notifyListeners();
  }

  void saveFile(String fileId) {
    final idx = _files.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    _files[idx] = _files[idx].asSaved();
    notifyListeners();
  }

  void renameFile(String fileId, String newName) {
    final idx      = _files.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    final resolved = newName.endsWith('.py') ? newName : '$newName.py';
    _files[idx]    = _files[idx].copyWith(name: resolved);
    notifyListeners();
  }

  void deleteFile(String fileId) {
    _files.removeWhere((f) => f.id == fileId);
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATE: TabState
// ─────────────────────────────────────────────────────────────────────────────

class TabState extends ChangeNotifier {
  final List<ScriptFile> _openTabs  = [];
  ScriptFile?            _activeFile;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<ScriptFile> get openTabs        => List.unmodifiable(_openTabs);
  ScriptFile?      get activeFile      => _activeFile;
  bool             get hasOpenTab      => _openTabs.isNotEmpty;
  bool             get hasUnsavedChanges => _openTabs.any((t) => t.isModified);

  int get activeIndex =>
      _activeFile == null ? -1 : _openTabs.indexWhere((t) => t.id == _activeFile!.id);

  // ── Tab operations ────────────────────────────────────────────────────────

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
      _activeFile = _openTabs.isEmpty ? null : _openTabs[(idx - 1).clamp(0, _openTabs.length - 1)];
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
    if (oldIndex < 0 || oldIndex >= _openTabs.length) return;
    if (newIndex < 0 || newIndex >= _openTabs.length) return;
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
//  STATE: EditorThemeHookState
// ─────────────────────────────────────────────────────────────────────────────

class EditorThemeHookState extends ChangeNotifier {
  EditorThemeState _theme;

  EditorThemeHookState({EditorThemeState? initial})
      : _theme = initial ?? EditorThemeState();

  EditorThemeState   get theme        => _theme;
  EditorSyntaxColors get syntax       => _theme.syntax;
  EditorChromeColors get chrome       => _theme.chrome;
  EditorTypography   get typography   => _theme.typography;
  EditorThemePreset  get activePreset => _theme.activePreset;

  void applyTheme(EditorThemeState newTheme) {
    _theme = newTheme;
    notifyListeners();
  }

  void applyPreset(EditorThemePreset preset) {
    _theme = EditorThemeState.fromPreset(preset);
    notifyListeners();
  }

  void updateSyntax(EditorSyntaxColors syntax) {
    _theme = _theme.copyWith(syntax: syntax);
    notifyListeners();
  }

  void updateChrome(EditorChromeColors chrome) {
    _theme = _theme.copyWith(chrome: chrome);
    notifyListeners();
  }

  void updateTypography(EditorTypography typography) {
    _theme = _theme.copyWith(typography: typography);
    notifyListeners();
  }

  void updateBackgroundOpacity(double opacity) {
    _theme = _theme.copyWith(backgroundOpacity: opacity);
    notifyListeners();
  }

  void updateBackgroundImage(String? path) {
    _theme = _theme.copyWith(backgroundImagePath: path);
    notifyListeners();
  }

  void updateBackgroundGradientEnd(Color color) {
    _theme = _theme.copyWith(backgroundGradientEnd: color);
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOOK: TradingViewHook — facade, single entry point
// ─────────────────────────────────────────────────────────────────────────────

class TradingViewHook {
  late final WorkspaceState       workspace;
  late final TabState             tabs;
  late final EditorThemeHookState editorTheme;

  TradingViewHook() {
    workspace   = WorkspaceState();
    tabs        = TabState();
    editorTheme = EditorThemeHookState();
    _openDefaultFile();
  }

  void _openDefaultFile() {
    try {
      final main = workspace.files.firstWhere((f) => f.name == 'main.py');
      tabs.openFile(main);
    } catch (_) {
      if (workspace.files.isNotEmpty) tabs.openFile(workspace.files.first);
    }
  }

  void openFile(ScriptFile file)  => tabs.openFile(file);

  void saveActiveFile() {
    final active = tabs.activeFile;
    if (active == null) return;
    workspace.saveFile(active.id);
    tabs.markSaved(active.id);
  }

  void onCodeChanged(String newContent) {
    final active = tabs.activeFile;
    if (active == null) return;
    workspace.updateFileContent(active.id, newContent);
    tabs.updateActiveContent(newContent);
  }

  void deleteFile(String fileId) {
    tabs.closeTab(fileId);
    workspace.deleteFile(fileId);
  }

  void dispose() {
    workspace.dispose();
    tabs.dispose();
    editorTheme.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INHERITED WIDGET: TradingViewHookProvider
// ─────────────────────────────────────────────────────────────────────────────

class TradingViewHookProvider extends InheritedWidget {
  const TradingViewHookProvider({
    super.key,
    required this.hook,
    required super.child,
  });

  final TradingViewHook hook;

  static TradingViewHook of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<TradingViewHookProvider>();
    assert(provider != null, 'TradingViewHookProvider not found in widget tree');
    return provider!.hook;
  }

  @override
  bool updateShouldNotify(TradingViewHookProvider old) => old.hook != hook;
}