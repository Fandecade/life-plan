import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 学习成果的类型：用于区分「活动」与「可验证的能力证据」。
enum ArtifactType {
  explanation('概念解释'),
  derivation('数学推导'),
  exercise('习题证明'),
  code('代码实现'),
  project('项目成果'),
  presentation('学术表达');

  const ArtifactType(this.label);

  final String label;

  static ArtifactType fromName(Object? value) => ArtifactType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => ArtifactType.explanation,
      );
}

/// 能力证据（Artifact）：一次学习或项目产出中可被复用的成果。
///
/// 与 LearningSession 分开：会话记录过程，Artifact 记录「拿得出手的结果」，
/// 可挂到能力上作为阶段成果的证据。
class Artifact extends SyncEntity {
  const Artifact({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    this.type = ArtifactType.explanation,
    this.capabilityId,
    this.actionItemId,
    this.sessionId,
    this.url = '',
    this.note = '',
    super.deletedAt,
    super.syncStatus,
  });

  final String title;
  final ArtifactType type;
  final String? capabilityId;
  final String? actionItemId;
  final String? sessionId;

  /// 外部成果链接（GitHub / 文档 / 录音）。
  final String url;
  final String note;

  factory Artifact.create({
    required String title,
    ArtifactType type = ArtifactType.explanation,
    String? capabilityId,
    String? actionItemId,
    String? sessionId,
    String url = '',
    String note = '',
  }) {
    final DateTime now = DateTime.now();
    return Artifact(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title.trim(),
      type: type,
      capabilityId: capabilityId,
      actionItemId: actionItemId,
      sessionId: sessionId,
      url: url.trim(),
      note: note,
    );
  }

  Artifact copyWith({
    String? title,
    ArtifactType? type,
    String? capabilityId,
    bool clearCapability = false,
    String? actionItemId,
    String? sessionId,
    String? url,
    String? note,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Artifact(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      type: type ?? this.type,
      capabilityId:
          clearCapability ? null : (capabilityId ?? this.capabilityId),
      actionItemId: actionItemId ?? this.actionItemId,
      sessionId: sessionId ?? this.sessionId,
      url: url ?? this.url,
      note: note ?? this.note,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'title': title,
        'type': type.name,
        'capabilityId': capabilityId,
        'actionItemId': actionItemId,
        'sessionId': sessionId,
        'url': url,
        'note': note,
      };

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] as String? ?? '',
      type: ArtifactType.fromName(json['type']),
      capabilityId: json['capabilityId'] as String?,
      actionItemId: json['actionItemId'] as String?,
      sessionId: json['sessionId'] as String?,
      url: json['url'] as String? ?? '',
      note: json['note'] as String? ?? '',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}