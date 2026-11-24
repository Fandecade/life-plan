import '../../core/database/repositories.dart';
import '../models/models.dart';

/// 排期服务：维护「行动单元 ↔ 时间块」的双向联动。
///
/// Milestone 1 已打通数据层：排期即生成时间块并把行动单元置为已排期；
/// Milestone 3 的时间盒视图直接复用这里的读写。
class ScheduleService {
  ScheduleService({
    required this.actions,
    required this.blocks,
  });

  final ActionItemRepository actions;
  final TimeBlockRepository blocks;

  Future<void> scheduleAction(
    ActionItem item,
    DateTime startAt, {
    int? durationMinutes,
    bool append = false,
  }) async {
    final int minutes = durationMinutes ?? item.estimatedMinutes ?? 30;
    final TimeBlock? existing = append ? null : blocks.forActionItem(item.id);
    if (existing != null) {
      await blocks.save(
        existing.copyWith(
          title: item.title,
          startAt: startAt,
          endAt: startAt.add(Duration(minutes: minutes)),
        ),
      );
    } else {
      await blocks.schedule(
        title: item.title,
        startAt: startAt,
        durationMinutes: minutes,
        actionItemId: item.id,
      );
    }
    await actions.save(
      item.copyWith(
        status: ActionItemStatus.scheduled,
        estimatedMinutes: item.estimatedMinutes ?? minutes,
      ),
    );
  }

  Future<void> unschedule(String actionItemId) async {
    final TimeBlock? block = blocks.forActionItem(actionItemId);
    if (block != null) {
      await blocks.softDelete(block.id);
    }
    final ActionItem? item = actions.byId(actionItemId);
    if (item != null && item.status == ActionItemStatus.scheduled) {
      await actions.setStatus(item.id, ActionItemStatus.inbox);
    }
  }

  /// 时间块勾选完成 → 同步行动单元。
  /// 输出式学习任务只推进到「进行中」，学习状态由输出自检与复习检验决定。
  Future<void> completeBlock(TimeBlock block) async {
    await blocks.setCompleted(block.id, true);
    final String? actionItemId = block.actionItemId;
    if (actionItemId == null) return;
    final ActionItem? item = actions.byId(actionItemId);
    final ActionItemStatus target = item?.executionMode == ExecutionMode.outputLearning
        ? ActionItemStatus.inProgress
        : ActionItemStatus.completed;
    await actions.setStatus(actionItemId, target);
  }

  Future<void> uncompleteBlock(TimeBlock block) async {
    await blocks.setCompleted(block.id, false);
    final String? actionItemId = block.actionItemId;
    if (actionItemId != null) {
      final ActionItem? item = actions.byId(actionItemId);
      if (item != null && item.isCompleted) {
        await actions.setStatus(actionItemId, ActionItemStatus.scheduled);
      }
    }
  }
}