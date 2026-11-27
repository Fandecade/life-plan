import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/modules/home/countdown_format.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 27, 18, 30);

  group('formatCountdown', () {
    test('超过一天显示天与时分', () {
      expect(
        formatCountdown(const Duration(days: 3, hours: 4, minutes: 12)),
        '3 天 04:12',
      );
    });

    test('小时级显示时分秒', () {
      expect(
        formatCountdown(const Duration(hours: 4, minutes: 12, seconds: 33)),
        '04:12:33',
      );
    });

    test('分钟级显示分秒', () {
      expect(
        formatCountdown(const Duration(minutes: 12, seconds: 33)),
        '12:33',
      );
    });

    test('非正数显示已到期', () {
      expect(formatCountdown(Duration.zero), '已到期');
      expect(formatCountdown(const Duration(seconds: -1)), '已到期');
    });
  });

  group('countdownDayDiff', () {
    test('忽略时刻只比较日期', () {
      expect(countdownDayDiff(DateTime(2026, 11, 27, 0, 1), now), 0);
      expect(countdownDayDiff(DateTime(2026, 11, 27, 23, 59), now), 0);
    });

    test('跨月与过去日期', () {
      expect(countdownDayDiff(DateTime(2026, 12, 2), now), 5);
      expect(countdownDayDiff(DateTime(2026, 11, 20), now), -7);
    });
  });

  group('formatDateOnlyCountdown', () {
    test('已过期显示已到期', () {
      expect(formatDateOnlyCountdown(DateTime(2026, 11, 26), now), '已到期');
    });

    test('当天显示今天', () {
      expect(formatDateOnlyCountdown(DateTime(2026, 11, 27), now), '今天');
    });

    test('未来显示剩余天数', () {
      expect(formatDateOnlyCountdown(DateTime(2026, 11, 30), now), '剩 3 天');
    });
  });

  group('countdownTargetLabel', () {
    test('仅日期不含时刻', () {
      expect(
        countdownTargetLabel(DateTime(2026, 11, 28, 18, 5), dateOnly: true),
        '11/28',
      );
    });

    test('含时刻显示时分', () {
      expect(
        countdownTargetLabel(DateTime(2026, 11, 28, 18, 5)),
        '11/28 18:05',
      );
    });
  });

  group('countdownColorFor', () {
    test('自定义固定色优先于自动变色', () {
      expect(
        countdownColorFor(
          target: DateTime(2026, 11, 20),
          now: now,
          dateOnly: true,
          customHex: '#FF8800',
        ),
        const Color(0xFFFF8800),
      );
    });

    test('仅日期按紧迫度在绿→黄→橙→红之间取档', () {
      Color colorOf(int day, {int month = 11}) => countdownColorFor(
            target: DateTime(2026, month, day),
            now: now,
            dateOnly: true,
          );
      expect(colorOf(26), countdownUrgent, reason: '已到期');
      expect(colorOf(27), countdownUrgent, reason: '今天');
      expect(colorOf(28), countdownUrgent, reason: '1 天内');
      expect(colorOf(29), countdownNear, reason: '2 天');
      expect(colorOf(30), countdownNear, reason: '3 天');
      expect(colorOf(4, month: 12), countdownSoon, reason: '7 天内');
      expect(colorOf(5, month: 12), countdownCalm, reason: '超过 7 天');
    });

    test('含时刻按剩余时长在绿→黄→橙→红之间取档', () {
      Color colorOf(DateTime target) => countdownColorFor(
            target: target,
            now: now,
          );
      expect(colorOf(now), countdownUrgent, reason: '已到期');
      expect(
        colorOf(now.add(const Duration(hours: 24))),
        countdownUrgent,
        reason: '1 天内',
      );
      expect(
        colorOf(now.add(const Duration(days: 2))),
        countdownNear,
        reason: '3 天内',
      );
      expect(
        colorOf(now.add(const Duration(days: 5))),
        countdownSoon,
        reason: '7 天内',
      );
      expect(
        colorOf(now.add(const Duration(days: 20))),
        countdownCalm,
        reason: '超过 7 天',
      );
    });
  });

  group('hex 颜色互转', () {
    test('parseHexColor 接受带井号与不带井号', () {
      expect(parseHexColor('#FF0000'), const Color(0xFFFF0000));
      expect(parseHexColor('FF0000'), const Color(0xFFFF0000));
    });

    test('parseHexColor 对非法输入返回 null', () {
      expect(parseHexColor(null), isNull);
      expect(parseHexColor('#12345'), isNull);
      expect(parseHexColor('#ZZZZZZ'), isNull);
    });

    test('hexFromColor 输出大写六位', () {
      expect(hexFromColor(const Color(0xFFFF0000)), '#FF0000');
      expect(hexFromColor(const Color(0xFF4A5F7A)), '#4A5F7A');
    });

    test('颜色互转可往返', () {
      const Color source = Color(0xFF00A3B5);
      expect(parseHexColor(hexFromColor(source)), source);
    });
  });
}