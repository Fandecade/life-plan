import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late FoggHabit habit;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_habit_link');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    habit = await bootstrap.foggHabits.create(
      anchorPrompt: '起床后',
      tinyBehavior: '喝一杯温水',
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('时间盒日视图出现今日微习惯并能打卡，月视图叠加微节律点', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.textContaining('今日微习惯'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('喝一杯温水'), findsWidgets);

    await tester.tap(find.textContaining('喝一杯温水').first);
    await settle(tester);

    expect(bootstrap.habitService.isDoneToday(habit), isTrue);

    await tester.tap(find.text('月'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('总投入'), findsOneWidget);
    expect(
      bootstrap.habitService
          .completedCountByDay(<String>[habit.id])[bootstrap.habitService.todayKey],
      1,
    );
  });
}