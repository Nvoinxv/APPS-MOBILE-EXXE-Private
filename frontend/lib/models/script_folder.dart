// Path: frontend/lib/models/script_folder.dart

import 'script_file.dart';

class ScriptFolder {
  final String             id;
  final String             name;
  final String?            parentFolderId;
  final bool               isExpanded;
  final List<ScriptFile>   files;
  final List<ScriptFolder> subFolders;

  const ScriptFolder({
    required this.id,
    required this.name,
    this.parentFolderId,
    this.isExpanded = true,
    this.files      = const [],
    this.subFolders = const [],
  });

  String? get parentId   => parentFolderId;
  bool    get isRoot     => parentFolderId == null;
  bool    get isEmpty    => files.isEmpty && subFolders.isEmpty;
  int     get totalFiles => files.length + subFolders.fold(0, (s, f) => s + f.totalFiles);

  ScriptFolder copyWith({
    String?           name,
    String?           parentFolderId,
    bool?             isExpanded,
    List<ScriptFile>?   files,
    List<ScriptFolder>? subFolders,
    bool              clearParent = false,
  }) =>
      ScriptFolder(
        id:             id,
        name:           name       ?? this.name,
        parentFolderId: clearParent ? null : (parentFolderId ?? this.parentFolderId),
        isExpanded:     isExpanded ?? this.isExpanded,
        files:          files      ?? this.files,
        subFolders:     subFolders ?? this.subFolders,
      );

  ScriptFolder toggled()   => copyWith(isExpanded: !isExpanded);
  ScriptFolder expanded()  => copyWith(isExpanded: true);
  ScriptFolder collapsed() => copyWith(isExpanded: false);

  ScriptFile? findFile(String fileId) {
    for (final f in files) { if (f.id == fileId) return f; }
    for (final s in subFolders) { final f = s.findFile(fileId); if (f != null) return f; }
    return null;
  }

  ScriptFolder? findFolder(String folderId) {
    if (id == folderId) return this;
    for (final s in subFolders) { final f = s.findFolder(folderId); if (f != null) return f; }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name,
    'parentFolderId': parentFolderId,
    'isExpanded': isExpanded,
  };

  factory ScriptFolder.fromJson(Map<String, dynamic> json) => ScriptFolder(
    id:             json['id']             as String,
    name:           json['name']           as String,
    parentFolderId: json['parentFolderId'] as String?,
    isExpanded:     json['isExpanded']     as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ScriptFolder && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ScriptFolder(id: $id, name: $name)';
}
