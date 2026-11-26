import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/theme/ui_style.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_refresh_smoke');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    await bootstrap.uiStyle.setStyle(AppUiStyle.refresh);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('新版下六个模块与时间盒时间安排均可渲染', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    for (final String title in <String>[
      '项目',
      '时间盒',
      '输出式学习',
      '福格习惯',
      '及时复盘',
      '设置',
      '人生规划',
    ]) {
      await tester.tap(find.text(title).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('时间安排'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('滚轮 / 拖动滚动 · 长按拖动圈选时间'), findsOneWidget);
  });
}