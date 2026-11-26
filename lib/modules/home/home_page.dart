import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router/module_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/habit_service.dart';
import '../../core/state/home_settings.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'home_heatmap.dart';

const AppModuleDescriptor homeDescriptor = AppModuleDescriptor(
  id: 'home',
  title: '主页',
  icon: Icons.home_rounded,
  routeName: AppRoutes.home,
  pageBuilder: _buildHomePage,
  isCore: true,
  description: '数据概览、热力图与常用板块',
);

Widget _buildHomePage(BuildContext context) => const HomePage();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HeatmapMetric _metric = HeatmapMetric.combined;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final HomeSettings homeSettings = context.watch<HomeSettings>();
    final DashboardService dashboard = context.read<DashboardService>();
    // 数据变化时重建主页。
    context.watch<ActionItemRepository>();
    context.watch<TimeBlockRepository>();
    context.watch<FoggHabitRepository>();
    context.watch<HabitLogRepository>();
    context.watch<LearningSessionRepository>();

    final DashboardSnapshot snapshot = dashboard.snapshot();
    final List<Widget> cards = <Widget>[];

    if (homeSettings.isEnabled(HomeCard.overview)) {
      cards.add(_OverviewCard(snapshot: snapshot));
    }
    if (homeSettings.isEnabled(HomeCard.heatmap)) {
      cards.add(
        _HeatmapCard(
          snapshot: snapshot,
          metric: _metric,
          onMetricChanged: (HeatmapMetric value) =>
              setState(() => _metric = value),
          onDayTap: _showDaySummary,
        ),
      );
    }
    if (homeSettings.isEnabled(HomeCard.rhythm)) {
      cards.add(_RhythmCards(snapshot: snapshot));
    }
    if (homeSettings.isEnabled(HomeCard.todos)) {
      cards.add(const _TodoCard());
    }
    if (homeSettings.isEnabled(HomeCard.habits)) {
      cards.add(const _HabitCard());
    }
    if (homeSettings.isEnabled(HomeCard.shortcuts)) {
      cards.add(const _Shortcuts());
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= 920;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 36 : 20,
            AppSpacing.xs,
            isDesktop ? 36 : 20,
            120,
          ),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Header(isDesktop: isDesktop),
                    const SizedBox(height: AppSpacing.lg),
                    for (int i = 0; i < cards.length; i++) ...<Widget>[
                      cards[i],
                      if (i != cards.length - 1)
                        const SizedBox(height: AppSpacing.lg),
                    ],
                    if (cards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Text(
                          '主页卡片都关掉了，可以在设置里重新打开。',
                          textAlign: TextAlign.center,
                          style: context.texts.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDaySummary(DateTime day, DayStat stat) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final AppPalette palette = sheetContext.palette;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color:
                  palette.glassEnabled ? palette.glass : palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: palette.glassBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppDate.monthDayWithWeekday(day),
                      style: sheetContext.texts.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SheetRow(label: '完成任务', value: '${stat.tasks} 项'),
                    _SheetRow(label: '微习惯打卡', value: '${stat.habits} 次'),
                    _SheetRow(
                      label: '学习投入',
                      value: '${stat.learningMinutes} 分钟',
                    ),
                    _SheetRow(label: '完成时间块', value: '${stat.blocks} 个'),
                    if (stat.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          '这一天没有记录，留白也算节奏。',
                          style: sheetContext.texts.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String greeting = now.hour < 6
        ? '夜深了，早点休息'
        : now.hour < 12
            ? '早上好'
            : now.hour < 18
                ? '下午好'
                : '晚上好';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${AppDate.monthDayWithWeekday(now)} · $greeting',
                style: context.texts.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '今天也按自己的节奏来',
                style: isDesktop
                    ? context.texts.headlineMedium
                    : context.texts.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppIconButton(
          icon: Icons.tune_rounded,
          tooltip: '设置',
          onPressed: () =>
              context.read<UiController>().setRoute(AppRoutes.settings),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = context.isDarkMode;
    final bool refresh = context.isRefreshStyle;
    final Color foreground = dark ? Colors.white : palette.textPrimary;
    final Color base = palette.accent;
    final Color start = Color.lerp(base, Colors.white, dark ? 0.06 : 0.42)!;
    final Color end = Color.lerp(base, Colors.black, dark ? 0.18 : 0.04)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: refresh
            ? LinearGradient(
                colors: <Color>[start, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: refresh ? null : palette.surface,
        borderRadius: BorderRadius.circular(refresh ? 28 : AppRadius.lg),
        border: refresh
            ? Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.18 : 0.35),
              )
            : Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '今日概览',
            style: context.texts.labelSmall?.copyWith(
              color: refresh
                  ? foreground.withValues(alpha: 0.7)
                  : palette.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _OverviewValue(
                label: '完成任务',
                value: '${snapshot.todayTasks}',
                foreground: refresh ? foreground : palette.textPrimary,
                subColor: refresh
                    ? foreground.withValues(alpha: 0.65)
                    : palette.textTertiary,
              ),
              _OverviewValue(
                label: '今日打卡',
                value:
                    '${snapshot.todayHabitsDone}/${snapshot.todayHabitsTotal}',
                foreground: refresh ? foreground : palette.textPrimary,
                subColor: refresh
                    ? foreground.withValues(alpha: 0.65)
                    : palette.textTertiary,
              ),
              _OverviewValue(
                label: '学习投入',
                value: '${snapshot.todayLearningMinutes} 分钟',
                foreground: refresh ? foreground : palette.textPrimary,
                subColor: refresh
                    ? foreground.withValues(alpha: 0.65)
                    : palette.textTertiary,
              ),
              _OverviewValue(
                label: '完成时间块',
                value: '${snapshot.todayBlocks}',
                foreground: refresh ? foreground : palette.textPrimary,
                subColor: refresh
                    ? foreground.withValues(alpha: 0.65)
                    : palette.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewValue extends StatelessWidget {
  const _OverviewValue({
    required this.label,
    required this.value,
    required this.foreground,
    required this.subColor,
  });

  final String label;
  final String value;
  final Color foreground;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: context.texts.headlineSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.texts.labelSmall?.copyWith(color: subColor),
        ),
      ],
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({
    required this.snapshot,
    required this.metric,
    required this.onMetricChanged,
    required this.onDayTap,
  });

  final DashboardSnapshot snapshot;
  final HeatmapMetric metric;
  final ValueChanged<HeatmapMetric> onMetricChanged;
  final void Function(DateTime day, DayStat stat) onDayTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('热力图', style: context.texts.titleSmall),
              const Spacer(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final HeatmapMetric value in HeatmapMetric.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _MetricPill(
                          label: value.label,
                          selected: value == metric,
                          onTap: () => onMetricChanged(value),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          HomeHeatmap(
            snapshot: snapshot,
            metric: metric,
            onDayTap: onDayTap,
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? palette.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: selected ? palette.background : palette.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RhythmCards extends StatelessWidget {
  const _RhythmCards({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final int percent = (snapshot.weekCompletion * 100).round();
    return Row(
      children: <Widget>[
        Expanded(
          child: _MiniStat(
            label: '连续记录',
            value: '${snapshot.streakDays} 天',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MiniStat(label: '本周完成', value: '$percent%'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MiniStat(
            label: '本周学习',
            value: snapshot.weekLearningMinutes >= 60
                ? '${(snapshot.weekLearningMinutes / 60).toStringAsFixed(1)}h'
                : '${snapshot.weekLearningMinutes}m',
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: context.texts.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.texts.labelSmall),
        ],
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard();

  @override
  Widget build(BuildContext context) {
    final DateTime today = AppDate.startOfDay(DateTime.now());
    final List<ActionItem> todos = context
        .watch<ActionItemRepository>()
        .all
        .where(
          (ActionItem item) =>
              !item.isCompleted &&
              item.scheduledDate != null &&
              AppDate.isSameDay(item.scheduledDate!, today),
        )
        .take(5)
        .toList(growable: false);
    final UiController ui = context.read<UiController>();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('今日待办', style: context.texts.titleSmall),
              const Spacer(),
              AppGhostButton(
                label: '查看全部',
                dense: true,
                onPressed: () => ui.setRoute(AppRoutes.timeBox),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                '今天还没有安排待办，留一点空白也好。',
                style: context.texts.bodySmall,
              ),
            )
          else
            for (final ActionItem item in todos)
              InkWell(
                onTap: () => ui.openDetail(item.id),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.radio_button_unchecked,
                        size: 15,
                        color: context.palette.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard();

  @override
  Widget build(BuildContext context) {
    final List<FoggHabit> habits =
        context.watch<FoggHabitRepository>().active.take(5).toList();
    final HabitService service = context.read<HabitService>();
    final int done = habits
        .where((FoggHabit habit) => service.isDoneToday(habit))
        .length;
    final UiController ui = context.read<UiController>();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('今日习惯', style: context.texts.titleSmall),
              const SizedBox(width: 6),
              Text(
                '$done/${habits.length}',
                style: context.texts.labelSmall,
              ),
              const Spacer(),
              AppGhostButton(
                label: '去打卡',
                dense: true,
                onPressed: () => ui.setRoute(AppRoutes.foggHabit),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (habits.isEmpty)
            Text('还没有微习惯，去福格习惯建立一个。', style: context.texts.bodySmall)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final FoggHabit habit in habits)
                  _HabitDot(
                    title: habit.tinyBehavior,
                    done: service.isDoneToday(habit),
                    onTap: () => ui.setRoute(AppRoutes.foggHabit),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HabitDot extends StatelessWidget {
  const _HabitDot({
    required this.title,
    required this.done,
    required this.onTap,
  });

  final String title;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: done ? palette.accentSoft : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14,
              color: done ? palette.accent : palette.textTertiary,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall?.copyWith(
                color: done ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final UiController ui = context.read<UiController>();
    final List<_Shortcut> items = <_Shortcut>[
      _Shortcut(
        label: '时间盒',
        icon: Icons.calendar_view_week_rounded,
        route: AppRoutes.timeBox,
        tone: const Color(0xFFDCE8D3),
      ),
      _Shortcut(
        label: '输出式学习',
        icon: Icons.auto_stories_rounded,
        route: AppRoutes.outputLearning,
        tone: const Color(0xFFE7E3F5),
      ),
      _Shortcut(
        label: '项目',
        icon: Icons.workspace_premium_rounded,
        route: AppRoutes.projects,
        tone: const Color(0xFFDDE8F2),
      ),
      _Shortcut(
        label: '及时复盘',
        icon: Icons.insights_rounded,
        route: AppRoutes.review,
        tone: const Color(0xFFF3E7DC),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('快捷入口', style: context.texts.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.6,
          children: <Widget>[
            for (final _Shortcut item in items)
              _ShortcutTile(
                item: item,
                onTap: () => ui.setRoute(item.route),
              ),
          ],
        ),
      ],
    );
  }
}

class _Shortcut {
  const _Shortcut({
    required this.label,
    required this.icon,
    required this.route,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final String route;
  final Color tone;
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item, required this.onTap});

  final _Shortcut item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = context.isDarkMode;
    final Color base = dark
        ? Color.lerp(item.tone, palette.background, 0.55)!
        : item.tone;
    final Color foreground = dark ? palette.textPrimary : palette.textPrimary;
    return Material(
      color: base,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(item.icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: foreground.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: context.texts.bodyMedium)),
          Text(
            value,
            style: context.texts.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}