import '../database/repositories.dart';
import '../models/models.dart';
import '../utils/date_utils.dart';

/// 热力图指标：综合活跃度、微习惯、任务完成、学习时长。
enum HeatmapMetric { combined, habit, task, learning }

extension HeatmapMetricLabel on HeatmapMetric {
  String get label {
    switch (this) {
      case HeatmapMetric.combined:
        return '综合';
      case HeatmapMetric.habit:
        return '习惯';
      case HeatmapMetric.task:
        return '任务';
      case HeatmapMetric.learning:
        return '学习';
    }
  }
}

/// 单日统计。
class DayStat {
  const DayStat({
    this.tasks = 0,
    this.habits = 0,
    this.learningMinutes = 0,
    this.blocks = 0,
  });

  final int tasks;
  final int habits;
  final int learningMinutes;
  final int blocks;

  bool get isEmpty =>
      tasks == 0 && habits == 0 && learningMinutes == 0 && blocks == 0;

  int get combined =>
      tasks + habits + blocks + (learningMinutes <= 0 ? 0 : (learningMinutes / 15).ceil());
}

/// 主页一次性快照，避免页面里散落统计口径。
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.todayTasks,
    required this.todayHabitsDone,
    required this.todayHabitsTotal,
    required this.todayLearningMinutes,
    required this.todayBlocks,
    required this.streakDays,
    required this.weekCompletion,
    required this.weekLearningMinutes,
    required this.heatmap,
  });

  final int todayTasks;
  final int todayHabitsDone;
  final int todayHabitsTotal;
  final int todayLearningMinutes;
  final int todayBlocks;
  final int streakDays;
  final double weekCompletion;
  final int weekLearningMinutes;

  /// dateKey -> 当日统计，覆盖最近 12 周。
  final Map<String, DayStat> heatmap;

  DayStat statOf(DateTime day) =>
      heatmap[AppDate.dateKey(day)] ?? const DayStat();

  int levelOf(DateTime day, HeatmapMetric metric) {
    final DayStat stat = statOf(day);
    final int value = switch (metric) {
      HeatmapMetric.combined => stat.combined,
      HeatmapMetric.habit => stat.habits,
      HeatmapMetric.task => stat.tasks,
      HeatmapMetric.learning => stat.learningMinutes,
    };
    if (value <= 0) return 0;
    if (metric == HeatmapMetric.learning) {
      if (value <= 15) return 1;
      if (value <= 30) return 2;
      if (value <= 60) return 3;
      return 4;
    }
    if (value == 1) return 1;
    if (value <= 2) return 2;
    if (value <= 4) return 3;
    return 4;
  }
}

/// 主页统计聚合：只读本地仓储，进入主页时计算一次。
class DashboardService {
  DashboardService({
    required this.actions,
    required this.blocks,
    required this.habits,
    required this.habitLogs,
    required this.sessions,
  });

  final ActionItemRepository actions;
  final TimeBlockRepository blocks;
  final FoggHabitRepository habits;
  final HabitLogRepository habitLogs;
  final LearningSessionRepository sessions;

  static const int heatmapDays = 84;

  DashboardSnapshot snapshot({DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    final DateTime today = AppDate.startOfDay(current);
    final String todayKey = AppDate.dateKey(today);
    final DateTime weekStart =
        today.subtract(Duration(days: today.weekday - 1));
    final DateTime heatStart =
        weekStart.subtract(const Duration(days: 77));

    final Map<String, DayStat> heatmap = <String, DayStat>{};
    DayStat statOf(DateTime day) =>
        heatmap[AppDate.dateKey(day)] ?? const DayStat();


    int todayTasks = 0;
    final Set<String> weekTaskIds = <String>{};
    final Set<String> weekDoneIds = <String>{};
    for (final ActionItem item in actions.all) {
      final DateTime? completedAt = item.completedAt;
      if (completedAt != null) {
        final String key = AppDate.dateKey(completedAt);
        heatmap[key] = _bump(
          heatmap[key],
          tasks: 1,
        );
        if (key == todayKey) todayTasks += 1;
        if (!completedAt.isBefore(weekStart) &&
            !completedAt.isAfter(today)) {
          weekDoneIds.add(item.id);
        }
      }
      final DateTime? scheduled = item.scheduledDate;
      if (scheduled != null &&
          !scheduled.isBefore(weekStart) &&
          !scheduled.isAfter(today)) {
        weekTaskIds.add(item.id);
      }
    }

    int todayBlocks = 0;
    for (final TimeBlock block in blocks.all) {
      if (!block.isCompleted) continue;
      final String key = AppDate.dateKey(block.startAt);
      heatmap[key] = _bump(heatmap[key], blocks: 1);
      if (key == todayKey) todayBlocks += 1;
    }

    final Set<String> activeHabitIds =
        habits.active.map((FoggHabit habit) => habit.id).toSet();
    int todayHabits = 0;
    for (final HabitLog log in habitLogs.all) {
      if (!log.isCompleted) continue;
      heatmap[log.dateKey] = _bump(heatmap[log.dateKey], habits: 1);
      if (log.dateKey == todayKey && activeHabitIds.contains(log.habitId)) {
        todayHabits += 1;
      }
    }

    int weekLearningMinutes = 0;
    for (final LearningSession session in sessions.all) {
      if (session.elapsedSeconds <= 0) continue;
      final DateTime at = session.completedAt ?? session.updatedAt;
      final int minutes = (session.elapsedSeconds / 60).ceil();
      heatmap[AppDate.dateKey(at)] =
          _bump(heatmap[AppDate.dateKey(at)], learningMinutes: minutes);
      if (!at.isBefore(weekStart) && !at.isAfter(current)) {
        weekLearningMinutes += minutes;
      }
    }

    final int denom = weekTaskIds.length;
    final int done = weekTaskIds.where(weekDoneIds.contains).length;
    final double weekCompletion = denom == 0
        ? (weekDoneIds.isEmpty ? 0 : 1)
        : (done / denom).clamp(0, 1);

    int streak = 0;
    DateTime cursor = today;
    final bool todayActive = (statOf(today).combined > 0);
    if (!todayActive) cursor = today.subtract(const Duration(days: 1));
    while (streak < 365) {
      if (statOf(cursor).isEmpty) break;
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // 清理热力图范围外的数据，避免无谓内存。
    heatmap.removeWhere((String key, DayStat _) {
      final DateTime date = DateTime.parse('${key}T00:00:00');
      return date.isBefore(heatStart) || date.isAfter(today);
    });

    final DayStat todayStat = statOf(today);
    return DashboardSnapshot(
      todayTasks: todayTasks,
      todayHabitsDone: todayHabits,
      todayHabitsTotal: activeHabitIds.length,
      todayLearningMinutes: todayStat.learningMinutes,
      todayBlocks: todayBlocks,
      streakDays: streak,
      weekCompletion: weekCompletion,
      weekLearningMinutes: weekLearningMinutes,
      heatmap: heatmap,
    );
  }


  DayStat _bump(
    DayStat? base, {
    int tasks = 0,
    int habits = 0,
    int learningMinutes = 0,
    int blocks = 0,
  }) {
    final DayStat current = base ?? const DayStat();
    return DayStat(
      tasks: current.tasks + tasks,
      habits: current.habits + habits,
      learningMinutes: current.learningMinutes + learningMinutes,
      blocks: current.blocks + blocks,
    );
  }
}