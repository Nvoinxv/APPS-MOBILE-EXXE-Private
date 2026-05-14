// Path: frontend/lib/models/script_folder.dart
//
// FIX v_snake_case:
//
//  fromJson() sebelumnya hanya baca camelCase key ('parentFolderId',
//  'isExpanded', dll). Backend/MongoDB return snake_case ('parent_folder_id',
//  'is_expanded', dll) dan _id bukan id.
//
//  Akibatnya:
//    - parentFolderId selalu null → semua folder dianggap root folder
//    - isExpanded null → default (tidak crash, tapi state salah)
//    - isIndicator null → false → folder tidak tampil di indicators panel
//
//  Fix: tiap field coba snake_case dulu, fallback camelCase (backward compat).

import 'script_file.dart';

class ScriptFolder {
  final String             id;
  final String             name;
  final String?            parentFolderId;
  final bool               isExpanded;
  final List<ScriptFile>   files;
  final List<ScriptFolder> subFolders;

  // ── Indicator fields ─────────────────────────────────────────────────────
  final bool isIndicator;
  final bool isShared;

  const ScriptFolder({
    required this.id,
    required this.name,
    this.parentFolderId,
    this.isExpanded  = true,
    this.files       = const [],
    this.subFolders  = const [],
    this.isIndicator = false,
    this.isShared    = false,
  });

  // ── Getters ──────────────────────────────────────────────────────────────
  String? get parentId   => parentFolderId;
  bool    get isRoot     => parentFolderId == null;
  bool    get isEmpty    => files.isEmpty && subFolders.isEmpty;
  int     get totalFiles =>
      files.length + subFolders.fold(0, (s, f) => s + f.totalFiles);

  bool get isSavedIndicator =>
      isIndicator && files.any((f) => f.status == ScriptFileStatus.saved);

  // ── copyWith ─────────────────────────────────────────────────────────────
  ScriptFolder copyWith({
    String?             name,
    String?             parentFolderId,
    bool?               isExpanded,
    List<ScriptFile>?   files,
    List<ScriptFolder>? subFolders,
    bool                clearParent  = false,
    bool?               isIndicator,
    bool?               isShared,
  }) =>
      ScriptFolder(
        id:             id,
        name:           name           ?? this.name,
        parentFolderId: clearParent    ? null : (parentFolderId ?? this.parentFolderId),
        isExpanded:     isExpanded     ?? this.isExpanded,
        files:          files          ?? this.files,
        subFolders:     subFolders     ?? this.subFolders,
        isIndicator:    isIndicator    ?? this.isIndicator,
        isShared:       isShared       ?? this.isShared,
      );

  // ── Convenience mutators ─────────────────────────────────────────────────
  ScriptFolder toggled()   => copyWith(isExpanded: !isExpanded);
  ScriptFolder expanded()  => copyWith(isExpanded: true);
  ScriptFolder collapsed() => copyWith(isExpanded: false);

  ScriptFolder markAsIndicator() => copyWith(isIndicator: true);
  ScriptFolder publishShared()   => copyWith(isShared: true);
  ScriptFolder unpublish()       => copyWith(isShared: false);

  // ── Tree search ──────────────────────────────────────────────────────────
  ScriptFile? findFile(String fileId) {
    for (final f in files)      { if (f.id == fileId) return f; }
    for (final s in subFolders) { final f = s.findFile(fileId); if (f != null) return f; }
    return null;
  }

  ScriptFolder? findFolder(String folderId) {
    if (id == folderId) return this;
    for (final s in subFolders) {
      final f = s.findFolder(folderId);
      if (f != null) return f;
    }
    return null;
  }

  // ── Serialization ────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':             id,
    'name':           name,
    'parentFolderId': parentFolderId,
    'isExpanded':     isExpanded,
    'isIndicator':    isIndicator,
    'isShared':       isShared,
  };

  // FIX: baca snake_case dari backend, fallback camelCase untuk compat.
  factory ScriptFolder.fromJson(Map<String, dynamic> json) {
    // id: 'id' (API transformed) atau '_id' (MongoDB raw)
    final id = (json['id'] ?? json['_id']) as String;

    // parent_folder_id (snake) atau parentFolderId (camel)
    final parentFolderId =
        (json['parent_folder_id'] ?? json['parentFolderId']) as String?;

    // is_expanded (snake) atau isExpanded (camel)
    final isExpanded =
        (json['is_expanded'] ?? json['isExpanded']) as bool? ?? true;

    // is_indicator (snake) atau isIndicator (camel)
    // NOTE: MongoDB mungkin belum punya field ini, default false.
    final isIndicator =
        (json['is_indicator'] ?? json['isIndicator']) as bool? ?? false;

    // is_shared (snake) atau isShared (camel)
    final isShared =
        (json['is_shared'] ?? json['isShared']) as bool? ?? false;

    return ScriptFolder(
      id:             id,
      name:           json['name'] as String,
      parentFolderId: parentFolderId,
      isExpanded:     isExpanded,
      isIndicator:    isIndicator,
      isShared:       isShared,
      // files dan subFolders tidak di-parse di sini —
      // di-populate oleh workspace hook setelah load semua data.
      files:      const [],
      subFolders: const [],
    );
  }

  // ── Equality + debug ─────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScriptFolder && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ScriptFolder(id: $id, name: $name)';
}