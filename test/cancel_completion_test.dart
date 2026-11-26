import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/utils/date_utils.dart';
import 'package:life_planner/core/widgets/app_card.dart';
import 'package:life_planner/core/widgets/state_views.dart';
import 'package:life_planner/modules/time_box/day_todo_view.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late ActionItem task;
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
    tempDir = await Directory.systemTemp.createTemp('life_planner_cancel');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    task = await bootstrap.actions.create(
      title: '取消完成验证',
      scheduledDate: AppDate.startOfDay(DateTime.now()),
    );
    habit = await bootstrap.foggHabits.create(
      anchorPrompt: '晚饭后',
      tinyBehavior: '收拾桌面 1 分钟',
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> openModule(WidgetTester tester, String title) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(title).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('任务已完成再次点击圆点需确认，可保持或取消', (
    WidgetTester tester,
  ) async {
    await openModule(tester, '时间盒');

    Finder rowCheck() {
      final Finder title = find.descendant(
        of: find.byType(DayTodoView),
        matching: find.text('取消完成验证'),
      );
      final Finder row = find
          .ancestor(of: title.first, matching: find.byType(AppCard))
          .first;
      return find.descendant(
        of: row,
        matching: find.byType(AppCheckCircle),
      );
    }

    await tester.tap(rowCheck());
    await settle(tester);
    expect(bootstrap.actions.byId(task.id)!.isCompleted, isTrue);

    // 再次点击不等于直接回退，而是先确认。
    await tester.tap(rowCheck());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('取消完成？'), findsOneWidget);

    await tester.tap(find.text('保持完成'));
    await settle(tester);
    expect(
      bootstrap.actions.byId(task.id)!.isCompleted,
      isTrue,
      reason: '选择保持后不应回退完成状态',
    );

    await tester.tap(rowCheck());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('取消完成'));
    await settle(tester);
    expect(bootstrap.actions.byId(task.id)!.isCompleted, isFalse);
  });

  testWidgets('微习惯已打卡再次点击需确认，确认后才撤销', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() => bootstrap.habitService.checkIn(habit));
    await openModule(tester, '福格习惯');

    Finder habitCheck() {
      final Finder card = find
          .ancestor(
            of: find.text('收拾桌面 1 分钟'),
            matching: find.byType(AppCard),
          )
          .first;
      return find.descendant(
        of: card,
        matching: find.byType(AppCheckCircle),
      );
    }

    expect(bootstrap.habitService.isDoneToday(habit), isTrue);

    await tester.tap(habitCheck());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('取消今天的打卡？'), findsOneWidget);

    await tester.tap(find.text('保持打卡'));
    await settle(tester);
    expect(
      bootstrap.habitService.isDoneToday(habit),
      isTrue,
      reason: '选择保持后打卡记录应保留',
    );

    await tester.tap(habitCheck());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('取消打卡'));
    await settle(tester);
    expect(bootstrap.habitService.isDoneToday(habit), isFalse);
  });
}