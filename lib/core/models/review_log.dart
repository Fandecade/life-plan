import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 复盘周期，periodKey 形如 2026-11-22 / 2026-W47 / 2026-11 / 2026。
enum ReviewPeriodType {
  daily('日'),
  weekly('周'),
  monthly('月'),
  yearly('年');

  const ReviewPeriodType(this.label);

  final String label;

  static ReviewPeriodType fromName(Object? value) =>
      ReviewPeriodType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => ReviewPeriodType.daily,
      );
}

class ReviewLog extends SyncEntity {
  const ReviewLog({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.periodType,
    required this.periodKey,
    this.winsText = '',
    this.blockersText = '',
    this.adjustmentsText = '',
    this.focusText = '',
    this.ifThenText = '',
    this.adjustmentPlan = '',
    this.expectedOutcome = '',
    this.actualOutcome = '',
    this.isCompleted = false,
    this.handledItemsJson = '[]',
    this.snapshotStatsJson = '{}',
    super.deletedAt,
    super.syncStatus,
  });

  final ReviewPeriodType periodType;
  final String periodKey;
  final String winsText;
  final String blockersText;
  final String adjustmentsText;

  /// 下一阶段聚焦（日复盘：明日最关键 1–3 件事）。
  final String focusText;

  /// If–Then 应对预案。
  final String ifThenText;

  /// 本期调整方案（下一周期验证用）。
  final String adjustmentPlan;

  /// 调整的预期效果（可验证指标）。
  final String expectedOutcome;

  /// 调整的实际效果（由下一周期回看时补填）。
  final String actualOutcome;

  /// 是否已完成本次复盘。
  final bool isCompleted;

  /// 已处理的待校准事项 id（JSON 数组），用于划掉后保留状态。
  final String handledItemsJson;

  /// 自动汇总的统计数据快照：完成任务数、时间盒时长、习惯达成率、学习输出数。
  final String snapshotStatsJson;

  List<String> get handledItems {
    try {
      final Object? json = jsonDecode(handledItemsJson);
      if (json is List) {
        return json.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // 坏数据按未处理对待。
    }
    return const <String>[];
  }

  Map<String, dynamic> get snapshotStats {
    try {
      final Object? json = jsonDecode(snapshotStatsJson);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return json.cast<String, dynamic>();
    } catch (_) {
      // 无法解析时返回空快照。
    }
    return const <String, dynamic>{};
  }

  factory ReviewLog.create({
    required ReviewPeriodType periodType,
    required String periodKey,
    String adjustmentPlan = '',
    String expectedOutcome = '',
  }) {
    final now = DateTime.now();
    return ReviewLog(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      periodType: periodType,
      periodKey: periodKey,
      adjustmentPlan: adjustmentPlan,
      expectedOutcome: expectedOutcome,
    );
  }

  ReviewLog copyWith({
    ReviewPeriodType? periodType,
    String? periodKey,
    String? winsText,
    String? blockersText,
    String? adjustmentsText,
    String? focusText,
    String? ifThenText,
    String? adjustmentPlan,
    String? expectedOutcome,
    String? actualOutcome,
    bool? isCompleted,
    String? handledItemsJson,
    String? snapshotStatsJson,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return ReviewLog(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      periodType: periodType ?? this.periodType,
      periodKey: periodKey ?? this.periodKey,
      winsText: winsText ?? this.winsText,
      blockersText: blockersText ?? this.blockersText,
      adjustmentsText: adjustmentsText ?? this.adjustmentsText,
      focusText: focusText ?? this.focusText,
      ifThenText: ifThenText ?? this.ifThenText,
      adjustmentPlan: adjustmentPlan ?? this.adjustmentPlan,
      expectedOutcome: expectedOutcome ?? this.expectedOutcome,
      actualOutcome: actualOutcome ?? this.actualOutcome,
      isCompleted: isCompleted ?? this.isCompleted,
      handledItemsJson: handledItemsJson ?? this.handledItemsJson,
      snapshotStatsJson: snapshotStatsJson ?? this.snapshotStatsJson,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'periodType': periodType.name,
        'periodKey': periodKey,
        'winsText': winsText,
        'blockersText': blockersText,
        'adjustmentsText': adjustmentsText,
        'focusText': focusText,
        'ifThenText': ifThenText,
        'adjustmentPlan': adjustmentPlan,
        'expectedOutcome': expectedOutcome,
        'actualOutcome': actualOutcome,
        'isCompleted': isCompleted,
        'handledItemsJson': handledItemsJson,
        'snapshotStatsJson': snapshotStatsJson,
      };

  factory ReviewLog.fromJson(Map<String, dynamic> json) {
    return ReviewLog(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      periodType: ReviewPeriodType.fromName(json['periodType']),
      periodKey: json['periodKey'] as String? ?? '',
      winsText: json['winsText'] as String? ?? '',
      blockersText: json['blockersText'] as String? ?? '',
      adjustmentsText: json['adjustmentsText'] as String? ?? '',
      focusText: json['focusText'] as String? ?? '',
      ifThenText: json['ifThenText'] as String? ?? '',
      adjustmentPlan: json['adjustmentPlan'] as String? ?? '',
      expectedOutcome: json['expectedOutcome'] as String? ?? '',
      actualOutcome: json['actualOutcome'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      handledItemsJson: json['handledItemsJson'] as String? ?? '[]',
      snapshotStatsJson: json['snapshotStatsJson'] as String? ?? '{}',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}