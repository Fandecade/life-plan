import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/learning_mastery.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'learning_common.dart';

/// 间隔复习的主动回忆流：先掩蔽自测，再对照卡点，最后标记结果并排下一次。
class LearningReviewFlow extends StatefulWidget {
  const LearningReviewFlow({
    super.key,
    required this.review,
    required this.task,
    required this.session,
    required this.onClose,
  });

  final LearningReview review;
  final ActionItem task;
  final LearningSession? session;
  final VoidCallback onClose;

  @override
  State<LearningReviewFlow> createState() => _LearningReviewFlowState();
}

class _LearningReviewFlowState extends State<LearningReviewFlow> {
  bool _revealed = false;
  bool _busy = false;
  LearningReview? _next;
  ReviewOutcome? _outcome;
  bool _mastered = false;
  bool _canPromote = false;

  LearningType get _type => widget.session?.learningType ?? LearningType.declarative;

  LearningDraft get _draft => LearningDraft.decode(
        widget.session?.stepsDataJson ?? '{}',
        _type,
      );

  Future<void> _submit(ReviewOutcome outcome) async {
    if (_busy) return;
    setState(() => _busy = true);
    final LearningReviewRepository repo =
        context.read<LearningReviewRepository>();
    final LearningReview next = await repo.completeReview(widget.review, outcome);
    if (!mounted) return;

    final List<LearningReview> all = repo.forActionItem(widget.task.id);
    final bool mastered = LearningMastery.isMastered(_type, all);
    final bool canPromote = LearningMastery.canPromoteEarly(all);
    if (mastered) {
      await _completeTask();
    }
    if (!mounted) return;
    setState(() {
      _next = next;
      _outcome = outcome;
      _mastered = mastered;
      _canPromote = canPromote && !mastered;
      _busy = false;
    });
  }

