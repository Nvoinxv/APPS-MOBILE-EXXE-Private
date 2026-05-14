// Path: frontend/lib/models/script_file.dart
//
// FIX v_snake_case:
//
//  fromJson() sebelumnya hanya baca camelCase key ('parentFolderId',
//  'createdAt', dll). Backend/MongoDB return snake_case ('parent_folder_id',
//  'created_at', dll) dan _id bukan id.
//
//  Akibatnya:
//    - parentFolderId selalu null → semua file jadi orphan (ga punya folder)
//    - createdAt/updatedAt null → DateTime.parse() crash di runtime
//    - isShared selalu false → ownership salah di indicator panel
//
//  Fix: tiap field coba snake_case dulu, fallback camelCase (backward compat
//  kalau ada bagian app yang masih kirim camelCase, e.g. local state).
//  id: coba 'id' dulu, fallback '_id' (MongoDB raw document).

enum ScriptLanguage   { python, pinescript, javascript }
enum ScriptFileStatus { saved, modified, error }

class ScriptFile {
  final String           id;
  final String           name;
  final String           content;
  final ScriptLanguage   language;
  final ScriptFileStatus status;
  final DateTime         createdAt;
  final DateTime         updatedAt;
  final String?          parentFolderId;

  // ── Indicator field ──────────────────────────────────────────────────────
  final bool isShared;

  const ScriptFile({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.language       = ScriptLanguage.python,
    this.status         = ScriptFileStatus.saved,
    this.parentFolderId,
    this.isShared       = false,
  });

  // ── Getters ──────────────────────────────────────────────────────────────
  String   get parentId     => parentFolderId ?? '';
  DateTime get lastModified => updatedAt;
  bool     get isPython     =>
      language == ScriptLanguage.python || extension == 'py';
  bool     get isModified   => status == ScriptFileStatus.modified;
  bool     get hasError     => status == ScriptFileStatus.error;
  bool     get isEmpty      => content.trim().isEmpty;
  int      get lineCount    =>
      content.isEmpty ? 1 : '\n'.allMatches(content).length + 1;

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  String get displayName =>
      name.contains('.') ? name : '$name.$_defaultExt';

  String get _defaultExt {
    switch (language) {
      case ScriptLanguage.python:     return 'py';
      case ScriptLanguage.pinescript: return 'pine';
      case ScriptLanguage.javascript: return 'js';
    }
  }

  // ── copyWith ─────────────────────────────────────────────────────────────
  ScriptFile copyWith({
    String?           name,
    String?           content,
    ScriptLanguage?   language,
    ScriptFileStatus? status,
    String?           parentFolderId,
    bool              clearParent = false,
    bool?             isShared,
  }) =>
      ScriptFile(
        id:             id,
        name:           name           ?? this.name,
        content:        content        ?? this.content,
        language:       language       ?? this.language,
        status:         status         ?? this.status,
        createdAt:      createdAt,
        updatedAt:      DateTime.now(),
        parentFolderId: clearParent    ? null : (parentFolderId ?? this.parentFolderId),
        isShared:       isShared       ?? this.isShared,
      );

  // ── Convenience mutators ─────────────────────────────────────────────────
  ScriptFile withContent(String newContent) =>
      copyWith(content: newContent, status: ScriptFileStatus.modified);

  ScriptFile asSaved()   => copyWith(status: ScriptFileStatus.saved);
  ScriptFile asError()   => copyWith(status: ScriptFileStatus.error);

  ScriptFile publishShared() => copyWith(isShared: true);
  ScriptFile unpublish()     => copyWith(isShared: false);

  // ── Serialization ────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':             id,
    'name':           name,
    'content':        content,
    'language':       language.name,
    'status':         status.name,
    'createdAt':      createdAt.toIso8601String(),
    'updatedAt':      updatedAt.toIso8601String(),
    'parentFolderId': parentFolderId,
    'isShared':       isShared,
  };

  // FIX: baca snake_case dari backend, fallback camelCase untuk compat.
  factory ScriptFile.fromJson(Map<String, dynamic> json) {
    // id: 'id' (API transformed) atau '_id' (MongoDB raw)
    final id = (json['id'] ?? json['_id']) as String;

    // parent_folder_id (snake) atau parentFolderId (camel)
    final parentFolderId =
        (json['parent_folder_id'] ?? json['parentFolderId']) as String?;

    // created_at / updated_at (snake) atau createdAt / updatedAt (camel)
    final rawCreated = json['created_at'] ?? json['createdAt'];
    final rawUpdated = json['updated_at'] ?? json['updatedAt'];

    // is_shared (snake) atau isShared (camel)
    final isShared =
        (json['is_shared'] ?? json['isShared']) as bool? ?? false;

    // language: dari file extension kalau field ga ada
    final rawLang = json['language'] as String?;
    final ScriptLanguage language;
    if (rawLang != null) {
      language = ScriptLanguage.values.firstWhere(
        (l) => l.name == rawLang,
        orElse: () => _langFromName(json['name'] as String? ?? ''),
      );
    } else {
      language = _langFromName(json['name'] as String? ?? '');
    }

    // status: is_modified (MongoDB bool) atau status string (app format)
    final ScriptFileStatus status;
    final rawStatus   = json['status'] as String?;
    final isModified  = json['is_modified'] as bool? ?? false;
    if (rawStatus != null) {
      status = ScriptFileStatus.values.firstWhere(
        (s) => s.name == rawStatus,
        orElse: () => ScriptFileStatus.saved,
      );
    } else {
      status = isModified ? ScriptFileStatus.modified : ScriptFileStatus.saved;
    }

    return ScriptFile(
      id:             id,
      name:           json['name']    as String,
      content:        json['content'] as String? ?? '',
      language:       language,
      status:         status,
      createdAt:      rawCreated != null
          ? DateTime.parse(rawCreated.toString())
          : DateTime.now(),
      updatedAt:      rawUpdated != null
          ? DateTime.parse(rawUpdated.toString())
          : DateTime.now(),
      parentFolderId: parentFolderId,
      isShared:       isShared,
    );
  }

  // Helper: deteksi language dari nama file kalau field 'language' ga ada.
  static ScriptLanguage _langFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pine': return ScriptLanguage.pinescript;
      case 'js':   return ScriptLanguage.javascript;
      default:     return ScriptLanguage.python;
    }
  }

  // ── Equality + debug ─────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ScriptFile && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ScriptFile(id: $id, name: $name)';
}