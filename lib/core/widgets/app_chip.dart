import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// 极简标签胶囊。
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dense = false,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dense;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tint = color ?? palette.textSecondary;
    final Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: filled ? tint.withValues(alpha: 0.1) : Colors.transparent,
        border: Border.all(color: tint.withValues(alpha: filled ? 0 : 0.4), width: 1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 10 : 11.5, color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (dense ? context.texts.labelSmall : context.texts.labelMedium)
                ?.copyWith(color: tint),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: content,
    );
  }
}

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 分段胶囊切换器：详情抽屉的执行模式、复盘的周期切换都复用它。
class SegmentBar<T> extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.dense = false,
    this.expand = false,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool dense;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Widget bar = Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: options.map((SegmentOption<T> option) {
          final bool selected = option.value == value;
          return expand
              ? Expanded(child: _buildItem(context, option, selected, dense))
              : _buildItem(context, option, selected, dense);
        }).toList(growable: false),
      ),
    );
    return bar;
  }

  Widget _buildItem(
    BuildContext context,
    SegmentOption<T> option,
    bool selected,
    bool dense,
  ) {
    final AppPalette palette = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(option.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 12,
          vertical: dense ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? palette.border : Colors.transparent,
          ),
        ),
        child: Text(
          option.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: (dense ? context.texts.labelMedium : context.texts.labelLarge)
              ?.copyWith(
            color: selected ? palette.textPrimary : palette.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}