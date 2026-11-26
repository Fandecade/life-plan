import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/shell/desktop_side_nav.dart';
import 'package:life_planner/core/state/home_settings.dart';
import 'package:life_planner/modules/home/home_heatmap.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_home');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('默认落地主页并渲染核心卡片与热力图', (WidgetTester tester) async {
    await openApp(tester);

    expect(find.text('今天也按自己的节奏来'), findsOneWidget);
    expect(find.text('今日概览'), findsOneWidget);
    expect(find.text('热力图'), findsOneWidget);

    await tester.ensureVisible(find.byType(HomeHeatmap));
    await tester.pump();

    expect(find.byType(HomeHeatmap), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeHeatmap),
        matching: find.byType(InkWell),
      ),
      findsNWidgets(84),
      reason: '热力图应覆盖 12 周 × 7 天',
    );
  });

  testWidgets('设置里关闭主页卡片后主页不再显示', (WidgetTester tester) async {
    await openApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(DesktopSideNav),
        matching: find.text('设置'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('主页').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder row = find
        .ancestor(of: find.text('热力图'), matching: find.byType(Row))
        .first;
    final Finder toggle = find.descendant(of: row, matching: find.byType(Switch));
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(bootstrap.homeSettings.isEnabled(HomeCard.heatmap), isFalse);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(
      find.descendant(
        of: find.byType(DesktopSideNav),
        matching: find.text('主页'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('热力图'), findsNothing);
    expect(find.text('今天也按自己的节奏来'), findsOneWidget);
  });
}