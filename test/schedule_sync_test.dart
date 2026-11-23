import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_sync_test');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('时间块完成会同步行动单元完成，取消完成可回退', () async {
    final TimeBlock block = bootstrap.timeBlocks.all.firstWhere(
      (TimeBlock item) => item.actionItemId != null,
    );
    final String actionId = block.actionItemId!;

    await bootstrap.schedules.completeBlock(block);

    expect(bootstrap.timeBlocks.byId(block.id)!.isCompleted, isTrue);
    expect(bootstrap.actions.byId(actionId)!.isCompleted, isTrue);

    await bootstrap.schedules.uncompleteBlock(
      bootstrap.timeBlocks.byId(block.id)!,
    );

    expect(bootstrap.timeBlocks.byId(block.id)!.isCompleted, isFalse);
    expect(bootstrap.actions.byId(actionId)!.isCompleted, isFalse);
  });

  test('排期生成时间块并置为已排期，取消排期后回退到任务池', () async {
    final ActionItem item = bootstrap.actions.inboxItems.first;
    final DateTime start = DateTime(2026, 11, 23, 10);

    await bootstrap.schedules.scheduleAction(item, start);

    final TimeBlock? block = bootstrap.timeBlocks.forActionItem(item.id);
    expect(block, isNotNull);
    expect(block!.startAt, start);
    expect(block.plannedMinutes, item.estimatedMinutes ?? 30);
    expect(bootstrap.actions.byId(item.id)!.status, ActionItemStatus.scheduled);

    await bootstrap.schedules.unschedule(item.id);

    expect(bootstrap.timeBlocks.forActionItem(item.id), isNull);
    expect(bootstrap.actions.byId(item.id)!.status, ActionItemStatus.inbox);
  });
}