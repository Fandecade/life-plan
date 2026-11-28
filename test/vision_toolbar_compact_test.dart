import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_toolbar');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('手机宽度下视图工具默认收起，展开时隐藏愿景列表', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('人生规划').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('视图工具'), findsOneWidget);
    expect(find.byTooltip('缩小'), findsNothing);

    final String visionTitle = bootstrap.visions.ordered.first.title;
    expect(find.text(visionTitle), findsWidgets);
    expect(find.byTooltip('新建愿景'), findsOneWidget);

    await tester.tap(find.byTooltip('视图工具'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byTooltip('缩小'), findsOneWidget);
    expect(find.byTooltip('收起视图工具'), findsOneWidget);
    expect(find.byTooltip('新建愿景'), findsNothing);
    // 手机默认纵向，因此按钮语义为「切换为横向」。
    expect(find.byTooltip('切换为横向布局'), findsOneWidget);

    await tester.tap(find.byTooltip('切换为横向布局'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byTooltip('切换为纵向布局'), findsOneWidget);

    await tester.tap(find.byTooltip('切换为纵向布局'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byTooltip('切换为横向布局'), findsOneWidget);

    await tester.tap(find.byTooltip('收起视图工具'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byTooltip('视图工具'), findsOneWidget);
    expect(find.text(visionTitle), findsWidgets);
    expect(find.byTooltip('新建愿景'), findsOneWidget);
  });

  testWidgets('平板/桌面宽度默认横向布局', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('人生规划').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('切换为纵向布局'), findsOneWidget);
    expect(find.byTooltip('切换为横向布局'), findsNothing);
  });
}
