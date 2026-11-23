import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';

/// 里程碑占位页：保持与整体一致的排版，同时明确当前已完成与下一步。
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.milestone,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String milestone;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: palette.border),
                ),
                child: Icon(icon, size: 20, color: palette.accent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: context.texts.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: context.texts.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  AppChip(label: milestone, color: palette.accent, filled: true),
                  const SizedBox(width: 6),
                  const AppChip(label: '接口已注册'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Divider(color: palette.hairline),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: '阶段说明'),
              const SizedBox(height: AppSpacing.md),
              ...points.map(
                (String point) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: StatusDot(color: palette.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(point, style: context.texts.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '模块已通过插件注册中心接入，可在设置 → 模块管理中随时启用或停用。',
                style: context.texts.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}