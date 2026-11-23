import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import 'time_box_common.dart';

/// 年视图：12 个月卡片，展示全年投入热力，点击钻取到月视图。
class YearView extends StatelessWidget {
  const YearView({
    super.key,
    required this.anchor,
    required this.blocks,
    required this.onDrillMonth,
  });

  final DateTime anchor;
  final List<TimeBlock> blocks;
  final ValueChanged<int> onDrillMonth;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Map<int, List<TimeBlock>> byMonth = <int, List<TimeBlock>>{
      for (int month = 1; month <= 12; month++) month: <TimeBlock>[],
    };
    for (final TimeBlock block in blocks) {
      if (block.startAt.year != anchor.year) continue;
      byMonth[block.startAt.month]?.add(block);
    }
    final int yearMinutes = totalMinutesOf(
      blocks.where((TimeBlock block) => block.startAt.year == anchor.year),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1000
            ? 4
            : (constraints.maxWidth >= 680 ? 3 : 2);
        const double gap = 12;
        final double cardWidth =
            (constraints.maxWidth - 40 - gap * (columns - 1)) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('${anchor.year}', style: context.texts.headlineSmall),
                  const SizedBox(width: 10),
                  Text(
                    '全年投入 ${yearMinutes > 0 ? AppDate.durationLabel(yearMinutes) : '—'}',
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (int month = 1; month <= 12; month++)
                    SizedBox(
                      width: cardWidth,
                      child: _monthCard(context, month, byMonth[month]!),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  StatusDot(color: palette.accent, size: 4),
                  const SizedBox(width: 6),
                  Text('热力条按每月 90 小时满格', style: context.texts.labelSmall),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _monthCard(BuildContext context, int month, List<TimeBlock> list) {
    final AppPalette palette = context.palette;
    final int minutes = totalMinutesOf(list);
    final int completed =
        list.where((TimeBlock block) => block.isCompleted).length;
    final int activeDays =
        list.map((TimeBlock block) => AppDate.dateKey(block.startAt)).toSet().length;
    final double heat = (minutes / (90 * 60)).clamp(0.0, 1.0);

    return AppCard(
      onTap: () => onDrillMonth(month),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('$month月', style: context.texts.titleSmall),
              const Spacer(),
              Text('$completed/${list.length}', style: context.texts.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            minutes > 0 ? AppDate.durationLabel(minutes) : '—',
            style: context.texts.headlineSmall?.copyWith(
              color: minutes > 0 ? palette.textPrimary : palette.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProgressHairline(value: heat, height: 3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            list.isEmpty ? '暂无安排' : '$activeDays 天有安排',
            style: context.texts.labelSmall,
          ),
        ],
      ),
    );
  }
}