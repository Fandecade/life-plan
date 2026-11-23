import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/review_service.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late TimeBlock block;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_review_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    final DateTime today = AppDate.startOfDay(DateTime.now());
    block = await bootstrap.timeBlocks.schedule(
      title: '复盘UI未完成块',
      startAt: today.add(const Duration(minutes: 5)),
      durationMinutes: 30,
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> openReview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('及时复盘').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('复盘页展示四周期、数据看板与引导问答', (WidgetTester tester) async {
    await openReview(tester);

    expect(find.text('日复盘'), findsOneWidget);
    expect(find.text('周复盘'), findsOneWidget);
    expect(find.text('月复盘'), findsOneWidget);
    expect(find.text('年复盘'), findsOneWidget);

    expect(find.text('时间投入'), findsOneWidget);
    expect(find.text('任务与学习'), findsOneWidget);
    expect(find.text('微习惯节律'), findsOneWidget);
    expect(find.text('能力精力分布'), findsOneWidget);

    expect(find.text('今日亮点（1 句）'), findsOneWidget);
    expect(find.text('明日最关键 1–3 件事'), findsOneWidget);
    expect(find.textContaining('待校准事项'), findsOneWidget);

    await tester.tap(find.text('周复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('本周有效模式（Keep）'), findsOneWidget);
    expect(find.text('If–Then 预案'), findsOneWidget);
  });

  testWidgets('未完成时间块可一键排入明日并划掉', (WidgetTester tester) async {
    await openReview(tester);

    expect(find.text('复盘UI未完成块'), findsWidgets);
    final Finder push = find.text('排入明日').first;
    await tester.ensureVisible(push);
    await tester.pump();
    await tester.tap(push);
    await settle(tester);

    final TimeBlock moved = bootstrap.timeBlocks.byId(block.id)!;
    expect(AppDate.isSameDay(moved.startAt, DateTime.now()), isFalse);
    expect(
      AppDate.isSameDay(
        moved.startAt,
        DateTime.now().add(const Duration(days: 1)),
      ),
      isTrue,
      reason: '应顺延到明日同一时刻',
    );
    expect(find.text('已处理'), findsWidgets);
  });

  testWidgets('引导问答自动保存，标记完成后周期状态更新', (
    WidgetTester tester,
  ) async {
    await openReview(tester);

    await tester.enterText(
      find.byType(TextField).first,
      '今天推进了复盘模块',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);

    final ReviewWindow window =
        ReviewWindow.of(ReviewPeriodType.daily, DateTime.now());
    final ReviewLog saved =
        bootstrap.reviewLogs.forPeriod(window.type, window.periodKey)!;
    expect(saved.winsText, contains('复盘模块'));

    await tester.tap(find.text('标记完成'));
    await settle(tester);

    expect(
      bootstrap.reviewLogs
          .forPeriod(window.type, window.periodKey)!
          .isCompleted,
      isTrue,
    );
    expect(find.text('已完成'), findsWidgets);
  });
}