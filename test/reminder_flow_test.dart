import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/shell/reminder_banner.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late TimeBlock block;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_reminder_flow');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    block = await bootstrap.timeBlocks.schedule(
      title: '启动提醒流程测试',
      startAt: DateTime.now().add(const Duration(minutes: 5)),
      durationMinutes: 30,
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  testWidgets('应用启动即展示到点提醒，点击完成后横幅收起', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ReminderBanner), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ReminderBanner),
        matching: find.text('启动提醒流程测试'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(ReminderBanner),
        matching: find.text('完成'),
      ),
    );
    await tester.pump();
    await settle(tester);

    expect(find.byType(ReminderBanner), findsNothing);
    expect(
      bootstrap.timeBlocks.byId(block.id)!.isCompleted,
      isTrue,
      reason: '完成动作应直接勾选时间块',
    );
  });
}