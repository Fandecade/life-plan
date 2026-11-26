import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/reminder_service.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;
  late DateTime today;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_reminder');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
    today = AppDate.startOfDay(DateTime.now());
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  DateTime at(int hour, int minute) =>
      DateTime(today.year, today.month, today.day, hour, minute);

  List<ReminderEvent> matching(String title, DateTime now) => bootstrap.reminders
      .tick(now: now)
      .where((ReminderEvent event) => event.title.contains(title))
      .toList(growable: false);

  test('时间盒块按提前量提醒，且同一会话不重复', () async {
    await bootstrap.timeBlocks.schedule(
      title: '提醒测试块',
      startAt: at(10, 5),
      durationMinutes: 30,
    );

    final List<ReminderEvent> first = matching('提醒测试块', at(10, 0));
    expect(first, hasLength(1));
    expect(first.single.kind, ReminderKind.timeBlock);
    expect(first.single.subtitle, contains('10:05'));
    expect(first.single.canComplete, isTrue);

    expect(
      matching('提醒测试块', at(10, 0)),
      isEmpty,
      reason: '同一提醒只发送一次',
    );
  });

  test('已完成的时间块与开始前的任务不提醒', () async {
    final TimeBlock done = await bootstrap.timeBlocks.schedule(
      title: '提醒测试已完成',
      startAt: at(10, 6),
      durationMinutes: 20,
    );
    await bootstrap.timeBlocks.setCompleted(done.id, true);
    expect(matching('提醒测试已完成', at(10, 1)), isEmpty);

    await bootstrap.timeBlocks.schedule(
      title: '提醒测试未到点',
      startAt: at(10, 56),
      durationMinutes: 20,
    );
    expect(
      matching('提醒测试未到点', at(10, 0)),
      isEmpty,
      reason: '未进入提前量窗口不应提醒',
    );
  });

  test('同一开始时刻的多个块合并为一条提醒', () async {
    await bootstrap.timeBlocks.schedule(
      title: '合并提醒甲',
      startAt: at(11, 30),
      durationMinutes: 20,
    );
    await bootstrap.timeBlocks.schedule(
      title: '合并提醒乙',
      startAt: at(11, 30),
      durationMinutes: 20,
    );

    final List<ReminderEvent> events = matching('合并提醒', at(11, 25));
    expect(events, hasLength(1));
    expect(events.single.title, contains('合并提醒甲'));
    expect(events.single.title, contains('合并提醒乙'));
    expect(events.single.blockIds, hasLength(2));
    expect(events.single.subtitle, contains('2 项'));
  });

  test('只定日期任务在当天固定时刻提醒，已排时段的任务跳过', () async {
    await bootstrap.actions.create(
      title: '只定日期提醒任务',
      scheduledDate: today,
    );
    final ActionItem scheduled = await bootstrap.actions.create(
      title: '已排时段任务',
      scheduledDate: today,
    );
    await bootstrap.schedules.scheduleAction(scheduled, at(9, 30));

    final List<ReminderEvent> events = bootstrap.reminders.tick(now: at(9, 10));
    expect(
      events.where((ReminderEvent event) => event.kind == ReminderKind.dateOnlyTask),
      hasLength(1),
    );
    expect(
      events.any((ReminderEvent event) => event.title == '已排时段任务'),
      isFalse,
    );
  });

  test('微习惯仅在未打卡时汇总提醒一次', () async {
    final FoggHabit habit = await bootstrap.foggHabits.create(
      anchorPrompt: '午饭后',
      tinyBehavior: '微习惯提醒测试',
    );

    await bootstrap.habitService.checkIn(habit);
    expect(
      bootstrap.reminders
          .tick(now: at(20, 35))
          .where((ReminderEvent event) => event.kind == ReminderKind.habitDigest),
      isEmpty,
      reason: '全部完成时不应提醒',
    );

    await bootstrap.habitService.undoToday(habit);
    final List<ReminderEvent> due = bootstrap.reminders
        .tick(now: at(20, 36))
        .where((ReminderEvent event) => event.kind == ReminderKind.habitDigest)
        .toList();
    expect(due, hasLength(1));
    expect(due.single.pendingCount, greaterThan(0));
    expect(due.single.canComplete, isFalse);
  });

  test('稍后 10 分钟会推迟并在到点后重新提醒', () async {
    await bootstrap.timeBlocks.schedule(
      title: '稍后提醒测试',
      startAt: at(12, 5),
      durationMinutes: 30,
    );

    final ReminderEvent event = matching('稍后提醒测试', at(12, 0)).single;
    await bootstrap.reminders.snooze(
      event,
      now: at(12, 0),
      delay: const Duration(minutes: 10),
    );

    expect(
      matching('稍后提醒测试', at(12, 9)),
      isEmpty,
      reason: '延后未到点不应再次提醒',
    );
    expect(
      matching('稍后提醒测试', at(12, 11)),
      hasLength(1),
      reason: '延后到点后应重新提醒',
    );
  });

  test('关闭提醒后不再产生事件，重新开启恢复', () async {
    await bootstrap.reminderSettings.setEnabled(false);
    expect(
      bootstrap.reminders.tick(now: at(13, 0)),
      isEmpty,
    );
    await bootstrap.reminderSettings.setEnabled(true);
    await bootstrap.timeBlocks.schedule(
      title: '重新开启提醒测试',
      startAt: at(13, 10),
      durationMinutes: 20,
    );
    expect(
      matching('重新开启提醒测试', at(13, 5)),
      hasLength(1),
    );
  });
}