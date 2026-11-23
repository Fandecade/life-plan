import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/widgets/state_views.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  /// 等待 Hive 异步落盘与帧刷新完成。
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_habit_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('新建微习惯后可打卡，并显示温和点阵', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('福格习惯').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('新建习惯'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('新建微习惯'), findsOneWidget);
    expect(find.text('黄金区'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('habit-anchor')),
      '洗完澡后',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('habit-tiny')),
      '把明天要穿的衣服摆好',
    );
    await tester.pump();

    await tester.tap(find.text('创建习惯'));
    await tester.pump();
    await settle(tester);

    final FoggHabit habit = bootstrap.foggHabits.all.firstWhere(
      (FoggHabit item) => item.tinyBehavior == '把明天要穿的衣服摆好',
    );
    expect(habit.anchorPrompt, '洗完澡后');
    expect(habit.isActive, isTrue);
    expect(bootstrap.habitRecipeVersions.forHabit(habit.id).length, 1);

    expect(find.text('把明天要穿的衣服摆好'), findsOneWidget);
    expect(find.text('今天已完成'), findsNothing);

    await tester.tap(find.byType(AppCheckCircle).first);
    await tester.pump();
    await settle(tester);

    expect(bootstrap.habitService.isDoneToday(habit), isTrue);
    expect(find.text('今天已完成'), findsOneWidget);
    expect(find.text('超额'), findsNothing);
  });
}