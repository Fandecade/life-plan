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