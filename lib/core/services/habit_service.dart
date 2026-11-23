import '../database/repositories.dart';
import '../models/models.dart';
import '../utils/date_utils.dart';
import 'action_line.dart';

enum HabitDiagnosis { ok, ability, promptTrigger }

class HabitDiagnosisResult {
  const HabitDiagnosisResult(this.kind, this.title, this.advice);

  final HabitDiagnosis kind;
  final String title;
  final String advice;
}

/// 福格习惯执行与诊断服务（不混入学习/复习逻辑）。
class HabitService {
  HabitService({
    required this.habits,
    required this.logs,
    required this.versions,
  });

  final FoggHabitRepository habits;
  final HabitLogRepository logs;
  final HabitRecipeVersionRepository versions;

  String get todayKey => AppDate.dateKey(DateTime.now());

  bool isDoneToday(FoggHabit habit) =>
      logs.forDay(habit.id, todayKey) != null;

  bool isExtraToday(FoggHabit habit) {
    final HabitLog? log = logs.forDay(habit.id, todayKey);
    return log?.isExtra ?? false;
  }

  Future<HabitLog> checkIn(FoggHabit habit, {bool extra = false}) =>
      logs.logDay(habit.id, todayKey, isExtra: extra);

  Future<void> undoToday(FoggHabit habit) => logs.removeDay(habit.id, todayKey);

  /// 最近 [days] 天的完成状态（从最早到今天），用于低饱和点阵。
  List<bool> dotPattern(FoggHabit habit, {int days = 14}) {
    final Set<String> dates = logs.completedDates(habit.id);
    final DateTime today = AppDate.startOfDay(DateTime.now());
    return List<bool>.generate(days, (int index) {
      final DateTime day = today.subtract(Duration(days: days - 1 - index));
      return dates.contains(AppDate.dateKey(day));
    });
  }

  int streak(FoggHabit habit) => logs.streak(habit.id);

  int completedInLastDays(FoggHabit habit, int days) =>
      dotPattern(habit, days: days).where((bool done) => done).length;

  /// 每日完成的习惯数（dateKey → 次数），供月视图微节律点使用。
  Map<String, int> completedCountByDay(Iterable<String> habitIds) {
    final Set<String> ids = habitIds.toSet();
    final Map<String, int> counts = <String, int>{};
    for (final HabitLog log in logs.all) {
      if (!log.isCompleted || !ids.contains(log.habitId)) continue;
      counts[log.dateKey] = (counts[log.dateKey] ?? 0) + 1;
    }
    return counts;
  }

  /// 保存配方并留存版本（微行为 / 锚点 / 庆祝方式的变更可对比）。
  Future<HabitRecipeVersion> saveRecipe(
    FoggHabit habit, {
    String note = '',
  }) async {
    await habits.save(habit);
    return versions.add(
      habitId: habit.id,
      anchorPrompt: habit.anchorPrompt,
      tinyBehavior: habit.tinyBehavior,
      celebration: habit.celebration,
      frictionsJson: habit.frictionsJson,
      note: note,
      completedIn7Days: completedInLastDays(habit, 7),
    );
  }

  /// 当前落点：由配方阻力与近 7 天完成率映射。
  ActionPoint currentActionPoint(FoggHabit habit, {int days = 7}) =>
      habitActionPoint(habit, completedInLastDays(habit, days));

  /// 按行动线推演结果生成新配方（阻力缩减 + 锚点/庆祝强化）并留存版本。
  Future<HabitRecipeVersion> applyActionLinePlan(
    FoggHabit habit,
    ActionPoint target,
  ) async {
    final ActionPoint current = currentActionPoint(habit);
    final FrictionProfile frictions = frictionsForCount(
      habit.frictions,
      frictionTargetCount(target.ability),
    );

    String celebration = habit.celebration;
    String motivationNote = habit.motivationNote;
    if (target.motivation > current.motivation + 0.5) {
      if (celebration.trim().isEmpty) {
        celebration = '握拳，默念：我做到了';
      }
      if (!motivationNote.contains('行动线')) {
        motivationNote = motivationNote.isEmpty
            ? '行动线推演：强化锚点与即时庆祝'
            : '$motivationNote；行动线推演：强化锚点与即时庆祝';
      }
    }

    String abilityTip = habit.abilityFrictionTip;
    if (target.ability > current.ability + 0.3) {
      abilityTip = abilityTip.isEmpty
          ? '行动线推演：先把微行为缩到 15 秒可启动'
          : abilityTip;
    }

    final FoggHabit next = habit.copyWith(
      frictions: frictions,
      celebration: celebration,
      abilityFrictionTip: abilityTip,
      motivationNote: motivationNote,
    );

    return saveRecipe(
      next,
      note: '行动线推演：能力 ${current.ability.toStringAsFixed(1)} → '
          '${target.ability.toStringAsFixed(1)}，动机 '
          '${current.motivation.toStringAsFixed(1)} → '
          '${target.motivation.toStringAsFixed(1)}',
    );
  }

  /// 福格曲线卡点诊断：完成率低时，先排查能力阻力，再看提示/动机。
  HabitDiagnosisResult diagnose(FoggHabit habit, {int days = 7}) {
    final int done = completedInLastDays(habit, days);
    if (done >= (days * 0.6).ceil()) {
      return const HabitDiagnosisResult(
        HabitDiagnosis.ok,
        '节奏稳定',
        '保持当前配方即可；若想加量，先确认动机充足，再小幅升级动作。',
      );
    }
    if (habit.frictions.count >= 2) {
      return HabitDiagnosisResult(
        HabitDiagnosis.ability,
        '更像能力阻力',
        '最近 $days 天完成 $done 次，且存在「${habit.frictions.labels.join(' / ')}」阻力。'
            '先把微行为再缩小一半，或提前把环境准备好。',
      );
    }
    return HabitDiagnosisResult(
      HabitDiagnosis.promptTrigger,
      '更像提示/动机问题',
      '最近 $days 天完成 $done 次，阻力不多。试试换更稳定的锚点，或换一种庆祝方式。',
    );
  }
}