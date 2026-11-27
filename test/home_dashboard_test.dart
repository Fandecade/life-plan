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
        matching: find.byIcon(Icons.tune_outlined),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('主页').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder row = find.byKey(
      const ValueKey<String>('home-card-heatmap'),
    );
    final Finder toggle =
        find.descendant(of: row, matching: find.byType(Switch));
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
        matching: find.byIcon(Icons.home_rounded),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('热力图'), findsNothing);
    expect(find.text('今天也按自己的节奏来'), findsOneWidget);
  });

  testWidgets('主页支持图表开关、排序、尺寸与快捷入口配置', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    // 图表默认关闭
    expect(find.text('近 14 天趋势'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(DesktopSideNav),
        matching: find.byIcon(Icons.tune_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('主页').last);
    await tester.pumpAndSettle();

    final Finder trendRow =
        find.byKey(const ValueKey<String>('home-card-trend'));
    await tester.ensureVisible(trendRow);
    await tester.pump();
    final Finder trendSwitch =
        find.descendant(of: trendRow, matching: find.byType(Switch));
    await tester.tap(trendSwitch);
    await tester.pump();
    expect(bootstrap.homeSettings.isEnabled(HomeCard.trend), isTrue);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DesktopSideNav),
        matching: find.byIcon(Icons.home_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('近 14 天趋势'), findsOneWidget);

    bootstrap.homeSettings.setOrder(<HomeCard>[
      HomeCard.trend,
      HomeCard.overview,
      HomeCard.heatmap,
      HomeCard.rhythm,
      HomeCard.todos,
      HomeCard.habits,
      HomeCard.shortcuts,
      HomeCard.weekly,
      HomeCard.capability,
    ]);
    bootstrap.homeSettings.setSize(
      HomeCard.overview,
      HomeCardSize.compact,
    );
    await tester.pump();

    expect(bootstrap.homeSettings.order.first, HomeCard.trend);
    expect(
      bootstrap.homeSettings.sizeOf(HomeCard.overview),
      HomeCardSize.compact,
    );

    bootstrap.homeSettings.setShortcutIds(<String>['time_box']);
    await tester.pump();
    expect(
      bootstrap.homeSettings.shortcutIds,
      <String>['time_box'],
    );
  });

  testWidgets('主页倒计时卡显示自定义、任务与过期状态', (
    WidgetTester tester,
  ) async {
    final a = (await tester.runAsync(
      () => bootstrap.countdowns.create(
        title: '发布作品集',
        targetAt: DateTime.now().add(const Duration(hours: 2)),
      ),
    ))!;
    final task = (await tester.runAsync(
      () => bootstrap.actions.create(
        title: '交付设计稿',
        dueDate: DateTime.now().add(const Duration(hours: 3)),
      ),
    ))!;
    final b = (await tester.runAsync(
      () => bootstrap.countdowns.create(
        title: '任务截止',
        sourceTaskId: task.id,
      ),
    ))!;
    final c = (await tester.runAsync(
      () => bootstrap.countdowns.create(
        title: '已过期倒计时',
        targetAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ))!;

    await openApp(tester);
    await tester.pump();
    await tester.ensureVisible(find.text('发布作品集'));

    expect(
      find.byKey(ValueKey<String>('countdown-card-${a.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('countdown-card-${b.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('countdown-card-${c.id}')),
      findsOneWidget,
    );
    expect(find.text('发布作品集'), findsOneWidget);
    expect(find.text('任务截止'), findsOneWidget);
    expect(find.text('已过期倒计时'), findsOneWidget);
    expect(find.text('已到期'), findsOneWidget);
  });
}