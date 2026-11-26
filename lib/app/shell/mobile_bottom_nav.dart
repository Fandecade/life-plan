import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/plugin/app_module_descriptor.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/ui_style.dart';

/// 移动端底部导航：经典版为贴底通栏；新版为悬浮玻璃胶囊（5 主项 + 更多）。
class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({
    super.key,
    required this.modules,
    required this.currentRoute,
    required this.onSelect,
  });

  final List<AppModuleDescriptor> modules;
  final String currentRoute;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    if (palette.style != AppUiStyle.refresh) {
      return _buildClassic(context, palette);
    }

    final List<AppModuleDescriptor> items = modules;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: palette.glassBlur,
              sigmaY: palette.glassBlur,
            ),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: palette.glass,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: palette.glassBorder),
              ),
              child: Row(
                children: <Widget>[
                  for (final AppModuleDescriptor module in items)
                    Expanded(
                      child: _RefreshItem(
                        module: module,
                        selected: module.routeName == currentRoute,
                        onTap: () => onSelect(module.routeName),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassic(BuildContext context, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: modules
                  .map(
                    (AppModuleDescriptor module) => _MobileItem(
                      module: module,
                      selected: module.routeName == currentRoute,
                      onTap: () => onSelect(module.routeName),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

}

class _RefreshItem extends StatelessWidget {
  const _RefreshItem({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final AppModuleDescriptor module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color active = palette.background;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? palette.textPrimary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              module.icon,
              size: 17,
              color: selected ? active : palette.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            module.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              fontSize: 9,
              color: selected ? palette.textPrimary : palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}


class _MobileItem extends StatelessWidget {
  const _MobileItem({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final AppModuleDescriptor module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tint = selected ? palette.accent : palette.textTertiary;
    return SizedBox(
      width: 68,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? palette.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(module.icon, size: 16, color: tint),
            ),
            const SizedBox(height: 3),
            Text(
              module.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall?.copyWith(
                color: tint,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}