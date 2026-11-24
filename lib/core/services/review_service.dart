import 'dart:async';
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
enum ReviewItemKind {
  unfinishedBlock,
  overdueReview,
  lowHabit,
  staleTask,
  learningBlindSpot,
}

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
    this.blindSpot,
  });

  final String id;
  final ReviewItemKind kind;
  final String title;
  final String subtitle;
  final TimeBlock? block;
  final LearningReview? review;
  final FoggHabit? habit;
  final ActionItem? task;
  final LearningBlindSpot? blindSpot;
}

/// 盲区来源：主动记录的卡点为主；关键词命中只作为待确认建议。
enum BlindSpotSource { marked, suggested }

/// 学习卡壳盲区片段：来自会话的卡点速记（marked）或输出文本关键词（suggested）。
class LearningBlindSpot {
  const LearningBlindSpot({
    required this.sessionId,
    required this.actionItemId,
    required this.title,
    required this.text,
    this.source = BlindSpotSource.marked,
  });

  final String sessionId;
  final String actionItemId;
  final String title;
  final String text;
  final BlindSpotSource source;

  bool get isSuggested => source == BlindSpotSource.suggested;
}

/// 某个配方版本在生效期内的执行表现（v1 → v2 对比用）。
class RecipeEffect {
  const RecipeEffect({
    required this.habitId,
    required this.habitTitle,
    required this.revision,
    required this.start,
    required this.end,
    required this.days,
    required this.checks,
  });

  final String habitId;
  final String habitTitle;
  final int revision;
  final DateTime start;
  final DateTime end;
  final int days;
  final int checks;

  double get rate => days == 0 ? 0 : checks / days;
}

/// 能力在本周期的推进：彻底完成、巩固中与投入时长。
class CapabilityProgress {
  const CapabilityProgress({
    required this.capabilityId,
    required this.title,
    required this.completed,
    required this.consolidating,
    required this.minutes,
  });

  final String capabilityId;
  final String title;
  final int completed;
  final int consolidating;
  final int minutes;
}

/// 年度成果精选条目。
class LearningHighlight {
  const LearningHighlight({
    required this.actionItemId,
    required this.title,
    required this.completedAt,
    required this.summary,
  });

  final String actionItemId;
  final String title;
  final DateTime completedAt;
  final String summary;
}

/// 热力格：月份内每天 / 全年第个月的活跃度。
class HeatCell {
  const HeatCell({required this.label, required this.value});

