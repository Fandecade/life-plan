import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';
import '../utils/date_utils.dart';

/// 通用 JSON 实体仓储：统一解码容错、软删除与变更通知。
class JsonEntityRepository<T extends SyncEntity> extends ChangeNotifier {
  JsonEntityRepository(this._box, this._decoder) {
    _listenable = _box.listenable();
    _listenable.addListener(_handleChanged);
  }

  final Box<String> _box;
  final T Function(Map<String, dynamic> json) _decoder;
  late final ValueListenable<Box<String>> _listenable;

  void _handleChanged() => notifyListeners();

  /// 全部未删除实体，按最近更新排序。
  List<T> get all {
    final List<T> items = <T>[];
    for (final String raw in _box.values) {
      final T? decoded = _tryDecode(raw);
      if (decoded != null && !decoded.isDeleted) {
        items.add(decoded);
      }
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  T? byId(String? id) {
    if (id == null) return null;
    final String? raw = _box.get(id);
    if (raw == null) return null;
    final T? decoded = _tryDecode(raw);
    if (decoded == null || decoded.isDeleted) return null;
    return decoded;
  }

  T? _tryDecode(String raw) {
    try {
      final Object? json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return _decoder(json);
      }
      if (json is Map) {
        return _decoder(json.cast<String, dynamic>());
      }
    } catch (_) {
      // 单条数据损坏不应阻塞整个列表渲染。
    }
    return null;
  }

  Future<void> put(T item) async {
    await _box.put(item.id, jsonEncode(item.toJson()));
  }

  Future<void> hardDelete(String id) async {
    await _box.delete(id);
  }

  Future<void> softDelete(String id) async {
    final Map<String, dynamic>? map = _readMap(id);
    if (map == null) return;
    final String now = DateTime.now().toIso8601String();
    map['deletedAt'] = now;
    map['updatedAt'] = now;
    map['syncStatus'] = SyncStatus.pendingDelete.name;
    await _box.put(id, jsonEncode(map));
  }

  Map<String, dynamic>? _readMap(String id) {
    final String? raw = _box.get(id);
    if (raw == null) return null;
    try {
      final Object? json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return json.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    return null;
  }

  int get count => all.length;

  @override
  void dispose() {
    _listenable.removeListener(_handleChanged);
    super.dispose();
  }
}

class VisionRepository extends JsonEntityRepository<Vision> {
  VisionRepository(Box<String> box) : super(box, Vision.fromJson);

  /// 切换栏顺序：显式 sortOrder 优先，其次按创建时间稳定排列。
  static int compareOrder(Vision a, Vision b) {
    if (a.sortOrder != b.sortOrder) {
      return a.sortOrder.compareTo(b.sortOrder);
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  List<Vision> get ordered => all.toList(growable: false)..sort(compareOrder);

  Future<Vision> create({
    required String title,
    String description = '',
    String timeHorizon = '3年',
    String colorHex = '#4A5F7A',
    int? sortOrder,
  }) async {
    final List<Vision> existing = all;
    int maxOrder = -1;
    for (final Vision item in existing) {
      if (item.sortOrder > maxOrder) maxOrder = item.sortOrder;
    }
    final Vision vision = Vision.create(
      title: title.trim(),
      description: description,
      timeHorizon: timeHorizon,
      colorHex: colorHex,
      sortOrder: sortOrder ?? maxOrder + 1,
    );
    await put(vision);
    return vision;
  }

  /// 拖动排序：把愿景移动到目标索引（拖动落点所在项的位置）。
  Future<void> moveTo(String visionId, int targetIndex) async {
    final List<Vision> list = ordered.toList();
    final int from = list.indexWhere((Vision item) => item.id == visionId);
    if (from < 0) return;
    final int to = targetIndex.clamp(0, list.length - 1);
    if (from == to) return;
    final Vision moved = list.removeAt(from);
    list.insert(to, moved);
    for (int i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) {
        await save(list[i].copyWith(sortOrder: i));
      }
    }
  }

  /// 在切换栏中前后移动（delta = -1 前移，+1 后移）。
  Future<void> move(String visionId, int delta) async {
    final List<Vision> list = ordered;
    final int index = list.indexWhere((Vision item) => item.id == visionId);
    final int target = index + delta;
    if (index < 0 || target < 0 || target >= list.length) return;

    for (int i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) {
        await save(list[i].copyWith(sortOrder: i));
      }
    }
    await save(list[index].copyWith(sortOrder: target));
    await save(list[target].copyWith(sortOrder: index));
  }

  Future<void> save(Vision vision) =>
      put(vision.copyWith(syncStatus: SyncStatus.pendingUpdate));
}

class CapabilityRepository extends JsonEntityRepository<Capability> {
  CapabilityRepository(Box<String> box) : super(box, Capability.fromJson);

  List<Capability> forVision(String visionId) => all
      .where((Capability item) => item.visionId == visionId)
      .toList(growable: false);

  Future<Capability> create({
    required String visionId,
    required String title,
    String description = '',
    String targetLevel = '',
  }) async {
    final Capability capability = Capability.create(
      visionId: visionId,
      title: title.trim(),
      description: description,
      targetLevel: targetLevel,
    );
    await put(capability);
    return capability;
  }

  Future<void> save(Capability capability) =>
      put(capability.copyWith(syncStatus: SyncStatus.pendingUpdate));
}

class ActionItemRepository extends JsonEntityRepository<ActionItem> {
  ActionItemRepository(Box<String> box) : super(box, ActionItem.fromJson);

  List<ActionItem> get openItems =>
      all.where((ActionItem item) => item.isOpen).toList(growable: false);

  List<ActionItem> get inboxItems =>
      all.where((ActionItem item) => item.isInbox).toList(growable: false);

  List<ActionItem> get scheduledItems => all
      .where((ActionItem item) => item.status == ActionItemStatus.scheduled)
      .toList(growable: false);

  List<ActionItem> get completedItems =>
      all.where((ActionItem item) => item.isCompleted).toList(growable: false);

  List<ActionItem> forCapability(String capabilityId) => all
      .where((ActionItem item) => item.capabilityId == capabilityId)
      .toList(growable: false);

  List<ActionItem> childrenOf(String parentId) => all
      .where((ActionItem item) => item.parentId == parentId)
      .toList(growable: false);

  Future<ActionItem> create({
    required String title,
    String? capabilityId,
    String? parentId,
    String? projectId,
    String note = '',
    ExecutionMode executionMode = ExecutionMode.standard,
    int? estimatedMinutes,
    ActionItemStatus status = ActionItemStatus.inbox,
    DateTime? dueDate,
    DateTime? scheduledDate,
    String ifThenText = '',
    CognitiveLoad cognitiveLoad = CognitiveLoad.medium,
  }) async {
    final ActionItem item = ActionItem.create(
      title: title.trim(),
      capabilityId: capabilityId,
      parentId: parentId,
      projectId: projectId,
      note: note,
      executionMode: executionMode,
      estimatedMinutes: estimatedMinutes,
      status: status,
      dueDate: dueDate,
      scheduledDate: scheduledDate,
      ifThenText: ifThenText,
      cognitiveLoad: cognitiveLoad,
    );
    await put(item);
    return item;
  }

  Future<void> save(ActionItem item) =>
      put(item.copyWith(syncStatus: SyncStatus.pendingUpdate));

  Future<void> setStatus(String id, ActionItemStatus status) async {
    final ActionItem? item = byId(id);
    if (item == null) return;
    final bool completed = status == ActionItemStatus.completed;
    await save(
      item.copyWith(
        status: status,
        completedAt: completed ? DateTime.now() : null,
        clearCompletedAt: !completed,
      ),
    );
  }

  Future<void> toggleCompleted(String id) async {
    final ActionItem? item = byId(id);
    if (item == null) return;
    await setStatus(
      id,
      item.isCompleted ? ActionItemStatus.inbox : ActionItemStatus.completed,
    );
  }

  Future<void> defer(String id) => setStatus(id, ActionItemStatus.deferred);

  int completedCountFor(String capabilityId) =>
      forCapability(capabilityId)
          .where((ActionItem item) => item.isCompleted)
          .length;
}

class TimeBlockRepository extends JsonEntityRepository<TimeBlock> {
  TimeBlockRepository(Box<String> box) : super(box, TimeBlock.fromJson);

  List<TimeBlock> forDay(DateTime day) {
    final List<TimeBlock> result = all
        .where((TimeBlock block) => AppDate.isSameDay(block.startAt, day))
        .toList();
    result.sort((a, b) => a.startAt.compareTo(b.startAt));
    return result;
  }

  /// 一个任务的全部时间块（按开始时间升序），支持同一任务多次推进。
  List<TimeBlock> blocksForActionItem(String actionItemId) {
    final List<TimeBlock> result =
        all
            .where((TimeBlock block) => block.actionItemId == actionItemId)
            .toList()
          ..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));
    return result;
  }

