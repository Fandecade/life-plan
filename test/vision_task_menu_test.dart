import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/modules/vision_map/vision_nodes.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_task_menu');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('任务卡三点菜单可添加子任务与删除任务', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('人生规划').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder card = find.byType(TaskNodeCard).first;
    expect(card, findsOneWidget);
    final Finder menu = find.descendant(
      of: card,
      matching: find.byTooltip('更多操作'),
    );
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('添加子任务'), findsOneWidget);

    await tester.tap(find.text('添加子任务'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('新建任务'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('vision-task-title')),
      '菜单添加的子任务',
    );
    await tester.tap(find.text('创建'));
    await settle(tester);

    final ActionItem created = bootstrap.actions.all.firstWhere(
      (ActionItem item) => item.title == '菜单添加的子任务',
    );
    expect(created.parentId, isNotNull, reason: '应挂在原任务下作为子任务');
  });
}
