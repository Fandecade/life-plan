import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/ui_style.dart';

/// 卡片：经典版为纯色 + 微边框；新版为磨砂玻璃 + 高光描边 + 大圆角。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.background,
    this.borderColor,
    this.radius = 14,
    this.clip = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? background;
  final Color? borderColor;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    if (palette.style == AppUiStyle.refresh) {
      return _buildGlass(context, palette);
    }

    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Widget content = Padding(padding: padding, child: child);

    return Padding(
      padding: margin,
      child: Material(
        color: background ?? palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: borderColor ?? palette.border),
        ),
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
      ),
    );
  }

  Widget _buildGlass(BuildContext context, AppPalette palette) {
    final double glassRadius = radius == 14 ? 24 : radius;
    final BorderRadius borderRadius = BorderRadius.circular(glassRadius);
    final Widget content = Padding(padding: padding, child: child);
    final bool blurred = palette.glassEnabled && palette.glassBlur > 0;

    Widget body = Container(
      decoration: BoxDecoration(
        color: background ??
            (palette.glassEnabled ? palette.glass : palette.surface),
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? palette.glassBorder),
        boxShadow: palette.glassEnabled
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
            ),
    );

    if (blurred) {
      body = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: palette.glassBlur,
            sigmaY: palette.glassBlur,
          ),
          child: body,
        ),
      );
    }

    return Padding(padding: margin, child: body);
  }
}

/// 新版的主视觉卡：低饱和主题色渐变 + 深色胶囊按钮；经典版回退普通卡片。
class AppFeatureCard extends StatelessWidget {
  const AppFeatureCard({
    super.key,
    required this.title,
    this.meta,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.tone,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final String title;
  final String? meta;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    if (palette.style != AppUiStyle.refresh) {
      return AppCard(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (meta != null) Text(meta!, style: context.texts.labelSmall),
            const SizedBox(height: 4),
            Text(title, style: context.texts.titleMedium),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(subtitle!, style: context.texts.bodySmall),
            ],
          ],
        ),
      );
    }

    final bool dark = context.isDarkMode;
    final Color base = tone ?? palette.accent;
    final Color foreground = dark ? Colors.white : palette.textPrimary;
    final Color start = Color.lerp(base, Colors.white, dark ? 0.06 : 0.42)!;
    final Color end = Color.lerp(base, Colors.black, dark ? 0.18 : 0.04)!;
    final Color button = dark
        ? Colors.white
        : Colors.black.withValues(alpha: 0.82);
    final Color onButton = dark ? palette.background : Colors.white;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.18 : 0.35),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: base.withValues(alpha: dark ? 0.18 : 0.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (meta != null)
            Text(
              meta!,
              style: context.texts.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            title,
            style: context.texts.headlineSmall?.copyWith(color: foreground),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: context.texts.bodySmall?.copyWith(
                color: foreground.withValues(alpha: 0.75),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: button,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        actionLabel!,
                        style: context.texts.labelLarge?.copyWith(
                          color: onButton,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: onButton,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 无边框的轻量分组容器，用于抽屉/面板内的分区。
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}