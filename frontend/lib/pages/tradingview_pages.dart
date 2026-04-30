// =============================================================================
// tradingview_pages.dart
// Path: frontend/lib/pages/tradingview_pages.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/role_guard.dart';
import '../hooks/tradingview_hook.dart';
import '../style/apps_colors_tradingview.dart';
import '../models/script_file.dart';
import '../models/script_folder.dart';
import '../utils/python_syntax_highlighter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 1 — EditorPermission
// ─────────────────────────────────────────────────────────────────────────────

class EditorPermission {
  final UserRole role;
  final String   userId;

  const EditorPermission({required this.role, required this.userId});

  factory EditorPermission.fromToken(String token, String userId) =>
      EditorPermission(
        role:   decodeRoleFromToken(token),
        userId: userId,
      );

  bool get canEnterEditor =>
      role == UserRole.admin || role == UserRole.exclusive;

  bool get isAdmin     => role == UserRole.admin;
  bool get isExclusive => role == UserRole.exclusive;

  static const String sharedOwnerId = 'admin_shared';

  bool canSeeFile({required String ownerId}) {
    if (isAdmin) return true;
    if (ownerId == sharedOwnerId) return true;
    return ownerId == userId;
  }

  bool get canCreate => canEnterEditor;

  bool canEdit({required String ownerId}) {
    if (isAdmin) return true;
    return ownerId == userId;
  }

  bool canDelete({required String ownerId}) => canEdit(ownerId: ownerId);
  bool canRename({required String ownerId}) => canEdit(ownerId: ownerId);

  bool get canPublishShared => isAdmin;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 2 — IsolatedWorkspaceState
//  FIX: simpan _roots lokal, jangan pass ke super(initial:...)
//       expose `roots` getter sendiri
// ─────────────────────────────────────────────────────────────────────────────

class IsolatedWorkspaceState extends WorkspaceState {
  final EditorPermission  permission;
  late List<ScriptFolder> _roots;

  IsolatedWorkspaceState({required this.permission}) : super() {
    _roots = _buildIsolatedWorkspace(permission);
  }

  // ── FIX: expose roots getter ──────────────────────────────────────────────
  List<ScriptFolder> get roots => _roots;

  // ── Build initial workspace ───────────────────────────────────────────────

  static List<ScriptFolder> _buildIsolatedWorkspace(EditorPermission perm) {
    final uid    = perm.userId;
    final rootId = 'root_$uid';
    final shared = EditorPermission.sharedOwnerId;

    final myRoot = ScriptFolder(
      id:         rootId,
      name:       'my_scripts',
      isExpanded: true,
      files: [
        ScriptFile(
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
          id:       '${uid}_main',
          name:     'main.py',
          parentFolderId: rootId,
          content:  _starterScript(perm),
        ),
      ],
      subFolders: [
        ScriptFolder(
          id:       '${uid}_strategies',
          name:     'strategies',
          parentFolderId: rootId,
        ),
        ScriptFolder(
          id:       '${uid}_indicators',
          name:     'indicators',
          parentFolderId: rootId,
        ),
      ],
    );

    final sharedRoot = ScriptFolder(
      id:         'root_$shared',
      name:       'shared_indicators',
      isExpanded: false,
      files: [
        ScriptFile(
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
          id:       '${shared}_rsi',
          name:     'rsi_template.py',
          parentFolderId: 'root_$shared',
          content:  _rsiTemplate(),
        ),
        ScriptFile(
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
          id:       '${shared}_ma',
          name:     'ma_crossover.py',
          parentFolderId: 'root_$shared',
          content:  _maCrossoverTemplate(),
        ),
      ],
    );

    return [myRoot, sharedRoot];
  }

  // ── Visible roots ─────────────────────────────────────────────────────────

  List<ScriptFolder> get visibleRoots {
    if (permission.isAdmin) return _roots.toList();
    return _roots.where((r) {
      final isOwn    = r.id.contains(permission.userId);
      final isShared = r.id.contains(EditorPermission.sharedOwnerId);
      return isOwn || isShared;
    }).toList();
  }

  // ── Ownership helpers ─────────────────────────────────────────────────────

  bool isSharedFile(ScriptFile file) =>
      file.id.contains(EditorPermission.sharedOwnerId) ||
      file.parentId.contains(EditorPermission.sharedOwnerId);

  bool isOwnFile(ScriptFile file) =>
      file.id.contains(permission.userId) ||
      file.parentId.contains(permission.userId);

