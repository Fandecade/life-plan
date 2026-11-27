
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router/module_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/habit_service.dart';
import '../../core/state/home_settings.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'countdown_format.dart';
import 'home_charts.dart';
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
    final HomeSettings homeSettings = context.watch<HomeSettings>();
    final DashboardService dashboard = context.read<DashboardService>();
    // 数据变化时重建主页。
    context.watch<ActionItemRepository>();
    context.watch<TimeBlockRepository>();
    context.watch<FoggHabitRepository>();
    context.watch<HabitLogRepository>();
    context.watch<LearningSessionRepository>();
    context.watch<CountdownRepository>();

    final DashboardSnapshot snapshot = dashboard.snapshot();
    final List<HomeCard> visible = homeSettings.order
        .where((HomeCard card) => homeSettings.isEnabled(card))
        .toList(growable: false);

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
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints inner) {
                        final double width = inner.maxWidth;
                        final bool twoCol = width >= 720;
                        const double gap = AppSpacing.lg;
                        if (visible.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Text(
                              '主页卡片都关掉了，可以在设置里重新打开。',
                              textAlign: TextAlign.center,
                              style: context.texts.bodySmall,
                            ),
                          );
                        }
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: <Widget>[
                            for (final HomeCard card in visible)
                              SizedBox(
                                key: ValueKey<String>(
                                  'home-card-${card.name}',
                                ),
                                width: !twoCol ||
                                        homeSettings.sizeOf(card) ==
                                            HomeCardSize.large
                                    ? width
                                    : (width - gap) / 2,
                                child: _cardFor(
                                  card,
                                  snapshot,
                                  homeSettings.sizeOf(card),
                                  homeSettings,
                                  dashboard,
                                ),
                              ),
                            ..._countdownCards(
                              context,
                              twoCol: twoCol,
                              width: width,
                              gap: gap,
                            ),
                          ],
                        );
                      },
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

  Widget _cardFor(
    HomeCard card,
    DashboardSnapshot snapshot,
    HomeCardSize size,
    HomeSettings settings,
    DashboardService dashboard,
  ) {
    switch (card) {
      case HomeCard.overview:
        return _OverviewCard(snapshot: snapshot, size: size);
      case HomeCard.heatmap:
        return _HeatmapCard(
          snapshot: snapshot,
          size: size,
          metric: _metric,
          onMetricChanged: (HeatmapMetric value) =>
              setState(() => _metric = value),
          onDayTap: _showDaySummary,
        );
      case HomeCard.rhythm:
        return _RhythmCards(snapshot: snapshot, size: size);
      case HomeCard.todos:
        return _TodoCard(size: size);
      case HomeCard.habits:
        return _HabitCard(size: size);
      case HomeCard.shortcuts:
        return _Shortcuts(size: size, ids: settings.shortcutIds);

      case HomeCard.trend:
        return _TrendCard(
          points: dashboard.recentDaily(snapshot),
          size: size,
        );
      case HomeCard.weekly:
        return _WeeklyCard(
          points: dashboard.recentWeeks(snapshot),
          size: size,
        );
      case HomeCard.capability:
        return _CapabilityCard(
          shares: dashboard.capabilityShares(),
          size: size,
        );
    }
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
  const _OverviewCard({required this.snapshot, required this.size});

  final DashboardSnapshot snapshot;
  final HomeCardSize size;

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
      padding: EdgeInsets.all(size.padding + 4),
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
    required this.size,
  });

  final DashboardSnapshot snapshot;
  final HeatmapMetric metric;
  final ValueChanged<HeatmapMetric> onMetricChanged;
  final void Function(DateTime day, DayStat stat) onDayTap;
  final HomeCardSize size;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(size.padding),
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
  const _RhythmCards({required this.snapshot, required this.size});

  final DashboardSnapshot snapshot;
  final HomeCardSize size;

  @override
  Widget build(BuildContext context) {
    final int percent = (snapshot.weekCompletion * 100).round();
    return Row(
      children: <Widget>[
        Expanded(
          child: _MiniStat(
            label: '连续记录',
            value: '${snapshot.streakDays} 天',
            size: size,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MiniStat(
            label: '本周完成',
            value: '$percent%',
            size: size,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MiniStat(
            label: '本周学习',
            size: size,
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
  const _MiniStat({
    required this.label,
    required this.value,
    required this.size,
  });

  final String label;
  final String value;
  final HomeCardSize size;

  @override
  Widget build(BuildContext context) {
    final double padding = size.padding * 0.75;
    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding,
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
  const _TodoCard({required this.size});

  final HomeCardSize size;

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
      padding: EdgeInsets.all(size.padding),
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
  const _HabitCard({required this.size});

  final HomeCardSize size;

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
      padding: EdgeInsets.all(size.padding),
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

List<Widget> _countdownCards(
  BuildContext context, {
  required bool twoCol,
  required double width,
  required double gap,
}) {
  final CountdownRepository repo = context.read<CountdownRepository>();
  final ActionItemRepository actions = context.read<ActionItemRepository>();
  final DateTime now = DateTime.now();
  final List<Widget> cards = <Widget>[];
  for (final Countdown item in repo.sorted()) {
    if (item.isTaskBound) {
      final ActionItem? task = actions.byId(item.sourceTaskId);
      if (task == null || task.isCompleted) continue;
    }
    if (item.autoHideExpired) {
      final DateTime? target = item.isTaskBound
          ? actions.byId(item.sourceTaskId)?.dueDate
          : item.targetAt;
      if (target != null && !target.isAfter(now)) continue;
    }
    cards.add(
      SizedBox(
        key: ValueKey<String>('countdown-card-${item.id}'),
        width: !twoCol ? width : (width - gap) / 2,
        child: _CountdownTileCard(item: item),
      ),
    );
    if (cards.length >= 6) break;
  }
  return cards;
}

class _CountdownTileCard extends StatefulWidget {
  const _CountdownTileCard({required this.item});

  final Countdown item;

  @override
  State<_CountdownTileCard> createState() => _CountdownTileCardState();
}

class _CountdownTileCardState extends State<_CountdownTileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (BuildContext context, Widget? child) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final ActionItemRepository actions = context.watch<ActionItemRepository>();
    final UiController ui = context.read<UiController>();
    final DateTime now = DateTime.now();
    final Countdown item = widget.item;

    DateTime? target = item.targetAt;
    String title = item.title.trim();
    String? taskId;
    if (item.isTaskBound) {
      final ActionItem? task = actions.byId(item.sourceTaskId);
      if (task == null || task.isCompleted) return const SizedBox.shrink();
      target = task.dueDate;
      taskId = task.id;
      if (title.isEmpty) title = task.title;
    }
    final bool expired = target != null && !target.isAfter(now);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (taskId != null) ...<Widget>[
                Icon(
                  Icons.task_alt_rounded,
                  size: 12,
                  color: context.palette.textTertiary,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title.isEmpty ? '倒计时' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
              ),
              Text('倒计时', style: context.texts.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () {
              if (taskId != null) {
                ui.openDetail(taskId!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('在「设置 → 主页」中编辑倒计时'),
                    behavior: SnackBarBehavior.floating,
                    width: 260,
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  target == null
                      ? '未设置时间'
                      : (expired
                          ? '已到期'
                          : formatCountdown(target.difference(now))),
                  style: context.texts.headlineSmall?.copyWith(
                    color: target == null
                        ? context.palette.textTertiary
                        : (expired
                            ? context.palette.danger
                            : context.palette.accent),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  target == null
                      ? '在设置中补上截止时间'
                      : countdownTargetLabel(target),
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.size, required this.ids});

  final HomeCardSize size;
  final List<String> ids;

  static const List<Color> _tones = <Color>[
    Color(0xFFDCE8D3),
    Color(0xFFE7E3F5),
    Color(0xFFDDE8F2),
    Color(0xFFF3E7DC),
    Color(0xFFE8E1DA),
    Color(0xFFDCE8E6),
  ];

  @override
  Widget build(BuildContext context) {
    final UiController ui = context.read<UiController>();
    final Map<String, AppModuleDescriptor> byId = <String, AppModuleDescriptor>{
      for (final AppModuleDescriptor module
          in context.watch<ModuleRegistry>().enabled)
        module.id: module,
    };
    final List<_Shortcut> items = <_Shortcut>[];
    for (final String id in ids) {
      final AppModuleDescriptor? module = byId[id];
      if (module == null) continue;
      items.add(
        _Shortcut(
          label: module.title,
          icon: module.icon,
          route: module.routeName,
          tone: _tones[items.length % _tones.length],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.all(size.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('快捷入口', style: context.texts.titleSmall),
              const Spacer(),
              AppGhostButton(
                label: '设置',
                dense: true,
                onPressed: () => ui.setRoute(AppRoutes.settings),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Text(
              '在「设置 → 主页 → 快捷入口」中添加常用模块。',
              style: context.texts.bodySmall,
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: size == HomeCardSize.compact
                  ? 2.9
                  : (size == HomeCardSize.large ? 2.2 : 2.5),
              children: <Widget>[
                for (final _Shortcut item in items)
                  _ShortcutTile(
                    item: item,
                    onTap: () => ui.setRoute(item.route),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points, required this.size});

  final List<DailyPoint> points;
  final HomeCardSize size;

  @override
  Widget build(BuildContext context) {
    return HomeChartCard(
      title: '近 14 天趋势',
      subtitle: '任务完成与学习投入',
      padding: size.padding,
      child: TrendChart(points: points),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.points, required this.size});

  final List<WeeklyPoint> points;
  final HomeCardSize size;

  @override
  Widget build(BuildContext context) {
    return HomeChartCard(
      title: '近四周对比',
      subtitle: '任务与学习投入的周度变化',
      padding: size.padding,
      child: WeeklyBars(points: points),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.shares, required this.size});

  final List<CapabilityShare> shares;
  final HomeCardSize size;

  @override
  Widget build(BuildContext context) {
    return HomeChartCard(
      title: '能力投入分布',
      subtitle: '近 30 天完成任务的占比',
      padding: size.padding,
      child: CapabilityRing(shares: shares),
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
