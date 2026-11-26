import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/date_utils.dart';

/// 12 周 × 7 天热力图；周一起始，最后一行是本周。
class HomeHeatmap extends StatelessWidget {
  const HomeHeatmap({
    super.key,
    required this.snapshot,
    required this.metric,
    required this.onDayTap,
  });

  final DashboardSnapshot snapshot;
  final HeatmapMetric metric;
  final void Function(DateTime day, DayStat stat) onDayTap;

  static const int weeks = 12;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final DateTime today = AppDate.startOfDay(DateTime.now());
    final DateTime thisMonday =
        today.subtract(Duration(days: today.weekday - 1));
    final DateTime start = thisMonday.subtract(const Duration(days: 77));
    final bool refresh = context.isRefreshStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int week = 0; week < weeks; week++)
              Expanded(
                child: Column(
                  children: <Widget>[
                    for (int day = 0; day < 7; day++)
                      Padding(
                        padding: const EdgeInsets.all(1.4),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _cell(
                            context,
                            start.add(Duration(days: week * 7 + day)),
                            today,
                            refresh,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Text('少', style: context.texts.labelSmall),
            const SizedBox(width: 6),
            for (int level = 0; level <= 4; level++) ...<Widget>[
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: _levelColor(palette, level),
                  borderRadius: BorderRadius.circular(3),
                  border: refresh && level == 0
                      ? Border.all(color: palette.glassBorder)
                      : null,
                ),
              ),
            ],
            const SizedBox(width: 3),
            Text('多', style: context.texts.labelSmall),
            const Spacer(),
            Text('最近 12 周', style: context.texts.labelSmall),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime date,
    DateTime today,
    bool refresh,
  ) {
    final AppPalette palette = context.palette;
    final bool future = date.isAfter(today);
    final int level = snapshot.levelOf(date, metric);
    return InkWell(
      onTap: future
          ? null
          : () => onDayTap(date, snapshot.statOf(date)),
      borderRadius: BorderRadius.circular(3),
      child: Container(
        decoration: BoxDecoration(
          color: future
              ? Colors.transparent
              : _levelColor(palette, level),
          borderRadius: BorderRadius.circular(3),
          border: refresh && !future && level == 0
              ? Border.all(color: palette.glassBorder)
              : null,
        ),
      ),
    );
  }

  Color _levelColor(AppPalette palette, int level) {
    switch (level) {
      case 0:
        return palette.surfaceMuted;
      case 1:
        return palette.accent.withValues(alpha: 0.22);
      case 2:
        return palette.accent.withValues(alpha: 0.45);
      case 3:
        return palette.accent.withValues(alpha: 0.7);
      default:
        return palette.accent;
    }
  }
}