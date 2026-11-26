import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/state/ui_controller.dart';
import '../router/module_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/ui_style.dart';

/// 顶栏：左侧模块标题，最右侧为任务池；时间盒时安排记录紧挨在任务池左侧。
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.isDesktop,
    this.onTitleTap,
  });

  final String title;
  final bool isDesktop;

  /// 手机端点击标题区域打开左侧抽屉。
  final VoidCallback? onTitleTap;

  Widget _wrapTitle(BuildContext context, TextStyle? style) {
    final Widget text = Text(
      title,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (onTitleTap == null) return text;
    return InkWell(
      onTap: onTitleTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: text,
      ),
    );
  }

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

    if (context.isRefreshStyle) {
      return Container(
        height: isDesktop ? 72 : 64,
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 18),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _wrapTitle(
                context,
                context.texts.displaySmall?.copyWith(
                  fontSize: isDesktop ? 30 : 24,
                  letterSpacing: -0.9,
                ),
              ),
            ),
            if (ui.currentRoute == AppRoutes.timeBox) ...<Widget>[
              _ScheduleTrigger(
                count: scheduledCount,
                onTap: ui.openSchedule,
                compact: !isDesktop,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            _InboxTrigger(
              count: inboxCount,
              onTap: ui.openInbox,
              compact: !isDesktop,
            ),
          ],
        ),
      );
    }

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
          // 标题撑满剩余空间，让任务池/安排记录始终贴住顶部栏最右侧。
          Expanded(
            child: _wrapTitle(context, context.texts.titleLarge),
          ),
          if (ui.currentRoute == AppRoutes.timeBox) ...<Widget>[
            _ScheduleTrigger(
              count: scheduledCount,
              onTap: ui.openSchedule,
              compact: !isDesktop,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          _InboxTrigger(
            count: inboxCount,
            onTap: ui.openInbox,
            compact: !isDesktop,
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
    final bool refresh = palette.style == AppUiStyle.refresh;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        refresh ? AppRadius.pill : AppRadius.sm,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: refresh ? 7 : 6,
        ),
        decoration: BoxDecoration(
          color: refresh
              ? (palette.glassEnabled ? palette.glass : palette.surface)
              : palette.surface,
          borderRadius: BorderRadius.circular(
            refresh ? AppRadius.pill : AppRadius.sm,
          ),
          border: Border.all(
            color: refresh ? palette.glassBorder : palette.border,
          ),
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
                  color: refresh ? palette.accent : palette.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: context.texts.labelSmall?.copyWith(
                    color: refresh ? palette.background : palette.accent,
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