import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../modules/home/home_page.dart';

/// 左侧抽屉：完整模块列表（含主页与设置），手机端从左边缘右滑打开。
class AppDrawer extends StatelessWidget {
  const AppDrawer({
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
    final bool refresh = context.isRefreshStyle;
    final List<AppModuleDescriptor> items = <AppModuleDescriptor>[
      homeDescriptor,
      ...modules,
    ];

    Widget body = Container(
      color: refresh
          ? (palette.glassEnabled ? palette.glass : palette.surface)
          : palette.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('人生规划', style: context.texts.titleMedium),
                  const SizedBox(height: 2),
                  Text('按自己的节奏推进', style: context.texts.labelSmall),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: <Widget>[
                  for (final AppModuleDescriptor module in items)
                    _DrawerItem(
                      module: module,
                      selected: module.routeName == currentRoute,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(module.routeName);
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('0.1.0 · 本地优先', style: context.texts.labelSmall),
            ),
          ],
        ),
      ),
    );

    if (refresh && palette.glassEnabled && palette.glassBlur > 0) {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: palette.glassBlur,
          sigmaY: palette.glassBlur,
        ),
        child: body,
      );
    }

    return Drawer(
      width: 300,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: body,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
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
    final bool refresh = context.isRefreshStyle;
    final Color foreground = selected ? palette.accent : palette.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? (refresh ? palette.accentSoft : palette.surfaceMuted)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 11,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  module.icon,
                  size: 18,
                  color: selected ? palette.accent : palette.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        module.title,
                        style: context.texts.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (module.description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 1),
                        Text(
                          module.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: palette.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}