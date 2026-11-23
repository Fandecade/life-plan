import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'time_box_common.dart';

/// 年视图：全年骨架、愿景方向与各月复盘轨迹，点击月份钻取月视图。
class YearView extends StatelessWidget {
  const YearView({
    super.key,
    required this.anchor,
    required this.blocks,
    required this.reviewedMonths,
    required this.visionTitles,
    required this.onDrillMonth,
  });

  final DateTime anchor;
  final List<TimeBlock> blocks;

  /// 已完成月度复盘的月份（1..12）。
  final Set<int> reviewedMonths;

  /// 年度方向（愿景标题），作为长期骨架提示。
  final List<String> visionTitles;
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
              if (visionTitles.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      Text('年度方向', style: context.texts.labelSmall),
                      const SizedBox(width: AppSpacing.sm),
                      for (final String title in visionTitles.take(4)) ...<Widget>[
                        AppChip(label: title, dense: true, color: palette.accent),
                        const SizedBox(width: 6),
                      ],
                      if (visionTitles.length > 4)
                        AppChip(
                          label: '+${visionTitles.length - 4}',
                          dense: true,
                        ),
                    ],
                  ),
                ),
              ],
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
                  const SizedBox(width: 14),
                  StatusDot(color: palette.success, size: 4),
                  const SizedBox(width: 6),
                  Text('已复盘', style: context.texts.labelSmall),
                  const SizedBox(width: 10),
                  StatusDot(color: palette.textTertiary, size: 4),
                  const SizedBox(width: 6),
                  Text('待复盘', style: context.texts.labelSmall),
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
    final bool reviewed = reviewedMonths.contains(month);

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
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  list.isEmpty ? '暂无安排' : '$activeDays 天有安排',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall,
                ),
              ),
              const Spacer(),
              StatusDot(
                color: reviewed ? palette.success : palette.textTertiary,
                size: 4,
              ),
              const SizedBox(width: 4),
              Text(
                reviewed ? '已复盘' : '待复盘',
                style: context.texts.labelSmall?.copyWith(
                  color: reviewed ? palette.success : palette.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}