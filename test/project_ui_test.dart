import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/widgets/state_views.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_project_ui');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('新建项目并在编辑中推进阶段', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('项目').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('还没有项目'), findsOneWidget);
    await tester.tap(find.text('新建项目'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const ValueKey<String>('project-title')),
      'UI 项目',
    );
    await tester.tap(find.text('保存项目'));
    await settle(tester);

    expect(find.text('UI 项目'), findsOneWidget);
    final Project project = bootstrap.projects.all.firstWhere(
      (Project item) => item.title == 'UI 项目',
    );

    await tester.tap(find.text('UI 项目'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('编辑项目'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('project-stage-input')),
      '阶段一',
    );
    await tester.tap(find.text('添加').first);
    await tester.pump();
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(AppCheckCircle),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.text('保存项目'));
    await settle(tester);

    final Project updated = bootstrap.projects.byId(project.id)!;
    expect(updated.stages.length, 1);
    expect(updated.doneStages, 1);
  });
}
