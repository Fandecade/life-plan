import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/shell/top_bar.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_top_bar');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
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

  testWidgets('时间盒顶栏：任务池在最右，安排记录紧邻其左', (
    WidgetTester tester,
  ) async {
    await openModule(tester, '时间盒');

    final Finder inbox = find.byTooltip('任务池 · ⌘K 呼出');
    final Finder schedule = find.byTooltip('安排记录 · 点击查看并跳转');
    expect(inbox, findsOneWidget);
    expect(schedule, findsOneWidget);

    final Rect inboxRect = tester.getRect(inbox);
    final Rect scheduleRect = tester.getRect(schedule);
    final Rect barRect = tester.getRect(find.byType(TopBar));
    expect(
      scheduleRect.right,
      lessThanOrEqualTo(inboxRect.left),
      reason: '安排记录应排在任务池左侧',
    );
    expect(
      inboxRect.right,
      greaterThan(barRect.right - 40),
      reason: '任务池入口应贴住顶部栏最右侧',
    );
    expect(
      inboxRect.right,
      greaterThan(barRect.right - 40),
      reason: '任务池入口应贴住顶部栏最右侧',
    );
  });

  testWidgets('其他模块顶栏：任务池在最右且不显示安排记录', (
    WidgetTester tester,
  ) async {
    await openModule(tester, '人生规划');

    final Finder inbox = find.byTooltip('任务池 · ⌘K 呼出');
    expect(inbox, findsOneWidget);
    expect(find.byTooltip('安排记录 · 点击查看并跳转'), findsNothing);

    final Rect inboxRect = tester.getRect(inbox);
    final Rect barRect = tester.getRect(find.byType(TopBar));
    expect(
      inboxRect.right,
      greaterThan(barRect.right - 40),
      reason: '任务池入口应贴住顶部栏最右侧',
    );
  });
}