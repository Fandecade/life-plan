import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../database/repositories.dart';
import '../models/models.dart';
import '../utils/date_utils.dart';
import 'habit_service.dart';
import 'reminder_settings.dart';
import 'routine_service.dart';
import 'schedule_service.dart';

/// 提醒类型：时间盒已排块、固定安排模板、只定日期任务、微习惯每日汇总。
enum ReminderKind {
  timeBlock,
  routineBlock,
  dateOnlyTask,
  habitDigest,
  countdown,
  dueTask,
}

/// 一条待展示的提醒。只描述「提醒什么、什么时候、能做什么」，
/// 不绑定具体展示方式，方便第二阶段同样交给系统通知。
class ReminderEvent {
  const ReminderEvent({
    required this.key,
    required this.kind,
    required this.at,
    required this.title,
    this.subtitle = '',
    this.startAt,
    this.blockIds = const <String>[],
    this.taskId,
    this.routineId,
    this.pendingCount = 0,
  });

  /// 去重键：同一提醒只发送一次。
  final String key;
  final ReminderKind kind;

  /// 实际提醒时刻（可能因「稍后」而推迟）。
  final DateTime at;

  final String title;
  final String subtitle;

  /// 事项开始时刻，用于跳转与固定安排完成时定位日期。
  final DateTime? startAt;

  /// 合并提醒涉及的时间块。
  final List<String> blockIds;

  final String? taskId;
  final String? routineId;

  /// 微习惯汇总里未完成的数量。
  final int pendingCount;

  bool get canComplete =>
      kind != ReminderKind.habitDigest && kind != ReminderKind.countdown;

  String get actionLabel {
    switch (kind) {
      case ReminderKind.habitDigest:
        return '去打卡';
      case ReminderKind.countdown:
        return '知道了';
      default:
        return '完成';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'kind': kind.name,
        'at': at.toIso8601String(),
        'title': title,
        'subtitle': subtitle,
        'startAt': startAt?.toIso8601String(),
        'blockIds': blockIds,
        'taskId': taskId,
        'routineId': routineId,
        'pendingCount': pendingCount,
      };

  factory ReminderEvent.fromJson(Map<String, dynamic> json) {
    final Object? rawKind = json['kind'];
    final ReminderKind kind = ReminderKind.values.firstWhere(
      (ReminderKind value) => value.name == rawKind,
      orElse: () => ReminderKind.timeBlock,
    );
    final Object? rawBlocks = json['blockIds'];
    return ReminderEvent(
      key: json['key'] as String? ?? '',
      kind: kind,
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      startAt: DateTime.tryParse(json['startAt'] as String? ?? ''),
      blockIds: rawBlocks is List
          ? rawBlocks.map((Object? value) => '$value').toList()
          : const <String>[],
      taskId: json['taskId'] as String?,
      routineId: json['routineId'] as String?,
      pendingCount: json['pendingCount'] as int? ?? 0,
    );
  }
}

/// 应用内提醒调度：计算到点的提醒、去重、稍后提醒与完成动作。
///
/// 第一阶段只在前台使用（AppShell 定时调用 [tick]）；
/// 第二阶段接入系统通知时，只需替换展示层并复用这里的计划与去重。
class ReminderService {
  ReminderService({
    required this.settings,
    required this.actions,
    required this.blocks,
    required this.routines,
    required this.exceptions,
    required this.habits,
    required this.habitService,
    required this.schedules,
    required this.routineService,
    required this.countdowns,
    required this.settingsBox,
    this.grace = const Duration(minutes: 30),
  });

  static const String _sentKey = 'app.reminder.sent';
  static const String _snoozeKey = 'app.reminder.snooze';

  final ReminderSettings settings;
  final ActionItemRepository actions;
  final TimeBlockRepository blocks;
  final WeeklyRoutineRepository routines;
  final RoutineExceptionRepository exceptions;
  final FoggHabitRepository habits;
  final HabitService habitService;
  final ScheduleService schedules;
  final RoutineService routineService;
  final CountdownRepository countdowns;
  final Box<dynamic> settingsBox;

