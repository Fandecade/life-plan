import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 能力：愿景之下的二级节点，也是任务归属与时间投入统计的维度。
class Capability extends SyncEntity {
  const Capability({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.visionId,
    required this.title,
    this.description = '',
    this.targetLevel = '',
    this.posX = 0,
    this.posY = 0,
    this.isCollapsed = false,
    super.deletedAt,
    super.syncStatus,
  });

  final String visionId;
  final String title;
  final String description;
  final String targetLevel;
  final double posX;
  final double posY;
  final bool isCollapsed;

  factory Capability.create({
    required String visionId,
    required String title,
    String description = '',
    String targetLevel = '',
  }) {
    final now = DateTime.now();
    return Capability(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      visionId: visionId,
      title: title,
      description: description,
      targetLevel: targetLevel,
    );
  }

  Capability copyWith({
    String? visionId,
    String? title,
    String? description,
    String? targetLevel,
    double? posX,
    double? posY,
    bool? isCollapsed,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Capability(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      visionId: visionId ?? this.visionId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetLevel: targetLevel ?? this.targetLevel,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'visionId': visionId,
        'title': title,
        'description': description,
        'targetLevel': targetLevel,
        'posX': posX,
        'posY': posY,
        'isCollapsed': isCollapsed,
      };

  factory Capability.fromJson(Map<String, dynamic> json) {
    return Capability(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      visionId: json['visionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetLevel: json['targetLevel'] as String? ?? '',
      posX: (json['posX'] as num?)?.toDouble() ?? 0,
      posY: (json['posY'] as num?)?.toDouble() ?? 0,
      isCollapsed: json['isCollapsed'] as bool? ?? false,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}