  String resolveOwnerId(ScriptFile file) =>
      isSharedFile(file) ? EditorPermission.sharedOwnerId : permission.userId;

  // ── Guarded CRUD ──────────────────────────────────────────────────────────

  ScriptFile? addFileGuarded(String parentFolderId, String name) {
    if (parentFolderId.contains(EditorPermission.sharedOwnerId) &&
        !permission.isAdmin) return null;
    return addFile(parentFolderId, name);
  }

  bool updateFileContentGuarded(String fileId, String content) {
    final file = findFile(fileId);
    if (file == null) return false;
    if (!permission.canEdit(ownerId: resolveOwnerId(file))) return false;
    updateFileContent(fileId, content);
    return true;
  }

  bool deleteFileGuarded(String fileId) {
    final file = findFile(fileId);
    if (file == null) return false;
    if (!permission.canDelete(ownerId: resolveOwnerId(file))) return false;
    deleteFile(fileId);
    return true;
  }

  bool renameFileGuarded(String fileId, String newName) {
    final file = findFile(fileId);
    if (file == null) return false;
    if (!permission.canRename(ownerId: resolveOwnerId(file))) return false;
    renameFile(fileId, newName);
    return true;
  }

  // ── Template scripts ──────────────────────────────────────────────────────

  static String _starterScript(EditorPermission perm) => '''# EXXE.LAB Script Editor
# Role: ${perm.isAdmin ? 'Admin' : 'Exclusive'} — User: ${perm.userId}

def strategy(close: list, period: int = 14) -> dict:
    """
    Custom trading strategy.
    Returns: { "signal": "buy" | "sell" | "hold", "value": float }
    """
    if len(close) < period:
        return {"signal": "hold", "value": 0.0}

    avg  = sum(close[-period:]) / period
    last = close[-1]

    if last > avg * 1.02:
        return {"signal": "buy",  "value": last}
    elif last < avg * 0.98:
        return {"signal": "sell", "value": last}
    return {"signal": "hold", "value": last}


if __name__ == "__main__":
    prices = [100, 102, 104, 103, 107, 110, 108, 112,
              115, 113, 116, 118, 120, 119, 122, 125]
    result = strategy(prices)
    print(f"Signal: {result['signal']} @ {result['value']:.2f}")
''';

  static String _rsiTemplate() => '''# RSI Template — EXXE.LAB Shared Indicator
# Published by: Admin  |  Read-only for Exclusive users

def rsi(close: list, period: int = 14) -> float:
    if len(close) < period + 1:
        return 50.0
    gains, losses = [], []
    for i in range(1, period + 1):
        diff = close[-i] - close[-i - 1]
        (gains if diff > 0 else losses).append(abs(diff))
    avg_gain = sum(gains) / period if gains else 0.0
    avg_loss = sum(losses) / period if losses else 0.0
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return round(100 - (100 / (1 + rs)), 2)


if __name__ == "__main__":
    prices = [44, 45, 43, 46, 48, 47, 50, 52, 51, 53,
              55, 54, 56, 58, 57, 60]
    print(f"RSI(14): {rsi(prices):.2f}")
''';

  static String _maCrossoverTemplate() => '''# MA Crossover — EXXE.LAB Shared Indicator
# Published by: Admin  |  Read-only for Exclusive users

def sma(data: list, period: int) -> float:
    if len(data) < period:
        return 0.0
    return sum(data[-period:]) / period


def ma_crossover_signal(close: list,
                         fast: int = 9,
                         slow: int = 21) -> str:
    fast_ma = sma(close, fast)
    slow_ma = sma(close, slow)
    if fast_ma > slow_ma:
        return "buy"
    elif fast_ma < slow_ma:
        return "sell"
    return "hold"


if __name__ == "__main__":
    prices = [100, 101, 103, 102, 105, 107, 106, 108,
              110, 109, 111, 113, 112, 115, 117, 116,
              118, 120, 119, 122, 121, 124]
    print(f"MA Crossover: {ma_crossover_signal(prices)}")
''';
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 3 — IsolatedTradingViewHook
// ─────────────────────────────────────────────────────────────────────────────

class IsolatedTradingViewHook {
  final EditorPermission       permission;
  final IsolatedWorkspaceState workspace;
  final TabState               tabs;
  final EditorThemeHookState   editorTheme;

