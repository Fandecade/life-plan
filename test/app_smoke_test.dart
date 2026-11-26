import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/app.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/app/shell/detail_drawer.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/state/ui_controller.dart';
import 'package:life_planner/core/utils/date_utils.dart';
import 'package:life_planner/modules/vision_map/vision_nodes.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_test');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    // 预置一个当天截止的任务，供月视图 DDL 徽章断言。
    await bootstrap.actions.create(
      title: '阶段验收准备',
      dueDate: DateTime.now(),
    );
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('桌面端骨架渲染 + 任务池添加任务闭环', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    // 插件注册中心驱动的导航入口
    expect(find.text('人生规划'), findsWidgets);
    expect(find.text('时间盒'), findsWidgets);
    expect(find.text('输出式学习'), findsWidgets);
    expect(find.text('福格习惯'), findsWidgets);
    expect(find.text('及时复盘'), findsWidgets);
    expect(find.text('设置'), findsWidgets);

    // 打开任务池并写入一件新任务
    await tester.tap(find.text('任务池').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '写一条验收用例');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('写一条验收用例'), findsWidgets);
    final List<ActionItem> items = bootstrap.actions.all;
    expect(
      items.any((ActionItem item) => item.title == '写一条验收用例'),
      isTrue,
      reason: '行动单元应写入仓储并即时刷新界面',
    );
  });

  testWidgets('导图渲染三级节点，点击任务卡打开详情抽屉', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    // 默认落在主页，先切到人生规划。
    await tester.tap(find.text('人生规划').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 愿景 → 能力 → 任务 三级节点同时存在
    expect(find.text('成为能独立交付产品的创造者'), findsWidgets);
    expect(find.text('产品设计与实现'), findsWidgets);
    expect(find.text('结构化表达与输出'), findsWidgets);
    expect(find.byType(TaskNodeCard), findsWidgets);
    expect(find.text('愿景'), findsWidgets);
    expect(find.text('能力'), findsWidgets);
    expect(find.text('任务'), findsWidgets);

    await tester.tap(find.byType(TaskNodeCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(ActionItemDetailDrawer), findsOneWidget);
    expect(find.text('执行模式'), findsOneWidget);
    expect(find.text('时间盒'), findsWidgets);
  });

  testWidgets('选中任务后按 Tab 创建子任务', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    await tester.tap(find.text('人生规划').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final int before = bootstrap.actions.all.length;

    await tester.tap(find.byType(TaskNodeCard).first);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final List<ActionItem> all = bootstrap.actions.all;
    expect(all.length, before + 1, reason: 'Tab 应在选中任务下创建子任务');
    final List<ActionItem> subtasks =
        all.where((ActionItem item) => item.parentId != null).toList();
    expect(subtasks, hasLength(1));
    expect(subtasks.first.title, '新子任务');
    expect(find.text('子任务'), findsWidgets, reason: '节点需显示类型标签');
  });

  testWidgets('空格打开节点详情，Enter 创建同级任务', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    await tester.tap(find.text('人生规划').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 愿景卡：空格打开节点的编辑详情，而不是就地改名
    await tester.tap(find.byType(VisionNodeCard).first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('编辑愿景'), findsOneWidget, reason: '空格应打开节点详情');
    expect(
      find.descendant(
        of: find.byType(VisionNodeCard).first,
        matching: find.byType(TextField),
      ),
      findsNothing,
      reason: '空格不应进入就地编辑',
    );

    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 任务卡：Enter 创建同级任务
    final int before = bootstrap.actions.all.length;
    await tester.tap(find.byType(TaskNodeCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      bootstrap.actions.all.length,
      before + 1,
      reason: 'Enter 应在选中节点旁创建同级任务',
    );
  });

  testWidgets('折叠能力后任务节点从画布移除，展开后恢复', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    await tester.tap(find.text('人生规划').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final int before = find.byType(TaskNodeCard).evaluate().length;
    expect(before, greaterThanOrEqualTo(3));

    await tester.tap(find.byTooltip('折叠任务').first);
    await tester.pumpAndSettle();
    expect(find.byType(TaskNodeCard).evaluate().length, lessThan(before));

    // 恢复展开，避免污染其他用例
    await tester.tap(find.byTooltip('展开任务').first);
    await tester.pumpAndSettle();
    expect(find.byType(TaskNodeCard).evaluate().length, before);
  });

  testWidgets('关闭模块后导航入口随之移除', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(find.text('福格习惯'), findsWidgets);
    await tester.runAsync(
      () => bootstrap.modules.setEnabled('fogg_habit', false),
    );
    await tester.pumpAndSettle();

    expect(bootstrap.modules.isEnabled('fogg_habit'), isFalse);
    expect(find.text('福格习惯'), findsNothing);
    expect(
      bootstrap.modules.detailSlotModules
          .any((module) => module.id == 'fogg_habit'),
      isFalse,
      reason: '停用模块后详情抽屉扩展槽位也必须消失',
    );
  });

  testWidgets('时间盒四级视图切换与时间块渲染', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('待排期'), findsOneWidget);
    await tester.tap(find.text('时间安排'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('08:00'), findsWidgets);

    final List<TimeBlock> todayBlocks = bootstrap.timeBlocks.all
        .where(
          (TimeBlock block) => AppDate.isSameDay(block.startAt, DateTime.now()),
        )
        .toList();
    expect(todayBlocks, isNotEmpty, reason: '示例数据应包含今日时间块');
    expect(
      find.byKey(ValueKey<String>('time-block-${todayBlocks.first.id}')),
      findsWidgets,
    );

    // 在时间轴上拖拽圈选 2 小时，再从人生规划任务中选择并排期
    final Rect trackRect = tester.getRect(
      find.byKey(const ValueKey<String>('time-track')),
    );
    final TestGesture selectGesture = await tester.startGesture(
      Offset(trackRect.left + 80, trackRect.top + 7 * 60),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await selectGesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await selectGesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('安排任务'), findsOneWidget);

    final ActionItem pick = bootstrap.actions.inboxItems.first;
    await tester.tap(find.byKey(ValueKey<String>('task-option-${pick.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final TimeBlock? created = bootstrap.timeBlocks.forActionItem(pick.id);
    expect(created, isNotNull, reason: '选择任务后应在圈选位置生成时间块');
    expect(created!.plannedMinutes, 120, reason: '时长应等于圈选的时间格');

    // 拖右下角手柄缩短，验证以 15 分钟为单位
    await tester.drag(
      find.byKey(ValueKey<String>('resize-block-${created.id}')),
      const Offset(0, -70),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final int duration = bootstrap.timeBlocks.byId(created.id)!.plannedMinutes;
    expect(duration % 15, 0, reason: '拉伸以 15 分钟为单位');
    expect(duration, lessThan(120), reason: '向上拉伸应缩短时长');

    // 完成联动改由 schedule_sync_test.dart 在服务层验证，
    // 避免 widget 测试的 fake async 环境等待真实 I/O。
    await tester.tap(find.text('周'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('周一'), findsOneWidget);


    await tester.tap(find.text('月'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('总投入'), findsOneWidget);
    expect(find.textContaining('DDL'), findsWidgets);

    await tester.tap(find.text('年'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('12月'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('安排记录仅在时间盒出现并可跳转到对应位置', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LifePlannerApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    // 人生规划页不出现「安排记录」
    expect(find.byTooltip('安排记录 · 点击查看并跳转'), findsNothing);

    await tester.tap(find.text('时间盒').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Finder trigger = find.byTooltip('安排记录 · 点击查看并跳转');
    expect(trigger, findsOneWidget, reason: '安排记录按钮只出现在时间盒');

    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final List<TimeBlock> blocks = List<TimeBlock>.from(bootstrap.timeBlocks.all)
      ..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));
    expect(blocks, isNotEmpty);

    final TimeBlock target = blocks.first;
    final Finder row =
        find.byKey(ValueKey<String>('schedule-row-${target.id}'));
    expect(row, findsOneWidget, reason: '安排记录面板应列出时间块');

    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('待排期'), findsOneWidget, reason: '跳转后应落在时间盒日视图');
    expect(
      find.textContaining(AppDate.monthDayLabel(target.startAt)),
      findsWidgets,
      reason: '日视图应切到目标日期',
    );

    // 让目标块的高亮计时器结束，避免遗留 pending timer。
    await tester.pump(const Duration(seconds: 2));
  });

  test('UiController 保证任务池与详情抽屉互斥', () {
    final UiController ui = UiController();
    ui.openInbox();
    expect(ui.inboxOpen, isTrue);

    ui.openDetail('item-1');
    expect(ui.detailOpen, isTrue);
    expect(ui.inboxOpen, isFalse);

    ui.setRoute('/time-box');
    expect(ui.detailOpen, isFalse);
    expect(ui.currentRoute, '/time-box');
  });
}