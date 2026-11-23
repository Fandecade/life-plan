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
    tempDir = await Directory.systemTemp.createTemp('life_planner_action_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    habit = await bootstrap.foggHabits.create(
      anchorPrompt: '下班回家后',
      tinyBehavior: '换上跑鞋',
      frictions: const FrictionProfile(
        time: true,
        brain: true,
        energy: true,
      ),
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('习惯菜单可打开行动线视图，推演后应用生成新配方', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('福格习惯').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('更多'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('行动线诊断与推演'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('行动线门槛'), findsOneWidget);
    expect(find.text('曲线弧度'), findsOneWidget);
    expect(find.textContaining('行动线之下'), findsOneWidget);

    await tester.tap(find.text('缩小微行为（右移）'));
    await tester.pump();
    await tester.tap(find.text('强化锚点 / 庆祝（上移）'));
    await tester.pump();

    expect(find.text('推演：会触发'), findsOneWidget);

    await tester.tap(find.text('应用并生成新配方'));
    await settle(tester);

    expect(find.text('行动线门槛'), findsNothing);

    final FoggHabit updated = bootstrap.foggHabits.byId(habit.id)!;
    expect(updated.frictions.count, 2, reason: '右移推演应削减一项阻力');
    expect(updated.celebration, isNotEmpty);
    expect(bootstrap.habitRecipeVersions.forHabit(habit.id).length, 1);
  });
}