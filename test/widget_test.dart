import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  group('ActionItem 数据契约', () {
    test('JSON 往返保留同步预留字段与业务字段', () {
      final ActionItem item = ActionItem.create(
        title: '写一份输出',
        estimatedMinutes: 30,
        executionMode: ExecutionMode.outputLearning,
      );

      final ActionItem restored = ActionItem.fromJson(item.toJson());

      expect(restored.id, item.id);
      expect(restored.title, '写一份输出');
      expect(restored.executionMode, ExecutionMode.outputLearning);
      expect(restored.estimatedMinutes, 30);
      expect(restored.status, ActionItemStatus.inbox);
      expect(restored.syncStatus, SyncStatus.localOnly);
      expect(restored.deletedAt, isNull);
      expect(restored.createdAt, item.createdAt);
    });

    test('copyWith 可清空可空字段并刷新 updatedAt', () {
      final ActionItem item = ActionItem.create(
        title: '挂载任务',
        capabilityId: 'cap-1',
        estimatedMinutes: 45,
      );

      final ActionItem cleared = item.copyWith(
        clearCapability: true,
        clearEstimatedMinutes: true,
      );

      expect(cleared.capabilityId, isNull);
      expect(cleared.estimatedMinutes, isNull);
      expect(cleared.title, '挂载任务');
    });

    test('默认状态为任务池，完成状态可判定', () {
      final ActionItem item = ActionItem.create(title: 'x');
      expect(item.isInbox, isTrue);
      expect(item.isOpen, isTrue);
      expect(item.isCompleted, isFalse);

      final ActionItem done =
          item.copyWith(status: ActionItemStatus.completed);
      expect(done.isCompleted, isTrue);
      expect(done.isOpen, isFalse);
    });
  });

  group('TimeBlock 时长计算', () {
    test('plannedMinutes 按起止时间计算', () {
      final DateTime start = DateTime(2026, 11, 22, 9, 0);
      final TimeBlock block = TimeBlock.create(
        title: '深度工作',
        startAt: start,
        endAt: start.add(const Duration(minutes: 45)),
      );
      expect(block.plannedMinutes, 45);
      expect(block.isStandalone, isTrue);
    });
  });

  group('AppDate 格式化', () {
    test('时长格式化覆盖小时与分钟', () {
      expect(AppDate.durationLabel(45), '45m');
      expect(AppDate.durationLabel(60), '1h');
      expect(AppDate.durationLabel(90), '1h30m');
      expect(AppDate.durationLabel(null), '');
      expect(AppDate.durationLabel(0), '');
    });

    test('dateKey 补零且可稳定比较', () {
      expect(AppDate.dateKey(DateTime(2026, 11, 2)), '2026-11-02');
      expect(AppDate.isSameDay(DateTime(2026, 11, 22, 1), DateTime(2026, 11, 22, 23)),
          isTrue);
      expect(AppDate.isSameDay(DateTime(2026, 11, 22), DateTime(2026, 11, 23)),
          isFalse);
    });
  });
}