import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late TimeBlock block;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_day_drag');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    final DateTime day = AppDate.startOfDay(DateTime.now());
    block = await bootstrap.timeBlocks.schedule(
      title: '长按拖动验证块',
      startAt: DateTime(day.year, day.month, day.day, 9),
      durationMinutes: 30,
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 16; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('手机端长按时间块可整体拖动，拉伸与居中样式保留', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('时间安排'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Finder blockFinder =
        find.byKey(ValueKey<String>('time-block-${block.id}'));
    expect(blockFinder, findsOneWidget);
    await tester.ensureVisible(blockFinder);
    await tester.pump();

    final Text title = tester.widget<Text>(
      find.descendant(
        of: blockFinder,
        matching: find.text('长按拖动验证块'),
      ),
    );
    expect(title.textAlign, TextAlign.center);

    expect(
      find.byKey(ValueKey<String>('resize-block-${block.id}')),
      findsOneWidget,
      reason: '右下角拉伸入口必须保留',
    );

    final DateTime beforeStart = block.startAt;
    final int beforeMinutes = block.plannedMinutes;

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(blockFinder));
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveBy(const Offset(0, 72));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    await settle(tester);

    final TimeBlock updated = bootstrap.timeBlocks.byId(block.id)!;
    expect(updated.startAt, isNot(beforeStart), reason: '长按拖动应改变开始时间');
    expect(
      updated.plannedMinutes,
      beforeMinutes,
      reason: '整体移动不改变时长',
    );
    expect(
      updated.startAt.minute % 15,
      0,
      reason: '落点应吸附到 15 分钟',
    );
  });
}