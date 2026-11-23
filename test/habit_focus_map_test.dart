import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late BehaviorCandidate draggable;
  late BehaviorCandidate edgeCase;
  late BehaviorCandidate twinA;
  late BehaviorCandidate twinB;
  late BehaviorCandidate tiny;
  late BehaviorCandidate hard;
  late BehaviorCandidate easy;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_focus_map');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    draggable = await bootstrap.behaviorCandidates.add(
      title: '饭后散步 1 分钟',
      impact: 4,
      effort: 2,
    );
    edgeCase = await bootstrap.behaviorCandidates.add(
      title: '睡前拉伸 30 秒',
      impact: 5,
      effort: 5,
    );
    twinA = await bootstrap.behaviorCandidates.add(
      title: '同档位候选甲',
      impact: 3,
      effort: 3,
    );
    twinB = await bootstrap.behaviorCandidates.add(
      title: '同档位候选乙',
      impact: 3,
      effort: 3,
    );
    tiny = await bootstrap.behaviorCandidates.add(
      title: '读',
      impact: 1,
      effort: 1,
    );
    hard = await bootstrap.behaviorCandidates.add(
      title: '每天写 2000 字',
      impact: 3,
      effort: 5,
    );
    easy = await bootstrap.behaviorCandidates.add(
      title: '喝一口水',
      impact: 3,
      effort: 1,
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> openFocusMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('福格习惯').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('新建习惯'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('拖动为连续定位：松手停在原地，不再跳到档位点', (
    WidgetTester tester,
  ) async {
    await openFocusMap(tester);

    final Finder node =
        find.byKey(ValueKey<String>('focus-node-${draggable.id}'));
    expect(node, findsOneWidget);

    final Offset before = tester.getCenter(node);
    const Offset delta = Offset(45, 40);
    await tester.drag(node, delta);
    await settle(tester);

    final Offset after = tester.getCenter(node);
    expect(
      (after - (before + delta)).distance,
      lessThan(4),
      reason: '松手位置应贴合手指终点，而不是吸附跳位',
    );

    final BehaviorCandidate moved =
        bootstrap.behaviorCandidates.byId(draggable.id)!;
    expect(moved.mapX, isNotNull, reason: '拖动后应记录连续坐标');
    expect(moved.mapY, isNotNull);
    expect(moved.impact, lessThan(4), reason: '下移应降低影响力档位');
  });

  testWidgets('向右拖动到最右为「易做」：effort 变为 1 且贴边', (
    WidgetTester tester,
  ) async {
    await openFocusMap(tester);

    final Finder node =
        find.byKey(ValueKey<String>('focus-node-${edgeCase.id}'));
    for (int i = 0; i < 5; i++) {
      await tester.drag(node, const Offset(150, 0));
      await settle(tester);
    }

    final BehaviorCandidate moved =
        bootstrap.behaviorCandidates.byId(edgeCase.id)!;
    expect(moved.effort, 1, reason: '最右侧代表最易做');
    expect(moved.impact, 5, reason: '水平拖动不应改变影响力档位');

    final Rect mapRect =
        tester.getRect(find.byKey(const ValueKey<String>('focus-map')));
    final Rect nodeRect = tester.getRect(node);
    expect(
      nodeRect.right,
      greaterThan(mapRect.right - 12),
      reason: '节点应贴近地图右侧边界',
    );
  });

  testWidgets('横轴方向：难做在左，易做在右', (WidgetTester tester) async {
    await openFocusMap(tester);

    final Offset hardCenter = tester.getCenter(
      find.byKey(ValueKey<String>('focus-node-${hard.id}')),
    );
    final Offset easyCenter = tester.getCenter(
      find.byKey(ValueKey<String>('focus-node-${easy.id}')),
    );
    expect(hardCenter.dx, lessThan(easyCenter.dx));
  });

  testWidgets('同档位节点自动散开，不再完全重合', (WidgetTester tester) async {
    await openFocusMap(tester);

    final Finder first = find.byKey(ValueKey<String>('focus-node-${twinA.id}'));
    final Finder second = find.byKey(ValueKey<String>('focus-node-${twinB.id}'));

    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getCenter(first), isNot(tester.getCenter(second)));
  });

  testWidgets('节点宽度随名称长度自适应，单字节点明显更窄', (
    WidgetTester tester,
  ) async {
    await openFocusMap(tester);

    final Finder tinyNode =
        find.byKey(ValueKey<String>('focus-node-${tiny.id}'));
    final Finder longNode =
        find.byKey(ValueKey<String>('focus-node-${twinA.id}'));

    expect(tinyNode, findsOneWidget);
    expect(longNode, findsOneWidget);

    final double tinyWidth = tester.getRect(tinyNode).width;
    final double longWidth = tester.getRect(longNode).width;

    expect(tinyWidth, lessThan(40), reason: '单字节点应贴合文字宽度');
    expect(longWidth, greaterThan(tinyWidth + 30), reason: '长名节点应更宽');
  });
}