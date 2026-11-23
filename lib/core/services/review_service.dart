import 'dart:convert';

import '../database/repositories.dart';
import '../models/models.dart';
import '../utils/date_utils.dart';
import 'schedule_service.dart';

/// 一次复盘的周期窗口（日 / 周 / 月 / 年）。
class ReviewWindow {
  const ReviewWindow({
    required this.type,
    required this.anchor,
    required this.start,
    required this.end,
  });

  final ReviewPeriodType type;
  final DateTime anchor;
  final DateTime start;
  final DateTime end;

  factory ReviewWindow.of(ReviewPeriodType type, DateTime anchor) {
    switch (type) {
      case ReviewPeriodType.daily:
        final DateTime start = AppDate.startOfDay(anchor);
        return ReviewWindow(
          type: type,
          anchor: anchor,
          start: start,
          end: start.add(const Duration(days: 1)),
        );
      case ReviewPeriodType.weekly:
        final DateTime start = AppDate.startOfWeek(anchor);
        return ReviewWindow(
          type: type,
          anchor: anchor,
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case ReviewPeriodType.monthly:
        final DateTime start = DateTime(anchor.year, anchor.month);
        return ReviewWindow(
          type: type,
          anchor: anchor,
          start: start,
          end: DateTime(anchor.year, anchor.month + 1),
        );
      case ReviewPeriodType.yearly:
        final DateTime start = DateTime(anchor.year);
        return ReviewWindow(
          type: type,
          anchor: anchor,
          start: start,
          end: DateTime(anchor.year + 1),
        );
    }
  }

  int get days {
    final int value = end.difference(start).inDays;
    return value < 1 ? 1 : value;
  }

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(end);

  /// 依当前周期类型前后平移。
  DateTime shifted(int direction) {
    switch (type) {
      case ReviewPeriodType.daily:
        return anchor.add(Duration(days: direction));
      case ReviewPeriodType.weekly:
        return anchor.add(Duration(days: 7 * direction));
      case ReviewPeriodType.monthly:
        return DateTime(anchor.year, anchor.month + direction);
      case ReviewPeriodType.yearly:
        return DateTime(anchor.year + direction);
    }
  }

  String get periodKey {
    switch (type) {
      case ReviewPeriodType.daily:
        return AppDate.dateKey(start);
      case ReviewPeriodType.weekly:
        final int week = _isoWeekNumber(start);
        return '${_isoYear(start)}-W${week.toString().padLeft(2, '0')}';
      case ReviewPeriodType.monthly:
        return '${start.year}-${AppDate.two(start.month)}';
      case ReviewPeriodType.yearly:
        return '${start.year}';
    }
  }

  String get label {
    switch (type) {
      case ReviewPeriodType.daily:
        return AppDate.monthDayWithWeekday(start);
      case ReviewPeriodType.weekly:
        return '${_isoYear(start)} 年第 ${_isoWeekNumber(start)} 周';
      case ReviewPeriodType.monthly:
        return '${start.year} 年 ${start.month} 月';
      case ReviewPeriodType.yearly:
        return '${start.year} 年';
    }
  }
}

int _isoYear(DateTime date) =>
    date.add(Duration(days: 4 - date.weekday)).year;

int _isoWeekNumber(DateTime date) {
  final DateTime thursday = date.add(Duration(days: 4 - date.weekday));
  final DateTime jan4 = DateTime(thursday.year, 1, 4);
  final DateTime firstThursday =
      jan4.add(Duration(days: 4 - jan4.weekday));
  return 1 + (thursday.difference(firstThursday).inDays / 7).floor();
}

/// 能力投入切片：用于周/月复盘的精力分布条。
class CapabilitySlice {
  const CapabilitySlice({
    required this.title,
    required this.minutes,
    required this.capabilityId,
  });