  Future<void> _promote() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _completeTask();
    if (!mounted) return;
    setState(() {
      _mastered = true;
      _canPromote = false;
      _busy = false;
    });
    _toast('已提前标记为已掌握');
  }

  /// 转为已掌握：清理未完成的复习节点与对应复习时间块，避免继续提醒。
  Future<void> _completeTask() async {
    final ActionItemRepository actions = context.read<ActionItemRepository>();
    final LearningReviewRepository reviews =
        context.read<LearningReviewRepository>();
    final TimeBlockRepository blocks = context.read<TimeBlockRepository>();
    await actions.setStatus(widget.task.id, ActionItemStatus.completed);
    for (final LearningReview review in reviews.forActionItem(widget.task.id)) {
      if (review.isDone) continue;
      final TimeBlock? block = blocks.forReview(review.id);
      if (block != null) {
        await blocks.softDelete(block.id);
      }
      await reviews.softDelete(review.id);
    }
  }

  Future<void> _scheduleToTimeBox() async {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final DateTime start =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20);
    await context.read<TimeBlockRepository>().schedule(
          title: '间隔复习 · ${widget.task.title}',
          startAt: start,
          durationMinutes: 30,
        );
    if (!mounted) return;
    _toast('已加入 ${AppDate.friendlyDay(start)} 20:00 的时间盒');
  }

  void _toast(String message) {
    final AppPalette palette = context.palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: context.texts.bodyMedium?.copyWith(color: palette.background),
        ),
        backgroundColor: palette.textPrimary,
        behavior: SnackBarBehavior.floating,
        width: 300,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tone = LearningVisuals.toneOf(_type);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: '返回工作台',
                onPressed: widget.onClose,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('间隔复习', style: context.texts.titleMedium),
              const SizedBox(width: AppSpacing.sm),
              AppChip(label: _type.tag, dense: true, filled: true, color: tone),
            ],
          ),
        ),
        Divider(color: palette.hairline, height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _next != null
                    ? _doneView(context, tone)
                    : (_revealed ? _checkView(context, tone) : _recallView(context, tone)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recallView(BuildContext context, Color tone) {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppChip(
          label: '第 ${widget.review.intervalDays} 天节点',
          dense: true,
          color: tone,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(widget.task.title, style: context.texts.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '先闭卷回忆：在脑中或白纸上复述核心内容，暂时不要看之前的记录。',
          style: context.texts.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.surfaceMuted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: <Widget>[
              StatusDot(color: palette.textTertiary, size: 5),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '回忆完成后再点下方按钮，对照当时的卡点与输出摘要。',
                  style: context.texts.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: AppPrimaryButton(
            label: '查看卡点核对',
            icon: Icons.visibility_outlined,
            onPressed: () => setState(() => _revealed = true),
          ),
        ),
      ],
    );
  }

  Widget _checkView(BuildContext context, Color tone) {
    final AppPalette palette = context.palette;
    final LearningDraft draft = _draft;
    final LearningMethodTemplate template = methodOf(_type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.task.title, style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        SectionHeader(title: '当时记录的卡点'),
        const SizedBox(height: AppSpacing.sm),
        if (draft.blocker.trim().isEmpty)
          Text('（未记录卡点）', style: context.texts.bodySmall)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
            ),
            child: Text(draft.blocker, style: context.texts.bodyMedium),
          ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: '输出摘要'),
        const SizedBox(height: AppSpacing.sm),
        for (int index = 0; index < draft.fullSteps.length; index++)
          if (draft.fullSteps[index].text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    template.stepAt(index).title,
                    style: context.texts.labelMedium?.copyWith(color: tone),
                  ),
                  const SizedBox(height: 2),
                  Text(draft.fullSteps[index].text, style: context.texts.bodyMedium),
                ],
              ),
            ),
        if (!draft.hasContent)
          Text('（本次没有留下文字记录）', style: context.texts.bodySmall),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: '标记本次回忆结果'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '顺畅 → 间隔翻倍；模糊 → 保持当前间隔；遗忘 → 回到 1 天。',
          style: context.texts.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            AppPrimaryButton(
              label: '顺畅',
              icon: Icons.check_rounded,
              dense: true,
              onPressed: _busy ? null : () => _submit(ReviewOutcome.smooth),
            ),
            AppGhostButton(
              label: '模糊',
              dense: true,
              onPressed: _busy ? null : () => _submit(ReviewOutcome.vague),
            ),
            AppGhostButton(
              label: '遗忘',
              tone: palette.danger,
              dense: true,
              onPressed: _busy ? null : () => _submit(ReviewOutcome.forgotten),
            ),
          ],
        ),
      ],
    );
  }

  Widget _doneView(BuildContext context, Color tone) {
    final AppPalette palette = context.palette;
    final LearningReview next = _next!;
    final ReviewOutcome outcome = _outcome ?? ReviewOutcome.vague;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            StatusDot(color: _mastered ? tone : palette.success, size: 6),
            const SizedBox(width: 6),
            Text(
              _mastered ? '已内化 · 任务标记为已完成' : '本次回忆已完成',
              style: context.texts.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(widget.task.title, style: context.texts.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.surfaceMuted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('标记为：${outcome.label}', style: context.texts.titleSmall),
              const SizedBox(height: 4),
              if (_mastered)
                Text(
                  '已完成核心复习节点，掌握状态已落定。',
                  style: context.texts.bodyMedium
                      ?.copyWith(color: palette.textSecondary),
                )
              else
                Text(
                  '下次复习：${AppDate.monthDayLabel(next.dueDate)} · 间隔 ${next.intervalDays} 天',
                  style: context.texts.bodyMedium
                      ?.copyWith(color: palette.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            if (_canPromote)
              AppPrimaryButton(
                label: '提前标记为已掌握',
                icon: Icons.verified_outlined,
                dense: true,
                onPressed: _busy ? null : _promote,
              ),
            AppGhostButton(
              label: '加入明天的时间盒',
              icon: Icons.event_available_outlined,
              dense: true,
              onPressed: _scheduleToTimeBox,
            ),
            AppGhostButton(
              label: '返回工作台',
              dense: true,
              onPressed: widget.onClose,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_mastered)
          AppChip(
            label: '接下来：${next.intervalDays} 天后再次主动回忆',
            dense: true,
            color: tone,
          ),
        if (_canPromote)
          const SizedBox(height: 6),
        if (_canPromote)
          AppChip(
            label: '连续两次顺畅，可提前通关',
            dense: true,
            color: palette.success,
          ),
      ],
    );
  }
}