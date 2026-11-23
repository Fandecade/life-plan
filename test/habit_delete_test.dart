import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton;
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
    tempDir = await Directory.systemTemp.createTemp('life_planner_habit_delete');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    habit = await bootstrap.foggHabits.create(
      anchorPrompt: '刷完牙后',
      tinyBehavior: '做 1 个深蹲',
    );
    await bootstrap.habitService.checkIn(habit);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('右键习惯卡片可删除微习惯，历史打卡保留', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('福格习惯').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('做 1 个深蹲'), findsOneWidget);

    await tester.tap(
      find.text('做 1 个深蹲'),
      buttons: kSecondaryButton,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('删除微习惯'), findsOneWidget);

    await tester.tap(find.text('删除微习惯'));
    await settle(tester);

    expect(bootstrap.foggHabits.byId(habit.id), isNull);
    expect(
      bootstrap.habitLogs.forHabit(habit.id),
      isNotEmpty,
      reason: '删除习惯不应清空历史打卡',
    );
    expect(find.text('做 1 个深蹲'), findsNothing);
  });
}