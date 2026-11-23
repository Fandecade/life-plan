import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/review_service.dart';
import 'package:life_planner/core/utils/date_utils.dart';
import 'package:life_planner/modules/vision_map/vision_canvas.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late TimeBlock block;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_review_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    final DateTime today = AppDate.startOfDay(DateTime.now());
    block = await bootstrap.timeBlocks.schedule(
      title: '复盘UI未完成块',
      startAt: today.add(const Duration(minutes: 5)),
      durationMinutes: 30,
    );

    final Capability capability = bootstrap.capabilities.all.first;
    final ActionItem learningTask = await bootstrap.actions.create(
      title: '复盘UI学习任务',
      capabilityId: capability.id,
    );
    final LearningDraft draft = LearningDraft.initial(LearningType.declarative)
        .copyWith(blocker: '写不出适用边界，概念盲区');
    await bootstrap.learningSessions.put(
      LearningSession.create(actionItemId: learningTask.id).copyWith(
        isFinished: true,
        completedAt: DateTime.now(),
        stepsDataJson: draft.encode(),
      ),
    );

    final FoggHabit recipeHabit = await bootstrap.foggHabits.create(
      anchorPrompt: '复盘UI锚点',
      tinyBehavior: '复盘UI配方习惯',
    );
    HabitRecipeVersion version({required int revision, required DateTime at}) =>
        HabitRecipeVersion(
          id: 'rui-v$revision-${recipeHabit.id}',
          createdAt: at,
          updatedAt: at,
          habitId: recipeHabit.id,
          revision: revision,
          anchorPrompt: '锚点 v$revision',
          tinyBehavior: '微行为 v$revision',
          celebration: '庆祝',
        );
    await bootstrap.habitRecipeVersions.put(
      version(revision: 1, at: today.subtract(const Duration(days: 6))),
    );
    await bootstrap.habitRecipeVersions.put(
      version(revision: 2, at: today.subtract(const Duration(days: 3))),
    );
    await bootstrap.habitLogs.logDay(
      recipeHabit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 4))),
    );
    await bootstrap.habitLogs.logDay(
      recipeHabit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 2))),
    );
    await bootstrap.habitLogs.logDay(
      recipeHabit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 1))),
    );

    await bootstrap.reviewService.saveEntry(
      ReviewWindow.of(ReviewPeriodType.weekly, DateTime.now()),
      wins: '历史一条',
      isCompleted: true,
    );

    final ActionItem work = await bootstrap.actions.create(
      title: '年度作品 B',
      executionMode: ExecutionMode.outputLearning,
      status: ActionItemStatus.scheduled,
    );
    await bootstrap.actions.save(
      work.copyWith(
        status: ActionItemStatus.completed,
        completedAt: DateTime.now(),
      ),
    );
    await bootstrap.learningSessions.put(
      LearningSession.create(actionItemId: work.id).copyWith(
        isFinished: true,
        completedAt: DateTime.now(),
        stepsDataJson:
            LearningDraft.initial(LearningType.declarative).encode(),
      ),
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> openReview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('及时复盘').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // State 复用时把周期重置为日复盘，避免上一个用例残留周期。
    await tester.tap(find.text('日复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('复盘页展示四周期、数据看板与引导问答', (WidgetTester tester) async {
    await openReview(tester);

    expect(find.text('日复盘'), findsOneWidget);
    expect(find.text('周复盘'), findsOneWidget);
    expect(find.text('月复盘'), findsOneWidget);
    expect(find.text('年复盘'), findsOneWidget);

    expect(find.text('时间投入'), findsOneWidget);
    expect(find.text('任务与学习'), findsOneWidget);
    expect(find.text('微习惯节律'), findsOneWidget);
    expect(find.text('能力精力分布'), findsOneWidget);

    expect(find.text('今日亮点（1 句）'), findsOneWidget);
    expect(find.text('明日最关键 1–3 件事'), findsOneWidget);
    expect(find.textContaining('待校准事项'), findsOneWidget);

    await tester.tap(find.text('周复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('本周有效模式（Keep）'), findsOneWidget);
    expect(find.text('If–Then 预案'), findsOneWidget);
  });

  testWidgets('未完成时间块可一键排入明日并划掉', (WidgetTester tester) async {
    await openReview(tester);

    expect(find.text('复盘UI未完成块'), findsWidgets);
    final Finder push = find.text('排入明日').first;
    await tester.ensureVisible(push);
    await tester.pump();
    await tester.tap(push);
    await settle(tester);

    final TimeBlock moved = bootstrap.timeBlocks.byId(block.id)!;
    expect(AppDate.isSameDay(moved.startAt, DateTime.now()), isFalse);
    expect(
      AppDate.isSameDay(
        moved.startAt,
        DateTime.now().add(const Duration(days: 1)),
      ),
      isTrue,
      reason: '应顺延到明日同一时刻',
    );
    expect(find.text('已处理'), findsWidgets);
  });

  testWidgets('月复盘展示学习摘要、能力推进、热力与配方对比', (
    WidgetTester tester,
  ) async {
    await openReview(tester);

    await tester.tap(find.text('月复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('学习系统摘要'), findsOneWidget);
    expect(find.text('能力推进'), findsOneWidget);
    expect(find.text('本月负荷热力'), findsOneWidget);
    expect(find.text('配方版本执行率'), findsOneWidget);
    expect(find.textContaining('v1 → v2'), findsWidgets);

    await tester.tap(find.text('年复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('全年活跃热力'), findsOneWidget);
  });

  testWidgets('学习盲区可一键生成回炉补盲任务', (WidgetTester tester) async {
    await openReview(tester);

    expect(find.textContaining('补盲：复盘UI学习任务'), findsWidgets);

    final Finder action = find.text('生成补盲任务').first;
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await settle(tester);

    final List<ActionItem> created = bootstrap.actions.all
        .where((ActionItem item) => item.title.contains('回炉补盲'))
        .toList();
    expect(created, isNotEmpty);
    expect(created.first.note, contains('盲区'));
    expect(created.first.status, ActionItemStatus.inbox);
    expect(find.text('已处理'), findsWidgets);
  });

  testWidgets('历史复盘可查看并跳转到对应周期', (WidgetTester tester) async {
    await openReview(tester);

    await tester.tap(find.text('历史'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('历史复盘'), findsOneWidget);
    expect(find.text('历史一条'), findsOneWidget);

    await tester.tap(find.text('历史一条'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('本周有效模式（Keep）'), findsOneWidget);
  });

  testWidgets('Keep 可沉淀为微习惯或学习模板', (WidgetTester tester) async {
    await openReview(tester);

    await tester.tap(find.text('周复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byType(TextField).first,
      '每天先做 5 分钟微输出，再展开完整学习',
    );
    await tester.pump(const Duration(milliseconds: 700));

    final Finder sediment = find.text('沉淀为微习惯');
    await tester.scrollUntilVisible(sediment, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(sediment);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('新建微习惯'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await settle(tester);

    final Finder template = find.text('存为学习模板');
    await tester.scrollUntilVisible(template, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(template);
    await settle(tester);

    expect(
      bootstrap.actions.all
          .where((ActionItem item) => item.title.contains('学习模板：'))
          .toList(),
      isNotEmpty,
    );
  });

  testWidgets('月/年复盘包含内嵌行动线与年度成果精选', (
    WidgetTester tester,
  ) async {
    await openReview(tester);

    await tester.tap(find.text('月复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder actionLine = find.text('习惯行动线');
    await tester.scrollUntilVisible(actionLine, 240,
        scrollable: find.byType(Scrollable).first);
    expect(actionLine, findsOneWidget);
    expect(find.text('改固定安排'), findsOneWidget);

    await tester.tap(find.text('年复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder highlights = find.text('年度成果精选');
    await tester.scrollUntilVisible(highlights, 240,
        scrollable: find.byType(Scrollable).first);
    expect(highlights, findsOneWidget);
    expect(find.text('年度作品 B'), findsOneWidget);
  });

  testWidgets('能力分布点击可跳转并聚焦图谱能力', (WidgetTester tester) async {
    await openReview(tester);

    final Finder legend = find.textContaining('结构化表达与输出').first;
    await tester.tap(legend);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(VisionCanvas), findsOneWidget);
  });

  testWidgets('引导问答自动保存，标记完成后周期状态更新', (
    WidgetTester tester,
  ) async {
    await openReview(tester);

    await tester.enterText(
      find.byType(TextField).first,
      '今天推进了复盘模块',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);

    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.daily, DateTime.now());
    final ReviewLog saved =
        bootstrap.reviewLogs.forPeriod(window.type, window.periodKey)!;
    expect(saved.winsText, contains('复盘模块'));

    await tester.tap(find.text('标记完成'));
    await settle(tester);

    expect(
      bootstrap.reviewLogs
          .forPeriod(window.type, window.periodKey)!
          .isCompleted,
      isTrue,
    );
    expect(find.text('已完成'), findsWidgets);
  });
}