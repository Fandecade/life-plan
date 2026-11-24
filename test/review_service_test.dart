import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/review_service.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_review_test');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('周期窗口：键、天数、包含与平移', () {
    final DateTime anchor = DateTime(2026, 11, 25, 10);
    final ReviewWindow daily =
        ReviewWindow.of(ReviewPeriodType.daily, anchor);
    expect(daily.periodKey, '2026-11-25');
    expect(daily.days, 1);
    expect(daily.contains(DateTime(2026, 11, 25, 23, 59)), isTrue);
    expect(daily.contains(DateTime(2026, 11, 26)), isFalse);

    final ReviewWindow weekly =
        ReviewWindow.of(ReviewPeriodType.weekly, anchor);
    expect(weekly.periodKey, '2026-W48');
    expect(weekly.days, 7);
    expect(weekly.start.weekday, DateTime.monday);

    final ReviewWindow monthly =
        ReviewWindow.of(ReviewPeriodType.monthly, anchor);
    expect(monthly.periodKey, '2026-11');
    expect(monthly.days, 30);

    final ReviewWindow yearly =
        ReviewWindow.of(ReviewPeriodType.yearly, anchor);
    expect(yearly.periodKey, '2026');
    expect(yearly.days, 365);

    expect(daily.shifted(1).day, 26);
    expect(weekly.shifted(-1).day, 18);
    expect(monthly.shifted(1).month, 12);
    expect(yearly.shifted(1).year, 2027);
  });

  test('数据快照与待校准事项覆盖四大模块', () async {
    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.weekly, DateTime.now());
    final DateTime yesterday =
        AppDate.startOfDay(DateTime.now().subtract(const Duration(days: 1)));

    final Capability capability = bootstrap.capabilities.all.first;
    final ActionItem task = await bootstrap.actions.create(
      title: '复盘快照任务',
      capabilityId: capability.id,
      estimatedMinutes: 60,
      status: ActionItemStatus.scheduled,
    );
    await bootstrap.actions.save(
      task.copyWith(
        status: ActionItemStatus.completed,
        completedAt: yesterday.add(const Duration(hours: 10)),
      ),
    );
    final TimeBlock block = await bootstrap.timeBlocks.schedule(
      title: '复盘快照任务',
      startAt: yesterday.add(const Duration(hours: 10)),
      durationMinutes: 60,
      actionItemId: task.id,
    );

    await bootstrap.learningSessions.put(
      LearningSession.create(actionItemId: task.id).copyWith(
        isFinished: true,
        completedAt: yesterday.add(const Duration(hours: 12)),
      ),
    );
    await bootstrap.learningReviews.put(
      LearningReview.create(
        sessionId: 'seed-session',
        actionItemId: task.id,
        dueDate: yesterday.add(const Duration(hours: 20)),
        intervalDays: 3,
      ),
    );

    final FoggHabit habit = await bootstrap.foggHabits.create(
      anchorPrompt: '复盘前',
      tinyBehavior: '复盘快照习惯',
    );
    await bootstrap.habitLogs.logDay(
      habit.id,
      AppDate.dateKey(yesterday),
    );

    final ReviewService service = bootstrap.reviewService;
    final ReviewSnapshot snapshot = service.snapshot(window);

    expect(snapshot.plannedMinutes, greaterThanOrEqualTo(60));
    expect(snapshot.completedTasks, greaterThanOrEqualTo(0));
    expect(snapshot.outputs, greaterThanOrEqualTo(1));
    expect(snapshot.habitChecks, greaterThanOrEqualTo(1));
    expect(snapshot.reviewsDue, greaterThanOrEqualTo(1));
    expect(snapshot.overdueReviews, isNotEmpty);
    expect(
      snapshot.capabilitySlices.any(
        (CapabilitySlice slice) =>
            slice.capabilityId == capability.id && slice.minutes >= 60,
      ),
      isTrue,
    );
    expect(
      snapshot.unfinishedBlocks.any((TimeBlock item) => item.id == block.id),
      isTrue,
    );

    final List<ReviewItem> pending = service.pending(window, snapshot);
    expect(
      pending.any((ReviewItem item) => item.id == 'block:${block.id}'),
      isTrue,
    );
    expect(
      pending.any((ReviewItem item) => item.id == 'habit:${habit.id}'),
      isTrue,
      reason: '本周只完成 1 次，应判定为节律偏低',
    );
    expect(
      pending.any(
        (ReviewItem item) => item.kind == ReviewItemKind.overdueReview,
      ),
      isTrue,
    );
  });

  test('向下动作：顺延、拆小、回池、取消、归档、复习顺延', () async {
    final ReviewService service = bootstrap.reviewService;
    final DateTime today = AppDate.startOfDay(DateTime.now());

    final ActionItem task = await bootstrap.actions.create(
      title: '动作测试任务',
      estimatedMinutes: 60,
      status: ActionItemStatus.scheduled,
    );
    final TimeBlock block = await bootstrap.timeBlocks.schedule(
      title: '动作测试任务',
      startAt: today.add(const Duration(hours: 8)),
      durationMinutes: 60,
      actionItemId: task.id,
    );

    await service.pushBlockToDay(block);
    final TimeBlock moved = bootstrap.timeBlocks.byId(block.id)!;
    expect(
      AppDate.isSameDay(moved.startAt, today.add(const Duration(days: 1))),
      isTrue,
    );
    expect(moved.plannedMinutes, 60);

    await service.shrinkTask(task);
    final ActionItem shrunk = bootstrap.actions.byId(task.id)!;
    expect(shrunk.estimatedMinutes, 30);
    expect(bootstrap.actions.childrenOf(task.id), isNotEmpty);
    expect(bootstrap.timeBlocks.byId(block.id)!.plannedMinutes, 30);

    await service.returnBlockToInbox(bootstrap.timeBlocks.byId(block.id)!);
    expect(bootstrap.timeBlocks.byId(block.id), isNull);
    expect(bootstrap.actions.byId(task.id)!.status, ActionItemStatus.inbox);

    final TimeBlock standalone = await bootstrap.timeBlocks.schedule(
      title: '无任务块',
      startAt: today.add(const Duration(hours: 9)),
      durationMinutes: 30,
    );
    await service.cancelBlock(standalone);
    expect(bootstrap.timeBlocks.byId(standalone.id), isNull);

    await service.archiveTask(bootstrap.actions.byId(task.id)!);
    expect(
      bootstrap.actions.byId(task.id)!.status,
      ActionItemStatus.deferred,
    );

    final LearningReview review = LearningReview.create(
      sessionId: 's',
      actionItemId: task.id,
      dueDate: today.subtract(const Duration(days: 2)),
      intervalDays: 3,
    );
    await bootstrap.learningReviews.put(review);
    await service.postponeReview(review);
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final LearningReview postponed =
        bootstrap.learningReviews.byId(review.id)!;
    expect(postponed.dueDate.hour, 20);
    expect(AppDate.isSameDay(postponed.dueDate, tomorrow), isTrue);
  });

  test('学习盲区解析与一键补盲任务', () async {
    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.daily, DateTime.now());
    final Capability capability = bootstrap.capabilities.all.first;
    final ActionItem task = await bootstrap.actions.create(
      title: '学习盲区任务',
      capabilityId: capability.id,
    );
    final LearningDraft draft = LearningDraft.initial(LearningType.declarative)
        .copyWith(blocker: '写不出适用边界，概念盲区');
    await bootstrap.learningSessions.put(
      LearningSession.create(actionItemId: task.id).copyWith(
        isFinished: true,
        completedAt: DateTime.now(),
        stepsDataJson: draft.encode(),
      ),
    );

    final List<LearningBlindSpot> spots =
        bootstrap.reviewService.blindSpots(window);
    final LearningBlindSpot marked = spots.firstWhere(
      (LearningBlindSpot spot) => spot.text.contains('写不出'),
    );
    expect(marked.source, BlindSpotSource.marked);
    expect(marked.isSuggested, isFalse);

    final int before = bootstrap.actions.all.length;
    final ActionItem created =
        await bootstrap.reviewService.createBlindSpotTask(spots.first);
    expect(created.title, contains('回炉补盲'));
    expect(created.note, contains('盲区'));
    expect(created.capabilityId, capability.id);
    expect(created.status, ActionItemStatus.inbox);
    expect(bootstrap.actions.all.length, before + 1);
  });

  test('配方版本生效期执行率可对比', () async {
    final DateTime today = AppDate.startOfDay(DateTime.now());
    final FoggHabit habit = await bootstrap.foggHabits.create(
      anchorPrompt: '配方对比锚点',
      tinyBehavior: '配方对比习惯',
    );
    HabitRecipeVersion version({
      required String id,
      required int revision,
      required DateTime createdAt,
    }) =>
        HabitRecipeVersion(
          id: id,
          createdAt: createdAt,
          updatedAt: createdAt,
          habitId: habit.id,
          revision: revision,
          anchorPrompt: '锚点 v$revision',
          tinyBehavior: '微行为 v$revision',
          celebration: '庆祝',
        );

    final DateTime v1Start = today.subtract(const Duration(days: 6));
    final DateTime v2Start = today.subtract(const Duration(days: 3));
    await bootstrap.habitRecipeVersions.put(
      version(id: 'rv-1-${habit.id}', revision: 1, createdAt: v1Start),
    );
    await bootstrap.habitRecipeVersions.put(
      version(id: 'rv-2-${habit.id}', revision: 2, createdAt: v2Start),
    );
    await bootstrap.habitLogs.logDay(
      habit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 4))),
    );
    await bootstrap.habitLogs.logDay(
      habit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 2))),
    );
    await bootstrap.habitLogs.logDay(
      habit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 1))),
    );

    final List<RecipeEffect> effects =
        bootstrap.reviewService.recipeEffects(habit.id);
    expect(effects.length, 2);
    expect(effects.first.revision, 1);
    expect(effects.first.days, 3);
    expect(effects.first.checks, 1);
    expect(effects.last.checks, 2);
    expect(
      effects.last.rate,
      greaterThan(effects.first.rate),
      reason: 'v2 生效期执行率应更高，形成可对比的改善',
    );
    expect(
      bootstrap.reviewService
          .habitsWithRecipeHistory()
          .any((FoggHabit item) => item.id == habit.id),
      isTrue,
    );
  });

  test('能力推进与月度负荷热力', () async {
    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.monthly, DateTime.now());
    final Capability capability = bootstrap.capabilities.all.first;
    final ActionItem task = await bootstrap.actions.create(
      title: '月度推进任务',
      capabilityId: capability.id,
      estimatedMinutes: 45,
      status: ActionItemStatus.scheduled,
    );
    await bootstrap.actions.save(
      task.copyWith(
        status: ActionItemStatus.completed,
        completedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
    final TimeBlock block = await bootstrap.timeBlocks.schedule(
      title: '月度推进任务',
      startAt: DateTime.now().subtract(const Duration(hours: 2)),
      durationMinutes: 45,
      actionItemId: task.id,
    );
    await bootstrap.timeBlocks.setCompleted(block.id, true);

    final List<CapabilityProgress> progress =
        bootstrap.reviewService.capabilityProgress(window);
    final CapabilityProgress row = progress.firstWhere(
      (CapabilityProgress item) => item.capabilityId == capability.id,
      orElse: () => const CapabilityProgress(
        capabilityId: '',
        title: '',
        completed: 0,
        consolidating: 0,
        minutes: 0,
      ),
    );
    expect(row.completed, greaterThanOrEqualTo(1));
    expect(row.minutes, greaterThanOrEqualTo(45));

    final List<HeatCell> heat = bootstrap.reviewService.dailyHeat(window);
    expect(heat.length, window.days);
    expect(
      heat.any((HeatCell cell) => cell.value >= 45),
      isTrue,
    );

    final List<HeatCell> yearlyHeat =
        bootstrap.reviewService.monthlyHeat(window.start.year);
    expect(yearlyHeat.length, 12);
    expect(
      yearlyHeat[DateTime.now().month - 1].value,
      greaterThanOrEqualTo(1),
    );
  });

  test('上一周期与复习负载调整', () async {
    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.weekly, DateTime.now());
    final ReviewService service = bootstrap.reviewService;
    final ReviewWindow previous = service.previousWindow(window);
    expect(previous.end, window.start);
    expect(previous.periodKey, isNot(window.periodKey));

    final ActionItem task = await bootstrap.actions.create(title: '复习负载任务');
    final LearningReview review = LearningReview.create(
      sessionId: 'load',
      actionItemId: task.id,
      dueDate: AppDate.startOfWeek(DateTime.now())
          .subtract(const Duration(days: 3)),
      intervalDays: 3,
    );
    await bootstrap.learningReviews.put(review);

    final int count = await service.spreadReviewLoad(
      <LearningReview>[review],
      days: 5,
      perDay: 1,
      hour: 21,
    );
    expect(count, 1);
    final LearningReview spread = bootstrap.learningReviews.byId(review.id)!;
    final int days = AppDate.startOfDay(spread.dueDate)
        .difference(AppDate.startOfDay(DateTime.now()))
        .inDays;
    expect(days, inInclusiveRange(1, 5));
    expect(spread.dueDate.hour, 21);

    final TimeBlock fragment = await service.scheduleReviewFragment(spread);
    expect(fragment.plannedMinutes, 10);
    expect(fragment.learningReviewId, review.id);
    expect(fragment.startAt.hour, 12);
    expect(
      AppDate.isSameDay(
        fragment.startAt,
        DateTime.now().add(const Duration(days: 1)),
      ),
      isTrue,
    );
  });

  test('年度成果精选汇总输出式学习完成项', () async {
    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.yearly, DateTime.now());
    final ActionItem task = await bootstrap.actions.create(
      title: '年度作品 A',
      executionMode: ExecutionMode.outputLearning,
      status: ActionItemStatus.scheduled,
    );
    await bootstrap.actions.save(
      task.copyWith(
        status: ActionItemStatus.completed,
        completedAt: DateTime.now(),
      ),
    );
    final LearningDraft base = LearningDraft.initial(LearningType.declarative);
    final List<LearningStepDraft> steps =
        List<LearningStepDraft>.from(base.fullSteps);
    steps[2] = steps[2].copyWith(text: '用费曼讲清了边界条件');
    await bootstrap.learningSessions.put(
      LearningSession.create(actionItemId: task.id).copyWith(
        isFinished: true,
        completedAt: DateTime.now(),
        stepsDataJson: base.copyWith(fullSteps: steps).encode(),
      ),
    );

    final List<LearningHighlight> highlights =
        bootstrap.reviewService.annualHighlights(window);
    final LearningHighlight row = highlights.firstWhere(
      (LearningHighlight item) => item.actionItemId == task.id,
      orElse: () => LearningHighlight(
        actionItemId: '',
        title: '',
        completedAt: DateTime(2000),
        summary: '',
      ),
    );
    expect(row.title, '年度作品 A');
    expect(row.summary, contains('费曼'));
  });

  test('复盘文本自动保存、划掉事项与完成标记可持久化', () async {
    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.daily, DateTime.now());
    final ReviewService service = bootstrap.reviewService;

    final ReviewLog log = await service.saveEntry(
      window,
      wins: '今天推进了复盘模块',
      focus: '明天先做数据看板',
      handled: <String>{'block:demo'},
      stats: service.snapshotStats(window),
    );

    expect(log.winsText, '今天推进了复盘模块');
    expect(log.focusText, '明天先做数据看板');
    expect(log.handledItems, contains('block:demo'));
    expect(log.snapshotStats['plannedMinutes'], isA<int>());

    await service.markHandled(window, 'review:demo');
    final ReviewLog after = bootstrap.reviewLogs.forPeriod(
      window.type,
      window.periodKey,
    )!;
    expect(after.handledItems, containsAll(<String>['block:demo', 'review:demo']));
    expect(after.winsText, '今天推进了复盘模块');

    await service.saveEntry(window, isCompleted: true);
    expect(
      bootstrap.reviewLogs.forPeriod(window.type, window.periodKey)!.isCompleted,
      isTrue,
    );
  });
}