  /// 应用重启或回到前台时，允许补发的最大延迟。
  final Duration grace;

  /// 进程内缓存：写盘是异步的，缓存保证同一会话内不会重复提醒。
  Map<String, String>? _sentCache;
  Map<String, dynamic>? _snoozeCache;

  Map<String, String> get _sent => _sentCache ??= _readStringMap(_sentKey);

  Map<String, dynamic> get _snoozed =>
      _snoozeCache ??= _readJsonMap(_snoozeKey);

  /// 未来 [days] 天内可预排的系统通知计划。
  ///
  /// 与应用内 [tick] 不同：这里只返回尚未到点的提醒，供系统通知提前排期；
  /// 微习惯汇总只排今天（未来是否打卡无法预知）。
  List<ReminderEvent> upcoming({DateTime? now, int days = 7}) {
    if (!settings.systemEnabled) return const <ReminderEvent>[];
    final DateTime current = now ?? DateTime.now();
    final DateTime end = current.add(Duration(days: days));
    final int lead = settings.leadMinutes;
    final List<ReminderEvent> plan = <ReminderEvent>[];

    final List<TimeBlock> blockList = blocks.all;
    final Map<DateTime, List<TimeBlock>> groups = <DateTime, List<TimeBlock>>{};
    for (final TimeBlock block in blockList) {
      if (block.isCompleted) continue;
      final DateTime remindAt =
          block.startAt.subtract(Duration(minutes: lead));
      if (remindAt.isBefore(current) || remindAt.isAfter(end)) continue;
      groups
          .putIfAbsent(_minuteOf(block.startAt), () => <TimeBlock>[])
          .add(block);
    }
    for (final MapEntry<DateTime, List<TimeBlock>> group in groups.entries) {
      final List<TimeBlock> items = group.value
        ..sort((TimeBlock a, TimeBlock b) => a.title.compareTo(b.title));
      final DateTime startAt = group.key;
      final String title =
          items.map((TimeBlock block) => block.title).join('、');
      final String subtitle = items.length > 1
          ? '${AppDate.timeLabel(startAt)} · ${items.length} 项'
          : '${AppDate.timeLabel(startAt)} · ${AppDate.durationLabel(items.first.plannedMinutes)}';
      plan.add(
        ReminderEvent(
          key: 'tb:${startAt.toIso8601String()}',
          kind: ReminderKind.timeBlock,
          at: startAt.subtract(Duration(minutes: lead)),
          title: title,
          subtitle: subtitle,
          startAt: startAt,
          blockIds: items.map((TimeBlock block) => block.id).toList(),
        ),
      );
    }

    final DateTime firstDay = AppDate.startOfDay(current);
    for (DateTime day = firstDay;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final String dateKey = AppDate.dateKey(day);
      for (final WeeklyRoutine routine in routines.active) {
        if (routine.weekday != day.weekday) continue;
        if (exceptions.isSkipped(routine.id, dateKey)) continue;
        final bool generated = blockList.any(
          (TimeBlock block) =>
              block.routineId == routine.id &&
              AppDate.isSameDay(block.startAt, day),
        );
        if (generated) continue;
        final DateTime startAt = DateTime(
          day.year,
          day.month,
          day.day,
          routine.startHour,
          routine.startMinute,
        );
        final DateTime remindAt = startAt.subtract(Duration(minutes: lead));
        if (remindAt.isBefore(current) || remindAt.isAfter(end)) continue;
        plan.add(
          ReminderEvent(
            key: 'routine:${routine.id}:$dateKey',
            kind: ReminderKind.routineBlock,
            at: remindAt,
            title: routine.title,
            subtitle:
                '${AppDate.timeLabel(startAt)} · ${AppDate.durationLabel(routine.durationMinutes)}',
            startAt: startAt,
            routineId: routine.id,
            taskId: routine.actionItemId,
          ),
        );
      }
    }

    final int dateOnlyMinutes = settings.dateOnlyMinutes;
    for (final ActionItem item in actions.all) {
      if (item.isCompleted || item.scheduledDate == null) continue;
      if (blocks.blocksForActionItem(item.id).isNotEmpty) continue;
      final DateTime day = AppDate.startOfDay(item.scheduledDate!);
      final DateTime at = DateTime(
        day.year,
        day.month,
        day.day,
        dateOnlyMinutes ~/ 60,
        dateOnlyMinutes % 60,
      );
      if (at.isBefore(current) || at.isAfter(end)) continue;
      plan.add(
        ReminderEvent(
          key: 'dateonly:${item.id}:${AppDate.dateKey(day)}',
          kind: ReminderKind.dateOnlyTask,
          at: at,
          title: item.title,
          subtitle: '${AppDate.timeLabel(at)} · 今日待办',
          startAt: at,
          taskId: item.id,
        ),
      );
    }

    // 自定义倒计时（绑定任务由任务截止提醒负责）。
    for (final Countdown item in countdowns.all) {
      if (item.isTaskBound) continue;
      final DateTime? target = item.targetAt;
      if (target == null) continue;
      final DateTime remindAt = item.dateOnly
          ? DateTime(target.year, target.month, target.day, 9)
          : target;
      if (remindAt.isBefore(current) || remindAt.isAfter(end)) continue;
      final String title =
          item.title.trim().isEmpty ? '倒计时' : item.title.trim();
      plan.add(
        ReminderEvent(
          key: 'countdown:${item.id}',
          kind: ReminderKind.countdown,
          at: remindAt,
          title: title,
          subtitle: item.dateOnly
              ? '倒计时 · ${target.month}/${target.day}'
              : '倒计时 · ${AppDate.timeLabel(target)}',
          startAt: target,
        ),
      );
    }

    // 任务截止：有具体时刻提前 1 小时，仅日期则当天 09:00。
    for (final ActionItem item in actions.all) {
      if (item.isCompleted || item.dueDate == null) continue;
      final DateTime deadline = item.dueDate!;

      final bool hasTime =
          deadline.hour != 0 || deadline.minute != 0;
      final DateTime at = hasTime
          ? deadline.subtract(const Duration(hours: 1))
          : DateTime(deadline.year, deadline.month, deadline.day, 9);
      if (at.isBefore(current) || at.isAfter(end)) continue;
      plan.add(
        ReminderEvent(
          key: 'due:${item.id}:${AppDate.dateKey(deadline)}',
          kind: ReminderKind.dueTask,
          at: at,
          title: item.title,
          subtitle:
              hasTime ? '截止 ${AppDate.timeLabel(deadline)}' : '今天截止',
          startAt: deadline,
          taskId: item.id,
        ),
      );
    }

    final List<FoggHabit> activeHabits = habits.active;
    if (activeHabits.isNotEmpty) {
      final int pending = activeHabits
          .where((FoggHabit habit) => !habitService.isDoneToday(habit))
          .length;
      final int digestMinutes = settings.habitDigestMinutes;
      final DateTime at = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day,
        digestMinutes ~/ 60,
        digestMinutes % 60,
      );
      if (pending > 0 && !at.isBefore(current) && !at.isAfter(end)) {
        plan.add(
          ReminderEvent(
            key: 'habit:${AppDate.dateKey(firstDay)}',
            kind: ReminderKind.habitDigest,
            at: at,
            title: '今天还有 $pending 个微习惯未完成',
            subtitle: '${AppDate.timeLabel(at)} · 去打卡',
            startAt: at,
            pendingCount: pending,
          ),
        );
      }
    }

