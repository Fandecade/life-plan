import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';

/// 时间盒几何常量与公共计算。
class TimeBoxMetrics {
  const TimeBoxMetrics._();

  static const int startHour = 6;
  static const int endHour = 24;
  static const int snapMinutes = 15;

  static const double dayHourHeight = 60;
  static const double weekHourHeight = 40;

  static const int dayMinutes = (endHour - startHour) * 60;
}

/// 时间 → 画布 y 坐标。
double yForTime(DateTime time, double hourHeight) {
  final double hours = time.hour + time.minute / 60.0;
  return (hours - TimeBoxMetrics.startHour) * hourHeight;
}

/// 画布 y 坐标 → 吸附到 15 分钟的时间。
DateTime timeForY(double y, DateTime day, double hourHeight) {
  final double hours = TimeBoxMetrics.startHour + y / hourHeight;
  final double minuteOfDay = hours * 60;
  final int snapped =
      (minuteOfDay / TimeBoxMetrics.snapMinutes).round() *
          TimeBoxMetrics.snapMinutes;
  final int clamped = snapped.clamp(
    TimeBoxMetrics.startHour * 60,
    TimeBoxMetrics.endHour * 60 - TimeBoxMetrics.snapMinutes,
  );
  return DateTime(day.year, day.month, day.day, clamped ~/ 60, clamped % 60);
}

class BlockSlot {
  const BlockSlot({required this.left, required this.width});

  /// 0..1 的相对位置与宽度。
  final double left;
  final double width;
}

/// 重叠时间块的分列算法：同组内等分宽度，避免互相遮挡。
Map<String, BlockSlot> layoutOverlaps(List<TimeBlock> blocks) {
  final List<TimeBlock> sorted = List<TimeBlock>.from(blocks)
    ..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));

  final List<List<TimeBlock>> groups = <List<TimeBlock>>[];
  List<TimeBlock> current = <TimeBlock>[];
  DateTime? groupEnd;

  for (final TimeBlock block in sorted) {
    if (current.isEmpty) {
      current = <TimeBlock>[block];
      groupEnd = block.endAt;
    } else if (block.startAt.isBefore(groupEnd!)) {
      current.add(block);
      if (block.endAt.isAfter(groupEnd)) groupEnd = block.endAt;
    } else {
      groups.add(current);
      current = <TimeBlock>[block];
      groupEnd = block.endAt;
    }
  }
  if (current.isNotEmpty) groups.add(current);

  final Map<String, BlockSlot> result = <String, BlockSlot>{};
  for (final List<TimeBlock> group in groups) {
    final List<DateTime> columnEnds = <DateTime>[];
    final Map<String, int> columnOf = <String, int>{};
    for (final TimeBlock block in group) {
      int column = columnEnds.indexWhere(
        (DateTime end) => !block.startAt.isBefore(end),
      );
      if (column == -1) {
        column = columnEnds.length;
        columnEnds.add(block.endAt);
      } else {
        columnEnds[column] = block.endAt;
      }
      columnOf[block.id] = column;
    }
    final int columns = columnEnds.length;
    for (final TimeBlock block in group) {
      final int column = columnOf[block.id] ?? 0;
      result[block.id] = BlockSlot(
        left: column / columns,
        width: 1 / columns,
      );
    }
  }
  return result;
}

/// 本周 7 天（周一 → 周日）。
List<DateTime> weekDaysOf(DateTime anchor) {
  final DateTime monday = AppDate.startOfWeek(anchor);
  return List<DateTime>.generate(
    7,
    (int index) => monday.add(Duration(days: index)),
  );
}

/// 月历网格：按周一开头补齐前后月，返回 35 或 42 天。
List<DateTime> monthGridDays(DateTime anchor) {
  final DateTime first = DateTime(anchor.year, anchor.month);
  final DateTime start = first.subtract(Duration(days: first.weekday - 1));
  final int daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
  final int offset = first.weekday - 1;
  final int cells = ((offset + daysInMonth) / 7).ceil() * 7;
  return List<DateTime>.generate(
    cells,
    (int index) => DateTime(start.year, start.month, start.day + index),
  );
}

int totalMinutesOf(Iterable<TimeBlock> blocks) {
  int total = 0;
  for (final TimeBlock block in blocks) {
    total += block.plannedMinutes;
  }
  return total;
}

/// 低饱和能力色板：用能力顺序稳定区分色块。
const List<Color> softCapabilityTones = <Color>[
  Color(0xFF5C7290),
  Color(0xFF6B7F62),
  Color(0xFF8A6E86),
  Color(0xFF9A795C),
  Color(0xFF5D7B7A),
  Color(0xFF7B6F8A),
];

Color toneForCapability(
  String? capabilityId,
  List<Capability> capabilities,
  AppPalette palette,
) {
  if (capabilityId == null) return palette.textSecondary;
  final int index = capabilities.indexWhere(
    (Capability capability) => capability.id == capabilityId,
  );
  if (index < 0) return palette.textSecondary;
  return softCapabilityTones[index % softCapabilityTones.length];
}

/// 单日总时长 → 热力强度（0..1，4 小时为满格）。
double heatForMinutes(int minutes) =>
    (minutes / (4 * 60)).clamp(0.0, 1.0);

/// 日历网格中的星期标题。
const List<String> weekdayShortLabels = <String>['一', '二', '三', '四', '五', '六', '日'];

String monthLabelOf(DateTime date) => '${date.year}年${date.month}月';

int minutesBetween(DateTime start, DateTime end) =>
    math.max(0, end.difference(start).inMinutes);
/// 把任务的愿景 / 能力翻译成展示标签，供时间盒与任务选择器共用。
class TaskLabelResolver {
  const TaskLabelResolver({required this.capabilities, required this.visions});

  final Map<String, Capability> capabilities;
  final Map<String, Vision> visions;

  Capability? capabilityOf(ActionItem? item) {
    final String? id = item?.capabilityId;
    return id == null ? null : capabilities[id];
  }

  Vision? visionOf(ActionItem? item) {
    final Capability? capability = capabilityOf(item);
    return capability == null ? null : visions[capability.visionId];
  }

  String? labelOf(ActionItem? item, {String separator = ' · '}) {
    final Vision? vision = visionOf(item);
    final Capability? capability = capabilityOf(item);
    final List<String> parts = <String>[
      if (vision != null) vision.title,
      if (capability != null) capability.title,
    ];
    return parts.isEmpty ? null : parts.join(separator);
  }
}