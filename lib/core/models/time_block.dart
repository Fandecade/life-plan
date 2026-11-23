import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 全局时间盒中的一个时间块。
///
/// 与动作单元双向联动：时间块完成 → 行动单元完成；行动单元排期 → 时间块生成。
class TimeBlock extends SyncEntity {
  const TimeBlock({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.actionItemId,
    this.learningReviewId,
    this.routineId,
    this.isCompleted = false,
    this.isOverridden = false,
    this.actualMinutes,
    super.deletedAt,
    super.syncStatus,
  });

  final String? actionItemId;
  final String? learningReviewId;

  /// 由周固定安排生成时记录来源，用于单周跳过与恢复。
  final String? routineId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final bool isCompleted;

  /// 单周特例：用户在本周修改过该固定块。
  final bool isOverridden;
  final int? actualMinutes;

  int get plannedMinutes => endAt.difference(startAt).inMinutes;

  bool get isStandalone => actionItemId == null;

  factory TimeBlock.create({
    required DateTime startAt,
    required DateTime endAt,
    String title = '',
    String? actionItemId,
    String? learningReviewId,
    String? routineId,
  }) {
    final now = DateTime.now();
    return TimeBlock(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title,
      startAt: startAt,
      endAt: endAt,
      actionItemId: actionItemId,
      learningReviewId: learningReviewId,
      routineId: routineId,
    );
  }

  TimeBlock copyWith({
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? actionItemId,
    bool clearActionItem = false,
    String? learningReviewId,
    bool clearLearningReview = false,
    String? routineId,
    bool clearRoutine = false,
    bool? isCompleted,
    bool? isOverridden,
    int? actualMinutes,
    bool clearActualMinutes = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return TimeBlock(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      actionItemId: clearActionItem ? null : (actionItemId ?? this.actionItemId),
      learningReviewId:
          clearLearningReview ? null : (learningReviewId ?? this.learningReviewId),
      routineId: clearRoutine ? null : (routineId ?? this.routineId),
      isCompleted: isCompleted ?? this.isCompleted,
      isOverridden: isOverridden ?? this.isOverridden,
      actualMinutes:
          clearActualMinutes ? null : (actualMinutes ?? this.actualMinutes),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'actionItemId': actionItemId,
        'learningReviewId': learningReviewId,
        'routineId': routineId,
        'title': title,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'isCompleted': isCompleted,
        'isOverridden': isOverridden,
        'actualMinutes': actualMinutes,
      };

  factory TimeBlock.fromJson(Map<String, dynamic> json) {
    return TimeBlock(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] as String? ?? '',
      startAt: parseDate(json['startAt']),
      endAt: parseDate(json['endAt']),
      actionItemId: json['actionItemId'] as String?,
      learningReviewId: json['learningReviewId'] as String?,
      routineId: json['routineId'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isOverridden: json['isOverridden'] as bool? ?? false,
      actualMinutes: (json['actualMinutes'] as num?)?.toInt(),
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}