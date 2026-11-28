import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/shell/desktop_side_nav.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/utils/date_utils.dart';
import 'package:life_planner/core/widgets/app_card.dart';
import 'package:life_planner/core/widgets/state_views.dart';
import 'package:life_planner/modules/time_box/day_todo_view.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late ActionItem overdueA;
  late ActionItem overdueB;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_overdue_todo');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    final DateTime today = AppDate.startOfDay(DateTime.now());
    overdueA = await bootstrap.actions.create(
      title: '逾期任务甲',
      scheduledDate: today.subtract(const Duration(days: 2)),
    );
    overdueB = await bootstrap.actions.create(
      title: '逾期任务乙',
      scheduledDate: today.subtract(const Duration(days: 1)),
    );
    final ActionItem doneOverdue = await bootstrap.actions.create(
      title: '已完成逾期任务',
      scheduledDate: today.subtract(const Duration(days: 3)),
    );
    await bootstrap.actions.toggleCompleted(doneOverdue.id);
    await bootstrap.actions.create(
      title: '今日任务丙',
      scheduledDate: today,
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> openTimeBox(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final Finder sideNavItem = find.descendant(
      of: find.byType(DesktopSideNav),
      matching: find.text('时间盒'),
    );
    if (sideNavItem.evaluate().isNotEmpty) {
      await tester.tap(sideNavItem.last);
    } else {
      await tester.tap(find.text('时间盒').last);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder dayTodoText(String text) => find.descendant(
        of: find.byType(DayTodoView),
        matching: find.text(text),
      );

  Finder dayTodoCircleOf(String text) => find.descendant(
        of: find
            .ancestor(
              of: dayTodoText(text).first,
              matching: find.byType(AppCard),
            )
            .first,
        matching: find.byType(AppCheckCircle),
      );

  testWidgets('今日待办包含已过期分组且排除已完成逾期任务', (WidgetTester tester) async {
    await openTimeBox(tester);

    expect(find.byType(DayTodoView), findsOneWidget);
    expect(find.textContaining('已过期 · 2'), findsOneWidget);
    expect(dayTodoText('逾期任务甲'), findsOneWidget);
    expect(find.textContaining('逾期 2 天'), findsOneWidget);
    expect(find.textContaining('未定时间 ·'), findsOneWidget);
    expect(find.text('今日任务丙'), findsWidgets);
    expect(find.text('已完成逾期任务'), findsNothing);
  });

  testWidgets('逾期任务点圆圈弹出处理菜单并可标记完成', (WidgetTester tester) async {
    await openTimeBox(tester);

    await tester.tap(dayTodoCircleOf('逾期任务甲'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('标记完成'), findsOneWidget);
    expect(find.text('顺延到今天'), findsOneWidget);
    expect(find.text('改期'), findsOneWidget);

    await tester.tap(find.text('标记完成'));
    await settle(tester);

    expect(bootstrap.actions.byId(overdueA.id)!.isCompleted, isTrue);
    expect(find.textContaining('已过期 · 1'), findsOneWidget);
    final Finder doneHeader = find.descendant(
      of: find.byType(DayTodoView),
      matching: find.textContaining('已完成 ·'),
    );
    expect(doneHeader, findsOneWidget);
    expect(dayTodoText('逾期任务甲'), findsNothing);

    await tester.tap(doneHeader);
    await tester.pump();
    expect(dayTodoText('逾期任务甲'), findsOneWidget);
  });

  testWidgets('逾期任务可通过菜单顺延到今天', (WidgetTester tester) async {
    await openTimeBox(tester);

    await tester.tap(dayTodoCircleOf('逾期任务乙'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('顺延到今天'));
    await settle(tester);

    final ActionItem updated = bootstrap.actions.byId(overdueB.id)!;
    expect(
      AppDate.isSameDay(updated.scheduledDate!, DateTime.now()),
      isTrue,
      reason: '顺延应把计划日期改到今天',
    );
    expect(find.textContaining('已过期 ·'), findsNothing);
  });
}