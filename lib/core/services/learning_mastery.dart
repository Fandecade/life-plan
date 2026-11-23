import '../models/models.dart';

/// 判断输出式学习任务的掌握阶段：
/// 首次独立输出通过 → 待巩固；完成核心复习节点并顺畅回忆 → 已掌握；
/// 连续两次顺畅可提前通关；项目式以原型/复盘交付即视为完成。
class LearningMastery {
  const LearningMastery._();

  /// 各类型的核心复习节点（到达该节点 + 最近一次顺畅 → 彻底掌握）。
  static int coreNodeFor(LearningType type) {
    switch (type) {
      case LearningType.declarative:
      case LearningType.custom:
        return 7;
      case LearningType.procedural:
      case LearningType.language:
        return 3;
      case LearningType.project:
        return 0;
    }
  }

  /// 项目式学习以「原型交付 + 边界复盘」为完成标准，复习只是可选回顾。
  static bool isProjectBased(LearningType type) => type == LearningType.project;

  static List<LearningReview> _doneSorted(List<LearningReview> reviews) {
    final List<LearningReview> done = reviews
        .where((LearningReview review) => review.isDone)
        .toList();
    done.sort((LearningReview a, LearningReview b) {
      final DateTime left = a.doneAt ?? a.dueDate;
      final DateTime right = b.doneAt ?? b.dueDate;
      return left.compareTo(right);
    });
    return done;
  }

  /// 标准 A：完成核心节点，且最近一次主动回忆为顺畅。
  static bool isMastered(LearningType type, List<LearningReview> reviews) {
    if (isProjectBased(type)) return true;
    final List<LearningReview> done = _doneSorted(reviews);
    if (done.isEmpty) return false;
    final LearningReview last = done.last;
    return last.outcome == ReviewOutcome.smooth &&
        last.intervalDays >= coreNodeFor(type);
  }

  /// 标准 B：连续两次主动回忆都顺畅，允许提前标记为已掌握。
  static bool canPromoteEarly(List<LearningReview> reviews) {
    final List<LearningReview> done = _doneSorted(reviews);
    if (done.length < 2) return false;
    final int length = done.length;
    return done[length - 1].outcome == ReviewOutcome.smooth &&
        done[length - 2].outcome == ReviewOutcome.smooth;
  }

  /// 首轮输出通过后的目标状态。
  static ActionItemStatus initialStatusFor(LearningType type) =>
      isProjectBased(type)
          ? ActionItemStatus.completed
          : ActionItemStatus.consolidating;
}