import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/habit_service.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_habit_test');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<FoggHabit> createHabit({
    String anchor = '早饭后',
    String tiny = '打开书读 1 页',
    FrictionProfile frictions = const FrictionProfile(),
  }) {
    return bootstrap.foggHabits.create(
      anchorPrompt: anchor,
      tinyBehavior: tiny,
      frictions: frictions,
    );
  }

  test('修改配方会留存版本，revision 单调递增', () async {
    final FoggHabit habit = await createHabit(tiny: '读 1 页');
    final HabitService service = bootstrap.habitService;

    final HabitRecipeVersion first = await service.saveRecipe(
      habit,
      note: '首次创建配方',
    );
    expect(first.revision, 1);
    expect(first.tinyBehavior, '读 1 页');

    final FoggHabit edited = habit.copyWith(tinyBehavior: '读 1 段');
    final HabitRecipeVersion second = await service.saveRecipe(
      edited,
      note: '更新配方',
    );
    expect(second.revision, 2);

    final List<HabitRecipeVersion> versions =
        bootstrap.habitRecipeVersions.forHabit(habit.id);
    expect(versions.length, 2);
    expect(versions.first.revision, 2);
    expect(versions.first.tinyBehavior, '读 1 段');
    expect(versions.last.tinyBehavior, '读 1 页');
    expect(bootstrap.foggHabits.byId(habit.id)!.tinyBehavior, '读 1 段');
  });

  test('超额完成只记增量，不抬高次日门槛', () async {
    final FoggHabit habit = await createHabit(tiny: '写 3 行');
    final HabitService service = bootstrap.habitService;
    final DateTime today = AppDate.startOfDay(DateTime.now());
    final String tomorrowKey =
        AppDate.dateKey(today.add(const Duration(days: 1)));

    await service.checkIn(habit);
    expect(service.isDoneToday(habit), isTrue);
    expect(service.isExtraToday(habit), isFalse);

    await service.checkIn(habit, extra: true);
    expect(service.isDoneToday(habit), isTrue);
    expect(service.isExtraToday(habit), isTrue);

    final List<bool> dots = service.dotPattern(habit);
    expect(dots.where((bool done) => done).length, 1);
    expect(dots.last, isTrue);

    expect(bootstrap.habitLogs.forDay(habit.id, tomorrowKey), isNull);
    final FoggHabit stored = bootstrap.foggHabits.byId(habit.id)!;
    expect(stored.tinyBehavior, '写 3 行');
    expect(stored.frictions.count, 0);

    await service.undoToday(habit);
    expect(service.isDoneToday(habit), isFalse);
  });

  test('连续天数温和计算：今天还没做时从昨天往前算', () async {
    final FoggHabit habit = await createHabit(anchor: '睡前', tiny: '铺好被子');
    final HabitService service = bootstrap.habitService;
    final DateTime today = AppDate.startOfDay(DateTime.now());

    await bootstrap.habitLogs.logDay(
      habit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 1))),
    );
    await bootstrap.habitLogs.logDay(
      habit.id,
      AppDate.dateKey(today.subtract(const Duration(days: 2))),
    );

    expect(service.streak(habit), 2);
    expect(service.isDoneToday(habit), isFalse);

    await service.checkIn(habit);
    expect(service.streak(habit), 3);
  });

  test('福格曲线诊断先排查能力阻力，再排查提示与动机', () async {
    final HabitService service = bootstrap.habitService;

    final FoggHabit steady = await createHabit(anchor: '稳定锚点', tiny: '微动作');
    final DateTime today = AppDate.startOfDay(DateTime.now());
    for (int offset = 0; offset < 5; offset++) {
      await bootstrap.habitLogs.logDay(
        steady.id,
        AppDate.dateKey(today.subtract(Duration(days: offset))),
      );
    }
    expect(service.diagnose(steady).kind, HabitDiagnosis.ok);

    final FoggHabit blocked = await createHabit(
      anchor: '通勤路上',
      tiny: '做 20 个俯卧撑',
      frictions: const FrictionProfile(energy: true, routine: true),
    );
    final HabitDiagnosisResult ability = service.diagnose(blocked);
    expect(ability.kind, HabitDiagnosis.ability);
    expect(ability.advice.contains('能力'), isFalse);
    expect(ability.title, '更像能力阻力');

    final FoggHabit noPrompt = await createHabit(anchor: '某个时间', tiny: '深呼吸');
    final HabitDiagnosisResult prompt = service.diagnose(noPrompt);
    expect(prompt.kind, HabitDiagnosis.promptTrigger);
    expect(prompt.title, '更像提示/动机问题');
  });

  test('每日完成计数用于月历微节律点', () async {
    final FoggHabit first = await createHabit(anchor: '节律一', tiny: '俯身拉伸');
    final FoggHabit second = await createHabit(anchor: '节律二', tiny: '远眺 20 秒');
    final HabitService service = bootstrap.habitService;

    await service.checkIn(first);
    await service.checkIn(second);

    final Map<String, int> counts = service.completedCountByDay(
      <String>[first.id, second.id],
    );
    expect(counts[service.todayKey], 2);
  });

  test('焦点地图：黄金行为判定与确认后才入图', () async {
    final BehaviorCandidate golden = BehaviorCandidate.create(
      title: '晚饭后读 1 页',
      impact: 5,
      effort: 1,
    );
    final BehaviorCandidate hard = BehaviorCandidate.create(
      title: '每天写 2000 字',
      impact: 5,
      effort: 4,
    );

    expect(golden.isGolden, isTrue);
    expect(hard.isGolden, isFalse);
    expect(golden.isSelected, isFalse);

    await bootstrap.behaviorCandidates.add(
      title: golden.title,
      impact: golden.impact,
      effort: golden.effort,
    );
    expect(
      bootstrap.behaviorCandidates.selected,
      isEmpty,
      reason: '候选需要用户确认后才进入焦点地图',
    );
    expect(bootstrap.behaviorCandidates.golden, isNotEmpty);
  });
}