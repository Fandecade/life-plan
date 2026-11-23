import '../models/models.dart';

/// 任务状态对能力/愿景进度的贡献权重。
///
/// 首轮输出通过后任务进入「待巩固」，按 70% 计入推进；
/// 只有经过主动检索检验转为「已完成」才计入 100%。
class ProgressWeight {
  const ProgressWeight._();

  static const double consolidating = 0.7;

  static double of(ActionItemStatus status) {
    switch (status) {
      case ActionItemStatus.completed:
        return 1;
      case ActionItemStatus.consolidating:
        return consolidating;
      case ActionItemStatus.inProgress:
      case ActionItemStatus.scheduled:
      case ActionItemStatus.inbox:
      case ActionItemStatus.deferred:
        return 0;
    }
  }

  static double ratio(Iterable<ActionItem> items) {
    int count = 0;
    double sum = 0;
    for (final ActionItem item in items) {
      count += 1;
      sum += of(item.status);
    }
    return count == 0 ? 0 : (sum / count).clamp(0.0, 1.0);
  }
}