  final String title;
  final int minutes;
  final String? capabilityId;
}

/// 复盘客观数据快照（全部来自现有模块，不新增录入）。
class ReviewSnapshot {
  const ReviewSnapshot({
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.blockCount,
    required this.completedBlockCount,
    required this.completedTasks,
    required this.consolidatingTasks,
    required this.outputs,
    required this.reviewsDue,
    required this.reviewsDone,
    required this.reviewsOverdue,
    required this.habitRate,
    required this.habitChecks,
    required this.habitTarget,
    required this.habitRates,
    required this.capabilitySlices,
    required this.unfinishedBlocks,
    required this.overdueReviews,
    required this.lowHabits,
    required this.staleTasks,
  });

  final int plannedMinutes;
  final int completedMinutes;
  final int blockCount;
  final int completedBlockCount;
  final int completedTasks;
  final int consolidatingTasks;
  final int outputs;
  final int reviewsDue;
  final int reviewsDone;
  final int reviewsOverdue;
  final double habitRate;
  final int habitChecks;
  final int habitTarget;
  final Map<String, double> habitRates;
  final List<CapabilitySlice> capabilitySlices;
  final List<TimeBlock> unfinishedBlocks;
  final List<LearningReview> overdueReviews;
  final List<FoggHabit> lowHabits;
  final List<ActionItem> staleTasks;

  double get plannedHours => plannedMinutes / 60;

  double get completedHours => completedMinutes / 60;

  double get blockRate =>
      blockCount == 0 ? 0 : completedBlockCount / blockCount;

  int get habitPercent => (habitRate * 100).round();

  int get capacityMinutes =>
      capabilitySlices.fold(0, (int sum, CapabilitySlice item) => sum + item.minutes);
}

/// 待校准事项类别。
enum ReviewItemKind { unfinishedBlock, overdueReview, lowHabit, staleTask }

/// 一条待校准事项：右侧直接配一个动作，处理完可划掉。
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.block,
    this.review,
    this.habit,
    this.task,
  });

  final String id;
  final ReviewItemKind kind;
  final String title;
  final String subtitle;
  final TimeBlock? block;
  final LearningReview? review;
  final FoggHabit? habit;
  final ActionItem? task;
}

/// 及时复盘服务：聚合四大模块数据，并把结论向下传导为真实动作。
class ReviewService {
  ReviewService({
    required this.logs,
    required this.actions,
    required this.blocks,
    required this.capabilities,
    required this.sessions,
    required this.learningReviews,
    required this.habits,
    required this.habitLogs,
    required this.schedules,
  });

  final ReviewLogRepository logs;
  final ActionItemRepository actions;
  final TimeBlockRepository blocks;
  final CapabilityRepository capabilities;
  final LearningSessionRepository sessions;
  final LearningReviewRepository learningReviews;
  final FoggHabitRepository habits;
  final HabitLogRepository habitLogs;
  final ScheduleService schedules;

