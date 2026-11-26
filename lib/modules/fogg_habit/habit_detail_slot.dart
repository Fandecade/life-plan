import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/habit_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/state_views.dart';
import 'habit_action_line_dialog.dart';
import 'habit_recipe_dialog.dart';

/// 任务详情抽屉中的「福格微习惯」扩展槽位。
///
/// 只做行为设计联动：展示已绑定的锚点微动作、提供打卡与配方调整入口，
/// 不参与学习与复习逻辑。关闭该模块时槽位随模块一起消失。
class HabitDetailSlot extends StatelessWidget {
  const HabitDetailSlot({super.key, required this.task});

  final ActionItem task;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final FoggHabitRepository habits = context.watch<FoggHabitRepository>();
    context.watch<HabitLogRepository>();
    final HabitService service = context.read<HabitService>();
    final FoggHabit? habit = habits.forActionItem(task.id);

    if (habit == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: palette.hairline),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('福格微习惯', style: context.texts.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '给它配一个锚点和 2 分钟内的小动作，比靠意志力更稳。',
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppGhostButton(
              label: '绑定微习惯',
              icon: Icons.add_rounded,
              dense: true,
              onPressed: () => showHabitRecipeDialog(
                context,
                linkedActionItemId: task.id,
              ),
            ),
          ],
        ),
      );
    }

    final bool done = service.isDoneToday(habit);
    final bool extra = service.isExtraToday(habit);
    final int streak = service.streak(habit);
    final List<bool> dots = service.dotPattern(habit);

    return GestureDetector(
      onSecondaryTapUp: (TapUpDetails details) =>
          _openDeleteMenu(context, habit, details.globalPosition),
      onLongPressStart: (LongPressStartDetails details) =>
          _openDeleteMenu(context, habit, details.globalPosition),
      child: Container(
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
              StatusDot(
                color: habit.isActive ? palette.accent : palette.textTertiary,
                size: 5,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('福格微习惯', style: context.texts.titleSmall),
              ),
              AppChip(
                label: habit.anchorPeriod.label,
                dense: true,
                color: palette.accent,
              ),
              if (extra) ...<Widget>[
                const SizedBox(width: 6),
                AppChip(
                  label: '超额',
                  dense: true,
                  filled: true,
                  color: palette.success,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(habit.anchorPrompt, style: context.texts.labelSmall),
          const SizedBox(height: 2),
          Text(
            habit.tinyBehavior,
            style: context.texts.bodyMedium?.copyWith(
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: palette.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (int index = 0; index < dots.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dots[index]
                        ? palette.accent.withValues(alpha: 0.7)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dots[index] ? Colors.transparent : palette.border,
                      width: 0.8,
                    ),
                  ),
                ),
              ],
              if (streak > 0) ...<Widget>[
                const SizedBox(width: 8),
                Text('连续 $streak 天', style: context.texts.labelSmall),
              ],
              const Spacer(),
              Text(done ? '今天已完成' : '今天还没做', style: context.texts.labelSmall),
              const SizedBox(width: 8),
              AppCheckCircle(
                checked: done,
                size: 24,
                padding: 0,
                onTap: () => _toggle(context, service, habit),
              ),
            ],
          ),
          if (!habit.isActive) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text('该习惯已停用，可重新启用或调整配方。', style: context.texts.labelSmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppGhostButton(
                label: '行动线推演',
                icon: Icons.show_chart_rounded,
                dense: true,
                onPressed: () =>
                    showHabitActionLineDialog(context, habit: habit),
              ),
              AppGhostButton(
                label: '调整配方',
                icon: Icons.tune_rounded,
                dense: true,
                onPressed: () => showHabitRecipeDialog(context, habit: habit),
              ),
              if (done && !extra)
                AppGhostButton(
                  label: '记超额',
                  icon: Icons.add_task_rounded,
                  dense: true,
                  onPressed: () => service.checkIn(habit, extra: true),
                ),
              if (!habit.isActive)
                AppGhostButton(
                  label: '重新启用',
                  icon: Icons.play_arrow_rounded,
                  dense: true,
                  onPressed: () =>
                      habits.save(habit.copyWith(isActive: true)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    HabitService service,
    FoggHabit habit,
  ) async {
    if (service.isDoneToday(habit)) {
      final bool confirmed = await confirmCancelHabitCheckIn(context);
      if (!confirmed || !context.mounted) return;
      await service.undoToday(habit);
      return;
    }
    await service.checkIn(habit);
  }

  Future<void> _openDeleteMenu(
    BuildContext context,
    FoggHabit habit,
    Offset globalPosition,
  ) async {
    final AppPalette palette = context.palette;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final String? action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'delete',
          height: 38,
          child: Text(
            '删除微习惯',
            style: context.texts.bodyMedium?.copyWith(color: palette.danger),
          ),
        ),
      ],
    );
    if (action != 'delete') return;
    await context.read<FoggHabitRepository>().softDelete(habit.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已删除微习惯，历史打卡仍保留',
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
}