  IsolatedTradingViewHook({required this.permission})
      : workspace   = IsolatedWorkspaceState(permission: permission),
        tabs        = TabState(),
        editorTheme = EditorThemeHookState() {
    _openDefaultFile();
  }

  void _openDefaultFile() {
    final visible = workspace.visibleRoots;
    if (visible.isEmpty) return;
    final myRoot = visible.firstWhere(
      (r) => r.id.contains(permission.userId),
      orElse: () => visible.first,
    );
    if (myRoot.files.isNotEmpty) tabs.openFile(myRoot.files.first);
  }

  void openFile(ScriptFile file) {
    final ownerId = workspace.resolveOwnerId(file);
    if (!permission.canSeeFile(ownerId: ownerId)) return;
    tabs.openFile(file);
  }

  void onCodeChanged(String content) {
    final active = tabs.activeFile;
    if (active == null) return;
    if (workspace.isSharedFile(active) && !permission.isAdmin) return;
    workspace.updateFileContentGuarded(active.id, content);
    tabs.updateActiveContent(content);
  }

  void saveActiveFile() {
    final active = tabs.activeFile;
    if (active == null) return;
    workspace.saveFile(active.id);
    tabs.markSaved(active.id);
  }

  void deleteFile(String fileId) {
    final success = workspace.deleteFileGuarded(fileId);
    if (success) tabs.closeTab(fileId);
  }

  bool get canEditActive {
    final active = tabs.activeFile;
    if (active == null) return false;
    final ownerId = workspace.resolveOwnerId(active);
    return permission.canEdit(ownerId: ownerId);
  }

  bool get activeIsShared {
    final active = tabs.activeFile;
    if (active == null) return false;
    return workspace.isSharedFile(active);
  }