  /// 任务「当前」时间块：优先未完成且最晚开始的块，否则取最后一个。
  TimeBlock? forActionItem(String actionItemId) {
    final List<TimeBlock> blocks = blocksForActionItem(actionItemId);
    if (blocks.isEmpty) return null;
    final List<TimeBlock> unfinished = blocks
        .where((TimeBlock block) => !block.isCompleted)
        .toList();
    return unfinished.isEmpty ? blocks.last : unfinished.last;
  }

  TimeBlock? forReview(String reviewId) {
    for (final TimeBlock block in all) {
      if (block.learningReviewId == reviewId) return block;
    }
    return null;
  }

  Future<TimeBlock> schedule({
    required String title,
    required DateTime startAt,
    required int durationMinutes,
    String? actionItemId,
    String? learningReviewId,
    String? routineId,
  }) async {
    final TimeBlock block = TimeBlock.create(
      startAt: startAt,
      endAt: startAt.add(Duration(minutes: durationMinutes)),
      title: title,
      actionItemId: actionItemId,
      learningReviewId: learningReviewId,
      routineId: routineId,
    );
    await put(block);
    return block;
  }

  Future<void> save(TimeBlock block) =>
      put(block.copyWith(syncStatus: SyncStatus.pendingUpdate));

  Future<void> setCompleted(String id, bool completed) async {
    final TimeBlock? block = byId(id);
    if (block == null) return;
    await save(
      block.copyWith(
        isCompleted: completed,
        actualMinutes: completed ? block.plannedMinutes : null,
        clearActualMinutes: !completed,
      ),
    );
  }
}

