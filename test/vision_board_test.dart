import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/shell/desktop_side_nav.dart';
import 'package:life_planner/app/theme/ui_style.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late Vision vision;
  late Capability design;
  late ActionItem writing;
  late ActionItem portfolio;
  late ActionItem doneTask;


  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_board');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    vision = await bootstrap.visions.create(
      title: '卡片愿景',
      description: '用作品说话，建立可持续的个人产品线',
      colorHex: '#6E659C',
    );
    design = await bootstrap.capabilities.create(
      visionId: vision.id,
      title: '产品设计',
      targetLevel: '能独立设计端到端产品',
    );
    await bootstrap.capabilities.create(
      visionId: vision.id,
      title: '前端工程',
    );
    writing = await bootstrap.actions.create(
      title: '写一篇发布文',
      capabilityId: design.id,
      estimatedMinutes: 30,
    );
    portfolio = await bootstrap.actions.create(
      title: '完成作品集首页',
      capabilityId: design.id,
      dueDate: DateTime.now().add(const Duration(days: 3)),
    );
    await bootstrap.actions.create(
      title: '子任务一',
      capabilityId: design.id,
      parentId: writing.id,
    );
    doneTask = await bootstrap.actions.create(
      title: '已完成任务',
      capabilityId: design.id,
    );
    await bootstrap.actions.toggleCompleted(doneTask.id);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await bootstrap.uiStyle.setVisionView(VisionViewMode.map);
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 16; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> openVision(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(DesktopSideNav),
        matching: find.byIcon(Icons.account_tree_outlined),
      ),
    );
    await settle(tester);
    // 默认活动愿景可能来自示例数据，先切到测试愿景。
    await tester.tap(find.text('卡片愿景').first);
    await settle(tester);
  }


  testWidgets('图谱与卡片视图可切换，任务默认收起', (WidgetTester tester) async {
    await openVision(tester);

    expect(find.text('图谱'), findsOneWidget);
    expect(find.text('卡片'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('vision-board-hero')), findsNothing);

    await tester.tap(find.text('卡片'));
    await settle(tester);

    expect(bootstrap.uiStyle.visionView, VisionViewMode.board);
    expect(
      find.byKey(const ValueKey<String>('vision-board-hero')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('vision-board-hero')),
        matching: find.text('卡片愿景'),
      ),
      findsOneWidget,
    );
    expect(find.text('产品设计'), findsOneWidget);
    expect(find.text('前端工程'), findsOneWidget);

    // 任务默认收起，只看结构与进度。
    expect(
      find.byKey(ValueKey<String>('vision-board-task-${writing.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('vision-board-task-${portfolio.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('vision-board-task-${doneTask.id}')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        ValueKey<String>('vision-board-capability-${design.id}'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(ValueKey<String>('vision-board-task-${writing.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('vision-board-task-${portfolio.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('vision-board-task-${doneTask.id}')),
      findsNothing,
      reason: '已完成默认折叠',
    );

    await tester.tap(find.text('展开已完成'));
    await tester.pump();
    expect(
      find.byKey(ValueKey<String>('vision-board-task-${doneTask.id}')),
      findsOneWidget,
    );

    // 切回图谱后卡片视图应消失。
    await tester.tap(find.text('图谱'));
    await settle(tester);
    expect(bootstrap.uiStyle.visionView, VisionViewMode.map);
    expect(find.byKey(const ValueKey<String>('vision-board-hero')), findsNothing);
  });

  testWidgets('点击愿景大卡可折叠能力区', (WidgetTester tester) async {
    await openVision(tester);
    await tester.tap(find.text('卡片'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('产品设计'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('vision-board-hero')),
    );
    await tester.pump();
    expect(find.text('产品设计'), findsNothing);
    expect(find.textContaining('点击上方卡片展开'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('vision-board-hero')),
    );
    await tester.pump();
    expect(find.text('产品设计'), findsOneWidget);
  });
}