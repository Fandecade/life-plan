import '../database/repositories.dart';
import '../models/models.dart';
import '../utils/date_utils.dart';

/// 周固定排程的实例化与单周覆盖服务。
///
/// - 打开某周 / 某日时间盒时，把 active 固定项实例化为具体日期的 TimeBlock；
/// - 单周跳过记录在 RoutineException，不影响其他周次；
/// - 已存在同 routine + 同日期的块不会重复生成。
class RoutineService {
  RoutineService({
    required this.routines,
    required this.exceptions,
    required this.blocks,
    required this.actions,
  });

  final WeeklyRoutineRepository routines;
  final RoutineExceptionRepository exceptions;
  final TimeBlockRepository blocks;
  final ActionItemRepository actions;

  /// 确保 [from, to] 日期范围内的固定项已生成时间块，返回新建数量。
  Future<int> ensureGenerated(DateTime from, DateTime to) async {
    final List<WeeklyRoutine> active = routines.active;
    if (active.isEmpty) return 0;

    int created = 0;
    final DateTime start = AppDate.startOfDay(from);
    final DateTime end = AppDate.startOfDay(to);

    for (DateTime day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final int weekday = day.weekday;
      for (final WeeklyRoutine routine in active) {
        if (routine.weekday != weekday) continue;
        final String dateKey = AppDate.dateKey(day);
        if (exceptions.isSkipped(routine.id, dateKey)) continue;
        final bool exists = blocks.all.any(
          (TimeBlock block) =>
              block.routineId == routine.id &&
              AppDate.isSameDay(block.startAt, day),
        );
        if (exists) continue;

        await blocks.schedule(
          title: routine.title,
          startAt: DateTime(
            day.year,
            day.month,
            day.day,
            routine.startHour,
            routine.startMinute,
          ),
          durationMinutes: routine.durationMinutes,
          actionItemId: routine.actionItemId,
          routineId: routine.id,
        );
        created += 1;
      }
    }
    return created;
  }

  /// 仅本周跳过：记录例外并移除该块，其他周次照常生成。
  Future<void> skipForWeek(TimeBlock block) async {
    final String? routineId = block.routineId;
    if (routineId == null) {
      await blocks.softDelete(block.id);
      return;
    }
    await exceptions.addSkip(routineId, AppDate.dateKey(block.startAt));
    await blocks.softDelete(block.id);
  }

  /// 恢复为固定安排默认：清除本周例外并按模板重新生成。
  Future<void> restoreDefault(TimeBlock block) async {
    final String? routineId = block.routineId;
    if (routineId == null) return;
    final WeeklyRoutine? routine = routines.byId(routineId);
    final String dateKey = AppDate.dateKey(block.startAt);
    await blocks.softDelete(block.id);
    await exceptions.removeSkip(routineId, dateKey);
    if (routine == null || !routine.isActive) return;

    final DateTime day = AppDate.startOfDay(block.startAt);
    await blocks.schedule(
      title: routine.title,
      startAt: DateTime(day.year, day.month, day.day, routine.startHour, routine.startMinute),
      durationMinutes: routine.durationMinutes,
      actionItemId: routine.actionItemId,
      routineId: routine.id,
    );
  }

  /// 删除整个固定安排项，并清理其未完成的生成块与例外记录。
  Future<void> deleteRoutine(WeeklyRoutine routine) async {
    await routines.softDelete(routine.id);
    for (final TimeBlock block in blocks.all) {
      if (block.routineId != routine.id || block.isCompleted) continue;
      await blocks.softDelete(block.id);
    }
    for (final RoutineException exception in exceptions.forRoutine(routine.id)) {
      await exceptions.softDelete(exception.id);
    }
  }

  /// 课表整体编辑后，移除所有未完成且非本周特例的生成块，等待重新生成。
  Future<void> refreshAllGenerated() async {
    for (final TimeBlock block in blocks.all) {
      if (block.routineId != null &&
          !block.isCompleted &&
          !block.isOverridden) {
        await blocks.softDelete(block.id);
      }
    }
  }

  /// 编辑模板后，移除该固定项尚未完成的生成块，等待按新时间重新生成。
  Future<void> refreshGenerated(String routineId) async {
    for (final TimeBlock block in blocks.all) {
      if (block.routineId == routineId && !block.isCompleted) {
        await blocks.softDelete(block.id);
      }
    }
  }

  /// 把某天的固定项复制到其他星期（同一标题/类型/时间/时长）。
  Future<void> copyDay({
    required int fromWeekday,
    required List<int> targetWeekdays,
  }) async {
    final List<WeeklyRoutine> source = routines.forWeekday(fromWeekday);
    for (final int weekday in targetWeekdays) {
      if (weekday == fromWeekday) continue;
      for (final WeeklyRoutine routine in source) {
        await routines.create(
          title: routine.title,
          weekday: weekday,
          startMinutes: routine.startMinutes,
          durationMinutes: routine.durationMinutes,
          kind: routine.kind,
          actionItemId: routine.actionItemId,
          colorIndex: routine.colorIndex,
        );
      }
    }
  }
}