import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';


/// 小节标题：左侧标题 + 右侧可选操作，克制的小字距。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: context.texts.labelMedium?.copyWith(
                    color: palette.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.texts.bodySmall),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 极细进度线（高度 3，圆角），用于愿景/能力完成度。
class ProgressHairline extends StatelessWidget {
  const ProgressHairline({
    super.key,
    required this.value,
    this.color,
    this.height = 3,
    this.background,
  });

  final double value;
  final Color? color;
  final double height;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double clamped = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: background ?? palette.surfaceMuted),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: color ?? palette.accent,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 状态微点：5px 圆点，表达语义状态而不喧哗。
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 5, this.glow = false});

  final Color color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 5, spreadRadius: 0.5),
              ]
            : null,
      ),
    );
  }
}

/// 轻快完成圆圈：点击即完成，带克制的对勾微动效。
class AppCheckCircle extends StatelessWidget {
  const AppCheckCircle({
    super.key,
    required this.checked,
    this.onTap,
    this.size = 18,
    this.color,
    this.padding = 3,
  });

  final bool checked;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  /// 点击热区内边距：紧凑场景（时间块）传 0 可避免溢出。
  final double padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tint = color ?? palette.accent;
    final Widget circle = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? tint : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: checked ? tint : palette.border,
          width: 1.3,
        ),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        scale: checked ? 1 : 0.4,
        child: Icon(
          Icons.check_rounded,
          size: size * 0.66,
          color: palette.background,
        ),
      ),
    );
    if (onTap == null) return circle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(padding: EdgeInsets.all(padding), child: circle),
    );
  }
}

/// 极简空状态：一个淡图标 + 一行说明，不堆插画。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? description;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 24 : 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 36 : 44,
              height: compact ? 36 : 44,
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(compact ? 10 : 12),
              ),
              child: Icon(
                icon,
                size: compact ? 17 : 20,
                color: palette.textTertiary,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleSmall?.copyWith(color: palette.textSecondary),
            ),
            if (description != null) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: context.texts.bodySmall,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 一行微小元信息（如 45m · 输出式学习）。
class MetaText extends StatelessWidget {
  const MetaText(this.text, {super.key, this.color, this.icon, this.maxLines = 1});

  final String text;
  final Color? color;
  final IconData? icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tint = color ?? palette.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 11.5, color: tint),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}