  void dispose() {
    workspace.dispose();
    tabs.dispose();
    editorTheme.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 4 — IsolatedHookProvider
// ─────────────────────────────────────────────────────────────────────────────

class IsolatedHookProvider extends InheritedWidget {
  const IsolatedHookProvider({
    super.key,
    required this.hook,
    required super.child,
  });

  final IsolatedTradingViewHook hook;

  static IsolatedTradingViewHook of(BuildContext context) {
    final p = context
        .dependOnInheritedWidgetOfExactType<IsolatedHookProvider>();
    assert(p != null, 'IsolatedHookProvider not found in widget tree');
    return p!.hook;
  }

  @override
  bool updateShouldNotify(IsolatedHookProvider old) => old.hook != hook;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 5 — TradingViewPages
// ─────────────────────────────────────────────────────────────────────────────

class TradingViewPages extends StatefulWidget {
  final String token;
  final String userId;

  const TradingViewPages({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<TradingViewPages> createState() => _TradingViewPagesState();
}

class _TradingViewPagesState extends State<TradingViewPages> {
  late final EditorPermission        _permission;
  late final IsolatedTradingViewHook _hook;
  bool _hookReady = false;

  @override
  void initState() {
    super.initState();
    _permission = EditorPermission.fromToken(widget.token, widget.userId);
    if (_permission.canEnterEditor) {
      _hook      = IsolatedTradingViewHook(permission: _permission);
      _hookReady = true;
    }
  }

  @override
  void dispose() {
    if (_hookReady) _hook.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permission.canEnterEditor) {
      return LockedScreen(token: widget.token);
    }

    return IsolatedHookProvider(
      hook:  _hook,
      child: _TradingViewShell(
        permission: _permission,
        hook:       _hook,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 6 — _TradingViewShell
// ─────────────────────────────────────────────────────────────────────────────

class _TradingViewShell extends StatelessWidget {
  final EditorPermission        permission;
  final IsolatedTradingViewHook hook;

  const _TradingViewShell({required this.permission, required this.hook});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        hook.editorTheme,
        hook.tabs,
        hook.workspace,
      ]),
      builder: (context, _) {
        final chrome = hook.editorTheme.chrome;
        return Scaffold(
          backgroundColor: chrome.background,
          body: SafeArea(
            child: Column(
              children: [
                _EditorTopBar(permission: permission, hook: hook),
                Expanded(
                  child: _EditorReadyState(
                    permission: permission,
                    hook:       hook,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 7 — _EditorTopBar
// ─────────────────────────────────────────────────────────────────────────────

class _EditorTopBar extends StatelessWidget {
  final EditorPermission        permission;
  final IsolatedTradingViewHook hook;

  const _EditorTopBar({required this.permission, required this.hook});

  @override
  Widget build(BuildContext context) {
    final chrome     = hook.editorTheme.chrome;
    final syntax     = hook.editorTheme.syntax;
    final active     = hook.tabs.activeFile;
    final hasUnsaved = hook.tabs.hasUnsavedChanges;

    return Container(
      height:  48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: chrome.toolbarBackground,
        border: Border(
          bottom: BorderSide(color: chrome.toolbarBorder),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => hasUnsaved
                ? _confirmExit(context)
                : Navigator.of(context).pop(),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        chrome.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: chrome.gutterBorder),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14, color: syntax.plain.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 10),

          Text(
            'EXXE Editor',
            style: TextStyle(
              color: syntax.plain, fontSize: 13,
              fontWeight: FontWeight.w700, letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),

          _RoleBadge(permission: permission),

          const Spacer(),

          if (active != null) ...[
            if (hasUnsaved)
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: chrome.cursorColor, shape: BoxShape.circle,
                ),
              ),
            Text(
              active.name,
              style: TextStyle(color: syntax.plain.withOpacity(0.65), fontSize: 12),
            ),
            if (hook.activeIsShared && !permission.isAdmin) ...[
              const SizedBox(width: 6),
              _ReadOnlyBadge(chrome: chrome),
            ],
            const SizedBox(width: 12),
          ],

          if (active != null && hook.canEditActive)
            _SaveButton(hook: hook, chrome: chrome),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _UnsavedDialog(hook: hook),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final EditorPermission permission;
  const _RoleBadge({required this.permission});

  @override
  Widget build(BuildContext context) {
    final isAdmin = permission.isAdmin;
    final label   = isAdmin ? 'ADMIN' : 'EXCLUSIVE';
    final color   = isAdmin
        ? const Color(0xFFFF6B35)
        : const Color(0xFFBEFF00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color, fontSize: 9,
          fontWeight: FontWeight.w800, letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  final EditorChromeColors chrome;
  const _ReadOnlyBadge({required this.chrome});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color:        chrome.consoleTextInfo.withOpacity(0.10),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: chrome.consoleTextInfo.withOpacity(0.3)),
    ),
    child: Text(
      'READ ONLY',
      style: TextStyle(
        color: chrome.consoleTextInfo, fontSize: 8,
        fontWeight: FontWeight.w700, letterSpacing: 1.2,
      ),
    ),
  );
}

class _SaveButton extends StatelessWidget {
  final IsolatedTradingViewHook hook;
  final EditorChromeColors      chrome;
  const _SaveButton({required this.hook, required this.chrome});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      hook.saveActiveFile();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        chrome.cursorColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chrome.cursorColor.withOpacity(0.4)),
      ),
      child: Text(
        'Save',
        style: TextStyle(
          color: chrome.cursorColor, fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dialog: UnsavedChanges
// ─────────────────────────────────────────────────────────────────────────────

class _UnsavedDialog extends StatelessWidget {
  final IsolatedTradingViewHook hook;
  const _UnsavedDialog({required this.hook});

  @override
  Widget build(BuildContext context) {
    final chrome = hook.editorTheme.chrome;
    final syntax = hook.editorTheme.syntax;
    return AlertDialog(
      backgroundColor: chrome.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Unsaved Changes',
        style: TextStyle(color: syntax.plain, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Ada perubahan yang belum disimpan.\nKeluar tanpa save?',
        style: TextStyle(color: syntax.comment, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: syntax.comment)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).pop();
          },
          child: Text('Keluar', style: TextStyle(color: chrome.consoleTextError)),
        ),
        TextButton(
          onPressed: () {
            hook.saveActiveFile();
            Navigator.pop(context);
            Navigator.of(context).pop();
          },
          child: Text('Save & Keluar', style: TextStyle(color: chrome.cursorColor)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _EditorReadyState extends StatelessWidget {
  final EditorPermission        permission;
  final IsolatedTradingViewHook hook;
  const _EditorReadyState({required this.permission, required this.hook});

  @override
  Widget build(BuildContext context) {
    final chrome     = hook.editorTheme.chrome;
    final syntax     = hook.editorTheme.syntax;
    final activeFile = hook.tabs.activeFile;
    final theme      = hook.editorTheme.theme;

    // ── No file open → empty state ─────────────────────────────────────────
    if (activeFile == null) {
      return Container(
        color: chrome.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.code_rounded, size: 52, color: syntax.keyword.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text(
                'No file open',
                style: TextStyle(
                  color: syntax.plain, fontSize: 20, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih file dari explorer untuk mulai edit.',
                style: TextStyle(color: syntax.comment, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // ── Active file: read-only view (PythonCodeView) ───────────────────────
    // TODO: ganti PythonCodeView dengan editable TextField ketika
    //       code_editor_widget.dart selesai; untuk sekarang read-only dulu.
    final canEdit    = hook.canEditActive;
    final isReadOnly = !canEdit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Read-only notice bar
        if (isReadOnly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color:   chrome.consoleTextInfo.withOpacity(0.08),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 13, color: chrome.consoleTextInfo),
                const SizedBox(width: 6),
                Text(
                  'Read-only — shared indicator milik admin',
                  style: TextStyle(
                    color:    chrome.consoleTextInfo,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

        // ── Code view ──────────────────────────────────────────────────────
        Expanded(
          child: _EditableOrReadOnly(
            file:     activeFile,
            hook:     hook,
            theme:    theme,
            canEdit:  canEdit,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EditableOrReadOnly
//  canEdit  → editable TextField dengan syntax highlight overlay (basic)
//  !canEdit → PythonCodeView read-only
// ─────────────────────────────────────────────────────────────────────────────

class _EditableOrReadOnly extends StatefulWidget {
  final ScriptFile              file;
  final IsolatedTradingViewHook hook;
  final EditorThemeState        theme;
  final bool                    canEdit;

  const _EditableOrReadOnly({
    required this.file,
    required this.hook,
    required this.theme,
    required this.canEdit,
  });

  @override
  State<_EditableOrReadOnly> createState() => _EditableOrReadOnlyState();
}

class _EditableOrReadOnlyState extends State<_EditableOrReadOnly> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.file.content);
  }

  @override
  void didUpdateWidget(_EditableOrReadOnly old) {
    super.didUpdateWidget(old);
    // File switched → update controller content
    if (old.file.id != widget.file.id) {
      _ctrl.text = widget.file.content;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.theme.chrome;
    final typo   = widget.theme.typography;

    if (!widget.canEdit) {
      // ── Read-only: PythonCodeView ────────────────────────────────────────
      return PythonCodeView(
        source:          widget.file.content,
        theme:           widget.theme,
        showLineNumbers: true,
      );
    }

    // ── Editable: raw TextField with monospace styling ────────────────────
    // Overlay highlight (PythonCodeView) can be layered here later via Stack.
    return Container(
      color: chrome.background,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gutter — line numbers synced to controller
            _LiveLineGutter(controller: _ctrl, theme: widget.theme),

            // Editor field
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicWidth(
                  child: TextField(
                    controller:     _ctrl,
                    maxLines:       null,
                    expands:        false,
                    keyboardType:   TextInputType.multiline,
                    style: typo.baseStyle.copyWith(color: widget.theme.syntax.plain),
                    cursorColor:    chrome.cursorColor,
                    decoration: InputDecoration(
                      border:          InputBorder.none,
                      contentPadding:  const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense:         true,
                    ),
                    onChanged: widget.hook.onCodeChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LiveLineGutter — line count synced to TextEditingController
// ─────────────────────────────────────────────────────────────────────────────

class _LiveLineGutter extends StatefulWidget {
  final TextEditingController controller;
  final EditorThemeState      theme;

  const _LiveLineGutter({required this.controller, required this.theme});

  @override
  State<_LiveLineGutter> createState() => _LiveLineGutterState();
}

class _LiveLineGutterState extends State<_LiveLineGutter> {
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    _lineCount = _count(widget.controller.text);
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    final c = _count(widget.controller.text);
    if (c != _lineCount) setState(() => _lineCount = c);
  }

  int _count(String t) =>
      t.isEmpty ? 1 : '\n'.allMatches(t).length + 1;

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.theme.chrome;
    final typo   = widget.theme.typography;
    return Container(
      color:   chrome.gutterBackground,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_lineCount, (i) => SizedBox(
          height: typo.fontSize * typo.lineHeight,
          child: Text(
            '${i + 1}',
            style: TextStyle(
              fontFamily: typo.fontFamily,
              fontSize:   typo.fontSize,
              height:     typo.lineHeight,
              color:      chrome.lineNumberDefault,
            ),
          ),
        )),
      ),
    );
  }
}