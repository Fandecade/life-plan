import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/habit_service.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'habit_recipe_dialog.dart';

enum HabitFilter { todayAnchors, all, recipes }

/// 福格习惯系统首页：今日锚点 / 全部习惯 / 配方调整记录。
class FoggHabitPage extends StatefulWidget {
  const FoggHabitPage({super.key});

  @override
  State<FoggHabitPage> createState() => _FoggHabitPageState();
}

class _FoggHabitPageState extends State<FoggHabitPage> {
  HabitFilter _filter = HabitFilter.todayAnchors;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<FoggHabit> habits = context.watch<FoggHabitRepository>().all;
    // 触发打卡变化后的重建
    context.watch<HabitLogRepository>();
    final List<HabitRecipeVersion> versions =
        context.watch<HabitRecipeVersionRepository>().all;

    final List<FoggHabit> activeHabits = habits
        .where((FoggHabit habit) => habit.isActive)
        .toList(growable: false);

    return Column(
      children: <Widget>[
        _header(context, activeHabits.length),
        Divider(color: palette.hairline, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: switch (_filter) {
              HabitFilter.todayAnchors =>
                _todayWidgets(context, activeHabits),
              HabitFilter.all => _allWidgets(context, habits),
              HabitFilter.recipes => _recipeWidgets(context, versions, habits),
            },
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, int activeCount) {
    final AppPalette palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '不靠意志力：锚点之后，做一个 2 分钟内的小动作',
                  style: context.texts.bodySmall,
                ),
              ),
              AppPrimaryButton(
                label: '新建习惯',
                icon: Icons.add_rounded,
                dense: true,
                onPressed: () => _createHabit(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                AppChip(
                  label: '今日锚点 · $activeCount',
                  dense: true,
                  filled: _filter == HabitFilter.todayAnchors,
                  color: palette.accent,
                  onTap: () =>
                      setState(() => _filter = HabitFilter.todayAnchors),
                ),
                const SizedBox(width: 6),
                AppChip(
                  label: '全部习惯',
                  dense: true,
                  filled: _filter == HabitFilter.all,
                  color: palette.accent,
                  onTap: () => setState(() => _filter = HabitFilter.all),
                ),
                const SizedBox(width: 6),
                AppChip(
                  label: '配方调整记录',
                  dense: true,
                  filled: _filter == HabitFilter.recipes,
                  color: palette.accent,
                  onTap: () => setState(() => _filter = HabitFilter.recipes),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _todayWidgets(BuildContext context, List<FoggHabit> habits) {
    if (habits.isEmpty) {
      return <Widget>[_emptyState(context)];
    }
    final List<Widget> widgets = <Widget>[];
    for (final AnchorPeriod period in AnchorPeriod.values) {
      final List<FoggHabit> group = habits
          .where((FoggHabit habit) => habit.anchorPeriod == period)
          .toList(growable: false);
      if (group.isEmpty) continue;
      widgets.add(SectionHeader(title: period.label));
      widgets.add(const SizedBox(height: AppSpacing.sm));
      for (final FoggHabit habit in group) {
        widgets.add(_habitCard(context, habit));
      }
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    return widgets;
  }

  List<Widget> _allWidgets(BuildContext context, List<FoggHabit> habits) {
    if (habits.isEmpty) return <Widget>[_emptyState(context)];
    return <Widget>[
      SectionHeader(title: '全部习惯 · ${habits.length}'),
      const SizedBox(height: AppSpacing.sm),
      for (final FoggHabit habit in habits)
        _habitCard(context, habit, dimmed: !habit.isActive),
    ];
  }

  List<Widget> _recipeWidgets(
    BuildContext context,
    List<HabitRecipeVersion> versions,
    List<FoggHabit> habits,
  ) {
    if (versions.isEmpty) {
      return <Widget>[
        const EmptyState(
          icon: Icons.history_rounded,
          title: '还没有配方版本',
          description: '创建或调整习惯后，每次变化都会留档，方便复盘对比。',
        ),
      ];
    }
    final List<HabitRecipeVersion> sorted = List<HabitRecipeVersion>.from(versions)
      ..sort((HabitRecipeVersion a, HabitRecipeVersion b) =>
          b.createdAt.compareTo(a.createdAt));
    final List<Widget> widgets = <Widget>[
      SectionHeader(title: '配方调整记录 · ${sorted.length}'),
      const SizedBox(height: AppSpacing.sm),
    ];
    for (final HabitRecipeVersion version in sorted) {
      String habitTitle = '已删除的习惯';
      for (final FoggHabit habit in habits) {
        if (habit.id == version.habitId) {
          habitTitle = habit.tinyBehavior;
          break;
        }
      }
      widgets.add(
        AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppChip(
                    label: 'v${version.revision}',
                    dense: true,
                    color: context.palette.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      habitTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                  ),
                  Text(
                    AppDate.monthDayWithWeekday(version.createdAt),
                    style: context.texts.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '锚点：${version.anchorPrompt}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                '微行为：${version.tinyBehavior}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodyMedium,
              ),
              if (version.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(version.note, style: context.texts.labelSmall),
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _emptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.loop_outlined,
      title: '还没有微习惯',
      description: '从一个稳定锚点开始：晚饭后 → 打开书读 1 页。',
      action: AppPrimaryButton(
        label: '新建第一个微习惯',
        icon: Icons.add_rounded,
        onPressed: () => _createHabit(context),
      ),
    );
  }

  Widget _habitCard(BuildContext context, FoggHabit habit, {bool dimmed = false}) {
    final AppPalette palette = context.palette;
    final HabitService service = context.read<HabitService>();
    final bool done = service.isDoneToday(habit);
    final bool extra = service.isExtraToday(habit);
    final int streak = service.streak(habit);
    final List<bool> dots = service.dotPattern(habit);

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        onTap: () => showHabitRecipeDialog(context, habit: habit),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppChip(
                  label: habit.anchorPeriod.label,
                  dense: true,
                  color: palette.accent,
                ),
                const SizedBox(width: 6),
                if (streak > 0)
                  Text(
                    '连续 $streak 天',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                if (extra) ...<Widget>[
                  const SizedBox(width: 6),
                  AppChip(
                    label: '超额',
                    dense: true,
                    filled: true,
                    color: palette.success,
                  ),
                ],
                const Spacer(),
                Builder(
                  builder: (BuildContext anchorContext) => AppIconButton(
                    icon: Icons.more_horiz_rounded,
                    iconSize: 15,
                    size: 24,
                    tooltip: '更多',
                    onPressed: () => _openMenu(anchorContext, habit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(habit.anchorPrompt, style: context.texts.labelSmall),
            const SizedBox(height: 3),
            Text(
              habit.tinyBehavior,
              style: context.texts.bodyLarge?.copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: palette.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: <Widget>[
                _dotPattern(context, dots),
                const Spacer(),
                Text(
                  done ? '今天已完成' : '点圆圈打卡',
                  style: context.texts.labelSmall,
                ),
                const SizedBox(width: 8),
                AppCheckCircle(
                  checked: done,
                  size: 26,
                  padding: 0,
                  onTap: () => _toggle(context, habit),
                ),
              ],
            ),
            if (done && !extra) ...<Widget>[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: AppGhostButton(
                  label: '今天顺势多做 · 记超额',
                  dense: true,
                  onPressed: () => _recordExtra(context, habit),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dotPattern(BuildContext context, List<bool> pattern) {
    final AppPalette palette = context.palette;
    return Row(
      children: <Widget>[
        for (int index = 0; index < pattern.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 3),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: pattern[index]
                  ? palette.accent.withValues(alpha: 0.7)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: pattern[index] ? Colors.transparent : palette.border,
                width: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggle(BuildContext context, FoggHabit habit) async {
    final HabitService service = context.read<HabitService>();
    if (service.isDoneToday(habit)) {
      await service.undoToday(habit);
      return;
    }
    await service.checkIn(habit);
    if (!mounted) return;
    _toast('已完成 · ${habit.celebration}');
  }

  Future<void> _recordExtra(BuildContext context, FoggHabit habit) async {
    await context.read<HabitService>().checkIn(habit, extra: true);
    if (!mounted) return;
    _toast('已记录超额（不会抬高明天的门槛）');
  }

  Future<void> _createHabit(BuildContext context) async {
    await showHabitRecipeDialog(context);
  }

  Future<void> _openMenu(
    BuildContext anchorContext,
    FoggHabit habit,
  ) async {
    final AppPalette palette = anchorContext.palette;
    final RenderBox box = anchorContext.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(anchorContext).context.findRenderObject()! as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final String? action = await showMenu<String>(
      context: context,
      position: position,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'edit',
          height: 38,
          child: Text('调整配方', style: context.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'diagnose',
          height: 38,
          child: Text('福格曲线诊断', style: context.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'archive',
          height: 38,
          child: Text(
            '停用',
            style: context.texts.bodyMedium?.copyWith(color: palette.danger),
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await showHabitRecipeDialog(context, habit: habit);
      case 'diagnose':
        await _showDiagnosis(context, habit);
      case 'archive':
        await context.read<FoggHabitRepository>().save(
              habit.copyWith(isActive: false),
            );
    }
  }

  Future<void> _showDiagnosis(BuildContext context, FoggHabit habit) async {
    final HabitService service = context.read<HabitService>();
    final HabitDiagnosisResult result = service.diagnose(habit);
    final int done = service.completedInLastDays(habit, 7);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            0,
          ),
          title: Text('福格曲线诊断', style: dialogContext.texts.titleLarge),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            0,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    StatusDot(
                      color: result.kind == HabitDiagnosis.ok
                          ? palette.success
                          : palette.warning,
                      size: 6,
                    ),
                    const SizedBox(width: 6),
                    Text(result.title, style: dialogContext.texts.titleSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(result.advice, style: dialogContext.texts.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '近 7 天完成 $done 次 · 阻力：'
                  '${habit.frictions.labels.isEmpty ? '无明显阻力' : habit.frictions.labels.join(' / ')}',
                  style: dialogContext.texts.bodySmall,
                ),
                if (habit.abilityFrictionTip.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '降阻准备：${habit.abilityFrictionTip}',
                    style: dialogContext.texts.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '关闭',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppPrimaryButton(
              label: '去调整配方',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showHabitRecipeDialog(context, habit: habit);
              },
            ),
          ],
        );
      },
    );
  }

  void _toast(String message) {
    final AppPalette palette = context.palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: context.texts.bodyMedium?.copyWith(color: palette.background),
        ),
        backgroundColor: palette.textPrimary,
        behavior: SnackBarBehavior.floating,
        width: 300,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}