  /// 汇总当前周期客观数据。
  ReviewSnapshot snapshot(ReviewWindow window) {
    final List<TimeBlock> windowBlocks = blocks.all
        .where((TimeBlock block) => window.contains(block.startAt))
        .toList(growable: false);

    int plannedMinutes = 0;
    int completedMinutes = 0;
    for (final TimeBlock block in windowBlocks) {
      plannedMinutes += block.plannedMinutes;
      if (block.isCompleted) completedMinutes += block.plannedMinutes;
    }
    final List<TimeBlock> unfinishedBlocks = windowBlocks
        .where((TimeBlock block) => !block.isCompleted)
        .toList()
      ..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));

    final List<ActionItem> items = actions.all;
    int completedTasks = 0;
    int consolidatingTasks = 0;
    for (final ActionItem item in items) {
      if (item.status == ActionItemStatus.consolidating) consolidatingTasks++;
      if (!item.isCompleted) continue;
      final DateTime doneAt = item.completedAt ?? item.updatedAt;
      if (window.contains(doneAt)) completedTasks++;
    }

    int outputs = 0;
    for (final LearningSession session in sessions.all) {
      final DateTime? finishedAt = session.completedAt;
      if (session.isFinished && finishedAt != null && window.contains(finishedAt)) {
        outputs++;
      }
    }

    int reviewsDue = 0;
    int reviewsDone = 0;
    final List<LearningReview> overdueReviews = <LearningReview>[];
    final DateTime now = DateTime.now();
    for (final LearningReview review in learningReviews.all) {
      if (window.contains(review.dueDate)) reviewsDue++;
      final DateTime? doneAt = review.doneAt;
      if (review.isDone && doneAt != null && window.contains(doneAt)) {
        reviewsDone++;
      }
      if (!review.isDone &&
          review.dueDate.isBefore(now) &&
          window.contains(review.dueDate)) {
        overdueReviews.add(review);
      }
    }
    overdueReviews.sort(
      (LearningReview a, LearningReview b) => a.dueDate.compareTo(b.dueDate),
    );

    final List<FoggHabit> activeHabits = habits.active;
    final Set<String> habitIds =
        activeHabits.map((FoggHabit habit) => habit.id).toSet();
    final Set<String> dayKeys = <String>{
      for (int i = 0; i < window.days; i++)
        AppDate.dateKey(window.start.add(Duration(days: i))),
    };
    final Map<String, int> checksByHabit = <String, int>{};
    int habitChecks = 0;
    for (final HabitLog log in habitLogs.all) {
      if (!log.isCompleted || !habitIds.contains(log.habitId)) continue;
      if (!dayKeys.contains(log.dateKey)) continue;
      checksByHabit[log.habitId] = (checksByHabit[log.habitId] ?? 0) + 1;
      habitChecks++;
    }
    final int habitTarget = activeHabits.length * window.days;
    final double habitRate =
        habitTarget == 0 ? 0 : habitChecks / habitTarget;
    final Map<String, double> habitRates = <String, double>{
      for (final FoggHabit habit in activeHabits)
        habit.id: (checksByHabit[habit.id] ?? 0) / window.days,
    };
    final List<FoggHabit> lowHabits = window.days >= 3
        ? activeHabits
            .where((FoggHabit habit) => (habitRates[habit.id] ?? 0) < 0.4)
            .toList(growable: false)
        : const <FoggHabit>[];

    final Map<String, (String, int)> byCapability =
        <String, (String, int)>{};
    for (final TimeBlock block in windowBlocks) {
      final String? capabilityId = block.actionItemId == null
          ? null
          : actions.byId(block.actionItemId!)?.capabilityId;
      final String title = capabilityId == null
          ? '未归类'
          : (capabilities.byId(capabilityId)?.title ?? '未归类');
      final String key = capabilityId ?? 'none';
      final (String, int) current = byCapability[key] ?? (title, 0);
      byCapability[key] = (title, current.$2 + block.plannedMinutes);
    }
    final List<CapabilitySlice> slices = <CapabilitySlice>[
      for (final MapEntry<String, (String, int)> entry
          in byCapability.entries)
        CapabilitySlice(
          title: entry.value.$1,
          minutes: entry.value.$2,
          capabilityId: entry.key == 'none' ? null : entry.key,
        ),
    ]..sort((CapabilitySlice a, CapabilitySlice b) => b.minutes.compareTo(a.minutes));

    final List<ActionItem> staleTasks = items
        .where((ActionItem item) =>
            item.status == ActionItemStatus.inbox &&
            item.createdAt.isBefore(window.start))
        .toList(growable: false);

    return ReviewSnapshot(
      plannedMinutes: plannedMinutes,
      completedMinutes: completedMinutes,
      blockCount: windowBlocks.length,
      completedBlockCount:
          windowBlocks.where((TimeBlock block) => block.isCompleted).length,
      completedTasks: completedTasks,
      consolidatingTasks: consolidatingTasks,
      outputs: outputs,
      reviewsDue: reviewsDue,
      reviewsDone: reviewsDone,
      reviewsOverdue: overdueReviews.length,
      habitRate: habitRate,
      habitChecks: habitChecks,
      habitTarget: habitTarget,
      habitRates: habitRates,
      capabilitySlices: slices,
      unfinishedBlocks: unfinishedBlocks,
      overdueReviews: overdueReviews,
      lowHabits: lowHabits,
      staleTasks: staleTasks,
    );
  }

  /// 生成待校准事项：未完成时间块 / 逾期复习 / 低迷习惯 / 僵滞任务池。
  List<ReviewItem> pending(ReviewWindow window, ReviewSnapshot snapshot) {
    final List<ReviewItem> items = <ReviewItem>[];
    final DateTime now = DateTime.now();

    for (final TimeBlock block in snapshot.unfinishedBlocks) {
      items.add(
        ReviewItem(
          id: 'block:${block.id}',
          kind: ReviewItemKind.unfinishedBlock,
          title: block.title.isEmpty ? '未命名时间块' : block.title,
          subtitle:
              '${AppDate.dateKey(block.startAt)} · ${AppDate.timeRangeLabel(block.startAt, block.endAt)}',
          block: block,
          task: block.actionItemId == null
              ? null
              : actions.byId(block.actionItemId!),
        ),
      );
      if (items.length >= 6) break;
    }

    for (final LearningReview review in snapshot.overdueReviews) {
      final ActionItem? task = actions.byId(review.actionItemId);
      final int overdueDays =
          now.difference(review.dueDate).inDays.clamp(0, 999);
      items.add(
        ReviewItem(
          id: 'review:${review.id}',
          kind: ReviewItemKind.overdueReview,
          title: '复习：${task?.title ?? '学习任务'}',
          subtitle: '逾期 $overdueDays 天 · 第 ${review.intervalDays} 天节点',
          review: review,
          task: task,
        ),
      );
      if (items.length >= 10) break;
    }

    for (final FoggHabit habit in snapshot.lowHabits) {
      final int percent = ((snapshot.habitRates[habit.id] ?? 0) * 100).round();
      items.add(
        ReviewItem(
          id: 'habit:${habit.id}',
          kind: ReviewItemKind.lowHabit,
          title: habit.tinyBehavior,
          subtitle: '本期节律偏低 · 完成率 $percent%',
          habit: habit,
        ),
      );
    }

    for (final ActionItem task in snapshot.staleTasks.take(2)) {
      items.add(
        ReviewItem(
          id: 'task:${task.id}',
          kind: ReviewItemKind.staleTask,
          title: task.title,
          subtitle: '停在任务池 · ${AppDate.monthDayLabel(task.createdAt)} 创建',
          task: task,
        ),
      );
    }

    return items;
  }

  /// 未完成时间块顺延到指定日期（默认明日）。
  Future<void> pushBlockToDay(TimeBlock block, {DateTime? day}) async {
    final DateTime target =
        AppDate.startOfDay(day ?? DateTime.now().add(const Duration(days: 1)));
    final DateTime start = DateTime(
      target.year,
      target.month,
      target.day,
      block.startAt.hour,
      block.startAt.minute,
    );
    await blocks.save(
      block.copyWith(
        startAt: start,
        endAt: start.add(Duration(minutes: block.plannedMinutes)),
      ),
    );
  }

  /// 拆小：缩短预估与时间块，并生成一个子任务。
  Future<void> shrinkTask(ActionItem task) async {
    final int minutes = (task.estimatedMinutes ?? 30).clamp(10, 240);
    final int half = (minutes / 2).round().clamp(5, minutes);
    final TimeBlock? block = blocks.forActionItem(task.id);
    if (block != null) {
      await blocks.save(
        block.copyWith(endAt: block.startAt.add(Duration(minutes: half))),
      );
    }
    await actions.save(task.copyWith(estimatedMinutes: half));
    await actions.create(
      title: '${task.title}（拆小版）',
      capabilityId: task.capabilityId,
      parentId: task.id,
      estimatedMinutes: half,
      note: '复盘时拆小：先完成 $half 分钟的启动版本。',
    );
  }

  /// 暂存回任务池（解除排期）。
  Future<void> returnToInbox(ActionItem task) => schedules.unschedule(task.id);

  /// 未完成块回到任务池（无关联任务则删除块）。
  Future<void> returnBlockToInbox(TimeBlock block) async {
    final String? actionItemId = block.actionItemId;
    if (actionItemId == null) {
      await blocks.softDelete(block.id);
      return;
    }
    await schedules.unschedule(actionItemId);
  }

  /// 取消时间块：块移除，关联任务标记为已延后。
  Future<void> cancelBlock(TimeBlock block) async {
    await blocks.softDelete(block.id);
    final String? actionItemId = block.actionItemId;
    if (actionItemId != null) {
      await actions.setStatus(actionItemId, ActionItemStatus.deferred);
    }
  }

  /// 归档 / 暂停低价值任务。
  Future<void> archiveTask(ActionItem task) =>
      actions.setStatus(task.id, ActionItemStatus.deferred);

  /// 逾期复习顺延到明日 20:00。
  Future<void> postponeReview(LearningReview review, {DateTime? day}) async {
    final DateTime target =
        AppDate.startOfDay(day ?? DateTime.now().add(const Duration(days: 1)));
    await learningReviews.save(
      review.copyWith(
        dueDate: DateTime(target.year, target.month, target.day, 20),
        intervalDays: review.intervalDays,
      ),
    );
  }

  /// 把当前快照压缩成可持久化的统计。
  Map<String, dynamic> snapshotStats(ReviewWindow window) {
    final ReviewSnapshot data = snapshot(window);
    return <String, dynamic>{
      'plannedMinutes': data.plannedMinutes,
      'completedMinutes': data.completedMinutes,
      'completedTasks': data.completedTasks,
      'outputs': data.outputs,
      'habitRate': data.habitRate,
      'reviewsOverdue': data.reviewsOverdue,
      'blocks': data.blockCount,
      'completedBlocks': data.completedBlockCount,
    };
  }

  /// 保存复盘文本（自动保存草稿与完成标记共用）。
  Future<ReviewLog> saveEntry(
    ReviewWindow window, {
    String? wins,
    String? blockers,
    String? adjustments,
    String? focus,
    String? ifThen,
    bool? isCompleted,
    Set<String>? handled,
    Map<String, dynamic>? stats,
  }) async {
    final ReviewLog log = logs.forPeriod(window.type, window.periodKey) ??
        ReviewLog.create(
          periodType: window.type,
          periodKey: window.periodKey,
        );
    final ReviewLog next = log.copyWith(
      winsText: wins,
      blockersText: blockers,
      adjustmentsText: adjustments,
      focusText: focus,
      ifThenText: ifThen,
      isCompleted: isCompleted,
      handledItemsJson:
          handled == null ? null : jsonEncode(handled.toList()),
      snapshotStatsJson: stats == null ? null : jsonEncode(stats),
    );
    await logs.save(next);
    return next;
  }

  /// 已处理事项划掉。
  Future<void> markHandled(ReviewWindow window, String itemId) async {
    final ReviewLog log = logs.forPeriod(window.type, window.periodKey) ??
        ReviewLog.create(
          periodType: window.type,
          periodKey: window.periodKey,
        );
    final Set<String> handled = log.handledItems.toSet()..add(itemId);
    await logs.save(
      log.copyWith(
        handledItemsJson: jsonEncode(handled.toList()),
        snapshotStatsJson: jsonEncode(snapshotStats(window)),
      ),
    );
  }
}

/// 与 ScheduleService 解耦的最小接口，便于测试替身与模块独立。
abstract class ScheduleServiceLike {
  Future<void> unschedule(String actionItemId);
}