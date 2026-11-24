import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_day_scroll');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('网格普通拖动是滚动，长按拖动才圈选时间', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder track = find.byKey(const ValueKey<String>('time-track'));
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.ancestor(of: track, matching: find.byType(Scrollable)).first,
    );
    final double before = scrollable.position.pixels;

    await tester.drag(track, const Offset(0, -180));
    await tester.pump();

    expect(
      scrollable.position.pixels,
      greaterThan(before),
      reason: '普通拖动应滚动时间轴，而不是圈选',
    );
    expect(find.text('安排任务'), findsNothing);

    final Offset start = tester.getCenter(track) + const Offset(0, 30);
    final TestGesture gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('安排任务'),
      findsOneWidget,
      reason: '长按后拖动才进入圈选排期',
    );
  });

  testWidgets('日视图时间网格支持滚轮滚动', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder track = find.byKey(const ValueKey<String>('time-track'));
    expect(track, findsOneWidget);

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.ancestor(of: track, matching: find.byType(Scrollable)).first,
    );
    final double before = scrollable.position.pixels;

    final Offset center = tester.getCenter(track);
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    await tester.sendEventToBinding(
      pointer.scroll(const Offset(0, 160)),
    );
    await tester.pump();

    expect(
      scrollable.position.pixels,
      greaterThan(before),
      reason: '滚轮落在时间网格上时也应滚动时间轴',
    );
  });
}