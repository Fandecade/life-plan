import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/shell/reminder_banner.dart';
import 'package:life_planner/app/theme/app_theme.dart';
import 'package:life_planner/core/services/reminder_service.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_reminder_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('任务提醒横幅显示时间并提供完成 / 稍后 / 查看', (
    WidgetTester tester,
  ) async {
    int completed = 0;
    int snoozed = 0;
    int opened = 0;
    int dismissed = 0;
    final ReminderEvent event = ReminderEvent(
      key: 'tb:ui-test',
      kind: ReminderKind.timeBlock,
      at: DateTime.now(),
      title: '梳理作品集结构',
      subtitle: '09:30 · 30m',
      startAt: DateTime.now(),
      blockIds: const <String>['block-1'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: ReminderBanner(
                event: event,
                onComplete: () => completed += 1,
                onSnooze: () => snoozed += 1,
                onOpen: () => opened += 1,
                onDismiss: () => dismissed += 1,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('提醒'), findsOneWidget);
    expect(find.text('梳理作品集结构'), findsOneWidget);
    expect(find.text('09:30 · 30m'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.tap(find.text('稍后 10 分钟'));
    await tester.tap(find.text('查看'));
    await tester.tap(find.byTooltip('关闭提醒'));

    expect(completed, 1);
    expect(snoozed, 1);
    expect(opened, 1);
    expect(dismissed, 1);
  });

  testWidgets('微习惯汇总横幅提供去打卡而不是完成', (
    WidgetTester tester,
  ) async {
    final ReminderEvent event = ReminderEvent(
      key: 'habit:ui-test',
      kind: ReminderKind.habitDigest,
      at: DateTime.now(),
      title: '今天还有 2 个微习惯未完成',
      subtitle: '20:30 · 去打卡',
      pendingCount: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: ReminderBanner(
                event: event,
                onComplete: () {},
                onSnooze: () {},
                onOpen: () {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('去打卡'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
  });

  testWidgets('设置页进入提醒设置并可分别开关', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('提醒'), findsWidgets);
    await tester.ensureVisible(find.text('提醒').last);
    await tester.tap(find.text('提醒').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('提醒设置'), findsOneWidget);
    expect(find.text('应用内提醒'), findsOneWidget);
    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('时间盒提前量'), findsOneWidget);
    expect(find.text('到点提醒'), findsOneWidget);

    final Finder row = find
        .ancestor(of: find.text('应用内提醒'), matching: find.byType(Row))
        .first;
    final Finder toggle =
        find.descendant(of: row, matching: find.byType(Switch));
    expect(toggle, findsOneWidget);
    expect(bootstrap.reminderSettings.inAppEnabled, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(bootstrap.reminderSettings.inAppEnabled, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(bootstrap.reminderSettings.inAppEnabled, isTrue);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('应用内提醒'), findsNothing);
    expect(find.text('提醒'), findsWidgets);
  });
}