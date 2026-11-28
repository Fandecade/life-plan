import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/theme/ui_style.dart';
import 'package:life_planner/core/widgets/app_card.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_ui_refresh');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    // 在真实异步环境中预置新版，避免测试内 await Hive 写盘。
    await bootstrap.uiStyle.setStyle(AppUiStyle.refresh);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('手机新版底栏为 5 项 + 更多', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(bootstrap.uiStyle.style, AppUiStyle.refresh);
    expect(find.text('主页'), findsWidgets);
    expect(find.text('时间盒'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(find.text('福格习惯'), findsNothing);
  });

  testWidgets('简洁/新版切换、主题色与降低透明效果', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('界面风格').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('简洁'), findsOneWidget);
    expect(find.text('新版'), findsOneWidget);

    await tester.tap(find.text('简洁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(bootstrap.uiStyle.style, AppUiStyle.flat);

    await tester.tap(find.text('新版'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(bootstrap.uiStyle.style, AppUiStyle.refresh);
    expect(find.byType(AppCard), findsWidgets);

    await tester.tap(find.byTooltip('柠檬'));
    await tester.pump();
    expect(bootstrap.uiStyle.accent, AppAccentTheme.citrus);

    final Finder glassRow = find
        .ancestor(of: find.text('降低透明效果'), matching: find.byType(Row))
        .first;
    final Finder glassSwitch = find.descendant(
      of: glassRow,
      matching: find.byType(Switch),
    );

    await tester.tap(glassSwitch);
    await tester.pump();
    expect(bootstrap.uiStyle.glassEnabled, isFalse);

    await tester.tap(glassSwitch);
    await tester.pump();
    expect(bootstrap.uiStyle.glassEnabled, isTrue);
  });
}
