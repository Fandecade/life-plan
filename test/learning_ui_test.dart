import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late ActionItem learningTask;
  late ActionItem secondTask;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_learn_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    learningTask = bootstrap.actions.all.firstWhere(
      (ActionItem item) => item.executionMode == ExecutionMode.outputLearning,
    );
    // 预置一个草稿会话，便于直接验证沉浸引导流（避免 widget 测试等待真实 I/O）。
    await bootstrap.learningSessions.startFor(
      learningTask,
      type: LearningType.declarative,
    );

    // 另一个没有会话的输出式学习任务，用于验证「先选方法再开始」。
    secondTask = await bootstrap.actions.create(
      title: '读《复盘的方法》引言',
      capabilityId: learningTask.capabilityId,
      executionMode: ExecutionMode.outputLearning,
    );

    // 预置一条已归档成果，用于验证成果库的分步骤折叠展示。
    final LearningSession archived =
        await bootstrap.learningSessions.startFor(
      secondTask,
      type: LearningType.declarative,
    );
    final LearningDraft archivedDraft = LearningDraft.initial(
      LearningType.declarative,
    )
        .withActiveText('第一次要点\n第二次要点')
        .withActiveIndex(1)
        .withActiveText('与旧知识的连接')
        .copyWith(blocker: '边界不清', link: 'https://example.com/note');
    await bootstrap.learningSessions.finish(
      archived.copyWith(stepsDataJson: archivedDraft.encode()),
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('学习监督台显示四个筛选与待学任务', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('输出式学习').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('今日待学'), findsWidgets);
    expect(find.textContaining('间隔复习'), findsWidgets);
    expect(find.textContaining('进行中草稿'), findsWidgets);
    expect(find.textContaining('输出成果库'), findsWidgets);

    // 开始前需要选择学习类型
    await tester.tap(find.text(secondTask.title).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('选择学习类型'), findsOneWidget);
    expect(find.text('陈述性知识'), findsOneWidget);
    expect(find.text('程序性知识'), findsOneWidget);
    expect(find.text('项目式学习'), findsOneWidget);
    expect(find.text('语言学习'), findsOneWidget);
    expect(find.text('自定义输出'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pump();
  });

  testWidgets('沉浸引导流可切换微输出并打开完成门禁', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('输出式学习').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 切到「进行中草稿」，打开预置会话
    await tester.tap(find.textContaining('进行中草稿'));
    await tester.pump();
    await tester.tap(find.text(learningTask.title).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('1 课前/读前设问'), findsOneWidget);
    expect(find.text('卡点速记'), findsWidgets);
    expect(find.text('外部成果链接'), findsWidgets);
    expect(find.text('完成本步 →'), findsOneWidget);

    // 列表式输入：第一行回车后出现下一个点
    await tester.enterText(find.byType(TextField).first, '第一个要点');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(find.text('回车继续下一个点…'), findsWidgets);

    // 切换 5 分钟微输出
    await tester.tap(find.text('切换 5m 轻量'));
    await tester.pump();
    expect(find.text('5 分钟微输出'), findsWidgets);
    expect(find.text('切换完整 4 步'), findsOneWidget);

    await tester.tap(find.text('切换完整 4 步'));
    await tester.pump();

    // 跳到第 4 步并触发完成门禁
    await tester.tap(find.textContaining('4 输出校验与间隔排期'));
    await tester.pump();
    await tester.tap(find.text('完成本次学习'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('完成前的自检'), findsOneWidget);
    expect(find.text('通过 · 已独立输出'), findsOneWidget);
    expect(find.text('存在盲区 · 卡壳'), findsOneWidget);
    expect(find.text('暂未完成'), findsOneWidget);

    // 暂未完成 → 保留草稿并回到工作台
    await tester.tap(find.text('暂未完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('今日待学'), findsWidgets);

    final List<LearningSession> drafts = bootstrap.learningSessions.inProgress;
    expect(drafts, isNotEmpty, reason: '暂未完成应保留草稿');
  });

  testWidgets('进行中的草稿可右键取消，任务回到待学', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('输出式学习').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.textContaining('进行中草稿'));
    await tester.pump();

    final LearningSession session = bootstrap.learningSessions.inProgress.first;
    final ActionItem task = bootstrap.actions.byId(session.actionItemId)!;

    await tester.tap(
      find.text(task.title).first,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('取消本次学习'), findsOneWidget);

    await tester.tap(find.text('取消本次学习'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('取消本次学习？'), findsOneWidget);

    await tester.tap(find.text('确认取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      bootstrap.learningSessions.inProgressFor(task.id),
      isNull,
      reason: '取消后草稿应从进行中移除',
    );
  });

  testWidgets('输出成果按步骤分块并可全部收起', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('输出式学习').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.textContaining('输出成果库'));
    await tester.pump();

    await tester.tap(find.text('查看').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('输出成果'), findsOneWidget);
    expect(find.text('全部收起'), findsOneWidget);
    expect(find.text('1 课前/读前设问'), findsWidgets);
    expect(find.text('第一次要点'), findsWidgets);
    expect(find.text('卡点速记'), findsWidgets);

    await tester.tap(find.text('全部收起'));
    await tester.pump();
    expect(find.text('第一次要点'), findsNothing);
    expect(find.text('全部展开'), findsOneWidget);
  });
}