import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/learning_mastery.dart';
import 'package:life_planner/core/utils/progress_weight.dart';

void main() {
  LearningReview review(
    int interval,
    ReviewOutcome outcome, {
    required int day,
  }) {
    final DateTime base = DateTime(2026, 11, day);
    return LearningReview(
      id: 'r-$interval-$day',
      createdAt: base,
      updatedAt: base,
      sessionId: 's1',
      actionItemId: 'a1',
      dueDate: base,
      intervalDays: interval,
      isDone: true,
      outcome: outcome,
      doneAt: base,
    );
  }

  test('首轮通过后：非项目型转入待巩固，项目型直接完成', () {
    expect(
      LearningMastery.initialStatusFor(LearningType.declarative),
      ActionItemStatus.consolidating,
    );
    expect(
      LearningMastery.initialStatusFor(LearningType.procedural),
      ActionItemStatus.consolidating,
    );
    expect(
      LearningMastery.initialStatusFor(LearningType.project),
      ActionItemStatus.completed,
    );
  });

  test('核心复习节点达标且最近一次顺畅，才算已掌握', () {
    expect(LearningMastery.isMastered(LearningType.declarative, []), isFalse);

    expect(
      LearningMastery.isMastered(LearningType.declarative, <LearningReview>[
        review(1, ReviewOutcome.smooth, day: 1),
        review(7, ReviewOutcome.smooth, day: 7),
      ]),
      isTrue,
    );

    // 最近一次模糊 → 未掌握
    expect(
      LearningMastery.isMastered(LearningType.declarative, <LearningReview>[
        review(1, ReviewOutcome.smooth, day: 1),
        review(7, ReviewOutcome.vague, day: 7),
      ]),
      isFalse,
    );

    // 未到核心节点（7 天）
    expect(
      LearningMastery.isMastered(LearningType.declarative, <LearningReview>[
        review(1, ReviewOutcome.smooth, day: 1),
        review(3, ReviewOutcome.smooth, day: 3),
      ]),
      isFalse,
    );

    // 程序性的核心节点是 3 天
    expect(
      LearningMastery.isMastered(LearningType.procedural, <LearningReview>[
        review(1, ReviewOutcome.smooth, day: 1),
        review(3, ReviewOutcome.smooth, day: 3),
      ]),
      isTrue,
    );
  });

  test('项目式以交付为完成标准，复习只作回顾', () {
    expect(LearningMastery.isMastered(LearningType.project, []), isTrue);
    expect(LearningMastery.coreNodeFor(LearningType.project), 0);
  });

  test('连续两次顺畅允许提前通关', () {
    expect(
      LearningMastery.canPromoteEarly(<LearningReview>[
        review(1, ReviewOutcome.smooth, day: 1),
        review(3, ReviewOutcome.smooth, day: 3),
      ]),
      isTrue,
    );
    expect(
      LearningMastery.canPromoteEarly(<LearningReview>[
        review(1, ReviewOutcome.smooth, day: 1),
        review(3, ReviewOutcome.vague, day: 3),
      ]),
      isFalse,
    );
    expect(
      LearningMastery.canPromoteEarly(<LearningReview>[
        review(1, ReviewOutcome.smooth, day: 1),
      ]),
      isFalse,
    );
  });

  test('进度权重：待巩固按 70% 计入，未开始为 0', () {
    expect(ProgressWeight.of(ActionItemStatus.completed), 1);
    expect(ProgressWeight.of(ActionItemStatus.consolidating), 0.7);
    expect(ProgressWeight.of(ActionItemStatus.inProgress), 0);
    expect(ProgressWeight.of(ActionItemStatus.inbox), 0);

    final List<ActionItem> items = <ActionItem>[
      ActionItem.create(title: 'a').copyWith(status: ActionItemStatus.completed),
      ActionItem.create(title: 'b')
          .copyWith(status: ActionItemStatus.consolidating),
      ActionItem.create(title: 'c'),
    ];
    expect(ProgressWeight.ratio(items), closeTo(0.5667, 0.001));
  });
}