class LearningSessionRepository extends JsonEntityRepository<LearningSession> {
  LearningSessionRepository(Box<String> box)
    : super(box, LearningSession.fromJson);

  List<LearningSession> forActionItem(String actionItemId) => all
      .where((LearningSession session) => session.actionItemId == actionItemId)
      .toList(growable: false);

  LearningSession? inProgressFor(String actionItemId) {
    for (final LearningSession session in all) {
      if (session.actionItemId == actionItemId && !session.isFinished) {
        return session;
      }
    }
    return null;
  }

  List<LearningSession> get inProgress => all
      .where((LearningSession session) => !session.isFinished)
      .toList(growable: false);

  List<LearningSession> get finished => all
      .where((LearningSession session) => session.isFinished)
      .toList(growable: false);

  /// 为任务开启一次新会话；已有未完成会话时直接复用。
  Future<LearningSession> startFor(
    ActionItem item, {
    LearningType type = LearningType.declarative,
    LearningMode mode = LearningMode.full,
    LearningDraft? draft,
  }) async {
    final LearningSession? existing = inProgressFor(item.id);
    if (existing != null) return existing;

    final LearningDraft next = draft ?? LearningDraft.initial(type, mode: mode);
    final LearningSession session = LearningSession.create(
      actionItemId: item.id,
      learningType: type,
      mode: mode,
    ).copyWith(stepsDataJson: next.encode());
    await put(session);
    return session;
  }

