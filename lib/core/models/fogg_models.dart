import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 福格行为模型 B = MAP 的本地配置。
///
/// anchorPrompt 对应 Prompt（锚点），tinyBehavior 对应 Action（微动作），
/// abilityFrictionTip 用来降低 Ability 门槛，motivationNote 记录 Motivation 来源。
class FoggHabit extends SyncEntity {
  const FoggHabit({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.anchorPrompt,
    required this.tinyBehavior,
    this.linkedCapabilityId,
    this.linkedActionItemId,
    this.abilityFrictionTip = '',
    this.motivationNote = '',
    this.isActive = true,
    super.deletedAt,
    super.syncStatus,
  });

  final String? linkedCapabilityId;
  final String? linkedActionItemId;
  final String anchorPrompt;
  final String tinyBehavior;
  final String abilityFrictionTip;
  final String motivationNote;
  final bool isActive;

  factory FoggHabit.create({
    required String anchorPrompt,
    required String tinyBehavior,
    String? linkedCapabilityId,
    String? linkedActionItemId,
    String abilityFrictionTip = '',
    String motivationNote = '',
  }) {
    final now = DateTime.now();
    return FoggHabit(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      anchorPrompt: anchorPrompt,
      tinyBehavior: tinyBehavior,
      linkedCapabilityId: linkedCapabilityId,
      linkedActionItemId: linkedActionItemId,
      abilityFrictionTip: abilityFrictionTip,
      motivationNote: motivationNote,
    );
  }

  FoggHabit copyWith({
    String? anchorPrompt,
    String? tinyBehavior,
    String? linkedCapabilityId,
    bool clearLinkedCapability = false,
    String? linkedActionItemId,
    bool clearLinkedActionItem = false,
    String? abilityFrictionTip,
    String? motivationNote,
    bool? isActive,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return FoggHabit(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      anchorPrompt: anchorPrompt ?? this.anchorPrompt,
      tinyBehavior: tinyBehavior ?? this.tinyBehavior,
      linkedCapabilityId:
          clearLinkedCapability ? null : (linkedCapabilityId ?? this.linkedCapabilityId),
      linkedActionItemId:
          clearLinkedActionItem ? null : (linkedActionItemId ?? this.linkedActionItemId),
      abilityFrictionTip: abilityFrictionTip ?? this.abilityFrictionTip,
      motivationNote: motivationNote ?? this.motivationNote,
      isActive: isActive ?? this.isActive,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'linkedCapabilityId': linkedCapabilityId,
        'linkedActionItemId': linkedActionItemId,
        'anchorPrompt': anchorPrompt,
        'tinyBehavior': tinyBehavior,
        'abilityFrictionTip': abilityFrictionTip,
        'motivationNote': motivationNote,
        'isActive': isActive,
      };

  factory FoggHabit.fromJson(Map<String, dynamic> json) {
    return FoggHabit(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      linkedCapabilityId: json['linkedCapabilityId'] as String?,
      linkedActionItemId: json['linkedActionItemId'] as String?,
      anchorPrompt: json['anchorPrompt'] as String? ?? '',
      tinyBehavior: json['tinyBehavior'] as String? ?? '',
      abilityFrictionTip: json['abilityFrictionTip'] as String? ?? '',
      motivationNote: json['motivationNote'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}

/// 习惯打卡日志，dateKey 使用 YYYY-MM-DD，便于按天聚合节奏图。
class HabitLog extends SyncEntity {
  const HabitLog({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.habitId,
    required this.dateKey,
    this.isCompleted = true,
    this.adjustmentNote = '',
    super.deletedAt,
    super.syncStatus,
  });

  final String habitId;
  final String dateKey;
  final bool isCompleted;
  final String adjustmentNote;

  factory HabitLog.create({
    required String habitId,
    required String dateKey,
    bool isCompleted = true,
    String adjustmentNote = '',
  }) {
    final now = DateTime.now();
    return HabitLog(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      habitId: habitId,
      dateKey: dateKey,
      isCompleted: isCompleted,
      adjustmentNote: adjustmentNote,
    );
  }

  HabitLog copyWith({
    String? dateKey,
    bool? isCompleted,
    String? adjustmentNote,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return HabitLog(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      habitId: habitId,
      dateKey: dateKey ?? this.dateKey,
      isCompleted: isCompleted ?? this.isCompleted,
      adjustmentNote: adjustmentNote ?? this.adjustmentNote,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'habitId': habitId,
        'dateKey': dateKey,
        'isCompleted': isCompleted,
        'adjustmentNote': adjustmentNote,
      };

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      habitId: json['habitId'] as String? ?? '',
      dateKey: json['dateKey'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? true,
      adjustmentNote: json['adjustmentNote'] as String? ?? '',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}