import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/habit_service.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'habit_action_line_dialog.dart';
import 'habit_recipe_dialog.dart';

/// 日视图「今日微习惯」全屏页：今日锚点的完整习惯卡片。
class DayHabitView extends StatelessWidget {
  const DayHabitView({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    if (!AppDate.isSameDay(day, DateTime.now())) {
      return const EmptyState(
        icon: Icons.loop_outlined,
        title: '微习惯只记录今天',
        description: '切回今天再打卡；历史节律可在福格习惯模块查看。',
      );
    }

    final List<FoggHabit> habits = context.watch<FoggHabitRepository>().active;
    context.watch<HabitLogRepository>();
    if (habits.isEmpty) {
      return const EmptyState(
        icon: Icons.loop_outlined,
        title: '今天还没有微习惯',
        description: '去「福格习惯」创建一个锚点 + 15 秒微行为。',
      );
    }
    final HabitService service = context.read<HabitService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text(
          '今日已完成 ${habits.where(service.isDoneToday).length}/${habits.length}',
          style: context.texts.labelSmall,
        ),
        const SizedBox(height: 8),
        for (final FoggHabit habit in habits)
          _habitCard(context, palette, service, habit),
      ],
    );
  }

  Widget _habitCard(
    BuildContext context,
    AppPalette palette,
    HabitService service,
    FoggHabit habit,
  ) {
    final bool done = service.isDoneToday(habit);
    final bool extra = service.isExtraToday(habit);
    final int streak = service.streak(habit);
    final List<bool> dots = service.dotPattern(habit, days: 14);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      onTap: () async {
        if (done) {
          await service.undoToday(habit);
        } else {
          await service.checkIn(habit);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppChip(
                label: habit.anchorPeriod.label,
                dense: true,
                color: palette.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  habit.tinyBehavior,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    color: done ? palette.textTertiary : null,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: palette.textTertiary,
                  ),
                ),
              ),
              if (extra)
                AppChip(
                  label: '超额',
                  dense: true,
                  filled: true,
                  color: palette.success,
                ),
              Builder(
                builder: (BuildContext anchorContext) => AppIconButton(
                  icon: Icons.more_horiz_rounded,
                  iconSize: 14,
                  size: 24,
                  tooltip: '更多',
                  onPressed: () => _openMenu(anchorContext, habit),
                ),
              ),
            ],
          ),
          if (habit.anchorPrompt.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(habit.anchorPrompt, style: context.texts.labelSmall),
          ],
          const SizedBox(height: 6),
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
              Text(
                done ? '今天已完成' : '今天还没做',
                style: context.texts.labelSmall,
              ),
              const SizedBox(width: 6),
              AppCheckCircle(
                checked: done,
                size: 24,
                padding: 0,
                onTap: () async {
                  if (done) {
                    await service.undoToday(habit);
                  } else {
                    await service.checkIn(habit);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(BuildContext anchorContext, FoggHabit habit) async {
    final AppPalette palette = anchorContext.palette;
    final RenderBox box = anchorContext.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(anchorContext).context.findRenderObject()! as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final String? action = await showMenu<String>(
      context: anchorContext,
      position: position,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'action',
          height: 38,
          child: Text('行动线推演', style: anchorContext.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'recipe',
          height: 38,
          child: Text('调整配方', style: anchorContext.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'extra',
          height: 38,
          child: Text('记超额', style: anchorContext.texts.bodyMedium),
        ),
      ],
    );
    if (action == null || !anchorContext.mounted) return;
    switch (action) {
      case 'action':
        await showHabitActionLineDialog(anchorContext, habit: habit);
      case 'recipe':
        await showHabitRecipeDialog(anchorContext, habit: habit);
      case 'extra':
        await anchorContext.read<HabitService>().checkIn(habit, extra: true);
    }
  }
}