  /// 开启一次「不配对任务」的学习；actionItemId 使用合成 id，
  /// 仅用于复习节点与时间块关联，不进入任务池。
  Future<LearningSession> startStandalone({
    required String title,
    LearningType type = LearningType.declarative,
    LearningMode mode = LearningMode.full,
    LearningDraft? draft,
  }) async {
    final LearningDraft next = draft ?? LearningDraft.initial(type, mode: mode);
    final String syntheticId =
        'standalone-${DateTime.now().microsecondsSinceEpoch}';
    final LearningSession session = LearningSession.create(
      actionItemId: syntheticId,
      title: title.trim().isEmpty ? '独立学习' : title.trim(),
      learningType: type,
      mode: mode,
    ).copyWith(stepsDataJson: next.encode());
    await put(session);
    return session;
  }

  Future<void> finish(LearningSession session, {LearningMode? mode}) async {
    await put(
      session.copyWith(
        isFinished: true,
        completedAt: DateTime.now(),
        mode: mode ?? session.mode,
        syncStatus: SyncStatus.pendingUpdate,
      ),
    );
  }
}

class LearningReviewRepository extends JsonEntityRepository<LearningReview> {
  LearningReviewRepository(Box<String> box)
    : super(box, LearningReview.fromJson);

  Future<void> save(LearningReview review) =>
      put(review.copyWith(syncStatus: SyncStatus.pendingUpdate));

  List<LearningReview> get pending => all
      .where((LearningReview review) => !review.isDone)
      .toList(growable: false);

  List<LearningReview> dueBy(DateTime day) {
    final DateTime limit = AppDate.endOfDay(day);
    final List<LearningReview> result = all
        .where(
          (LearningReview review) =>
              !review.isDone && !review.dueDate.isAfter(limit),
        )
        .toList();
    result.sort(
      (LearningReview a, LearningReview b) => a.dueDate.compareTo(b.dueDate),
    );
    return result;
  }

  List<LearningReview> forSession(String sessionId) => all
      .where((LearningReview review) => review.sessionId == sessionId)
      .toList(growable: false);

  List<LearningReview> forActionItem(String actionItemId) => all
      .where((LearningReview review) => review.actionItemId == actionItemId)
      .toList(growable: false);

  int get pendingCount => pending.length;

  /// 完成一次学习后，按类型间隔批量生成复习提醒。
  Future<List<LearningReview>> scheduleFor({
    required String sessionId,
    required String actionItemId,
    required LearningType type,
    DateTime? base,
  }) async {
    final DateTime start = AppDate.startOfDay(base ?? DateTime.now());
    final List<LearningReview> created = <LearningReview>[];
    for (final int days in intervalsOf(type)) {
      final LearningReview review = LearningReview.create(
        sessionId: sessionId,
        actionItemId: actionItemId,
        dueDate: start.add(Duration(days: days)),
        intervalDays: days,
      );
      await put(review);
      created.add(review);
    }
    return created;
  }

  /// 记录本次主动回忆结果，并按结果生成下一次提醒。
  Future<LearningReview> completeReview(
    LearningReview review,
    ReviewOutcome outcome, {
    DateTime? base,
  }) async {
    final DateTime now = DateTime.now();
    await put(
      review.copyWith(
        isDone: true,
        outcome: outcome,
        doneAt: now,
        syncStatus: SyncStatus.pendingUpdate,
      ),
    );

    final int nextDays = nextIntervalDays(review.intervalDays, outcome);
    final LearningReview next = LearningReview.create(
      sessionId: review.sessionId,
      actionItemId: review.actionItemId,
      dueDate: AppDate.startOfDay(base ?? now).add(Duration(days: nextDays)),
      intervalDays: nextDays,
    );
    await put(next);
    return next;
  }
}

class WeeklyRoutineRepository extends JsonEntityRepository<WeeklyRoutine> {
  WeeklyRoutineRepository(Box<String> box) : super(box, WeeklyRoutine.fromJson);

  List<WeeklyRoutine> get active => all
      .where((WeeklyRoutine routine) => routine.isActive)
      .toList(growable: false);

  List<WeeklyRoutine> forWeekday(int weekday) => all
      .where((WeeklyRoutine routine) => routine.weekday == weekday)
      .toList(growable: false);

