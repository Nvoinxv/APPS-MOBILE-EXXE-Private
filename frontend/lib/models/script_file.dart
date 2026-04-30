// Path: frontend/lib/models/script_file.dart

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

  const ScriptFile({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.language       = ScriptLanguage.python,
    this.status         = ScriptFileStatus.saved,
    this.parentFolderId,
  });

  String   get parentId    => parentFolderId ?? '';
  DateTime get lastModified => updatedAt;
  bool     get isPython    => language == ScriptLanguage.python || extension == 'py';
  bool     get isModified  => status == ScriptFileStatus.modified;
  bool     get hasError    => status == ScriptFileStatus.error;
  bool     get isEmpty     => content.trim().isEmpty;
  int      get lineCount   => content.isEmpty ? 1 : '\n'.allMatches(content).length + 1;

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  String get displayName => name.contains('.') ? name : '$name.$_defaultExt';

  String get _defaultExt {
    switch (language) {
      case ScriptLanguage.python:     return 'py';
      case ScriptLanguage.pinescript: return 'pine';
      case ScriptLanguage.javascript: return 'js';
    }
  }

  ScriptFile copyWith({
    String?           name,
    String?           content,
    ScriptLanguage?   language,
    ScriptFileStatus? status,
    String?           parentFolderId,
    bool              clearParent = false,
  }) =>
      ScriptFile(
        id:             id,
        name:           name     ?? this.name,
        content:        content  ?? this.content,
        language:       language ?? this.language,
        status:         status   ?? this.status,
        createdAt:      createdAt,
        updatedAt:      DateTime.now(),
        parentFolderId: clearParent ? null : (parentFolderId ?? this.parentFolderId),
      );

  ScriptFile withContent(String newContent) =>
      copyWith(content: newContent, status: ScriptFileStatus.modified);

  ScriptFile asSaved() => copyWith(status: ScriptFileStatus.saved);
  ScriptFile asError() => copyWith(status: ScriptFileStatus.error);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'content': content,
    'language': language.name, 'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'parentFolderId': parentFolderId,
  };

  factory ScriptFile.fromJson(Map<String, dynamic> json) => ScriptFile(
    id:             json['id']      as String,
    name:           json['name']    as String,
    content:        json['content'] as String? ?? '',
    language:       ScriptLanguage.values.firstWhere(
      (l) => l.name == json['language'], orElse: () => ScriptLanguage.python),
    status:         ScriptFileStatus.values.firstWhere(
      (s) => s.name == json['status'], orElse: () => ScriptFileStatus.saved),
    createdAt:      DateTime.parse(json['createdAt'] as String),
    updatedAt:      DateTime.parse(json['updatedAt'] as String),
    parentFolderId: json['parentFolderId'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ScriptFile && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ScriptFile(id: $id, name: $name)';
}
