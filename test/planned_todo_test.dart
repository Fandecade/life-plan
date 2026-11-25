import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/utils/date_utils.dart';
import 'package:life_planner/core/widgets/app_card.dart';
import 'package:life_planner/app/shell/inbox_panel.dart';
import 'package:life_planner/core/widgets/state_views.dart';
import 'package:life_planner/modules/time_box/day_todo_view.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late ActionItem todoA;
  late ActionItem todoB;
  late ActionItem todoC;
  late ActionItem todoD;
  late ActionItem detailTask;
  late ActionItem inboxTask;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_planned_todo');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    final DateTime today = AppDate.startOfDay(DateTime.now());
    todoA = await bootstrap.actions.create(
      title: '待办甲',
      scheduledDate: today,
      estimatedMinutes: 30,
    );
    todoB = await bootstrap.actions.create(
      title: '待办乙',
      scheduledDate: today,
    );
    todoC = await bootstrap.actions.create(
      title: '待办丙',
      scheduledDate: today,
    );
    todoD = await bootstrap.actions.create(
      title: '待办丁',
      scheduledDate: today,
    );
    final TimeBlock block = await bootstrap.timeBlocks.schedule(
      title: '待办丁',
      startAt: DateTime(today.year, today.month, today.day, 10),
      durationMinutes: 30,
      actionItemId: todoD.id,
    );
    await bootstrap.timeBlocks.setCompleted(block.id, true);

    final Capability capability = bootstrap.capabilities.all.first;
    detailTask = await bootstrap.actions.create(
      title: '详情排期任务',
      capabilityId: capability.id,
    );
    inboxTask = await bootstrap.actions.create(title: '任务池排期任务');
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> openModule(WidgetTester tester, String title) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(title).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('日视图显示今日待办并可勾选完成', (WidgetTester tester) async {
    await openModule(tester, '时间盒');

    expect(find.textContaining('今日待办 ·'), findsOneWidget);
    expect(find.text('待办甲'), findsWidgets);
    expect(find.text('待办乙'), findsWidgets);

    await tester.tap(
      find
          .descendant(
            of: find.byType(DayTodoView),
            matching: find.byType(AppCheckCircle),
          )
          .first,
    );
    await settle(tester);

    final ActionItem? a = bootstrap.actions.byId(todoA.id);
    final ActionItem? b = bootstrap.actions.byId(todoB.id);
    expect((a?.isCompleted ?? false) || (b?.isCompleted ?? false), isTrue);

    // 已完成项保留在今日待办（划线），已定时间区包含已完成块。
    expect(find.text('待办甲'), findsWidgets);
    expect(find.textContaining('未定时间 ·'), findsOneWidget);
    expect(find.textContaining('已定时间 ·'), findsOneWidget);
    expect(find.text('待办丁'), findsWidgets);
  });

  testWidgets('排期可只定日期，不生成时间块', (WidgetTester tester) async {
    await openModule(tester, '及时复盘');
    await tester.pump(const Duration(milliseconds: 200));

    final Finder todoText = find.textContaining('今日待办：待办丙');
    expect(todoText, findsWidgets);
    final Finder row = find.ancestor(
      of: todoText.first,
      matching: find.byType(Row),
    ).first;
    await tester.tap(
      find.descendant(of: row, matching: find.text('安排时间')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('安排待办'), findsOneWidget);
    await tester.tap(find.text('只安排到这一天'));
    await tester.pump();
    expect(find.text('只定日期（不选时段）'), findsOneWidget);
    await tester.tap(find.text('确认安排'));
    await settle(tester);

    expect(
      bootstrap.timeBlocks.blocksForActionItem(todoC.id),
      isEmpty,
      reason: '只定日期不应生成时间块',
    );
    final ActionItem updated = bootstrap.actions.byId(todoC.id)!;
    expect(updated.scheduledDate, isNotNull);
    expect(
      AppDate.isSameDay(updated.scheduledDate!, DateTime.now()),
      isTrue,
    );
  });

  testWidgets('详情排期日历可只安排到这一天', (WidgetTester tester) async {
    await openModule(tester, '人生规划');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('详情排期任务').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Finder scheduleButton = find.text('排入时间盒');
    await tester.ensureVisible(scheduleButton);
    await tester.pump();
    await tester.tap(scheduleButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('排入时间盒'), findsWidgets);
    expect(find.text('只安排到这一天'), findsOneWidget);

    await tester.tap(find.text('只安排到这一天'));
    await settle(tester);

    final ActionItem updated = bootstrap.actions.byId(detailTask.id)!;
    expect(updated.scheduledDate, isNotNull);
    expect(
      AppDate.isSameDay(updated.scheduledDate!, DateTime.now()),
      isTrue,
    );
    expect(
      bootstrap.timeBlocks.blocksForActionItem(detailTask.id),
      isEmpty,
      reason: '只定日期不应生成时间块',
    );
  });

  testWidgets('任务池的排入时间盒也支持只安排到这一天', (WidgetTester tester) async {
    await openModule(tester, '时间盒');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('任务池').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Finder panelScroll = find
        .descendant(
          of: find.byType(InboxPanel),
          matching: find.byType(Scrollable),
        )
        .first;
    final Finder inboxTitle = find.descendant(
      of: find.byType(InboxPanel),
      matching: find.text('任务池排期任务'),
    );
    for (int i = 0; i < 8; i++) {
      if (tester.any(inboxTitle)) break;
      await tester.drag(panelScroll, const Offset(0, -200));
      await tester.pump();
    }
    await tester.pump();

    final Finder row = find
        .ancestor(
          of: inboxTitle.first,
          matching: find.byType(AppCard),
        )
        .first;
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('排入时间盒')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('排入时间盒'), findsWidgets);
    await tester.tap(find.text('只安排到这一天'));
    await settle(tester);

    final ActionItem updated = bootstrap.actions.byId(inboxTask.id)!;
    expect(updated.scheduledDate, isNotNull);
    expect(
      bootstrap.timeBlocks.blocksForActionItem(inboxTask.id),
      isEmpty,
    );
  });

  testWidgets('日视图三选一：待办 / 微习惯 / 时间安排', (WidgetTester tester) async {
    await openModule(tester, '时间盒');

    expect(find.byType(DayTodoView), findsOneWidget);

    await tester.tap(find.text('时间安排'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('time-track')),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('今日微习惯'));
    await tester.pump();
    expect(find.text('今天还没有微习惯'), findsOneWidget);

    await tester.tap(find.textContaining('今日待办'));
    await tester.pump();
    expect(find.byType(DayTodoView), findsOneWidget);
  });

  testWidgets('复盘列出今日待办并可顺延到明天', (WidgetTester tester) async {
    await openModule(tester, '及时复盘');
    await tester.pump(const Duration(milliseconds: 200));

    final Finder todoText = find.textContaining('今日待办：待办乙');
    expect(todoText, findsWidgets);

    final Finder row = find.ancestor(
      of: todoText.first,
      matching: find.byType(Row),
    ).first;
    final Finder more = find.descendant(
      of: row,
      matching: find.byTooltip('更多处理'),
    );
    await tester.tap(more);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('顺延到明天'));
    await settle(tester);

    final ActionItem updated = bootstrap.actions.byId(todoB.id)!;
    expect(
      AppDate.isSameDay(
        updated.scheduledDate!,
        DateTime.now().add(const Duration(days: 1)),
      ),
      isTrue,
    );
  });
}
