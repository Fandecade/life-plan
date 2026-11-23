import 'package:flutter/material.dart';

import '../../core/plugin/app_module_descriptor.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 移动端精简底部导航（横向可滚动，避免模块较多时挤压）。
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