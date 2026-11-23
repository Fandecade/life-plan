import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 输出式学习的两种档位：完整四步 / 5 分钟微输出。
enum LearningMode {
  full('完整输出', '四步深度输出'),
  quick('微输出', '5 分钟轻量推进');

  const LearningMode(this.label, this.description);

  final String label;
  final String description;

  static LearningMode fromName(Object? value) => LearningMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => LearningMode.full,
      );
}

/// 五类学习目标，决定系统加载哪套方法论步骤流与复习间隔。
enum LearningType {
  declarative('陈述性知识', '概念 · 费曼', true),
  procedural('程序性知识', '实操 · 刻意练习', false),
  project('项目式学习', '项目式', false),
  language('语言学习', '语言', false),
  custom('自定义输出', '自定义', true);

  const LearningType(this.label, this.tag, this.supportsQuick);

  final String label;
  final String tag;

  /// 是否提供 5 分钟轻量微输出档（规格仅陈述性知识与自定义支持）。
  final bool supportsQuick;

  static LearningType fromName(Object? value) => LearningType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => LearningType.declarative,
      );
}

/// 一次学习推进会话：只存步骤进度、简要记录、卡点与外部链接。
class LearningSession extends SyncEntity {
  const LearningSession({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.actionItemId,
    this.learningType = LearningType.declarative,
    this.mode = LearningMode.full,
    this.stepsDataJson = '{}',
    this.currentStepIndex = 0,
    this.isFinished = false,
    this.completedAt,
    super.deletedAt,
    super.syncStatus,
  });

  final String actionItemId;
  final LearningType learningType;
  final LearningMode mode;
  final String stepsDataJson;
  final int currentStepIndex;
  final bool isFinished;
  final DateTime? completedAt;

  factory LearningSession.create({
    required String actionItemId,
    LearningType learningType = LearningType.declarative,
    LearningMode mode = LearningMode.full,
  }) {
    final now = DateTime.now();
    return LearningSession(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      actionItemId: actionItemId,
      learningType: learningType,
      mode: mode,
    );
  }

  LearningSession copyWith({
    LearningType? learningType,
    LearningMode? mode,
    String? stepsDataJson,
    int? currentStepIndex,
    bool? isFinished,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return LearningSession(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      actionItemId: actionItemId,
      learningType: learningType ?? this.learningType,
      mode: mode ?? this.mode,
      stepsDataJson: stepsDataJson ?? this.stepsDataJson,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isFinished: isFinished ?? this.isFinished,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'actionItemId': actionItemId,
        'learningType': learningType.name,
        'mode': mode.name,
        'stepsDataJson': stepsDataJson,
        'currentStepIndex': currentStepIndex,
        'isFinished': isFinished,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory LearningSession.fromJson(Map<String, dynamic> json) {
    return LearningSession(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      actionItemId: json['actionItemId'] as String? ?? '',
      learningType: LearningType.fromName(json['learningType']),
      mode: LearningMode.fromName(json['mode']),
      stepsDataJson: json['stepsDataJson'] as String? ?? '{}',
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      isFinished: json['isFinished'] as bool? ?? false,
      completedAt: parseNullableDate(json['completedAt']),
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}

/// 主动回忆结果：顺畅 → 拉长间隔，模糊 → 保持，遗忘 → 回到 1 天。
enum ReviewOutcome {
  smooth('顺畅'),
  vague('模糊'),
  forgotten('遗忘');

  const ReviewOutcome(this.label);

  final String label;

  static ReviewOutcome fromName(Object? value) => ReviewOutcome.values.firstWhere(
        (outcome) => outcome.name == value,
        orElse: () => ReviewOutcome.vague,
      );
}

/// 间隔复习提醒（1 / 3 / 7 / 15 / 30 天等）。
class LearningReview extends SyncEntity {
  const LearningReview({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.sessionId,
    required this.actionItemId,
    required this.dueDate,
    required this.intervalDays,
    this.isDone = false,
    this.outcome,
    this.doneAt,
    super.deletedAt,
    super.syncStatus,
  });

  final String sessionId;
  final String actionItemId;
  final DateTime dueDate;
  final int intervalDays;
  final bool isDone;
  final ReviewOutcome? outcome;
  final DateTime? doneAt;

  bool get isOverdue =>
      !isDone && dueDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  factory LearningReview.create({
    required String sessionId,
    required String actionItemId,
    required DateTime dueDate,
    required int intervalDays,
  }) {
    final now = DateTime.now();
    return LearningReview(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      sessionId: sessionId,
      actionItemId: actionItemId,
      dueDate: dueDate,
      intervalDays: intervalDays,
    );
  }

  LearningReview copyWith({
    DateTime? dueDate,
    int? intervalDays,
    bool? isDone,
    ReviewOutcome? outcome,
    bool clearOutcome = false,
    DateTime? doneAt,
    bool clearDoneAt = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return LearningReview(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sessionId: sessionId,
      actionItemId: actionItemId,
      dueDate: dueDate ?? this.dueDate,
      intervalDays: intervalDays ?? this.intervalDays,
      isDone: isDone ?? this.isDone,
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'sessionId': sessionId,
        'actionItemId': actionItemId,
        'dueDate': dueDate.toIso8601String(),
        'intervalDays': intervalDays,
        'isDone': isDone,
        'outcome': outcome?.name,
        'doneAt': doneAt?.toIso8601String(),
      };

  factory LearningReview.fromJson(Map<String, dynamic> json) {
    return LearningReview(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      sessionId: json['sessionId'] as String? ?? '',
      actionItemId: json['actionItemId'] as String? ?? '',
      dueDate: parseDate(json['dueDate']),
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 1,
      isDone: json['isDone'] as bool? ?? false,
      outcome: json['outcome'] == null
          ? null
          : ReviewOutcome.fromName(json['outcome']),
      doneAt: parseNullableDate(json['doneAt']),
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}