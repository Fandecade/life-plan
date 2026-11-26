import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/reminder_service.dart';
import '../../core/widgets/app_button.dart';

/// 应用内提醒横幅：极简卡片，提供完成 / 稍后 / 跳转与关闭。
class ReminderBanner extends StatelessWidget {
  const ReminderBanner({
    super.key,
    required this.event,
    required this.onComplete,
    required this.onSnooze,
    required this.onOpen,
    required this.onDismiss,
  });

  final ReminderEvent event;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: Container(

        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.alarm_rounded,
                  size: 15,
                  color: palette.accent,
                ),
                const SizedBox(width: 6),
                Text('提醒', style: context.texts.labelSmall),
                const Spacer(),
                AppIconButton(
                  icon: Icons.close_rounded,
                  iconSize: 14,
                  size: 24,
                  tooltip: '关闭提醒',
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                    if (event.subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        event.subtitle,
                        style: context.texts.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                AppGhostButton(
                  label: event.actionLabel,
                  dense: true,
                  onPressed: onComplete,
                ),
                const SizedBox(width: 2),
                AppGhostButton(
                  label: '稍后 10 分钟',
                  dense: true,
                  onPressed: onSnooze,
                ),
                const Spacer(),
                AppGhostButton(
                  label: '查看',
                  dense: true,
                  tone: palette.accent,
                  onPressed: onOpen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}