import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 锚点时段，用于首页按时段分组。
enum AnchorPeriod {
  morning('晨间锚点'),
  midday('日间间隙'),
  evening('晚间收尾'),
  anytime('随时触发');

  const AnchorPeriod(this.label);

  final String label;

  static AnchorPeriod fromName(Object? value) => AnchorPeriod.values.firstWhere(
        (period) => period.name == value,
        orElse: () => AnchorPeriod.anytime,
      );
}

/// 5 维能力阻力（时间 / 金钱 / 体力 / 脑力 / 日程习惯）。
class FrictionProfile {
  const FrictionProfile({
    this.time = false,
    this.money = false,
    this.energy = false,
    this.brain = false,
    this.routine = false,
    this.note = '',
  });

  final bool time;
  final bool money;
  final bool energy;
  final bool brain;
  final bool routine;
  final String note;

  int get count => <bool>[time, money, energy, brain, routine]
      .where((bool flag) => flag)
      .length;

  List<String> get labels => <String>[
        if (time) '时间',
        if (money) '金钱',
        if (energy) '体力',
        if (brain) '脑力',
        if (routine) '日程习惯',
      ];

  FrictionProfile copyWith({
    bool? time,
    bool? money,
    bool? energy,
    bool? brain,
    bool? routine,
    String? note,
  }) {
    return FrictionProfile(
      time: time ?? this.time,
      money: money ?? this.money,
      energy: energy ?? this.energy,
      brain: brain ?? this.brain,
      routine: routine ?? this.routine,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': time,
        'money': money,
        'energy': energy,
        'brain': brain,
        'routine': routine,
        'note': note,
      };

  factory FrictionProfile.fromJson(Map<String, dynamic> json) => FrictionProfile(
        time: json['time'] as bool? ?? false,
        money: json['money'] as bool? ?? false,
        energy: json['energy'] as bool? ?? false,
        brain: json['brain'] as bool? ?? false,
        routine: json['routine'] as bool? ?? false,
        note: json['note'] as String? ?? '',
      );

  static FrictionProfile decode(String raw) {
    try {
      final Object? json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return FrictionProfile.fromJson(json);
      if (json is Map) return FrictionProfile.fromJson(json.cast<String, dynamic>());
    } catch (_) {
      // 坏数据回退为空阻力。
    }
    return const FrictionProfile();
  }

  String encode() => jsonEncode(toJson());
}

/// 福格习惯配置：锚点提示 → 微行为，附 5 维降阻与即时庆祝。
class FoggHabit extends SyncEntity {
  const FoggHabit({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.anchorPrompt,
    required this.tinyBehavior,
    this.linkedCapabilityId,
    this.linkedActionItemId,
    this.anchorPeriod = AnchorPeriod.anytime,
    this.celebration = '握拳，默念：我做到了',
    this.frictionsJson = '{}',
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
  final AnchorPeriod anchorPeriod;
  final String celebration;
  final String frictionsJson;
  final String abilityFrictionTip;
  final String motivationNote;
  final bool isActive;

  FrictionProfile get frictions => FrictionProfile.decode(frictionsJson);

  factory FoggHabit.create({
    required String anchorPrompt,
    required String tinyBehavior,
    String? linkedCapabilityId,
    String? linkedActionItemId,
    AnchorPeriod anchorPeriod = AnchorPeriod.anytime,
    String celebration = '握拳，默念：我做到了',
    FrictionProfile frictions = const FrictionProfile(),
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
      anchorPeriod: anchorPeriod,
      celebration: celebration,
      frictionsJson: frictions.encode(),
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
    AnchorPeriod? anchorPeriod,
    String? celebration,
    FrictionProfile? frictions,
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
      anchorPeriod: anchorPeriod ?? this.anchorPeriod,
      celebration: celebration ?? this.celebration,
      frictionsJson: frictions == null ? frictionsJson : frictions.encode(),
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
        'anchorPeriod': anchorPeriod.name,
        'celebration': celebration,
        'frictionsJson': frictionsJson,
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
      anchorPeriod: AnchorPeriod.fromName(json['anchorPeriod']),
      celebration: json['celebration'] as String? ?? '握拳，默念：我做到了',
      frictionsJson: json['frictionsJson'] as String? ?? '{}',
      abilityFrictionTip: json['abilityFrictionTip'] as String? ?? '',
      motivationNote: json['motivationNote'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}

/// 习惯打卡日志；isExtra 表示「超额完成」，不抬高次日门槛。
class HabitLog extends SyncEntity {
  const HabitLog({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.habitId,
    required this.dateKey,
    this.isCompleted = true,
    this.isExtra = false,
    this.adjustmentNote = '',
    super.deletedAt,
    super.syncStatus,
  });

  final String habitId;
  final String dateKey;
  final bool isCompleted;
  final bool isExtra;
  final String adjustmentNote;

  factory HabitLog.create({
    required String habitId,
    required String dateKey,
    bool isCompleted = true,
    bool isExtra = false,
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
      isExtra: isExtra,
      adjustmentNote: adjustmentNote,
    );
  }

  HabitLog copyWith({
    String? dateKey,
    bool? isCompleted,
    bool? isExtra,
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
      isExtra: isExtra ?? this.isExtra,
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
        'isExtra': isExtra,
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
      isExtra: json['isExtra'] as bool? ?? false,
      adjustmentNote: json['adjustmentNote'] as String? ?? '',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}

/// 行为集群中的一个候选行为，用于焦点地图筛选黄金行为。
///
/// impact（1..5，越高影响力越大）、effort（1..5，越大越难做）。
class BehaviorCandidate extends SyncEntity {
  const BehaviorCandidate({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    this.impact = 3,
    this.effort = 3,
    this.isSelected = false,
    super.deletedAt,
    super.syncStatus,
  });

  final String title;
  final int impact;
  final int effort;
  final bool isSelected;

  bool get isGolden => impact >= 4 && effort <= 2;

  factory BehaviorCandidate.create({
    required String title,
    int impact = 3,
    int effort = 3,
  }) {
    final now = DateTime.now();
    return BehaviorCandidate(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title,
      impact: impact.clamp(1, 5),
      effort: effort.clamp(1, 5),
    );
  }

  BehaviorCandidate copyWith({
    String? title,
    int? impact,
    int? effort,
    bool? isSelected,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return BehaviorCandidate(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      impact: (impact ?? this.impact).clamp(1, 5),
      effort: (effort ?? this.effort).clamp(1, 5),
      isSelected: isSelected ?? this.isSelected,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'title': title,
        'impact': impact,
        'effort': effort,
        'isSelected': isSelected,
      };

  factory BehaviorCandidate.fromJson(Map<String, dynamic> json) {
    return BehaviorCandidate(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] as String? ?? '',
      impact: (json['impact'] as num?)?.toInt() ?? 3,
      effort: (json['effort'] as num?)?.toInt() ?? 3,
      isSelected: json['isSelected'] as bool? ?? false,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}

/// 配方版本：每次修改微行为 / 锚点 / 庆祝方式时留存，供复盘对比。
class HabitRecipeVersion extends SyncEntity {
  const HabitRecipeVersion({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.habitId,
    required this.revision,
    required this.anchorPrompt,
    required this.tinyBehavior,
    required this.celebration,
    this.frictionsJson = '{}',
    this.note = '',
    super.deletedAt,
    super.syncStatus,
  });

  final String habitId;
  final int revision;
  final String anchorPrompt;
  final String tinyBehavior;
  final String celebration;
  final String frictionsJson;
  final String note;

  factory HabitRecipeVersion.create({
    required String habitId,
    required int revision,
    required String anchorPrompt,
    required String tinyBehavior,
    required String celebration,
    String frictionsJson = '{}',
    String note = '',
  }) {
    final now = DateTime.now();
    return HabitRecipeVersion(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      habitId: habitId,
      revision: revision,
      anchorPrompt: anchorPrompt,
      tinyBehavior: tinyBehavior,
      celebration: celebration,
      frictionsJson: frictionsJson,
      note: note,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'habitId': habitId,
        'revision': revision,
        'anchorPrompt': anchorPrompt,
        'tinyBehavior': tinyBehavior,
        'celebration': celebration,
        'frictionsJson': frictionsJson,
        'note': note,
      };

  factory HabitRecipeVersion.fromJson(Map<String, dynamic> json) {
    return HabitRecipeVersion(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      habitId: json['habitId'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      anchorPrompt: json['anchorPrompt'] as String? ?? '',
      tinyBehavior: json['tinyBehavior'] as String? ?? '',
      celebration: json['celebration'] as String? ?? '',
      frictionsJson: json['frictionsJson'] as String? ?? '{}',
      note: json['note'] as String? ?? '',
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}