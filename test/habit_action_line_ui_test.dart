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

    expect(find.text('行动线门槛（环境阻力）'), findsOneWidget);
    expect(find.text('行动线弯曲度（动机敏锐度）'), findsOneWidget);
    expect(find.textContaining('行动线下方'), findsOneWidget);

    final Finder sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(4));

    final Rect abilityRect = tester.getRect(sliders.at(0));
    await tester.tapAt(
      Offset(abilityRect.left + abilityRect.width * 0.97, abilityRect.center.dy),
    );
    await tester.pump();

    final Rect motivationRect = tester.getRect(sliders.at(1));
    await tester.tapAt(
      Offset(
        motivationRect.left + motivationRect.width * 0.97,
        motivationRect.center.dy,
      ),
    );
    await tester.pump();

    expect(find.textContaining('行动线之上'), findsOneWidget);

    await tester.tap(find.text('应用并生成新配方'));
    await settle(tester);

    expect(find.textContaining('行动线门槛'), findsNothing);

    final FoggHabit updated = bootstrap.foggHabits.byId(habit.id)!;
    expect(updated.frictions.count, 0, reason: '能力值拉满应清空阻力');
    expect(updated.celebration, isNotEmpty);
    expect(bootstrap.habitRecipeVersions.forHabit(habit.id).length, 1);
  });

  testWidgets('行动线诊断作为页签嵌入，不占用弹窗', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('福格习惯').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('行动线诊断'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey<String>('action-line-canvas')),
      findsOneWidget,
    );
    expect(find.text('选择诊断习惯'), findsOneWidget);
    expect(find.text('应用并生成新配方'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('配方调整记录可右键删除', (WidgetTester tester) async {
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

    final int before =
        bootstrap.habitRecipeVersions.forHabit(habit.id).length;
    expect(before, greaterThanOrEqualTo(1));

    await tester.tap(find.text('v$before').first, buttons: kSecondaryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('删除该配方记录'), findsOneWidget);

    await tester.tap(find.text('删除该配方记录'));
    await settle(tester);

    expect(
      bootstrap.habitRecipeVersions.forHabit(habit.id).length,
      before - 1,
    );
  });
}