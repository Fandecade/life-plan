import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 主页倒计时：自定义目标时间，或绑定任务截止日期（动态跟随任务）。
class Countdown extends SyncEntity {
  const Countdown({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    this.targetAt,
    this.sourceTaskId,
    this.autoHideExpired = false,
    this.dateOnly = false,
    this.colorHex,
    this.sortOrder = 0,
    super.deletedAt,
    super.syncStatus,
  });

  final String title;
  final DateTime? targetAt;
  final String? sourceTaskId;
  final bool autoHideExpired;
  final bool dateOnly;

  /// 自定义颜色（#RRGGBB）；null 表示按剩余时间自动变色。
  final String? colorHex;
  final int sortOrder;

  bool get isTaskBound => sourceTaskId != null;

  /// 绑定任务时以任务截止时间为准，避免双写不一致。
  DateTime? resolveTarget(DateTime? taskDueDate) =>
      isTaskBound ? taskDueDate : targetAt;

  factory Countdown.create({
    required String title,
    DateTime? targetAt,
    String? sourceTaskId,
    bool autoHideExpired = false,
    bool dateOnly = false,
    String? colorHex,
    int sortOrder = 0,
  }) {
    final DateTime now = DateTime.now();
    return Countdown(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title.trim(),
      targetAt: targetAt,
      sourceTaskId: sourceTaskId,
      autoHideExpired: autoHideExpired,
      dateOnly: dateOnly,
      colorHex: colorHex,
      sortOrder: sortOrder,
    );
  }

  Countdown copyWith({
    String? title,
    DateTime? targetAt,
    bool clearTargetAt = false,
    String? sourceTaskId,
    bool clearSourceTask = false,
    bool? autoHideExpired,
    bool? dateOnly,
    String? colorHex,
    bool clearColor = false,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Countdown(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      targetAt: clearTargetAt ? null : (targetAt ?? this.targetAt),
      sourceTaskId:
          clearSourceTask ? null : (sourceTaskId ?? this.sourceTaskId),
      autoHideExpired: autoHideExpired ?? this.autoHideExpired,
      dateOnly: dateOnly ?? this.dateOnly,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'title': title,
        'targetAt': targetAt?.toIso8601String(),
        'sourceTaskId': sourceTaskId,
        'autoHideExpired': autoHideExpired,
        'dateOnly': dateOnly,
        'colorHex': colorHex,
        'sortOrder': sortOrder,
      };

  factory Countdown.fromJson(Map<String, dynamic> json) {
    return Countdown(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] as String? ?? '',
      targetAt: parseNullableDate(json['targetAt']),
      sourceTaskId: json['sourceTaskId'] as String?,
      autoHideExpired: json['autoHideExpired'] as bool? ?? false,
      dateOnly: json['dateOnly'] as bool? ?? false,
      colorHex: json['colorHex'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}