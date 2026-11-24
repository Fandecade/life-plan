import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

enum ProjectStatus {
  active('进行中'),
  paused('暂停'),
  completed('已完成'),
  archived('已归档');

  const ProjectStatus(this.label);

  final String label;

  static ProjectStatus fromName(Object? value) =>
      ProjectStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => ProjectStatus.active,
      );
}

/// 项目阶段：不是待办，而是项目推进的里程碑检查点。
class ProjectStage {
  const ProjectStage({
    required this.id,
    required this.title,
    this.done = false,
  });

  final String id;
  final String title;
  final bool done;

  ProjectStage copyWith({String? title, bool? done}) => ProjectStage(
        id: id,
        title: title ?? this.title,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'done': done,
      };

  factory ProjectStage.fromJson(Map<String, dynamic> json) => ProjectStage(
        id: json['id'] as String? ?? _uuid.v4(),
        title: json['title'] as String? ?? '',
        done: json['done'] as bool? ?? false,
      );
}

/// 项目：综合实践载体，可关联多项能力、阶段、验收标准与产物证据。
///
/// 与 ActionItem 分开：任务是可执行行动，项目是「通过什么综合实践形成能力」。
class Project extends SyncEntity {
  const Project({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    this.goal = '',
    this.status = ProjectStatus.active,
    this.capabilityIdsJson = '[]',
    this.stagesJson = '[]',
    this.acceptance = '',
    this.artifactUrl = '',
    this.note = '',
    super.deletedAt,
    super.syncStatus,
  });

  final String title;
  final String goal;
  final ProjectStatus status;
  final String capabilityIdsJson;
  final String stagesJson;
  final String acceptance;
  final String artifactUrl;
  final String note;

  List<String> get capabilityIds {
    try {
      final Object? json = jsonDecode(capabilityIdsJson);
      if (json is List) return json.whereType<String>().toList(growable: false);
    } catch (_) {}
    return const <String>[];
  }

  List<ProjectStage> get stages {
    try {
      final Object? json = jsonDecode(stagesJson);
      if (json is List) {
        return json
            .whereType<Map>()
            .map((Map item) =>
                ProjectStage.fromJson(item.cast<String, dynamic>()))
            .where((ProjectStage stage) => stage.title.trim().isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
    return const <ProjectStage>[];
  }

  int get doneStages =>
      stages.where((ProjectStage stage) => stage.done).length;

  double get stageProgress =>
      stages.isEmpty ? 0 : doneStages / stages.length;

  factory Project.create({
    required String title,
    String goal = '',
    ProjectStatus status = ProjectStatus.active,
    List<String> capabilityIds = const <String>[],
    List<ProjectStage> stages = const <ProjectStage>[],
    String acceptance = '',
    String artifactUrl = '',
    String note = '',
  }) {
    final DateTime now = DateTime.now();
    return Project(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title.trim(),
      goal: goal,
      status: status,
      capabilityIdsJson: jsonEncode(capabilityIds),
      stagesJson:
          jsonEncode(stages.map((ProjectStage stage) => stage.toJson()).toList()),
      acceptance: acceptance,
      artifactUrl: artifactUrl.trim(),
      note: note,
    );
  }

  Project copyWith({
    String? title,
    String? goal,
    ProjectStatus? status,
    String? capabilityIdsJson,
    String? stagesJson,
    String? acceptance,
    String? artifactUrl,
    String? note,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Project(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      goal: goal ?? this.goal,
      status: status ?? this.status,
      capabilityIdsJson: capabilityIdsJson ?? this.capabilityIdsJson,
      stagesJson: stagesJson ?? this.stagesJson,
      acceptance: acceptance ?? this.acceptance,
      artifactUrl: artifactUrl ?? this.artifactUrl,
      note: note ?? this.note,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'title': title,
        'goal': goal,
        'status': status.name,
        'capabilityIdsJson': capabilityIdsJson,
        'stagesJson': stagesJson,
        'acceptance': acceptance,
        'artifactUrl': artifactUrl,
        'note': note,
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      status: ProjectStatus.fromName(json['status']),
      capabilityIdsJson: json['capabilityIdsJson'] as String? ?? '[]',
      stagesJson: json['stagesJson'] as String? ?? '[]',
      acceptance: json['acceptance'] as String? ?? '',
      artifactUrl: json['artifactUrl'] as String? ?? '',
      note: json['note'] as String? ?? '',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}