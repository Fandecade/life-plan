import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/learning_mastery.dart';
import '../../core/utils/date_utils.dart';
import '../../core/state/ui_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'learning_common.dart';

/// 任务详情抽屉中的「输出式学习」扩展槽位。
///
/// 关闭输出式学习模块时，该槽位随模块一起从抽屉消失（由插件注册中心控制）。
class LearningDetailSlot extends StatelessWidget {
  const LearningDetailSlot({super.key, required this.task});

  final ActionItem task;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final LearningSessionRepository sessions =
        context.watch<LearningSessionRepository>();
    final LearningReviewRepository reviews =
        context.watch<LearningReviewRepository>();
    final UiController ui = context.watch<UiController>();

    final LearningSession? draftSession = sessions.inProgressFor(task.id);
    final int finishedCount = sessions.all
        .where((LearningSession session) =>
            session.actionItemId == task.id && session.isFinished)
        .length;
    final int pendingReviews = reviews
        .forActionItem(task.id)
        .where((LearningReview review) => !review.isDone)
        .length;

    LearningType type = draftSession?.learningType ?? LearningType.declarative;
    if (draftSession == null) {
      for (final LearningSession session in sessions.all) {
        if (session.actionItemId == task.id && session.isFinished) {
          type = session.learningType;
          break;
        }
      }
    }
    final Color tone = LearningVisuals.toneOf(type);

    final LearningDraft? draft = draftSession == null
        ? null
        : LearningDraft.decode(draftSession.stepsDataJson, draftSession.learningType);

    final List<LearningReview> taskReviews = reviews.forActionItem(task.id);
    final bool canPromote =
        !task.isCompleted && LearningMastery.canPromoteEarly(taskReviews);

    final String status;
    if (draft != null) {
      status = '进行中 · ${stepProgressLabel(draft)}';
    } else if (task.isCompleted) {
      status = finishedCount > 0 ? '已掌握 · 输出 $finishedCount 次' : '已掌握';
    } else if (task.status == ActionItemStatus.consolidating) {
      status = '待巩固 · 待复习 $pendingReviews 次';
    } else if (finishedCount > 0) {
      status = '已完成 $finishedCount 次输出';
    } else {
      status = '尚未开始';
    }

    final List<LearningReview> pendingList = taskReviews
        .where((LearningReview review) => !review.isDone)
        .toList()
      ..sort((LearningReview a, LearningReview b) =>
          a.dueDate.compareTo(b.dueDate));
    final LearningReview? nextReview =
        pendingList.isEmpty ? null : pendingList.first;
    final String? reviewHint = nextReview == null
        ? null
        : '下次复习：${AppDate.monthDayLabel(nextReview.dueDate)} · D${nextReview.intervalDays}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusDot(color: tone, size: 5),
              const SizedBox(width: 6),
              Text('输出式学习', style: context.texts.titleSmall),
              const Spacer(),
              if (pendingReviews > 0)
                AppChip(
                  label: '待复习 $pendingReviews',
                  dense: true,
                  color: palette.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            status,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (reviewHint != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(reviewHint, style: context.texts.labelSmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (draft == null && canPromote)
                AppGhostButton(
                  label: '标记已掌握',
                  icon: Icons.verified_outlined,
                  dense: true,
                  onPressed: () => context
                      .read<ActionItemRepository>()
                      .setStatus(task.id, ActionItemStatus.completed),
                ),
              if (nextReview != null)
                AppGhostButton(
                  label: '立即回忆',
                  icon: Icons.psychology_outlined,
                  dense: true,
                  onPressed: () => ui.openReview(nextReview.id),
                ),
              AppGhostButton(
                label: draft != null ? '继续输出' : '开始输出',
                icon: Icons.auto_stories_outlined,
                dense: true,
                onPressed: () => ui.openLearning(task.id),
              ),
            ],
          ),
          if (draft != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ProgressHairline(
              value: draft.filledStepCount /
                  (draft.fullSteps.isEmpty ? 1 : draft.fullSteps.length),
              height: 2,
              color: tone,
            ),
          ],
        ],
      ),
    );
  }
}