import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/core/models/countdown.dart';

void main() {
  group('Countdown 仅日期与颜色字段', () {
    test('create 保留 dateOnly 与 colorHex', () {
      final Countdown item = Countdown.create(
        title: '  交付作品集  ',
        targetAt: DateTime(2026, 12, 1),
        dateOnly: true,
        colorHex: '#FF8800',
      );
      expect(item.title, '交付作品集');
      expect(item.dateOnly, isTrue);
      expect(item.colorHex, '#FF8800');
    });

    test('默认值向后兼容', () {
      final Countdown item = Countdown.create(
        title: '普通倒计时',
        targetAt: DateTime(2026, 12, 1, 8, 30),
      );
      expect(item.dateOnly, isFalse);
      expect(item.colorHex, isNull);
    });

    test('copyWith 可设置与清除自定义颜色', () {
      final Countdown item = Countdown.create(
        title: '周计划',
        targetAt: DateTime(2026, 12, 1),
        dateOnly: true,
      ).copyWith(colorHex: '#4A5F7A');
      expect(item.colorHex, '#4A5F7A');

      expect(item.copyWith().colorHex, '#4A5F7A');
      expect(item.copyWith(clearColor: true).colorHex, isNull);
      expect(item.copyWith(clearColor: true).dateOnly, isTrue);
    });

    test('copyWith 可切换回含时刻', () {
      final Countdown item = Countdown.create(
        title: '切换',
        targetAt: DateTime(2026, 12, 1),
        dateOnly: true,
      ).copyWith(dateOnly: false);
      expect(item.dateOnly, isFalse);
    });

    test('toJson / fromJson 往返保留新字段', () {
      final Countdown item = Countdown.create(
        title: '往返测试',
        targetAt: DateTime(2026, 12, 1),
        dateOnly: true,
        colorHex: '#D9534F',
      );
      final Countdown restored = Countdown.fromJson(item.toJson());
      expect(restored.dateOnly, isTrue);
      expect(restored.colorHex, '#D9534F');
      expect(restored.targetAt, DateTime(2026, 12, 1));
    });

    test('fromJson 缺失新字段时使用默认值', () {
      final Countdown item = Countdown.fromJson(<String, dynamic>{
        'id': 'legacy-id',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'title': '旧数据',
        'targetAt': DateTime(2026, 12, 1).toIso8601String(),
      });
      expect(item.dateOnly, isFalse);
      expect(item.colorHex, isNull);
    });
  });
}
