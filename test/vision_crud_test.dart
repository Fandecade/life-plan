import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/widgets/state_views.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late Vision pillVision;
  late Vision dragVision;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_vision_crud');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    pillVision = await bootstrap.visions.create(title: 'CRUD 胶囊愿景');
    dragVision = await bootstrap.visions.create(title: 'CRUD 拖动愿景');
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('新建愿景追加在末尾，支持前后移动', () async {
    final Vision a = await bootstrap.visions.create(title: 'CRUD A');
    final Vision b = await bootstrap.visions.create(title: 'CRUD B');

    final List<Vision> ordered = bootstrap.visions.ordered;
    expect(ordered.last.id, b.id, reason: '新建应排在末尾而不是第一位');
    expect(b.sortOrder, greaterThan(a.sortOrder));

    await bootstrap.visions.move(b.id, -1);
    final List<Vision> afterMove = bootstrap.visions.ordered;
    final int bIndex = afterMove.indexWhere((Vision v) => v.id == b.id);
    final int aIndex = afterMove.indexWhere((Vision v) => v.id == a.id);
    expect(bIndex, aIndex - 1, reason: '前移后应排在 A 之前');

    await bootstrap.visions.softDelete(b.id);
    await bootstrap.visions.softDelete(a.id);

    await bootstrap.visions.moveTo(b.id, 0);
  });

  test('拖动排序可移动到指定索引', () async {
    final Vision a = await bootstrap.visions.create(title: '排序 A');
    final Vision b = await bootstrap.visions.create(title: '排序 B');
    final Vision c = await bootstrap.visions.create(title: '排序 C');
    expect(bootstrap.visions.ordered.last.id, c.id);

    await bootstrap.visions.moveTo(c.id, 0);
    final List<Vision> after = bootstrap.visions.ordered;
    expect(after.first.id, c.id, reason: '拖到第一项应排在最前');
    expect(
      after.indexWhere((Vision v) => v.id == a.id),
      lessThan(after.indexWhere((Vision v) => v.id == b.id)),
      reason: '其余愿景的相对顺序应保持稳定',
    );

    await bootstrap.visions.softDelete(a.id);
    await bootstrap.visions.softDelete(b.id);
    await bootstrap.visions.softDelete(c.id);
  });

  testWidgets('愿景胶囊可拖动排序', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('人生规划').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Vision first = bootstrap.visions.ordered.first;
    final Finder source = find.text(dragVision.title).first;
    final Finder target = find.text(first.title).first;

    await tester.longPress(source);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('完成'), findsOneWidget, reason: '长按应进入编辑模式');

    final Offset from = tester.getCenter(source);
    final Offset to = tester.getCenter(target);
    final TestGesture gesture = await tester.startGesture(from);
    await tester.pump();
    for (int i = 1; i <= 8; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 8)!);
      await tester.pump();
    }
    await gesture.up();
    await settle(tester);

    expect(
      bootstrap.visions.ordered.first.id,
      dragVision.id,
      reason: '拖到第一位后应排在最前',
    );
    await tester.tap(find.text('完成'));
    await tester.pump();
  });

  testWidgets('长按愿景进入抖动编辑模式，显示删除叉号并可完成', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('人生规划').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.longPress(find.text('CRUD 拖动愿景').first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('完成'), findsOneWidget);
    expect(find.byTooltip('删除这个愿景'), findsWidgets);

    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('完成'), findsNothing);
    expect(find.byTooltip('删除这个愿景'), findsNothing);
  });

  testWidgets('愿景胶囊右键只保留删除', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('人生规划').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder pill = find.text('CRUD 胶囊愿景').first;
    expect(pill, findsOneWidget);

    await tester.tap(pill, buttons: kSecondaryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('删除这个愿景'), findsOneWidget);
    expect(find.text('前移'), findsNothing);

    await tester.tap(find.text('删除这个愿景'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('删除整个愿景？'), findsOneWidget);

    await tester.tap(find.text('删除').last);
    await settle(tester);

    expect(bootstrap.visions.byId(pillVision.id), isNull);
  });

  testWidgets('能力阶段成果可添加并标记达成', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('人生规划').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 前面用例可能切换过愿景：先切回带能力的愿景再操作。
    final Vision withCapabilities = bootstrap.visions.all.firstWhere(
      (Vision vision) => bootstrap.capabilities.all
          .any((Capability item) => item.visionId == vision.id),
    );
    await tester.tap(find.text(withCapabilities.title).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('更多操作').at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('阶段成果'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const ValueKey<String>('milestone-title')),
      '能独立解释核心概念',
    );
    await tester.pump();
    await tester.tap(find.text('添加'));
    await settle(tester);

    final Capability capability = bootstrap.capabilities.all.firstWhere(
      (Capability item) => item.milestones.isNotEmpty,
      orElse: () => bootstrap.capabilities.all.first,
    );
    expect(capability.milestones, isNotEmpty);
    expect(capability.milestones.first.title, contains('核心概念'));

    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(AppCheckCircle),
          )
          .first,
    );
    await settle(tester);
    expect(
      bootstrap.capabilities.byId(capability.id)!.achievedMilestones,
      1,
    );

    await tester.tap(find.text('完成'));
    await tester.pump();
  });

  testWidgets('愿景可从节点菜单删除，并连带清理能力与任务', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final Vision target = bootstrap.visions.ordered.first;
    final int before = bootstrap.visions.all.length;

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('人生规划').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('删除愿景'), findsWidgets);
    await tester.tap(find.text('删除愿景').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('删除整个愿景？'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await settle(tester);

    expect(bootstrap.visions.all.length, before - 1);
    expect(bootstrap.visions.byId(target.id), isNull);
    expect(
      bootstrap.capabilities
          .all
          .where((Capability item) => item.visionId == target.id)
          .toList(),
      isEmpty,
    );
  });
}