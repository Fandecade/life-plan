import 'package:flutter/material.dart';

import '../../core/plugin/app_module_descriptor.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 桌面/平板左侧可折叠导航栏。
class DesktopSideNav extends StatelessWidget {
  const DesktopSideNav({
    super.key,
    required this.modules,
    required this.currentRoute,
    required this.collapsed,
    required this.onToggle,
    required this.onSelect,
  });

  final List<AppModuleDescriptor> modules;
  final String currentRoute;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: collapsed ? 68 : 224,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(right: BorderSide(color: palette.hairline)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(height: 56, child: _brand(context)),
          Divider(color: palette.hairline, height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...modules.map(
            (AppModuleDescriptor module) => _NavItem(
              module: module,
              selected: module.routeName == currentRoute,
              collapsed: collapsed,
              onTap: () => onSelect(module.routeName),
            ),
          ),
          const Spacer(),
          Divider(color: palette.hairline, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.end,
              children: <Widget>[
                if (!collapsed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text('收起导航', style: context.texts.bodySmall),
                    ),
                  ),
                Tooltip(
                  message: collapsed ? '展开导航' : '收起导航',
                  child: IconButton(
                    onPressed: onToggle,
                    iconSize: 16,
                    splashRadius: 16,
                    color: palette.textTertiary,
                    icon: Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  Widget _brand(BuildContext context) {
    final AppPalette palette = context.palette;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : AppSpacing.lg),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.timeline_rounded,
              size: 14,
              color: context.isDarkMode ? const Color(0xFF121417) : Colors.white,
            ),
          ),
          if (!collapsed) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '人生规划',
                  style: context.texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                Text('成长与执行', style: context.texts.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.module,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final AppModuleDescriptor module;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10),
      decoration: BoxDecoration(
        color: selected ? palette.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected ? palette.border : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: <Widget>[
          Icon(
            module.icon,
            size: 16,
            color: selected ? palette.accent : palette.textSecondary,
          ),
          if (!collapsed) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                module.title,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodyMedium?.copyWith(
                  color: selected ? palette.textPrimary : palette.textSecondary,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
      child: Tooltip(
        message: collapsed ? module.title : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: content,
          ),
        ),
      ),
    );
  }
}