  final String label;
  final int value;
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
    required this.habitVersions,
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
  final HabitRecipeVersionRepository habitVersions;
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
      final int days = ((snapshot.habitRates[habit.id] ?? 0) * window.days).round();
      items.add(
        ReviewItem(
          id: 'habit:${habit.id}',
          kind: ReviewItemKind.lowHabit,
          title: habit.tinyBehavior,
          subtitle: '本期完成 $days 天 · 节奏偏缓，可按当前节奏继续',
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

    int blindIndex = 0;
    for (final LearningBlindSpot spot in blindSpots(window).take(3)) {
      items.add(
        ReviewItem(
          id: 'blind:${spot.sessionId}:$blindIndex',
          kind: ReviewItemKind.learningBlindSpot,
          title: spot.isSuggested
              ? '疑似卡点：${spot.title}'
              : '补盲：${spot.title}',
          subtitle: spot.isSuggested
              ? '关键词建议：${spot.text}（确认后再生成任务）'
              : spot.text,
          blindSpot: spot,
        ),
      );
      blindIndex++;
    }

    return items;
  }

  /// 上一个同类型周期，用于「较上期」对比。
  ReviewWindow previousWindow(ReviewWindow window) =>
      ReviewWindow.of(window.type, window.shifted(-1));

  /// 把时间块安排到指定时刻（默认保持原时长），与时间盒共用同一数据。
  Future<void> moveBlockTo(
    TimeBlock block,
    DateTime start, {
    int? minutes,
  }) async {
    final int length = minutes ?? block.plannedMinutes;
    await blocks.save(
      block.copyWith(
        startAt: start,
        endAt: start.add(Duration(minutes: length)),
      ),
    );
  }

  /// 把逾期复习安排到指定时刻：更新到期时间并生成可点开的时间盒块。
  ///
  /// 复习与时间块的写入不阻塞界面；两者都只在本地落盘。
  Future<TimeBlock> scheduleReviewAt(
    LearningReview review,
    DateTime start, {
    int minutes = 15,
  }) async {
    final ActionItem? task = actions.byId(review.actionItemId);
    final TimeBlock block = TimeBlock.create(
      title: '间隔复习：${task?.title ?? '学习任务'}',
      startAt: start,
      endAt: start.add(Duration(minutes: minutes)),
      learningReviewId: review.id,
    );
    unawaited(blocks.put(block));
    unawaited(learningReviews.save(review.copyWith(dueDate: start)));
    return block;
  }

  /// 撤销某一项「已处理」标记（动作本身由页面按需回滚）。
  Future<void> unmarkHandled(ReviewWindow window, String itemId) async {
    final ReviewLog? log = logs.forPeriod(window.type, window.periodKey);
    if (log == null) return;
    final Set<String> handled = log.handledItems.toSet()..remove(itemId);
    await logs.save(
      log.copyWith(handledItemsJson: jsonEncode(handled.toList())),
    );
  }

  /// 复习积压分散到未来若干天（天数、每日上限与时间都可调）。
  Future<int> spreadReviewLoad(
    List<LearningReview> reviews, {
    int days = 3,
    int perDay = 2,
    int hour = 20,
  }) async {
    final DateTime today = AppDate.startOfDay(DateTime.now());
    final int span = days < 1 ? 1 : days;
    final int cap = perDay < 1 ? 1 : perDay;
    int index = 0;
    for (final LearningReview review in reviews) {
      if (review.isDone) continue;
      final DateTime day =
          today.add(Duration(days: (index ~/ cap) % span + 1));
      unawaited(
        learningReviews.save(
          review.copyWith(
            dueDate: DateTime(day.year, day.month, day.day, hour),
          ),
        ),
      );
      index++;
    }
    return index;
  }

  /// 把一条逾期复习排进明日的碎片时间盒（12:30，10 分钟）。
  Future<TimeBlock> scheduleReviewFragment(
    LearningReview review, {
    DateTime? day,
  }) async {
    final DateTime base = AppDate.startOfDay(
      day ?? DateTime.now().add(const Duration(days: 1)),
    );
    final ActionItem? task = actions.byId(review.actionItemId);
    return blocks.schedule(
      title: '碎片复习：${task?.title ?? '学习任务'}',
      startAt: DateTime(base.year, base.month, base.day, 12, 30),
      durationMinutes: 10,
      learningReviewId: review.id,
    );
  }

  /// 年度成果精选：窗口内完成的输出式学习任务 + 输出摘要。
  List<LearningHighlight> annualHighlights(ReviewWindow window) {
    final List<ActionItem> items = actions.all
        .where((ActionItem item) =>
            item.executionMode == ExecutionMode.outputLearning &&
            item.isCompleted &&
            window.contains(item.completedAt ?? item.updatedAt))
        .toList()
      ..sort((ActionItem a, ActionItem b) =>
          (b.completedAt ?? b.updatedAt).compareTo(
            a.completedAt ?? a.updatedAt,
          ));

    final List<LearningHighlight> result = <LearningHighlight>[];
    for (final ActionItem item in items) {
      final List<LearningSession> finished = sessions
          .forActionItem(item.id)
          .where((LearningSession session) => session.isFinished)
          .toList();
      String summary = item.note.trim();
      if (finished.isNotEmpty) {
        final LearningDraft draft = LearningDraft.decode(
          finished.last.stepsDataJson,
          finished.last.learningType,
        );
        final List<String> texts = <String>[
          for (final LearningStepDraft step in draft.fullSteps)
            if (step.text.trim().isNotEmpty) step.text.trim(),
          for (final LearningStepDraft step in draft.quickSteps)
            if (step.text.trim().isNotEmpty) step.text.trim(),
        ];
        if (texts.isNotEmpty) summary = texts.first;
      }
      if (summary.length > 80) {
        summary = '${summary.substring(0, 80)}…';
      }
      result.add(
        LearningHighlight(
          actionItemId: item.id,
          title: item.title,
          completedAt: item.completedAt ?? item.updatedAt,
          summary: summary,
        ),
      );
      if (result.length >= 6) break;
    }
    return result;
  }

  /// 解析学习会话里的卡点速记与输出关键词，得到可回炉的盲区片段。
  List<LearningBlindSpot> blindSpots(ReviewWindow window) {
    final List<LearningBlindSpot> result = <LearningBlindSpot>[];
    for (final LearningSession session in sessions.all) {
      final DateTime at = session.completedAt ?? session.updatedAt;
      if (!window.contains(at)) continue;
      final ActionItem? task = actions.byId(session.actionItemId);
      final LearningDraft draft =
          LearningDraft.decode(session.stepsDataJson, session.learningType);

      final List<String> marked = <String>[];
      final List<String> suggested = <String>[];
      final String blocker = draft.blocker.trim();
      if (blocker.length >= 2) marked.add(blocker);
      for (final LearningStepDraft step in draft.fullSteps) {
        for (final String sentence in _sentences(step.text)) {
          if (!_hasBlindKeyword(sentence)) continue;
          if (blocker.contains(sentence) || marked.contains(sentence)) continue;
          if (!suggested.contains(sentence)) suggested.add(sentence);
        }
      }

      for (final String piece in marked.take(1)) {
        result.add(
          LearningBlindSpot(
            sessionId: session.id,
            actionItemId: session.actionItemId,
            title: task?.title ?? '学习内容',
            text: piece,
            source: BlindSpotSource.marked,
          ),
        );
      }
      for (final String piece in suggested.take(2)) {
        result.add(
          LearningBlindSpot(
            sessionId: session.id,
            actionItemId: session.actionItemId,
            title: task?.title ?? '学习内容',
            text: piece,
            source: BlindSpotSource.suggested,
          ),
        );
      }
      if (result.length >= 8) break;
    }
    return result;
  }

  /// 由盲区一键生成回炉补盲任务（留在任务池，等待排期）。
  Future<ActionItem> createBlindSpotTask(LearningBlindSpot spot) {
    final ActionItem? source = actions.byId(spot.actionItemId);
    return actions.create(
      title: '回炉补盲：${spot.title}',
      capabilityId: source?.capabilityId,
      estimatedMinutes: 20,
      note: '盲区：${spot.text}\n'
          '建议 24 小时内做一次费曼式简化输出（5 分钟微输出即可）。',
    );
  }

  /// 该习惯的配方版本生效期执行率（按版本时间升序）。
  List<RecipeEffect> recipeEffects(String habitId) {
    final FoggHabit? habit = habits.byId(habitId);
    if (habit == null) return const <RecipeEffect>[];
    final List<HabitRecipeVersion> versions =
        habitVersions.forHabit(habitId).toList()
          ..sort((HabitRecipeVersion a, HabitRecipeVersion b) =>
              a.createdAt.compareTo(b.createdAt));
    if (versions.length < 2) return const <RecipeEffect>[];

    final Set<String> checked = <String>{
      for (final HabitLog log in habitLogs.all)
        if (log.isCompleted && log.habitId == habitId) log.dateKey,
    };
    final DateTime now = AppDate.startOfDay(DateTime.now());
    final List<RecipeEffect> effects = <RecipeEffect>[];
    for (int i = 0; i < versions.length; i++) {
      final DateTime start = AppDate.startOfDay(versions[i].createdAt);
      final DateTime end = i + 1 < versions.length
          ? AppDate.startOfDay(versions[i + 1].createdAt)
          : now.add(const Duration(days: 1));
      final int days = end.difference(start).inDays;
      if (days <= 0) continue;
      int checks = 0;
      for (int offset = 0; offset < days; offset++) {
        if (checked.contains(
          AppDate.dateKey(start.add(Duration(days: offset))),
        )) {
          checks++;
        }
      }
      effects.add(
        RecipeEffect(
          habitId: habitId,
          habitTitle: habit.tinyBehavior,
          revision: versions[i].revision,
          start: start,
          end: end,
          days: days,
          checks: checks,
        ),
      );
    }
    return effects;
  }

  /// 有 ≥2 个配方版本的活跃习惯，供月/年复盘对比。
  List<FoggHabit> habitsWithRecipeHistory() => habits.active
      .where((FoggHabit habit) =>
          habitVersions.forHabit(habit.id).length >= 2)
      .toList(growable: false);

  /// 各能力在本周期的完成 / 巩固中 / 投入时长。
  List<CapabilityProgress> capabilityProgress(ReviewWindow window) {
    final Map<String, int> completed = <String, int>{};
    final Map<String, int> consolidating = <String, int>{};
    final Map<String, int> minutes = <String, int>{};
    for (final ActionItem item in actions.all) {
      final String? capabilityId = item.capabilityId;
      if (capabilityId == null) continue;
      if (item.isCompleted) {
        final DateTime at = item.completedAt ?? item.updatedAt;
        if (window.contains(at)) {
          completed[capabilityId] = (completed[capabilityId] ?? 0) + 1;
        }
      }
      if (item.status == ActionItemStatus.consolidating) {
        consolidating[capabilityId] =
            (consolidating[capabilityId] ?? 0) + 1;
      }
    }
    for (final TimeBlock block in blocks.all) {
      if (!window.contains(block.startAt)) continue;
      final String? actionItemId = block.actionItemId;
      if (actionItemId == null) continue;
      final String? capabilityId = actions.byId(actionItemId)?.capabilityId;
      if (capabilityId == null) continue;
      minutes[capabilityId] =
          (minutes[capabilityId] ?? 0) + block.plannedMinutes;
    }

    final List<CapabilityProgress> result = <CapabilityProgress>[];
    for (final Capability capability in capabilities.all) {
      final int done = completed[capability.id] ?? 0;
      final int holding = consolidating[capability.id] ?? 0;
      final int spent = minutes[capability.id] ?? 0;
      if (done == 0 && holding == 0 && spent == 0) continue;
      result.add(
        CapabilityProgress(
          capabilityId: capability.id,
          title: capability.title,
          completed: done,
          consolidating: holding,
          minutes: spent,
        ),
      );
    }
    result.sort((CapabilityProgress a, CapabilityProgress b) =>
        b.minutes.compareTo(a.minutes));
    return result;
  }

  /// 月视图：每天已完成的时间块分钟数。
  List<HeatCell> dailyHeat(ReviewWindow window) {
    final Map<String, int> byDay = <String, int>{};
    for (final TimeBlock block in blocks.all) {
      if (!block.isCompleted || !window.contains(block.startAt)) continue;
      final String key = AppDate.dateKey(block.startAt);
      byDay[key] = (byDay[key] ?? 0) + block.plannedMinutes;
    }
    return <HeatCell>[
      for (int offset = 0; offset < window.days; offset++)
        HeatCell(
          label: '${window.start.add(Duration(days: offset)).day}',
          value: byDay[AppDate.dateKey(
                window.start.add(Duration(days: offset)),
              )] ??
              0,
        ),
    ];
  }

  /// 年视图：12 个月的已完成时间块数。
  List<HeatCell> monthlyHeat(int year) {
    final Map<int, int> byMonth = <int, int>{};
    for (final TimeBlock block in blocks.all) {
      if (!block.isCompleted || block.startAt.year != year) continue;
      byMonth[block.startAt.month] =
          (byMonth[block.startAt.month] ?? 0) + 1;
    }
    return <HeatCell>[
      for (int month = 1; month <= 12; month++)
        HeatCell(label: '$month', value: byMonth[month] ?? 0),
    ];
  }

  List<String> _sentences(String raw) {
    return raw
        .split(RegExp(r'[。！？!?\n;；]'))
        .map((String part) => part.trim())
        .where((String part) => part.length >= 4)
        .toList(growable: false);
  }

  bool _hasBlindKeyword(String sentence) {
    const List<String> keywords = <String>[
      '盲区',
      '卡住',
      '卡在',
      '不会',
      '没懂',
      '不理解',
      '写不出',
      '讲不清',
      '错因',
      '薄弱',
    ];
    return keywords.any(sentence.contains);
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
    unawaited(
      learningReviews.save(
        review.copyWith(
          dueDate: DateTime(target.year, target.month, target.day, 20),
          intervalDays: review.intervalDays,
        ),
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