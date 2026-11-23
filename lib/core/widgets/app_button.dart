import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// 主按钮：用近黑/近白实底，不用高饱和主色，保持克制。
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Widget child = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: palette.textPrimary,
        foregroundColor: palette.background,
        disabledBackgroundColor: palette.surfaceMuted,
        disabledForegroundColor: palette.textTertiary,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 16,
          vertical: dense ? 8 : 11,
        ),
        minimumSize: Size(0, dense ? 32 : 38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? AppRadius.sm : 10),
        ),
        textStyle: context.texts.labelLarge,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 14 : 15),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// 次级按钮：仅文字与微弱底色，不抢视觉。
class AppGhostButton extends StatelessWidget {
  const AppGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.dense = false,
    this.tone,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color color = tone ?? palette.textSecondary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 12,
          vertical: dense ? 6 : 9,
        ),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: context.texts.labelLarge,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 13 : 14),
            const SizedBox(width: 5),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// 顶栏/卡片上的轻量图标按钮（32x32，hover 才有底色）。
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 32,
    this.iconSize = 17,
    this.tone,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? tone;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Widget content = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: active ? palette.surfaceMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Icon(
            icon,
            size: iconSize,
            color: onPressed == null
                ? palette.textTertiary.withValues(alpha: 0.5)
                : (tone ?? palette.textSecondary),
          ),
        ),
      ),
    );
    return tooltip == null ? content : Tooltip(message: tooltip!, child: content);
  }
}