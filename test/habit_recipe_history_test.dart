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
    tempDir = await Directory.systemTemp.createTemp('life_planner_recipe_history');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    habit = await bootstrap.foggHabits.create(
      anchorPrompt: '晚饭后',
      tinyBehavior: '读 1 页',
      frictions: const FrictionProfile(time: true, energy: true),
    );
    await bootstrap.habitService.saveRecipe(habit, note: 'v1 初始配方');
    await bootstrap.habitService.saveRecipe(
      habit.copyWith(frictions: const FrictionProfile()),
      note: 'v2 降阻',
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('配方调整记录点开后展示历史版本落点对比', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('福格习惯').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('配方调整记录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('v2'), findsWidgets);

    await tester.tap(find.text('v2').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('行动线门槛'), findsOneWidget);
    expect(find.textContaining('历史 v2：'), findsOneWidget);
    expect(find.textContaining('灰色 = 历史 v2'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(find.text('行动线门槛'), findsNothing);
  });
}