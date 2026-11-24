import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 能力的阶段成果：能力达到某个水平时，可以独立完成什么（验收标准）。
///
/// 它是「能力的证据」，不是另一层待办；不计入任务完成数。
class CapabilityMilestone {
  const CapabilityMilestone({
    required this.id,
    required this.title,
    this.evidence = '',
    this.achieved = false,
    this.achievedAt,
  });

  final String id;
  final String title;
  final String evidence;
  final bool achieved;
  final DateTime? achievedAt;

  CapabilityMilestone copyWith({
    String? title,
    String? evidence,
    bool? achieved,
    DateTime? achievedAt,
    bool clearAchievedAt = false,
  }) {
    return CapabilityMilestone(
      id: id,
      title: title ?? this.title,
      evidence: evidence ?? this.evidence,
      achieved: achieved ?? this.achieved,
      achievedAt: clearAchievedAt ? null : (achievedAt ?? this.achievedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'evidence': evidence,
        'achieved': achieved,
        'achievedAt': achievedAt?.toIso8601String(),
      };

  factory CapabilityMilestone.fromJson(Map<String, dynamic> json) {
    final String? achievedAt = json['achievedAt'] as String?;
    return CapabilityMilestone(
      id: json['id'] as String? ?? _uuid.v4(),
      title: json['title'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
      achieved: json['achieved'] as bool? ?? false,
      achievedAt: achievedAt == null ? null : DateTime.tryParse(achievedAt),
    );
  }
}

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
    this.milestonesJson = '[]',
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

  /// 阶段成果（Milestone）列表的快照，JSON 数组。
  final String milestonesJson;

  List<CapabilityMilestone> get milestones => decodeMilestones(milestonesJson);

  int get achievedMilestones =>
      milestones.where((CapabilityMilestone item) => item.achieved).length;

  factory Capability.create({
    required String visionId,
    required String title,
    String description = '',
    String targetLevel = '',
    String milestonesJson = '[]',
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
      milestonesJson: milestonesJson,
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
    String? milestonesJson,
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
      milestonesJson: milestonesJson ?? this.milestonesJson,
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
        'milestonesJson': milestonesJson,
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
      milestonesJson: json['milestonesJson'] as String? ?? '[]',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}

/// 容错解析阶段成果 JSON。
List<CapabilityMilestone> decodeMilestones(String raw) {
  try {
    final Object? json = jsonDecode(raw);
    if (json is List) {
      return json
          .whereType<Map>()
          .map((Map item) =>
              CapabilityMilestone.fromJson(item.cast<String, dynamic>()))
          .where((CapabilityMilestone item) => item.title.trim().isNotEmpty)
          .toList(growable: false);
    }
  } catch (_) {
    // 坏数据按空列表处理。
  }
  return const <CapabilityMilestone>[];
}

String encodeMilestones(List<CapabilityMilestone> milestones) =>
    jsonEncode(milestones.map((CapabilityMilestone item) => item.toJson()).toList());