    plan.sort((ReminderEvent a, ReminderEvent b) => a.at.compareTo(b.at));
    return plan;
  }

  /// 计算当前应展示的提醒并记录为已发送。
  ///
  /// 同步只读 Hive，写盘在后台完成，避免阻塞首帧与测试。
  List<ReminderEvent> tick({DateTime? now}) {
    if (!settings.inAppEnabled) return const <ReminderEvent>[];
    final DateTime current = now ?? DateTime.now();
    final Map<String, String> sent = _sent;
    final Map<String, dynamic> snoozed = _snoozed;

    final DateTime expire = current.subtract(const Duration(days: 7));
    final int beforeCleanup = sent.length;
    sent.removeWhere((String _, String value) {
      final DateTime? at = DateTime.tryParse(value);
      return at == null || at.isBefore(expire);
    });
    bool sentChanged = sent.length != beforeCleanup;

    final List<ReminderEvent> due = <ReminderEvent>[];
    final Set<String> produced = <String>{};
    bool snoozeChanged = false;

    // 1. 「稍后 10 分钟」到点。
    for (final String key in snoozed.keys.toList(growable: false)) {
      final Object? raw = snoozed[key];
      if (raw is! Map) {
        snoozed.remove(key);
        snoozeChanged = true;
        continue;
      }
      final ReminderEvent event =
          ReminderEvent.fromJson(raw.cast<String, dynamic>());
      if (event.at.isAfter(current)) {
        // 延后未到点：屏蔽原提醒，避免源头再次生成。
        produced.add(event.key);
        continue;
      }
      if (sent.containsKey(event.key)) continue;
      due.add(event);
      produced.add(event.key);
      snoozed.remove(key);
      snoozeChanged = true;
    }

    // 2. 时间盒已排块：按同一开始分钟合并。
    final int lead = settings.leadMinutes;
    final Map<DateTime, List<TimeBlock>> groups = <DateTime, List<TimeBlock>>{};
    for (final TimeBlock block in blocks.all) {
      if (block.isCompleted) continue;
      final DateTime remindAt =
          block.startAt.subtract(Duration(minutes: lead));
      if (!_isDue(remindAt, current)) continue;
      groups
          .putIfAbsent(_minuteOf(block.startAt), () => <TimeBlock>[])
          .add(block);
    }
    for (final MapEntry<DateTime, List<TimeBlock>> group in groups.entries) {
      final List<TimeBlock> items = group.value
        ..sort((TimeBlock a, TimeBlock b) => a.title.compareTo(b.title));
      final String key = 'tb:${group.key.toIso8601String()}';
      if (sent.containsKey(key) || produced.contains(key)) continue;
      final DateTime startAt = group.key;
      final String title = items.map((TimeBlock block) => block.title).join('、');
      final String subtitle = items.length > 1
          ? '${AppDate.timeLabel(startAt)} · ${items.length} 项'
          : '${AppDate.timeLabel(startAt)} · ${AppDate.durationLabel(items.first.plannedMinutes)}';
      due.add(
        ReminderEvent(
          key: key,
          kind: ReminderKind.timeBlock,
          at: current,
          title: title,
          subtitle: subtitle,
          startAt: startAt,
          blockIds: items.map((TimeBlock block) => block.id).toList(),
        ),
      );
      produced.add(key);
    }

    // 3. 固定安排模板：尚未生成时间块的实例直接按模板提醒。
    final List<TimeBlock> blockList = blocks.all;
    final DateTime rangeEnd = current.add(const Duration(days: 1));
    for (DateTime day = AppDate.startOfDay(current);
        !day.isAfter(rangeEnd);
        day = day.add(const Duration(days: 1))) {
      final String dateKey = AppDate.dateKey(day);
      for (final WeeklyRoutine routine in routines.active) {
        if (routine.weekday != day.weekday) continue;
        if (exceptions.isSkipped(routine.id, dateKey)) continue;
        final bool generated = blockList.any(
          (TimeBlock block) =>
              block.routineId == routine.id &&
              AppDate.isSameDay(block.startAt, day),
        );
        if (generated) continue;
        final DateTime startAt = DateTime(
          day.year,
          day.month,
          day.day,
          routine.startHour,
          routine.startMinute,
        );
        final DateTime remindAt =
            startAt.subtract(Duration(minutes: lead));
        if (!_isDue(remindAt, current)) continue;
        final String key = 'routine:${routine.id}:$dateKey';
        if (sent.containsKey(key) || produced.contains(key)) continue;
        due.add(
          ReminderEvent(
            key: key,
            kind: ReminderKind.routineBlock,
            at: current,
            title: routine.title,
            subtitle:
                '${AppDate.timeLabel(startAt)} · ${AppDate.durationLabel(routine.durationMinutes)}',
            startAt: startAt,
            routineId: routine.id,
            taskId: routine.actionItemId,
          ),
        );
        produced.add(key);
      }
    }

    // 4. 只定日期的任务：当天固定时刻提醒一次。
    final int dateOnlyMinutes = settings.dateOnlyMinutes;
    final DateTime today = AppDate.startOfDay(current);
    final DateTime dateOnlyAt = DateTime(
      today.year,
      today.month,
      today.day,
      dateOnlyMinutes ~/ 60,
      dateOnlyMinutes % 60,
    );
    if (_isDue(dateOnlyAt, current)) {
      for (final ActionItem item in actions.all) {
        if (item.isCompleted || item.scheduledDate == null) continue;
        if (!AppDate.isSameDay(item.scheduledDate!, today)) continue;
        if (blocks.blocksForActionItem(item.id).isNotEmpty) continue;
        final String key = 'dateonly:${item.id}:${AppDate.dateKey(today)}';
        if (sent.containsKey(key) || produced.contains(key)) continue;
        due.add(
          ReminderEvent(
            key: key,
            kind: ReminderKind.dateOnlyTask,
            at: current,
            title: item.title,
            subtitle: '${AppDate.timeLabel(dateOnlyAt)} · 今日待办',
            startAt: dateOnlyAt,
            taskId: item.id,
          ),
        );
        produced.add(key);
      }
    }

    // 5. 倒计时：到点提醒。
    for (final Countdown item in countdowns.all) {
      if (item.isTaskBound) continue;
      final DateTime? target = item.targetAt;
      if (target == null) continue;
      final DateTime remindAt = item.dateOnly
          ? DateTime(target.year, target.month, target.day, 9)
          : target;
      if (!_isDue(remindAt, current)) continue;
      final String key = 'countdown:${item.id}';
      if (sent.containsKey(key) || produced.contains(key)) continue;
      due.add(
        ReminderEvent(
          key: key,
          kind: ReminderKind.countdown,
          at: current,
          title: item.title.trim().isEmpty ? '倒计时' : item.title.trim(),
          subtitle: item.dateOnly
              ? '倒计时 · ${target.month}/${target.day}'
              : '倒计时 · ${AppDate.timeLabel(target)}',
          startAt: target,
        ),
      );
      produced.add(key);
    }

    // 6. 任务截止：有具体时刻提前 1 小时，仅日期则当天 09:00。
    for (final ActionItem item in actions.all) {
      if (item.isCompleted || item.dueDate == null) continue;
      final DateTime deadline = item.dueDate!;
      final bool hasTime =
          deadline.hour != 0 || deadline.minute != 0;
      final DateTime at = hasTime
          ? deadline.subtract(const Duration(hours: 1))
          : DateTime(deadline.year, deadline.month, deadline.day, 9);
      if (!_isDue(at, current)) continue;
      final String key =
          'due:${item.id}:${AppDate.dateKey(deadline)}';
      if (sent.containsKey(key) || produced.contains(key)) continue;
      due.add(
        ReminderEvent(
          key: key,
          kind: ReminderKind.dueTask,
          at: current,
          title: item.title,
          subtitle:
              hasTime ? '截止 ${AppDate.timeLabel(deadline)}' : '今天截止',
          startAt: deadline,
          taskId: item.id,
        ),
      );
      produced.add(key);
    }

    // 7. 微习惯：每天一次未打卡汇总。
    final List<FoggHabit> activeHabits = habits.active;
    if (activeHabits.isNotEmpty) {
      final int pending = activeHabits
          .where((FoggHabit habit) => !habitService.isDoneToday(habit))
          .length;
      final int digestMinutes = settings.habitDigestMinutes;
      final DateTime digestAt = DateTime(
        today.year,
        today.month,
        today.day,
        digestMinutes ~/ 60,
        digestMinutes % 60,
      );
      final String key = 'habit:${AppDate.dateKey(today)}';
      if (pending > 0 &&
          _isDue(digestAt, current) &&
          !sent.containsKey(key) &&
          !produced.contains(key)) {
        due.add(
          ReminderEvent(
            key: key,
            kind: ReminderKind.habitDigest,
            at: current,
            title: '今天还有 $pending 个微习惯未完成',
            subtitle: '${AppDate.timeLabel(digestAt)} · 去打卡',
            startAt: digestAt,
            pendingCount: pending,
          ),
        );
        produced.add(key);
      }
    }

    if (due.isNotEmpty) {
      for (final ReminderEvent event in due) {
        sent[event.key] = current.toIso8601String();
      }
      sentChanged = true;
    }
    if (sentChanged) unawaited(_writeStringMap(_sentKey, sent));
    if (snoozeChanged) unawaited(_writeJsonMap(_snoozeKey, snoozed));

    return due;
  }

