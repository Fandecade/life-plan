import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/modules/time_box/time_box_common.dart';

void main() {
  final DateTime day = DateTime(2026, 11, 22);

  TimeBlock makeBlock(String id, int hour, int minute, int minutes) {
    final DateTime start = DateTime(day.year, day.month, day.day, hour, minute);
    return TimeBlock(
      id: id,
      createdAt: day,
      updatedAt: day,
      title: id,
      startAt: start,
      endAt: start.add(Duration(minutes: minutes)),
    );
  }

  test('overlap 分列：重叠块等分宽度，独立块占满', () {
    final List<TimeBlock> blocks = <TimeBlock>[
      makeBlock('a', 9, 0, 60),
      makeBlock('b', 9, 30, 60),
      makeBlock('c', 11, 0, 30),
    ];

    final Map<String, BlockSlot> slots = layoutOverlaps(blocks);

    expect(slots['a']!.width, 0.5);
    expect(slots['b']!.width, 0.5);
    expect(slots['a']!.left, 0);
    expect(slots['b']!.left, 0.5);
    expect(slots['c']!.width, 1);
    expect(slots['c']!.left, 0);
  });

  test('yForTime 与 timeForY 往返，并吸附到 15 分钟', () {
    final double y = yForTime(
      DateTime(2026, 11, 22, 9, 30),
      TimeBoxMetrics.dayHourHeight,
    );
    expect(y, 210);

    final DateTime snapped =
        timeForY(y + 7, day, TimeBoxMetrics.dayHourHeight);
    expect(snapped.hour, 9);
    expect(snapped.minute, 30);

    final DateTime clamped =
        timeForY(-200, day, TimeBoxMetrics.dayHourHeight);
    expect(clamped.hour, TimeBoxMetrics.startHour);
    expect(clamped.minute, 0);
  });

  test('monthGridDays 按周对齐并覆盖整月', () {
    final List<DateTime> days = monthGridDays(DateTime(2026, 11, 1));

    expect(days.length % 7, 0);
    expect(days.first.weekday, DateTime.monday);
    expect(days.where((DateTime item) => item.month == 11).length, 30);
  });

  test('weekDaysOf 返回周一到周日', () {
    final List<DateTime> days = weekDaysOf(DateTime(2026, 11, 22));

    expect(days.length, 7);
    expect(days.first.weekday, DateTime.monday);
    expect(days.last.weekday, DateTime.sunday);
    expect(days.first, DateTime(2026, 11, 16));
  });

  test('totalMinutesOf 累加计划时长', () {
    final List<TimeBlock> blocks = <TimeBlock>[
      makeBlock('a', 9, 0, 45),
      makeBlock('b', 10, 0, 30),
    ];
    expect(totalMinutesOf(blocks), 75);
  });
}