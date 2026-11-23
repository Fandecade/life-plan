import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/action_line.dart';
import 'package:life_planner/core/services/habit_service.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_action_line');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('行动线：能力越高，所需动机越低', () {
    const ActionLineModel line = ActionLineModel();
    expect(
      line.requiredMotivation(2),
      greaterThan(line.requiredMotivation(8)),
    );
    expect(line.requiredMotivation(10), closeTo(3.0, 0.001));
  });

  test('曲率越大，同等能力下所需动机越低（更靠「易做」触发）', () {
    const ActionLineModel flat = ActionLineModel(curvature: 0.8);
    const ActionLineModel curved = ActionLineModel(curvature: 2.6);
    expect(
      curved.requiredMotivation(5),
      lessThan(flat.requiredMotivation(5)),
    );
  });

  test('落点映射：阻力多且完成少时落在行动线下方', () async {
    final FoggHabit habit = await bootstrap.foggHabits.create(
      anchorPrompt: '下班回家后',
      tinyBehavior: '换上跑鞋',
      frictions: const FrictionProfile(energy: true, brain: true),
    );
    final HabitService service = bootstrap.habitService;
    final ActionPoint point = service.currentActionPoint(habit);

    expect(point.ability, lessThan(7));
    expect(
      const ActionLineModel().isAbove(point),
      isFalse,
      reason: '阻力 2 项、近 7 天 0 次，应判定为卡阻',
    );
  });

  test('阻力削减优先级：体力 > 脑力 > 时间 > 日程习惯 > 金钱', () {
    const FrictionProfile all = FrictionProfile(
      time: true,
      money: true,
      energy: true,
      brain: true,
      routine: true,
    );
    final FrictionProfile reduced = frictionsForCount(all, 2);

    expect(reduced.count, 2);
    expect(reduced.energy, isFalse);
    expect(reduced.brain, isFalse);
    expect(reduced.time, isFalse);
    expect(reduced.routine, isTrue);
    expect(reduced.money, isTrue);
  });

  test('推演建议：线下且有阻力时先引向能力 / 右移', () async {
    final FoggHabit habit = await bootstrap.foggHabits.create(
      anchorPrompt: '午休后',
      tinyBehavior: '做 30 个俯卧撑',
      frictions: const FrictionProfile(time: true, energy: true),
    );
    final HabitService service = bootstrap.habitService;
    final ActionPoint point = service.currentActionPoint(habit);
    final String advice = actionLineAdvice(
      habit: habit,
      point: point,
      line: const ActionLineModel(),
      completedInLast7Days: 0,
    );

    expect(advice, contains('缩小一半'));
  });

  test('配方版本记录当时的 7 天完成率，可用于还原历史落点', () async {
    final FoggHabit habit = await bootstrap.foggHabits.create(
      anchorPrompt: '午饭后',
      tinyBehavior: '站 1 分钟',
      frictions: const FrictionProfile(time: true, energy: true),
    );
    final DateTime today = AppDate.startOfDay(DateTime.now());
    await bootstrap.habitLogs.logDay(habit.id, AppDate.dateKey(today));
    await bootstrap.habitLogs.logDay(
      habit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 2))),
    );

    final HabitRecipeVersion version =
        await bootstrap.habitService.saveRecipe(habit, note: '快照');
    expect(version.completedIn7Days, 2);

    final ActionPoint historical = habitActionPoint(
      habit.copyWith(frictions: const FrictionProfile()),
      version.completedIn7Days,
    );
    final ActionPoint current = habitActionPoint(habit, version.completedIn7Days);
    expect(
      historical.ability,
      greaterThan(current.ability),
      reason: '降阻后的历史落点应更靠右',
    );
  });

  test('应用推演会生成新版本并减少阻力、补强庆祝', () async {
    final FoggHabit habit = await bootstrap.foggHabits.create(
      anchorPrompt: '刷完牙后',
      tinyBehavior: '做 1 个深蹲',
      celebration: '',
      frictions: const FrictionProfile(time: true, brain: true, energy: true),
    );
    final HabitService service = bootstrap.habitService;

    final HabitRecipeVersion version = await service.applyActionLinePlan(
      habit,
      const ActionPoint(10, 8),
    );

    final FoggHabit updated = bootstrap.foggHabits.byId(habit.id)!;
    expect(version.revision, 1);
    expect(updated.frictions.count, 0, reason: '目标能力拉满应清空阻力');
    expect(updated.celebration, isNotEmpty, reason: '动机提升应补默认庆祝');
    expect(updated.motivationNote, contains('行动线推演'));
    expect(
      bootstrap.habitRecipeVersions.forHabit(habit.id).length,
      1,
      reason: '应用推演应留存配方版本',
    );
    expect(version.note, contains('行动线推演'));
  });
}