  Future<WeeklyRoutine> create({
    required String title,
    required int weekday,
    required int startMinutes,
    required int durationMinutes,
    RoutineKind kind = RoutineKind.fixedRoutine,
    String? actionItemId,
    int colorIndex = 0,
  }) async {
    final WeeklyRoutine routine = WeeklyRoutine.create(
      title: title,
      weekday: weekday,
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      kind: kind,
      actionItemId: actionItemId,
      colorIndex: colorIndex,
    );
    await put(routine);
    return routine;
  }

  Future<void> save(WeeklyRoutine routine) =>
      put(routine.copyWith(syncStatus: SyncStatus.pendingUpdate));
}

class RoutineExceptionRepository
    extends JsonEntityRepository<RoutineException> {
  RoutineExceptionRepository(Box<String> box)
    : super(box, RoutineException.fromJson);

  bool isSkipped(String routineId, String dateKey) {
    for (final RoutineException exception in all) {
      if (exception.routineId == routineId &&
          exception.dateKey == dateKey &&
          exception.isSkipped) {
        return true;
      }
    }
    return false;
  }

  List<RoutineException> forRoutine(String routineId) => all
      .where((RoutineException exception) => exception.routineId == routineId)
      .toList(growable: false);

  Future<void> addSkip(String routineId, String dateKey) async {
    if (isSkipped(routineId, dateKey)) return;
    await put(
      RoutineException.createSkip(routineId: routineId, dateKey: dateKey),
    );
  }

  Future<void> removeSkip(String routineId, String dateKey) async {
    for (final RoutineException exception in forRoutine(routineId)) {
      if (exception.dateKey == dateKey) {
        await softDelete(exception.id);
      }
    }
  }
}

class CountdownRepository extends JsonEntityRepository<Countdown> {
  CountdownRepository(Box<String> box) : super(box, Countdown.fromJson);

  List<Countdown> sorted() {
    final List<Countdown> items = all.toList();
    items.sort((Countdown a, Countdown b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
    });
    return items;
  }

  Future<Countdown> create({
    required String title,
    DateTime? targetAt,
    String? sourceTaskId,
    bool autoHideExpired = false,
    bool dateOnly = false,
    String? colorHex,
  }) async {
    int nextOrder = 0;
    for (final Countdown item in all) {
      if (item.sortOrder >= nextOrder) nextOrder = item.sortOrder + 1;
    }
    final Countdown item = Countdown.create(
      title: title,
      targetAt: targetAt,
      sourceTaskId: sourceTaskId,
      autoHideExpired: autoHideExpired,
      dateOnly: dateOnly,
      colorHex: colorHex,
      sortOrder: nextOrder,
    );
    await put(item);
    return item;
  }

  Future<void> save(Countdown item) =>
      put(item.copyWith(syncStatus: SyncStatus.pendingUpdate));

  Future<void> remove(Countdown item) => softDelete(item.id);

  Future<void> reorder(List<Countdown> items) async {
    for (int i = 0; i < items.length; i++) {
      final Countdown item = items[i];
      if (item.sortOrder == i) continue;
      await put(
        item.copyWith(sortOrder: i, syncStatus: SyncStatus.pendingUpdate),
      );
    }
  }
}

class ProjectRepository extends JsonEntityRepository<Project> {
  ProjectRepository(Box<String> box) : super(box, Project.fromJson);

  List<Project> byStatus(ProjectStatus status) => all
      .where((Project item) => item.status == status)
      .toList(growable: false);

  List<Project> forCapability(String capabilityId) => all
      .where((Project item) => item.capabilityIds.contains(capabilityId))
      .toList(growable: false);

  Future<Project> create({
    required String title,
    String goal = '',
    ProjectStatus status = ProjectStatus.active,
    List<String> capabilityIds = const <String>[],
    List<ProjectStage> stages = const <ProjectStage>[],
    String acceptance = '',
    String artifactUrl = '',
    String note = '',
  }) async {
    final Project project = Project.create(
      title: title,
      goal: goal,
      status: status,
      capabilityIds: capabilityIds,
      stages: stages,
      acceptance: acceptance,
      artifactUrl: artifactUrl,
      note: note,
    );
    await put(project);
    return project;
  }

  Future<void> save(Project project) =>
      put(project.copyWith(syncStatus: SyncStatus.pendingUpdate));
}

