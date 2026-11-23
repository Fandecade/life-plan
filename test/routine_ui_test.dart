import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_routine_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('时间盒可打开固定安排并新建固定项', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('固定安排').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('新建'), findsOneWidget);
    expect(find.text('周一'), findsWidgets);

    await tester.tap(find.text('新建'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('新建固定项'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.text('生效星期'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-title')),
      '午饭与午休',
    );
    await tester.pump();
    await tester.tap(find.text('创建'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();

    expect(
      bootstrap.weeklyRoutines.all.any(
        (WeeklyRoutine routine) => routine.title == '午饭与午休',
      ),
      isTrue,
      reason: '固定项应写入本地模板',
    );
  });
}