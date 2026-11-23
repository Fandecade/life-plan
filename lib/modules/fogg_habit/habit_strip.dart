import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/services/habit_service.dart';

/// 时间盒日视图顶部的轻提示条：今日激活的微习惯，一键打卡。
///
/// 只做提示与记录，不占用时间轴格子；模块关闭或无习惯时整条消失。
class HabitAnchorStrip extends StatelessWidget {
  const HabitAnchorStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ModuleRegistry modules = context.watch<ModuleRegistry>();
    if (!modules.isEnabled('fogg_habit')) return const SizedBox.shrink();

    final List<FoggHabit> habits = context.watch<FoggHabitRepository>().active;
    context.watch<HabitLogRepository>();
    if (habits.isEmpty) return const SizedBox.shrink();
    final HabitService service = context.read<HabitService>();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        7,
        AppSpacing.md,
        8,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Text('今日微习惯', style: context.texts.labelSmall),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final FoggHabit habit in habits) ...<Widget>[
                    _AnchorPill(
                      habit: habit,
                      done: service.isDoneToday(habit),
                      onTap: () async {
                        if (service.isDoneToday(habit)) {
                          await service.undoToday(habit);
                        } else {
                          await service.checkIn(habit);
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnchorPill extends StatelessWidget {
  const _AnchorPill({
    required this.habit,
    required this.done,
    required this.onTap,
  });

  final FoggHabit habit;
  final bool done;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: done
              ? palette.accentSoft.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: done ? Colors.transparent : palette.border,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: done
                    ? palette.accent
                    : palette.textTertiary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${habit.anchorPeriod.label} · ${habit.tinyBehavior}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall?.copyWith(
                  color: done ? palette.accent : palette.textSecondary,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}