class ArtifactRepository extends JsonEntityRepository<Artifact> {
  ArtifactRepository(Box<String> box) : super(box, Artifact.fromJson);

  List<Artifact> forCapability(String capabilityId) => all
      .where((Artifact item) => item.capabilityId == capabilityId)
      .toList(growable: false);

  List<Artifact> forActionItem(String actionItemId) => all
      .where((Artifact item) => item.actionItemId == actionItemId)
      .toList(growable: false);

  Future<Artifact> create({
    required String title,
    ArtifactType type = ArtifactType.explanation,
    String? capabilityId,
    String? actionItemId,
    String? sessionId,
    String url = '',
    String note = '',
  }) async {
    final Artifact artifact = Artifact.create(
      title: title,
      type: type,
      capabilityId: capabilityId,
      actionItemId: actionItemId,
      sessionId: sessionId,
      url: url,
      note: note,
    );
    await put(artifact);
    return artifact;
  }

  Future<void> save(Artifact artifact) =>
      put(artifact.copyWith(syncStatus: SyncStatus.pendingUpdate));
}

class ReviewLogRepository extends JsonEntityRepository<ReviewLog> {
  ReviewLogRepository(Box<String> box) : super(box, ReviewLog.fromJson);

  Future<void> save(ReviewLog log) =>
      put(log.copyWith(syncStatus: SyncStatus.pendingUpdate));

  ReviewLog? forPeriod(ReviewPeriodType type, String periodKey) {
    for (final ReviewLog log in all) {
      if (log.periodType == type && log.periodKey == periodKey) return log;
    }
    return null;
  }

  bool hasMonthly(String periodKey) =>
      forPeriod(ReviewPeriodType.monthly, periodKey) != null;

  Set<int> reviewedMonthsOf(int year) {
    final Set<int> months = <int>{};
    for (final ReviewLog log in all) {
      if (log.periodType != ReviewPeriodType.monthly) continue;
      final List<String> parts = log.periodKey.split('-');
      if (parts.length < 2) continue;
      final int? logYear = int.tryParse(parts[0]);
      final int? logMonth = int.tryParse(parts[1]);
      if (logYear == year && logMonth != null) months.add(logMonth);
    }
    return months;
  }
}

class FoggHabitRepository extends JsonEntityRepository<FoggHabit> {
  FoggHabitRepository(Box<String> box) : super(box, FoggHabit.fromJson);

  List<FoggHabit> get active =>
      all.where((FoggHabit habit) => habit.isActive).toList(growable: false);

  FoggHabit? forActionItem(String actionItemId) {
    for (final FoggHabit habit in all) {
      if (habit.linkedActionItemId == actionItemId) return habit;
    }
    return null;
  }

  FoggHabit? forCapability(String capabilityId) {
    for (final FoggHabit habit in all) {
      if (habit.linkedCapabilityId == capabilityId) return habit;
    }
    return null;
  }

  Future<FoggHabit> create({
    required String anchorPrompt,
    required String tinyBehavior,
    String? linkedCapabilityId,
    String? linkedActionItemId,
    AnchorPeriod anchorPeriod = AnchorPeriod.anytime,
    String celebration = '握拳，默念：我做到了',
    FrictionProfile frictions = const FrictionProfile(),
    String abilityFrictionTip = '',
    String motivationNote = '',
  }) async {
    final FoggHabit habit = FoggHabit.create(
      anchorPrompt: anchorPrompt,
      tinyBehavior: tinyBehavior,
      linkedCapabilityId: linkedCapabilityId,
      linkedActionItemId: linkedActionItemId,
      anchorPeriod: anchorPeriod,
      celebration: celebration,
      frictions: frictions,
      abilityFrictionTip: abilityFrictionTip,
      motivationNote: motivationNote,
    );
    await put(habit);
    return habit;
  }

  Future<void> save(FoggHabit habit) =>
      put(habit.copyWith(syncStatus: SyncStatus.pendingUpdate));
}

class HabitLogRepository extends JsonEntityRepository<HabitLog> {
  HabitLogRepository(Box<String> box) : super(box, HabitLog.fromJson);

