import 'dart:math' as math;

import '../models/models.dart';

/// 行动线图上的落点：能力（易做度）与动机，均为 0–10。
class ActionPoint {
  const ActionPoint(this.ability, this.motivation);

  final double ability;
  final double motivation;

  ActionPoint copyWith({double? ability, double? motivation}) => ActionPoint(
        ability ?? this.ability,
        motivation ?? this.motivation,
      );

  ActionPoint clamp() => ActionPoint(
        ability.clamp(0, 10),
        motivation.clamp(0, 10),
      );
}

/// 福格行动线（B=MAP 的横切面）。
///
/// 曲线从左上（难做且需要高动机）滑向右下（极易做时只需很低动机），
/// 线上方是「会触发」区域，下方是「易卡住」区域。
class ActionLineModel {
  const ActionLineModel({
    this.threshold = 3.0,
    this.curvature = 1.4,
  });

  /// 门槛：曲线在「极易做」一端的动机要求（1–8）。
  final double threshold;

  /// 曲率：越大曲线下降越快，越靠「极易做」补偿低动机；
  /// 越小越平缓，越依赖动机。
  final double curvature;

  /// 给定能力时，跨过行动线所需的最低动机。
  double requiredMotivation(double ability) {
    final double x = (ability / 10).clamp(0, 1);
    final double value =
        threshold + (10 - threshold) * math.pow(1 - x, curvature);
    return value.clamp(0, 10);
  }

  bool isAbove(ActionPoint point) =>
      point.motivation >= requiredMotivation(point.ability);
}

/// 由习惯配方与近 7 天完成情况映射当前落点（启发式，用于诊断参考）。
///
/// - 能力：阻力越少越靠右（越容易做）；
/// - 动机：完成率越高、锚点与庆祝越完整，越靠上。
ActionPoint habitActionPoint(FoggHabit habit, int completedInLast7Days) {
  final double ability = (10 - habit.frictions.count * 1.7).clamp(1.0, 10.0);
  final double rate = (completedInLast7Days / 7).clamp(0.0, 1.0);
  final double motivation = (1.5 +
          rate * 6 +
          (habit.celebration.trim().isEmpty ? 0 : 0.9) +
          (habit.anchorPrompt.trim().isEmpty ? 0 : 0.6))
      .clamp(0.5, 9.8);
  return ActionPoint(ability, motivation);
}

/// 目标能力值对应的阻力项数量（5 维中保留几项）。
int frictionTargetCount(double ability) =>
    ((10 - ability) / 1.7).round().clamp(0, 5);

/// 按优先级削减阻力：体力 > 脑力 > 时间 > 日程习惯 > 金钱。
FrictionProfile frictionsForCount(FrictionProfile current, int target) {
  final Map<String, bool> flags = <String, bool>{
    'energy': current.energy,
    'brain': current.brain,
    'time': current.time,
    'routine': current.routine,
    'money': current.money,
  };
  int count = flags.values.where((bool flag) => flag).length;
  for (final String key in <String>[
    'energy',
    'brain',
    'time',
    'routine',
    'money',
  ]) {
    if (count <= target) break;
    if (flags[key] == true) {
      flags[key] = false;
      count--;
    }
  }
  return current.copyWith(
    energy: flags['energy'],
    brain: flags['brain'],
    time: flags['time'],
    routine: flags['routine'],
    money: flags['money'],
  );
}

/// 一句话推演建议：落点在线上时保持，在线下时按阻力数量分流。
String actionLineAdvice({
  required FoggHabit habit,
  required ActionPoint point,
  required ActionLineModel line,
  required int completedInLast7Days,
}) {
  if (line.isAbove(point)) {
    return completedInLast7Days >= 4
        ? '落点在行动线上方，节奏可保持；想加量先确认动机充足，再小幅升级。'
        : '落点已在线上方，先保持小动作，让习惯自然固化。';
  }
  if (habit.frictions.count >= 2) {
    return '落点在线下方，且有「${habit.frictions.labels.join(' / ')}」阻力：'
        '先把微行为缩小一半（向右移）。';
  }
  return '落点在线下方，阻力不多：换更稳定的锚点，或强化即时庆祝（向上移）。';
}