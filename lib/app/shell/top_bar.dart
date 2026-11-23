import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/state/theme_controller.dart';
import '../../core/state/ui_controller.dart';
import '../../core/widgets/app_button.dart';
import '../router/module_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 顶栏：左侧模块标题，右侧任务池 / 安排记录（仅时间盒）与主题切换。
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, required this.isDesktop});

  final String title;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final UiController ui = context.watch<UiController>();
    final int inboxCount = context.watch<ActionItemRepository>().inboxItems.length;
    final int scheduledCount = context
        .watch<TimeBlockRepository>()
        .all
        .where((TimeBlock block) => !block.isCompleted)
        .length;
    final bool isDark = context.isDarkMode;

    return Container(
      height: isDesktop ? 56 : 50,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xl : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: context.texts.titleLarge,
            ),
          ),
          const Spacer(),
          _InboxTrigger(
            count: inboxCount,
            onTap: ui.openInbox,
            compact: !isDesktop,
          ),
          if (ui.currentRoute == AppRoutes.timeBox) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            _ScheduleTrigger(
              count: scheduledCount,
              onTap: ui.openSchedule,
              compact: !isDesktop,
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
          AppIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: isDark ? '切换到浅色' : '切换到深色',
            onPressed: () => context.read<ThemeController>().setMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                ),
          ),
        ],
      ),
    );
  }
}

class _InboxTrigger extends StatelessWidget {
  const _InboxTrigger({
    required this.count,
    required this.onTap,
    this.compact = false,
  });

  final int count;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '任务池 · ⌘K 呼出',
      child: _TriggerShell(
        icon: Icons.inbox_outlined,
        label: '任务池',
        count: count,
        compact: compact,
        onTap: onTap,
      ),
    );
  }
}

class _ScheduleTrigger extends StatelessWidget {
  const _ScheduleTrigger({
    required this.count,
    required this.onTap,
    this.compact = false,
  });

  final int count;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '安排记录 · 点击查看并跳转',
      child: _TriggerShell(
        icon: Icons.calendar_month_outlined,
        label: '安排记录',
        count: count,
        compact: compact,
        onTap: onTap,
      ),
    );
  }
}

class _TriggerShell extends StatelessWidget {
  const _TriggerShell({
    required this.icon,
    required this.label,
    required this.count,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: palette.textSecondary),
            if (!compact) ...<Widget>[
              const SizedBox(width: 6),
              Text(label, style: context.texts.labelLarge),
            ],
            if (count > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}