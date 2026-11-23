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
    this.snapshotStatsJson = '{}',
    super.deletedAt,
    super.syncStatus,
  });

  final ReviewPeriodType periodType;
  final String periodKey;
  final String winsText;
  final String blockersText;
  final String adjustmentsText;

  /// 自动汇总的统计数据快照：完成任务数、时间盒时长、习惯达成率、学习输出数。
  final String snapshotStatsJson;

  factory ReviewLog.create({
    required ReviewPeriodType periodType,
    required String periodKey,
  }) {
    final now = DateTime.now();
    return ReviewLog(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      periodType: periodType,
      periodKey: periodKey,
    );
  }

  ReviewLog copyWith({
    ReviewPeriodType? periodType,
    String? periodKey,
    String? winsText,
    String? blockersText,
    String? adjustmentsText,
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
      snapshotStatsJson: json['snapshotStatsJson'] as String? ?? '{}',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}