  /// 完成提醒对应的事项；微习惯汇总交给界面跳转打卡。
  Future<void> complete(ReminderEvent event) async {
    switch (event.kind) {
      case ReminderKind.timeBlock:
        for (final String id in event.blockIds) {
          final TimeBlock? block = blocks.byId(id);
          if (block == null || block.isCompleted) continue;
          await schedules.completeBlock(block);
        }
      case ReminderKind.routineBlock:
        final DateTime? startAt = event.startAt;
        final String? routineId = event.routineId;
        if (startAt == null || routineId == null) return;
        final DateTime day = AppDate.startOfDay(startAt);
        await routineService.ensureGenerated(day, day);
        for (final TimeBlock block in blocks.all) {
          if (block.routineId == routineId &&
              AppDate.isSameDay(block.startAt, day) &&
              !block.isCompleted) {
            await schedules.completeBlock(block);
            break;
          }
        }
      case ReminderKind.dateOnlyTask:
        final String? taskId = event.taskId;
        if (taskId == null) return;
        await actions.setStatus(taskId, ActionItemStatus.completed);
      case ReminderKind.dueTask:
        final String? taskId = event.taskId;
        if (taskId == null) return;
        await actions.setStatus(taskId, ActionItemStatus.completed);
      case ReminderKind.countdown:
        return;
      case ReminderKind.habitDigest:
        return;
    }
  }

