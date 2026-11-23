import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_routine');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('固定项按周实例化，且不会重复生成', () async {
    final WeeklyRoutine routine = await bootstrap.weeklyRoutines.create(
      title: '午饭与午休',
      weekday: 1,
      startMinutes: 12 * 60,
      durationMinutes: 60,
    );
    final DateTime monday = DateTime(2026, 11, 23);
    final DateTime sunday = monday.add(const Duration(days: 6));

    await bootstrap.routines.ensureGenerated(monday, sunday);

    List<TimeBlock> blocks = bootstrap.timeBlocks.all
        .where((TimeBlock block) => block.routineId == routine.id)
        .toList();
    expect(blocks, hasLength(1));
    expect(blocks.first.startAt, DateTime(2026, 11, 23, 12));
    expect(blocks.first.plannedMinutes, 60);

    await bootstrap.routines.ensureGenerated(monday, sunday);
    blocks = bootstrap.timeBlocks.all
        .where((TimeBlock block) => block.routineId == routine.id)
        .toList();
    expect(blocks, hasLength(1), reason: '已生成的块不应重复创建');
  });

  test('单周跳过只影响该周，其他周照常生成', () async {
    final WeeklyRoutine routine = await bootstrap.weeklyRoutines.create(
      title: '固定例会',
      weekday: 3,
      startMinutes: 19 * 60,
      durationMinutes: 90,
    );
    final DateTime monday = DateTime(2026, 11, 30);
    final DateTime sunday = monday.add(const Duration(days: 6));
    await bootstrap.routines.ensureGenerated(monday, sunday);

    final TimeBlock block = bootstrap.timeBlocks.all.firstWhere(
      (TimeBlock item) => item.routineId == routine.id,
    );
    await bootstrap.routines.skipForWeek(block);

    expect(bootstrap.timeBlocks.byId(block.id), isNull);

    final DateTime nextMonday = monday.add(const Duration(days: 7));
    await bootstrap.routines.ensureGenerated(
      nextMonday,
      nextMonday.add(const Duration(days: 6)),
    );
    expect(
      bootstrap.timeBlocks.all
          .where((TimeBlock item) =>
              item.routineId == routine.id &&
              item.startAt.isAfter(sunday))
          .length,
      1,
      reason: '下一周仍应按原课表生成',
    );
  });

  test('恢复默认与删除固定项会同步清理生成块', () async {
    final WeeklyRoutine routine = await bootstrap.weeklyRoutines.create(
      title: '健身课',
      weekday: 4,
      startMinutes: 18 * 60,
      durationMinutes: 60,
    );
    final DateTime day = DateTime(2026, 12, 10);
    await bootstrap.routines.ensureGenerated(day, day);
    final TimeBlock block = bootstrap.timeBlocks.all.firstWhere(
      (TimeBlock item) => item.routineId == routine.id,
    );

    await bootstrap.routines.skipForWeek(block);
    expect(bootstrap.timeBlocks.byId(block.id), isNull);

    await bootstrap.routines.restoreDefault(block);
    expect(
      bootstrap.timeBlocks.all
          .where((TimeBlock item) => item.routineId == routine.id)
          .length,
      1,
    );

    final TimeBlock restored = bootstrap.timeBlocks.all.firstWhere(
      (TimeBlock item) => item.routineId == routine.id,
    );
    await bootstrap.routines.deleteRoutine(
      bootstrap.weeklyRoutines.byId(routine.id)!,
    );
    expect(bootstrap.weeklyRoutines.byId(routine.id), isNull);
    expect(bootstrap.timeBlocks.byId(restored.id), isNull);
  });

  test('编辑固定项后可刷新生成块并应用新时间', () async {
    final WeeklyRoutine routine = await bootstrap.weeklyRoutines.create(
      title: '通勤',
      weekday: 5,
      startMinutes: 8 * 60 + 30,
      durationMinutes: 30,
    );
    final DateTime day = DateTime(2026, 12, 11);
    await bootstrap.routines.ensureGenerated(day, day);

    await bootstrap.weeklyRoutines.save(
      routine.copyWith(startMinutes: 9 * 60, durationMinutes: 45),
    );
    await bootstrap.routines.refreshGenerated(routine.id);
    await bootstrap.routines.ensureGenerated(day, day);

    final TimeBlock block = bootstrap.timeBlocks.all.firstWhere(
      (TimeBlock item) => item.routineId == routine.id,
    );
    expect(block.startAt, DateTime(2026, 12, 11, 9));
    expect(block.plannedMinutes, 45);
  });
}