  List<HabitLog> forHabit(String habitId) => all
      .where((HabitLog log) => log.habitId == habitId)
      .toList(growable: false);

  HabitLog? forDay(String habitId, String dateKey) {
    for (final HabitLog log in all) {
      if (log.habitId == habitId && log.dateKey == dateKey) return log;
    }
    return null;
  }

  Set<String> completedDates(String habitId) =>
      forHabit(habitId)
          .where((HabitLog log) => log.isCompleted)
          .map((HabitLog log) => log.dateKey)
          .toSet();

  Future<HabitLog> logDay(
    String habitId,
    String dateKey, {
    bool isExtra = false,
  }) async {
    final HabitLog? existing = forDay(habitId, dateKey);
    if (existing != null) {
      final HabitLog updated = existing.copyWith(
        isCompleted: true,
        isExtra: isExtra || existing.isExtra,
        syncStatus: SyncStatus.pendingUpdate,
      );
      await put(updated);
      return updated;
    }
    final HabitLog log = HabitLog.create(
      habitId: habitId,
      dateKey: dateKey,
      isExtra: isExtra,
    );
    await put(log);
    return log;
  }

  Future<void> removeDay(String habitId, String dateKey) async {
    final HabitLog? existing = forDay(habitId, dateKey);
    if (existing == null) return;
    await softDelete(existing.id);
  }

  /// 温和连续天数：今天未打卡时从昨天往前算，不显示「断签」。
  int streak(String habitId, {DateTime? now}) {
    final Set<String> dates = completedDates(habitId);
    DateTime cursor = AppDate.startOfDay(now ?? DateTime.now());
    if (!dates.contains(AppDate.dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    int count = 0;
    while (dates.contains(AppDate.dateKey(cursor))) {
      count += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class BehaviorCandidateRepository
    extends JsonEntityRepository<BehaviorCandidate> {
  BehaviorCandidateRepository(Box<String> box)
    : super(box, BehaviorCandidate.fromJson);

  List<BehaviorCandidate> get selected => all
      .where((BehaviorCandidate candidate) => candidate.isSelected)
      .toList(growable: false);

  List<BehaviorCandidate> get golden => all
      .where((BehaviorCandidate candidate) => candidate.isGolden)
      .toList(growable: false);

  Future<BehaviorCandidate> add({
    required String title,
    int impact = 3,
    int effort = 3,
  }) async {
    final BehaviorCandidate candidate = BehaviorCandidate.create(
      title: title,
      impact: impact,
      effort: effort,
    );
    await put(candidate);
    return candidate;
  }

  Future<void> save(BehaviorCandidate candidate) =>
      put(candidate.copyWith(syncStatus: SyncStatus.pendingUpdate));
}

class HabitRecipeVersionRepository
    extends JsonEntityRepository<HabitRecipeVersion> {
  HabitRecipeVersionRepository(Box<String> box)
    : super(box, HabitRecipeVersion.fromJson);

  List<HabitRecipeVersion> forHabit(String habitId) {
    final List<HabitRecipeVersion> versions = all
        .where((HabitRecipeVersion version) => version.habitId == habitId)
        .toList();
    versions.sort(
      (HabitRecipeVersion a, HabitRecipeVersion b) =>
          b.revision.compareTo(a.revision),
    );
    return versions;
  }

  int nextRevision(String habitId) {
    int max = 0;
    for (final HabitRecipeVersion version in forHabit(habitId)) {
      if (version.revision > max) max = version.revision;
    }
    return max + 1;
  }

  Future<HabitRecipeVersion> add({
    required String habitId,
    required String anchorPrompt,
    required String tinyBehavior,
    required String celebration,
    String frictionsJson = '{}',
    String note = '',
    int completedIn7Days = 0,
  }) async {
    final HabitRecipeVersion version = HabitRecipeVersion.create(
      habitId: habitId,
      revision: nextRevision(habitId),
      anchorPrompt: anchorPrompt,
      tinyBehavior: tinyBehavior,
      celebration: celebration,
      frictionsJson: frictionsJson,
      note: note,
      completedIn7Days: completedIn7Days,
    );
    await put(version);
    return version;
  }
}