  /// 「稍后 10 分钟」：持久化待重发的提醒。
  Future<void> snooze(
    ReminderEvent event, {
    Duration delay = const Duration(minutes: 10),
    DateTime? now,
  }) async {
    final Map<String, dynamic> snoozed = _snoozed;
    // 延后意味着「再提醒一次」，先撤销已发送标记。
    final Map<String, String> sent = _sent;
    final bool removed = sent.remove(event.key) != null;
    if (removed) unawaited(_writeStringMap(_sentKey, sent));
    final ReminderEvent next = ReminderEvent(
      key: event.key,
      kind: event.kind,
      at: (now ?? DateTime.now()).add(delay),
      title: event.title,
      subtitle: event.subtitle,
      startAt: event.startAt,
      blockIds: event.blockIds,
      taskId: event.taskId,
      routineId: event.routineId,
      pendingCount: event.pendingCount,
    );
    snoozed[event.key] = next.toJson();
    await _writeJsonMap(_snoozeKey, snoozed);
  }

  bool _isDue(DateTime remindAt, DateTime now) {
    if (remindAt.isAfter(now)) return false;
    return now.difference(remindAt) <= grace;
  }

  DateTime _minuteOf(DateTime value) =>
      DateTime(value.year, value.month, value.day, value.hour, value.minute);

  Map<String, String> _readStringMap(String key) {
    final Object? raw = settingsBox.get(key);
    if (raw is! String || raw.isEmpty) return <String, String>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (Object? key, Object? value) =>
              MapEntry<String, String>('$key', '$value'),
        );
      }
    } catch (_) {
      // 损坏的记录直接忽略，下一次 tick 会重建。
    }
    return <String, String>{};
  }

  Map<String, dynamic> _readJsonMap(String key) {
    final Object? raw = settingsBox.get(key);
    if (raw is! String || raw.isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // 同上，忽略损坏记录。
    }
    return <String, dynamic>{};
  }

  Future<void> _writeStringMap(String key, Map<String, String> value) =>
      settingsBox.put(key, jsonEncode(value));

  Future<void> _writeJsonMap(String key, Map<String, dynamic> value) =>
      settingsBox.put(key, jsonEncode(value));
}