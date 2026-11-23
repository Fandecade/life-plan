import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 固定安排项的两类形态。
enum RoutineKind {
  fixedRoutine('固定事项'),
  linkedTask('关联任务');

  const RoutineKind(this.label);

  final String label;

  static RoutineKind fromName(Object? value) => RoutineKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => RoutineKind.fixedRoutine,
      );
}

/// 周固定排程模板项：绑定「星期几 + 起始分钟 + 时长」，不绑定具体日期。
class WeeklyRoutine extends SyncEntity {
  const WeeklyRoutine({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    required this.weekday,
    required this.startMinutes,
    required this.durationMinutes,
    this.kind = RoutineKind.fixedRoutine,
    this.actionItemId,
    this.isActive = true,
    this.colorIndex = 0,
    super.deletedAt,
    super.syncStatus,
  });

  final RoutineKind kind;
  final String title;

  /// 1 = 周一 … 7 = 周日。
  final int weekday;

  /// 当天起始分钟（0..1439）。
  final int startMinutes;
  final int durationMinutes;

  /// linkedTask 时关联的行动单元。
  final String? actionItemId;
  final bool isActive;

  /// 低饱和色板索引。
  final int colorIndex;

  int get startHour => startMinutes ~/ 60;

  int get startMinute => startMinutes % 60;

  int get endMinutes =>
      (startMinutes + durationMinutes).clamp(0, 24 * 60 - 1);

  factory WeeklyRoutine.create({
    required String title,
    required int weekday,
    required int startMinutes,
    required int durationMinutes,
    RoutineKind kind = RoutineKind.fixedRoutine,
    String? actionItemId,
    int colorIndex = 0,
  }) {
    final now = DateTime.now();
    return WeeklyRoutine(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title,
      weekday: weekday.clamp(1, 7),
      startMinutes: startMinutes.clamp(0, 24 * 60 - 1),
      durationMinutes: durationMinutes.clamp(15, 12 * 60),
      kind: kind,
      actionItemId: actionItemId,
      colorIndex: colorIndex,
    );
  }

  WeeklyRoutine copyWith({
    String? title,
    int? weekday,
    int? startMinutes,
    int? durationMinutes,
    RoutineKind? kind,
    String? actionItemId,
    bool clearActionItem = false,
    bool? isActive,
    int? colorIndex,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return WeeklyRoutine(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      weekday: (weekday ?? this.weekday).clamp(1, 7),
      startMinutes: (startMinutes ?? this.startMinutes).clamp(0, 24 * 60 - 1),
      durationMinutes: (durationMinutes ?? this.durationMinutes).clamp(15, 12 * 60),
      kind: kind ?? this.kind,
      actionItemId: clearActionItem ? null : (actionItemId ?? this.actionItemId),
      isActive: isActive ?? this.isActive,
      colorIndex: colorIndex ?? this.colorIndex,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'kind': kind.name,
        'title': title,
        'weekday': weekday,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'actionItemId': actionItemId,
        'isActive': isActive,
        'colorIndex': colorIndex,
      };

  factory WeeklyRoutine.fromJson(Map<String, dynamic> json) {
    return WeeklyRoutine(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      kind: RoutineKind.fromName(json['kind']),
      title: json['title'] as String? ?? '',
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 9 * 60,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      actionItemId: json['actionItemId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}

/// 单周例外：某一天跳过某个固定项，不影响其他周次。
class RoutineException extends SyncEntity {
  const RoutineException({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.routineId,
    required this.dateKey,
    this.isSkipped = true,
    super.deletedAt,
    super.syncStatus,
  });

  final String routineId;

  /// YYYY-MM-DD
  final String dateKey;
  final bool isSkipped;

  factory RoutineException.createSkip({
    required String routineId,
    required String dateKey,
  }) {
    final now = DateTime.now();
    return RoutineException(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      routineId: routineId,
      dateKey: dateKey,
    );
  }

  RoutineException copyWith({
    bool? isSkipped,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return RoutineException(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      routineId: routineId,
      dateKey: dateKey,
      isSkipped: isSkipped ?? this.isSkipped,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'routineId': routineId,
        'dateKey': dateKey,
        'isSkipped': isSkipped,
      };

  factory RoutineException.fromJson(Map<String, dynamic> json) {
    return RoutineException(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      routineId: json['routineId'] as String? ?? '',
      dateKey: json['dateKey'] as String? ?? '',
      isSkipped: json['isSkipped'] as bool? ?? true,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}