import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/action_line.dart';
import '../../core/services/habit_service.dart';
import '../../core/services/review_service.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/state_views.dart';
import '../fogg_habit/habit_action_line_dialog.dart';
import '../fogg_habit/habit_recipe_dialog.dart';
import 'review_schedule_dialog.dart';
import '../time_box/routine_schedule_view.dart';

/// 及时复盘：日 / 周 / 月 / 年四级。
///
/// 数据先行（自动汇总四大模块）→ 引导式反思（AAR / 元认知）→
/// 待校准事项一键向下传导，复盘结束即已落进系统。
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  ReviewPeriodType _type = ReviewPeriodType.daily;
  DateTime _anchor = DateTime.now();

  final TextEditingController _wins = TextEditingController();
  final TextEditingController _blockers = TextEditingController();
  final TextEditingController _adjustments = TextEditingController();
  final TextEditingController _focus = TextEditingController();
  final TextEditingController _ifThen = TextEditingController();
  final TextEditingController _plan = TextEditingController();
  final TextEditingController _expected = TextEditingController();
  final TextEditingController _actual = TextEditingController();

  ReviewLog? _previousLog;
  String _previousPlan = '';
  String _previousExpected = '';

  final Set<String> _handled = <String>{};

  /// 本次会话内已处理的事项快照：动作后数据可能移出窗口，
  /// 但仍以「已划掉」的形式留在列表里，便于确认处理结果。
  final Map<String, ReviewItem> _handledItems = <String, ReviewItem>{};

  /// 本次会话内的撤销动作（点错了可回滚）。
  final Map<String, Future<void> Function()> _undo =
      <String, Future<void> Function()>{};
  Timer? _saveTimer;
  bool _initialized = false;

  ReviewWindow get _window => ReviewWindow.of(_type, _anchor);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _syncFromStore();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _wins.dispose();
    _blockers.dispose();
    _adjustments.dispose();
    _focus.dispose();
    _ifThen.dispose();
    _plan.dispose();
    _expected.dispose();
    _actual.dispose();
    super.dispose();
  }

  void _syncFromStore() {
    final ReviewWindow window = _window;
    final ReviewLog? log =
        context.read<ReviewLogRepository>().forPeriod(window.type, window.periodKey);
    _wins.text = log?.winsText ?? '';
    _blockers.text = log?.blockersText ?? '';
    _adjustments.text = log?.adjustmentsText ?? '';
    _focus.text = log?.focusText ?? '';
    _ifThen.text = log?.ifThenText ?? '';
    _plan.text = log?.adjustmentPlan ?? '';
    _expected.text = log?.expectedOutcome ?? '';

    final ReviewWindow previous =
        context.read<ReviewService>().previousWindow(window);
    final ReviewLog? previousLog = context
        .read<ReviewLogRepository>()
        .forPeriod(previous.type, previous.periodKey);
    _previousLog = previousLog;
    _previousPlan = previousLog?.adjustmentPlan ?? '';
    _previousExpected = previousLog?.expectedOutcome ?? '';
    _actual.text = previousLog?.actualOutcome ?? '';

    _handled
      ..clear()
      ..addAll(log?.handledItems ?? const <String>[]);
    _handledItems.clear();
    _undo.clear();
  }

  void _selectType(ReviewPeriodType type) {
    if (type == _type) return;
    setState(() => _type = type);
    _syncFromStore();
  }

  void _shift(int direction) {
    setState(() => _anchor = _window.shifted(direction));
    _syncFromStore();
  }

  Future<void> _confirmReopen() async {
    final AppPalette palette = context.palette;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: palette.border),
        ),
        title: Text('撤销完成标记？', style: dialogContext.texts.titleLarge),
        content: Text(
          '撤销后这份复盘会回到「未复盘」，文本与已处理事项都会保留。',
          style: dialogContext.texts.bodyMedium,
        ),
        actions: <Widget>[
          AppGhostButton(
            label: '保留完成',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppPrimaryButton(
            label: '撤销完成',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _persist(isCompleted: false);
    if (!mounted) return;
    _toast('已撤销完成标记，可继续补充');
  }

  Future<void> _openHistory() async {
    final AppPalette palette = context.palette;
    final List<ReviewLog> logs = context
        .read<ReviewLogRepository>()
        .all
        .where((ReviewLog log) =>
            log.isCompleted ||
            log.winsText.isNotEmpty ||
            log.blockersText.isNotEmpty ||
            log.adjustmentsText.isNotEmpty ||
            log.focusText.isNotEmpty)
        .toList()
      ..sort((ReviewLog a, ReviewLog b) => b.updatedAt.compareTo(a.updatedAt));

    final ReviewLog? picked = await showDialog<ReviewLog>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: palette.border),
        ),
        title: Text('历史复盘', style: dialogContext.texts.titleLarge),
        content: SizedBox(
          width: 520,
          child: logs.isEmpty
              ? Text('还没有历史复盘。', style: dialogContext.texts.bodySmall)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final ReviewLog log in logs)
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () => Navigator.of(dialogContext).pop(log),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: <Widget>[
                                AppChip(
                                  label: '${log.periodType.label}复盘',
                                  dense: true,
                                  color: palette.accent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        ReviewWindow.of(
                                          log.periodType,
                                          _anchorOfLog(log),
                                        ).label,
                                        style: dialogContext.texts.bodyMedium,
                                      ),
                                      if (log.winsText.isNotEmpty)
                                        Text(
                                          _firstSentence(log.winsText, 24),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              dialogContext.texts.labelSmall,
                                        ),
                                    ],
                                  ),
                                ),
                                if (log.isCompleted)
                                  AppChip(
                                    label: '已完成',
                                    dense: true,
                                    color: palette.success,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  AppDate.monthDayLabel(log.updatedAt),
                                  style: dialogContext.texts.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _type = picked.periodType;
      _anchor = _anchorOfLog(picked);
    });
    _syncFromStore();
  }

  DateTime _anchorOfLog(ReviewLog log) {
    switch (log.periodType) {
      case ReviewPeriodType.daily:
        return DateTime.tryParse(log.periodKey) ?? DateTime.now();
      case ReviewPeriodType.monthly:
        final List<String> parts = log.periodKey.split('-');
        if (parts.length < 2) return DateTime.now();
        return DateTime(
          int.tryParse(parts[0]) ?? DateTime.now().year,
          int.tryParse(parts[1]) ?? 1,
        );
      case ReviewPeriodType.yearly:
        return DateTime(int.tryParse(log.periodKey) ?? DateTime.now().year);
      case ReviewPeriodType.weekly:
        final List<String> parts = log.periodKey.split('-W');
        final int year = int.tryParse(parts.first) ?? DateTime.now().year;
        final int week =
            parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
        final DateTime jan4 = DateTime(year, 1, 4);
        final DateTime firstMonday =
            jan4.subtract(Duration(days: jan4.weekday - 1));
        return firstMonday.add(Duration(days: (week - 1) * 7));
    }
  }

  Future<void> _sedimentHabit() async {
    final String source = _wins.text.trim();
    if (source.isEmpty) {
      _toast('先写一条本周有效模式，再沉淀为微习惯');
      return;
    }
    final bool changed = await showHabitRecipeDialog(
      context,
      initialAnchor: '在「本周有效模式」之后',
      initialTiny: _firstSentence(source, 28),
    );
    if (!mounted || !changed) return;
    _toast('已沉淀为微习惯');
  }

  Future<void> _sedimentTemplate() async {
    final String source = _wins.text.trim();
    if (source.isEmpty) {
      _toast('先写一条本周有效模式，再存为学习模板');
      return;
    }
    await context.read<ActionItemRepository>().create(
          title: '学习模板：${_firstSentence(source, 20)}',
          executionMode: ExecutionMode.outputLearning,
          estimatedMinutes: 5,
          note: '复盘沉淀的学习模板：$source\n'
              '建议先用 5 分钟微输出验证一次，再固化为长期做法。',
        );
    if (!mounted) return;
    _toast('已存为学习模板任务（任务池）');
  }

  String _firstSentence(String text, int maxChars) {
    final String first = text
        .split(RegExp(r'[。！？!?\n;；]'))
        .map((String part) => part.trim())
        .firstWhere((String part) => part.isNotEmpty, orElse: () => text);
    return first.length > maxChars ? '${first.substring(0, maxChars)}…' : first;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _persist);
  }

  Future<void> _persist({bool? isCompleted}) async {
    final ReviewService service = context.read<ReviewService>();
    final ReviewWindow window = _window;
    await service.saveEntry(
      window,
      wins: _wins.text,
      blockers: _blockers.text,
      adjustments: _adjustments.text,
      focus: _focus.text,
      ifThen: _ifThen.text,
      adjustmentPlan: _plan.text,
      expectedOutcome: _expected.text,
      isCompleted: isCompleted,
      handled: _handled,
      stats: service.snapshotStats(window),
    );
    if (!mounted) return;
    if (isCompleted == true) {
      _toast('已完成本次复盘，文本与动作都已归档');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ReviewService service = context.read<ReviewService>();
    final ReviewLog? log =
        context.watch<ReviewLogRepository>().forPeriod(_type, _window.periodKey);
    // 数据看板随任一模块变化刷新
    context.watch<ActionItemRepository>();
    context.watch<TimeBlockRepository>();
    context.watch<HabitLogRepository>();
    final List<FoggHabit> activeHabits =
        context.watch<FoggHabitRepository>().active;
    context.watch<LearningReviewRepository>();
    context.watch<LearningSessionRepository>();

    final ReviewSnapshot snapshot = service.snapshot(_window);
    final bool deepPeriod = _type == ReviewPeriodType.monthly ||
        _type == ReviewPeriodType.yearly;
    final List<LearningBlindSpot> spots = _type == ReviewPeriodType.daily
        ? const <LearningBlindSpot>[]
        : service.blindSpots(_window);
    final List<CapabilityProgress> progress =
        deepPeriod ? service.capabilityProgress(_window) : const <CapabilityProgress>[];
    final List<FoggHabit> recipeHabits =
        deepPeriod ? service.habitsWithRecipeHistory() : const <FoggHabit>[];
    final List<HeatCell> heat = switch (_type) {
      ReviewPeriodType.monthly => service.dailyHeat(_window),
      ReviewPeriodType.yearly => service.monthlyHeat(_window.start.year),
      _ => const <HeatCell>[],
    };
    final List<LearningHighlight> highlights = _type == ReviewPeriodType.yearly
        ? service.annualHighlights(_window)
        : const <LearningHighlight>[];
    final List<ReviewItem> live = service.pending(_window, snapshot);
    final Set<String> liveIds =
        live.map((ReviewItem item) => item.id).toSet();
    final List<ReviewItem> items = <ReviewItem>[
      ...live,
      for (final ReviewItem item in _handledItems.values)
        if (!liveIds.contains(item.id)) item,
    ];
    final Set<String> handledIds = <String>{
      ...(log?.handledItems ?? const <String>[]),
      ..._handled,
    };
    final int openItems = items
        .where((ReviewItem item) => !handledIds.contains(item.id))
        .length;

    return Column(
      children: <Widget>[
        _header(context, palette, log, openItems),
        Divider(color: palette.hairline, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              _metrics(
                context,
                palette,
                snapshot,
                service.snapshot(service.previousWindow(_window)),
              ),
              const SizedBox(height: AppSpacing.md),
              _capabilityBar(context, palette, snapshot),
              if (_type != ReviewPeriodType.daily) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _insights(
                  context,
                  palette,
                  snapshot,
                  spots,
                  progress,
                  recipeHabits,
                  heat,
                  activeHabits,
                  highlights,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget reflection = _reflectionCard(context, palette);
                  final Widget pending =
                      _pendingCard(context, palette, items, openItems, handledIds);
                  if (constraints.maxWidth >= 940) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: reflection),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(flex: 2, child: pending),
                      ],
                    );
                  }
                  return Column(
                    children: <Widget>[
                      reflection,
                      const SizedBox(height: AppSpacing.md),
                      pending,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    AppPalette palette,
    ReviewLog? log,
    int openItems,
  ) {
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
                  '先看客观事实，再动笔；结论要落成具体动作，而不是写完就锁进历史。',
                  style: context.texts.bodySmall,
                ),
              ),
              AppGhostButton(
                label: '历史',
                icon: Icons.history_rounded,
                dense: true,
                onPressed: _openHistory,
              ),
              const SizedBox(width: 6),
              AppChip(
                label: log?.isCompleted == true ? '已完成' : '未复盘',
                dense: true,
                filled: true,
                color: log?.isCompleted == true
                    ? palette.success
                    : palette.warning,
              ),
              const SizedBox(width: 6),
              AppPrimaryButton(
                label: log?.isCompleted == true ? '已完成' : '标记完成',
                dense: true,
                onPressed: log?.isCompleted == true
                    ? _confirmReopen
                    : () => _persist(isCompleted: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final ReviewPeriodType type in ReviewPeriodType.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AppChip(
                            label: '${type.label}复盘',
                            dense: true,
                            filled: _type == type,
                            color: palette.accent,
                            onTap: () => _selectType(type),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppIconButton(
                icon: Icons.chevron_left_rounded,
                iconSize: 18,
                size: 26,
                tooltip: '上一个周期',
                onPressed: () => _shift(-1),
              ),
              Text(_window.label, style: context.texts.labelMedium),
              AppIconButton(
                icon: Icons.chevron_right_rounded,
                iconSize: 18,
                size: 26,
                tooltip: '下一个周期',
                onPressed: () => _shift(1),
              ),
            ],
          ),
          if (openItems > 0) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '本期有 $openItems 项可顺便校准；逐项处理或选择「暂不调整」后，随时可以完成复盘。',
              style: context.texts.labelSmall?.copyWith(color: palette.warning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metrics(
    BuildContext context,
    AppPalette palette,
    ReviewSnapshot snapshot,
    ReviewSnapshot previous,
  ) {
    final double hourDelta = snapshot.completedHours - previous.completedHours;
    final int taskDelta = snapshot.completedTasks - previous.completedTasks;
    final int habitDelta = snapshot.habitPercent - previous.habitPercent;
    final List<Widget> cards = <Widget>[
      _metricCard(
        context,
        palette,
        label: '时间投入',
        value: '${snapshot.completedHours.toStringAsFixed(1)}h',
        detail: '计划 ${snapshot.plannedHours.toStringAsFixed(1)}h · '
            '完成率 ${(snapshot.blockRate * 100).round()}%',
        delta: '较上期 ${hourDelta >= 0 ? '+' : ''}'
            '${hourDelta.toStringAsFixed(1)}h',
        deltaPositive: hourDelta >= 0,
        progress: snapshot.blockRate,
        tone: palette.accent,
      ),
      _metricCard(
        context,
        palette,
        label: '任务与学习',
        value: '完成 ${snapshot.completedTasks}',
        detail: '新增巩固 ${snapshot.consolidatingTasks} · '
            '独立输出 ${snapshot.outputs}',
        delta: '较上期 ${taskDelta >= 0 ? '+' : ''}$taskDelta 项',
        deltaPositive: taskDelta >= 0,
        progress: snapshot.completedTasks == 0
            ? 0
            : (snapshot.completedTasks /
                    (snapshot.completedTasks + snapshot.consolidatingTasks))
                .clamp(0, 1),
        tone: palette.success,
      ),
      _metricCard(
        context,
        palette,
        label: '微习惯节律',
        value: '${snapshot.habitPercent}%',
        detail: '完成 ${snapshot.habitChecks}/${snapshot.habitTarget} 次 · '
            '${snapshot.lowHabits.length} 项节奏偏缓',
        delta: '较上期 ${habitDelta >= 0 ? '+' : ''}$habitDelta 个百分点',
        deltaPositive: habitDelta >= 0,
        progress: snapshot.habitRate,
        tone: snapshot.lowHabits.isEmpty ? palette.success : palette.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            children: <Widget>[
              for (int i = 0; i < cards.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return Column(
          children: <Widget>[
            for (int i = 0; i < cards.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              cards[i],
            ],
          ],
        );
      },
    );
  }

  Widget _metricCard(
    BuildContext context,
    AppPalette palette, {
    required String label,
    required String value,
    required String detail,
    String? delta,
    bool deltaPositive = true,
    required double progress,
    required Color tone,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: context.texts.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: context.texts.titleLarge),
          const SizedBox(height: 2),
          Text(detail, style: context.texts.bodySmall),
          if (delta != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              delta,
              style: context.texts.labelSmall?.copyWith(
                color: deltaPositive ? palette.success : palette.danger,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ProgressHairline(value: progress, color: tone),
        ],
      ),
    );
  }

  void _openCapabilityOf(String? capabilityId) {
    final UiController ui = context.read<UiController>();
    if (capabilityId == null) {
      ui.setRoute('/vision-map');
    } else {
      ui.openCapability(capabilityId);
    }
  }

  Widget _capabilityBar(
    BuildContext context,
    AppPalette palette,
    ReviewSnapshot snapshot,
  ) {
    final List<CapabilitySlice> slices = snapshot.capabilitySlices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '能力精力分布',
          subtitle: '时间花在哪，成长就在哪；点击可跳到规划图谱',
        ),
        const SizedBox(height: 8),
        if (slices.isEmpty || snapshot.capacityMinutes == 0)
          Text('本期还没有排过时间块。', style: context.texts.bodySmall)
        else ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 9,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < slices.length; i++)
                    Expanded(
                      flex: math.max(1, slices[i].minutes),
                      child: InkWell(
                        onTap: () => _openCapabilityOf(slices[i].capabilityId),
                        child: ColoredBox(
                          color: slices[i].capabilityId == null
                              ? palette.surfaceMuted
                              : _sliceTones[i % _sliceTones.length],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              for (int i = 0; i < slices.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => _openCapabilityOf(slices[i].capabilityId),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: slices[i].capabilityId == null
                              ? palette.surfaceMuted
                              : _sliceTones[i % _sliceTones.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${slices[i].title} · '
                        '${(slices[i].minutes / 60).toStringAsFixed(1)}h',
                        style: context.texts.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _insights(
    BuildContext context,
    AppPalette palette,
    ReviewSnapshot snapshot,
    List<LearningBlindSpot> spots,
    List<CapabilityProgress> progress,
    List<FoggHabit> recipeHabits,
    List<HeatCell> heat,
    List<FoggHabit> activeHabits,
    List<LearningHighlight> highlights,
  ) {
    final bool deep = _type == ReviewPeriodType.monthly ||
        _type == ReviewPeriodType.yearly;
    final List<Widget> blocks = <Widget>[
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget learning = _learningCard(context, palette, snapshot, spots);
          final Widget? capability =
              deep ? _capabilityCard(context, palette, progress) : null;
          if (capability == null) return learning;
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: learning),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: capability),
              ],
            );
          }
          return Column(
            children: <Widget>[
              learning,
              const SizedBox(height: AppSpacing.md),
              capability,
            ],
          );
        },
      ),
    ];

    if (snapshot.capacityMinutes > 0) {
      blocks.add(const SizedBox(height: AppSpacing.md));
      blocks.add(_loadCard(context, palette, snapshot));
    }

    if (heat.isNotEmpty) {
      blocks.add(const SizedBox(height: AppSpacing.md));
      blocks.add(_heatCard(context, palette, heat));
    }

    if (recipeHabits.isNotEmpty) {
      blocks.add(const SizedBox(height: AppSpacing.md));
      blocks.add(_recipeCard(context, palette, recipeHabits));
    }

    if (_type != ReviewPeriodType.weekly) {
      blocks.add(const SizedBox(height: AppSpacing.md));
      blocks.add(_actionLineMiniCard(context, palette, activeHabits));
    }

    if (_type == ReviewPeriodType.yearly) {
      blocks.add(const SizedBox(height: AppSpacing.md));
      blocks.add(_highlightsCard(context, palette, highlights));
    }

    return Column(children: blocks);
  }

  Widget _learningCard(
    BuildContext context,
    AppPalette palette,
    ReviewSnapshot snapshot,
    List<LearningBlindSpot> spots,
  ) {
    final int due = snapshot.reviewsDue;
    final int done = snapshot.reviewsDone;
    final String recallRate =
        due == 0 ? '—' : '${((done / due) * 100).clamp(0, 100).round()}%';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '学习系统摘要',
            subtitle: '独立输出、复习节奏与卡壳盲区',
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              _miniStat(context, palette, '应复习', '$due'),
              _miniStat(context, palette, '已复习', '$done'),
              _miniStat(context, palette, '按时率', recallRate),
              _miniStat(context, palette, '独立输出', '${snapshot.outputs}'),
            ],
          ),
          if (spots.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text('卡壳盲区 · ${spots.length} 条', style: context.texts.labelSmall),
            const SizedBox(height: 4),
            for (final LearningBlindSpot spot in spots.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '· ${spot.text}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    AppPalette palette,
    String label,
    String value,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: context.texts.titleSmall),
          const SizedBox(height: 1),
          Text(label, style: context.texts.labelSmall),
        ],
      ),
    );
  }

  Widget _capabilityCard(
    BuildContext context,
    AppPalette palette,
    List<CapabilityProgress> progress,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '能力推进',
            subtitle: '彻底完成 / 巩固中 / 本期投入',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (progress.isEmpty)
            Text('本期没有能力推进数据。', style: context.texts.bodySmall)
          else
            for (final CapabilityProgress item in progress.take(5))
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => _openCapabilityOf(item.capabilityId),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodyMedium,
                        ),
                      ),
                      Text(
                        '完成 ${item.completed} · 巩固 ${item.consolidating}',
                        style: context.texts.labelSmall,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(item.minutes / 60).toStringAsFixed(1)}h',
                        style: context.texts.labelSmall?.copyWith(
                          color: palette.textSecondary,
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

  Widget _loadCard(
    BuildContext context,
    AppPalette palette,
    ReviewSnapshot snapshot,
  ) {
    final int total = snapshot.capacityMinutes;
    final Map<CognitiveLoad, int> minutes = snapshot.loadMinutes;
    final Map<CognitiveLoad, Color> tones = <CognitiveLoad, Color>{
      CognitiveLoad.high: palette.warning,
      CognitiveLoad.medium: palette.accent,
      CognitiveLoad.low: palette.textTertiary,
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '认知负荷结构',
            subtitle: '同等时长，不同脑力消耗；不是所有 2 小时都等价',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final CognitiveLoad load in <CognitiveLoad>[
            CognitiveLoad.high,
            CognitiveLoad.medium,
            CognitiveLoad.low,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 52,
                    child: Text(load.label, style: context.texts.labelSmall),
                  ),
                  Expanded(
                    child: ProgressHairline(
                      value: total == 0
                          ? 0
                          : (minutes[load] ?? 0) / total,
                      color: tones[load]!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${((minutes[load] ?? 0) / 60).toStringAsFixed(1)}h',
                      style: context.texts.labelSmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          if (snapshot.highLoadRate > 0.6) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '高负荷占比 ${(snapshot.highLoadRate * 100).round()}% 偏高：'
              '建议在时间盒里保留 10–15% 缓冲与恢复时间。',
              style: context.texts.labelSmall?.copyWith(color: palette.warning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heatCard(
    BuildContext context,
    AppPalette palette,
    List<HeatCell> cells,
  ) {
    final bool monthly = _type == ReviewPeriodType.monthly;
    int maxValue = 0;
    for (final HeatCell cell in cells) {
      if (cell.value > maxValue) maxValue = cell.value;
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: monthly ? '本月负荷热力' : '全年活跃热力',
            subtitle: monthly ? '每天已完成的时间块时长' : '每月已完成的时间块数',
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 46,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final HeatCell cell in cells)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.2),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: maxValue == 0
                                    ? 0.06
                                    : (cell.value / maxValue).clamp(0.06, 1),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: palette.accent.withValues(
                                      alpha: cell.value == 0 ? 0.08 : 0.45,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cell.label,
                            style: context.texts.labelSmall?.copyWith(
                              fontSize: 8,
                              height: 1,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipeCard(
    BuildContext context,
    AppPalette palette,
    List<FoggHabit> habits,
  ) {
    final ReviewService service = context.read<ReviewService>();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '配方版本执行率',
            subtitle: '调整前后对比：v1 → v2 是否真的更容易发生',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final FoggHabit habit in habits.take(3))
            Builder(
              builder: (BuildContext context) {
                final List<RecipeEffect> effects = service.recipeEffects(habit.id);
                if (effects.length < 2) return const SizedBox.shrink();
                final RecipeEffect previous = effects[effects.length - 2];
                final RecipeEffect latest = effects.last;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              habit.tinyBehavior,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodyMedium,
                            ),
                          ),
                          Text(
                            'v${previous.revision} → v${latest.revision}',
                            style: context.texts.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ProgressHairline(
                              value: previous.rate,
                              color: palette.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ProgressHairline(
                              value: latest.rate,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Text(
                            '${(previous.rate * 100).round()}%',
                            style: context.texts.labelSmall,
                          ),
                          const Spacer(),
                          Text(
                            '${(latest.rate * 100).round()}%',
                            style: context.texts.labelSmall?.copyWith(
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _actionLineMiniCard(
    BuildContext context,
    AppPalette palette,
    List<FoggHabit> habits,
  ) {
    final HabitService habitService = context.read<HabitService>();
    final List<FoggHabit> shown = habits.take(5).toList(growable: false);
    const ActionLineModel line = ActionLineModel();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SectionHeader(
                  title: '习惯行动线',
                  subtitle: '点击节点可调配方；落在行动线下方优先缩小微行为',
                ),
              ),
              AppGhostButton(
                label: '改固定安排',
                icon: Icons.event_repeat_rounded,
                dense: true,
                onPressed: () => showRoutineSchedule(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (shown.isEmpty)
            Text('还没有可诊断的微习惯。', style: context.texts.bodySmall)
          else
            SizedBox(
              height: 150,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size size =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  final Rect plot =
                      Rect.fromLTRB(8, 8, size.width - 8, size.height - 8);
                  return Container(
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MiniActionLinePainter(
                              plot: plot,
                              line: line,
                              accent: palette.accent,
                              success: palette.success,
                              danger: palette.danger,
                              axis: palette.border,
                            ),
                          ),
                        ),
                        for (final FoggHabit habit in shown)
                          _miniHabitPoint(
                            context,
                            palette,
                            habitService,
                            habit,
                            plot,
                            size,
                            line,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniHabitPoint(
    BuildContext context,
    AppPalette palette,
    HabitService habitService,
    FoggHabit habit,
    Rect plot,
    Size size,
    ActionLineModel line,
  ) {
    final ActionPoint point = habitService.currentActionPoint(habit);
    final bool above = line.isAbove(point);
    final Offset offset = Offset(
      plot.left + point.ability / 10 * plot.width,
      plot.bottom - point.motivation / 10 * plot.height,
    );
    final String label = habit.tinyBehavior.length > 6
        ? '${habit.tinyBehavior.substring(0, 6)}…'
        : habit.tinyBehavior;

    return Positioned(
      left: (offset.dx - 20).clamp(4, size.width - 72),
      top: (offset.dy - 8).clamp(4, size.height - 18),
      child: GestureDetector(
        onTap: () => showHabitActionLineDialog(context, habit: habit),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: above ? palette.success : palette.danger,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface, width: 1.2),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: context.texts.labelSmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightsCard(
    BuildContext context,
    AppPalette palette,
    List<LearningHighlight> highlights,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '年度成果精选',
            subtitle: '输出式学习完成的作品与摘要，点击查看任务',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (highlights.isEmpty)
            Text('今年还没有完成的输出成果。', style: context.texts.bodySmall)
          else
            for (final LearningHighlight highlight in highlights)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () =>
                    context.read<UiController>().openDetail(highlight.actionItemId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: palette.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              highlight.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodyMedium,
                            ),
                            if (highlight.summary.isNotEmpty)
                              Text(
                                highlight.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.labelSmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppDate.monthDayLabel(highlight.completedAt),
                        style: context.texts.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _reflectionCard(BuildContext context, AppPalette palette) {
    final List<_Question> questions = _questionsFor(_type);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '引导式复盘',
            subtitle: _type == ReviewPeriodType.daily
                ? '3–5 分钟：只看今天执行与明日微调'
                : '对事不对人：先分清系统问题与外部干扰',
          ),
          if (_previousPlan.isNotEmpty) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: palette.surfaceMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: palette.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('上期调整回看', style: context.texts.titleSmall),
                  const SizedBox(height: 4),
                  Text('方案：$_previousPlan', style: context.texts.bodySmall),
                  if (_previousExpected.isNotEmpty)
                    Text(
                      '预期：$_previousExpected',
                      style: context.texts.bodySmall,
                    ),
                  const SizedBox(height: 6),
                  AppTextField(
                    key: const ValueKey<String>('review-previous-actual'),
                    controller: _actual,
                    maxLines: 2,
                    minLines: 1,
                    hintText: '实际效果如何？写下来，下期闭环才算完成',
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppGhostButton(
                      label: '保存实际效果',
                      dense: true,
                      onPressed: _savePreviousOutcome,
                    ),
                  ),
                ],
              ),
            ),
          ],
          for (final _Question question in questions) ...<Widget>[
            Text(question.title, style: context.texts.labelSmall),
            const SizedBox(height: 4),
            AppTextField(
              key: ValueKey<String>('review-q-${question.title}'),
              controller: question.controller,
              hintText: question.hint,
              maxLines: 3,
              minLines: 2,
              onChanged: (_) => _scheduleSave(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_type != ReviewPeriodType.daily) ...<Widget>[
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                AppGhostButton(
                  label: '沉淀为微习惯',
                  icon: Icons.loop_rounded,
                  dense: true,
                  onPressed: _sedimentHabit,
                ),
                AppGhostButton(
                  label: '存为学习模板',
                  icon: Icons.school_outlined,
                  dense: true,
                  onPressed: _sedimentTemplate,
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '自动保存草稿 · 离开页面也不会丢',
            style: context.texts.labelSmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  List<_Question> _questionsFor(ReviewPeriodType type) {
    switch (type) {
      case ReviewPeriodType.daily:
        return <_Question>[
          _Question(
            '今日亮点（1 句）',
            '今天最值得肯定的一步推进是什么？',
            _wins,
          ),
          _Question(
            '明日最关键 1–3 件事',
            '只写必须推动的核心，不要列成待办清单',
            _focus,
          ),
        ];
      case ReviewPeriodType.weekly:
        return <_Question>[
          _Question('本周有效模式（Keep）', '哪套做法最有效？可沉淀为习惯或模板', _wins),
          _Question(
            '最大瓶颈 · 元认知自问',
            '是排期过载、只输入没输出，还是习惯落在行动线下方？',
            _blockers,
          ),
          _Question('下周结构性调整', '要改的不是「更努力」，而是结构', _adjustments),
          _Question(
            'If–Then 预案',
            '例：如果周三加班，就把 1 小时学习缩成 5 分钟微输出',
            _ifThen,
          ),
          _Question(
            '本期调整方案（可验证）',
            '具体改什么：任务颗粒度 / 时间安排 / 学习策略 / 习惯配方',
            _plan,
          ),
          _Question(
            '预期效果',
            '希望看到什么变化？例：完成率 +10%、估时误差下降、复习按时率提升',
            _expected,
          ),
        ];
      case ReviewPeriodType.monthly:
        return <_Question>[
          _Question('能力推进评估', '哪些能力有实质突破？哪些连续两周停滞？', _wins),
          _Question('停滞与偏离', '沉没成本止损：哪些目标已不合时宜？', _blockers),
          _Question('目标减法（Stop Doing）', '决定暂停或归档什么，给核心能力腾空间', _adjustments),
          _Question(
            '本期调整方案（可验证）',
            '具体改什么：能力布局 / 时间结构 / 项目取舍',
            _plan,
          ),
          _Question(
            '预期效果',
            '希望看到什么变化？例：核心能力投入占比提升、停滞能力恢复推进',
            _expected,
          ),
        ];
      case ReviewPeriodType.yearly:
        return <_Question>[
          _Question('年度代表作', '今年最拿得出手的成果与作品是什么？', _wins),
          _Question(
            '愿景对齐',
            '我是不是在用低难度的假努力回避核心短板？排期与 3 年愿景一致吗？',
            _blockers,
          ),
          _Question('下一年度布局', '愿景与核心能力如何调整？', _adjustments),
        ];
    }
  }

  Widget _pendingCard(
    BuildContext context,
    AppPalette palette,
    List<ReviewItem> items,
    int openItems,
    Set<String> handledIds,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '待校准事项 · $openItems',
            subtitle: '点完一项划掉一项，复盘结束即已落进系统',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Text('本期没有需要特别调整的事项。', style: context.texts.bodySmall)
          else
            for (final ReviewItem item in items) ...<Widget>[
              _pendingRow(context, palette, item, handledIds),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  Widget _pendingRow(
    BuildContext context,
    AppPalette palette,
    ReviewItem item,
    Set<String> handledIds,
  ) {
    final bool handled = handledIds.contains(item.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: handled ? palette.textTertiary : _kindTone(palette, item.kind),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodyMedium?.copyWith(
                  decoration: handled ? TextDecoration.lineThrough : null,
                  decorationColor: palette.textTertiary,
                  color: handled ? palette.textTertiary : null,
                ),
              ),
              Text(item.subtitle, style: context.texts.labelSmall),
            ],
          ),
        ),
        if (handled)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('已处理', style: context.texts.labelSmall),
              if (_undo.containsKey(item.id)) ...<Widget>[
                const SizedBox(width: 2),
                AppGhostButton(
                  label: '撤销',
                  dense: true,
                  onPressed: () => _undoItem(item),
                ),
              ],
            ],
          )
        else
          _itemActions(context, palette, item),
      ],
    );
  }

  Widget _itemActions(
    BuildContext context,
    AppPalette palette,
    ReviewItem item,
  ) {
    switch (item.kind) {
      case ReviewItemKind.unfinishedBlock:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppGhostButton(
              label: '安排日期',
              dense: true,
              onPressed: () => _runItem(item, 'scheduleBlock'),
            ),
            Builder(
              builder: (BuildContext anchorContext) => AppIconButton(
                icon: Icons.more_horiz_rounded,
                iconSize: 15,
                size: 26,
                tooltip: '更多处理',
                onPressed: () async {
                  final String? action =
                      await _showBlockMenu(anchorContext, palette);
                  if (action == null) return;
                  await _runItem(item, action);
                },
              ),
            ),
          ],
        );
      case ReviewItemKind.overdueReview:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppGhostButton(
              label: '安排时间',
              dense: true,
              onPressed: () => _runItem(item, 'scheduleReview'),
            ),
            Builder(
              builder: (BuildContext anchorContext) => AppIconButton(
                icon: Icons.more_horiz_rounded,
                iconSize: 15,
                size: 26,
                tooltip: '更多处理',
                onPressed: () async {
                  final String? action =
                      await _showReviewMenu(anchorContext, palette);
                  if (action == null) return;
                  await _runItem(item, action);
                },
              ),
            ),
          ],
        );
      case ReviewItemKind.lowHabit:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppGhostButton(
              label: '调配方',
              dense: true,
              onPressed: () => _runItem(item, 'habit'),
            ),
            _skipButton(context, palette, item),
          ],
        );
      case ReviewItemKind.staleTask:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppGhostButton(
              label: '归档',
              dense: true,
              onPressed: () => _runItem(item, 'archive'),
            ),
            _skipButton(context, palette, item),
          ],
        );
      case ReviewItemKind.learningBlindSpot:
        final bool suggested = item.blindSpot?.isSuggested ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppGhostButton(
              label: suggested ? '确认补盲' : '生成补盲任务',
              dense: true,
              onPressed: () => _runItem(item, 'blind'),
            ),
            _skipButton(
              context,
              palette,
              item,
              label: suggested ? '忽略这条建议' : '暂不调整（维持现状）',
            ),
          ],
        );
    }
  }

  Widget _skipButton(
    BuildContext context,
    AppPalette palette,
    ReviewItem item, {
    String label = '暂不调整（维持现状）',
  }) {
    return Builder(
      builder: (BuildContext anchorContext) => AppIconButton(
        icon: Icons.more_horiz_rounded,
        iconSize: 15,
        size: 26,
        tooltip: label,
        onPressed: () async {
          final String? action =
              await _showSkipMenu(anchorContext, palette, label: label);
          if (action == null) return;
          await _runItem(item, action);
        },
      ),
    );
  }

  Future<String?> _showSkipMenu(
    BuildContext anchorContext,
    AppPalette palette, {
    String label = '暂不调整（维持现状）',
  }) async {
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
    return showMenu<String>(
      context: anchorContext,
      position: position,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'rootcause',
          height: 38,
          child: Text('判断原因并调整…', style: context.texts.bodyMedium),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'skip',
          height: 38,
          child: Text(label, style: context.texts.bodyMedium),
        ),
      ],
    );
  }

  Future<String?> _showReviewMenu(
    BuildContext anchorContext,
    AppPalette palette,
  ) async {
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
    return showMenu<String>(
      context: anchorContext,
      position: position,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'spread',
          height: 38,
          child: Text('分散复习负载…', style: context.texts.bodyMedium),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'rootcause',
          height: 38,
          child: Text('判断原因并调整…', style: context.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'skip',
          height: 38,
          child: Text('暂不调整（维持现状）', style: context.texts.bodyMedium),
        ),
      ],
    );
  }

  Future<String?> _showBlockMenu(
    BuildContext anchorContext,
    AppPalette palette,
  ) async {
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
    return showMenu<String>(
      context: anchorContext,
      position: position,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'decompose',
          height: 38,
          child: Text('拆解任务（去图谱）', style: context.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'inbox',
          height: 38,
          child: Text('回任务池', style: context.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'cancel',
          height: 38,
          child: Text(
            '取消',
            style: context.texts.bodyMedium?.copyWith(color: palette.danger),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'rootcause',
          height: 38,
          child: Text('判断原因并调整…', style: context.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'skip',
          height: 38,
          child: Text('暂不调整（维持现状）', style: context.texts.bodyMedium),
        ),
      ],
    );
  }

  Future<void> _runItem(ReviewItem item, String action) async {
    final ReviewService service = context.read<ReviewService>();
    final TimeBlockRepository blockRepo = context.read<TimeBlockRepository>();
    final ActionItemRepository actionRepo = context.read<ActionItemRepository>();
    final LearningReviewRepository reviewRepo =
        context.read<LearningReviewRepository>();
    final UiController ui = context.read<UiController>();

    if (action == 'rootcause') {
      await _openRootCauseDialog(item);
      return;
    }

    if (action == 'habit') {
      final FoggHabit? habit = item.habit;
      if (habit == null) return;
      final HabitRecipeVersion? version =
          await showHabitActionLineDialog(context, habit: habit);
      if (!mounted) return;
      if (version != null) {
        await service.markHandled(_window, item.id);
        if (!mounted) return;
        setState(() {
          _handled.add(item.id);
          _handledItems[item.id] = item;
        });
        _toast('已按推演生成 v${version.revision} 配方');
      }
      return;
    }

    final TimeBlock? block = item.block;
    final ActionItem? task = item.task;
    final LearningReview? review = item.review;
    Future<void> Function()? restore;

    switch (action) {
      case 'skip':
        restore = () async {};
      case 'scheduleBlock':
        if (block == null) return;
        final ReviewScheduleResult? picked = await showReviewScheduleDialog(
          context,
          initial: block.startAt,
          initialMinutes: block.plannedMinutes,
          title: '安排时间块',
          hint: '确认后同步到时间盒，日期、时间与时长都可随时再改',
        );
        if (picked == null) return;
        final DateTime original = block.startAt;
        final int originalMinutes = block.plannedMinutes;
        await service.moveBlockTo(
          block,
          picked.start,
          minutes: picked.minutes,
        );
        restore = () async {
          final TimeBlock? current = blockRepo.byId(block.id);
          if (current != null) {
            await service.moveBlockTo(
              current,
              original,
              minutes: originalMinutes,
            );
          }
        };
      case 'scheduleReview':
        if (review == null) return;
        final DateTime originalDue = review.dueDate;
        final DateTime defaultStart = originalDue.isAfter(DateTime.now())
            ? originalDue
            : AppDate.startOfDay(
                DateTime.now().add(const Duration(days: 1)),
              ).add(const Duration(hours: 20));
        final ReviewScheduleResult? picked = await showReviewScheduleDialog(
          context,
          initial: defaultStart,
          initialMinutes: 15,
          title: '安排复习',
          hint: '会同步生成时间盒块，点开直接进入主动回忆；时长可随手改',
        );
        if (picked == null) return;
        final TimeBlock created = await service.scheduleReviewAt(
          review,
          picked.start,
          minutes: picked.minutes,
        );
        restore = () async {
          await reviewRepo.save(review.copyWith(dueDate: originalDue));
          await blockRepo.softDelete(created.id);
        };
      case 'decompose':
        if (task == null) return;
        ui.openTaskLocation(task.id);
      case 'inbox':
        if (block == null && task == null) return;
        final ActionItemStatus? status = task?.status;
        if (block != null) {
          await service.returnBlockToInbox(block);
        } else if (task != null) {
          await service.returnToInbox(task);
        }
        restore = () async {
          if (block != null) await blockRepo.put(block);
          if (task != null && status != null) {
            await actionRepo.setStatus(task.id, status);
          }
        };
      case 'cancel':
        if (block == null) return;
        final ActionItemStatus? status = task?.status;
        await service.cancelBlock(block);
        restore = () async {
          await blockRepo.put(block);
          if (task != null && status != null) {
            await actionRepo.setStatus(task.id, status);
          }
        };
      case 'archive':
        if (task == null) return;
        final ActionItemStatus archived = task.status;
        await service.archiveTask(task);
        restore = () => actionRepo.setStatus(task.id, archived);
      case 'spread':
        if (review == null) return;
        final DateTime originalDue = review.dueDate;
        final ({int days, int perDay, int hour})? plan =
            await _openSpreadDialog();
        if (plan == null) return;
        await service.spreadReviewLoad(
          <LearningReview>[review],
          days: plan.days,
          perDay: plan.perDay,
          hour: plan.hour,
        );
        restore = () => reviewRepo.save(review.copyWith(dueDate: originalDue));
      case 'blind':
        final LearningBlindSpot? spot = item.blindSpot;
        if (spot == null) return;
        final ActionItem created = await service.createBlindSpotTask(spot);
        restore = () => actionRepo.hardDelete(created.id);
    }

    await service.markHandled(_window, item.id);
    if (!mounted) return;
    setState(() {
      _handled.add(item.id);
      _handledItems[item.id] = item;
      _undo[item.id] = restore ?? () async {};
    });
    _toast(_actionToast(action));
  }

  Future<void> _openRootCauseDialog(ReviewItem item) async {
    const List<String> causes = <String>[
      '目标过大',
      '能力不足',
      '时间不足',
      '行为阻力',
      '目标不再重要',
      '估时不准',
    ];
    final AppPalette palette = context.palette;
    String? selected;
    final String? cause = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          title: Text('这件事为什么没推进？', style: context.texts.titleLarge),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '先判断原因，再选择对应调整方式，而不是一律重排时间。',
                  style: context.texts.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final String item in causes)
                      AppChip(
                        label: item,
                        dense: true,
                        filled: selected == item,
                        color: palette.accent,
                        onTap: () => setLocal(() => selected = item),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppPrimaryButton(
              label: '按此调整',
              onPressed: selected == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(selected),
            ),
          ],
        ),
      ),
    );
    if (cause == null || !mounted) return;
    final String action = _actionForCause(item, cause);
    await _runItem(item, action);
    if (!mounted) return;
    _toast('已按「$cause」处理：${_actionToast(action)}');
  }

  String _actionForCause(ReviewItem item, String cause) {
    switch (cause) {
      case '目标过大':
        return item.task != null ? 'decompose' : 'scheduleBlock';
      case '能力不足':
        if (item.blindSpot != null) return 'blind';
        return item.task != null ? 'decompose' : 'skip';
      case '时间不足':
        if (item.block != null) return 'scheduleBlock';
        if (item.review != null) return 'scheduleReview';
        return 'skip';
      case '行为阻力':
        return item.habit != null ? 'habit' : 'skip';
      case '目标不再重要':
        if (item.task != null) return 'archive';
        return item.block != null ? 'cancel' : 'skip';
      case '估时不准':
        return item.block != null ? 'scheduleBlock' : 'skip';
    }
    return 'skip';
  }

  Future<({int days, int perDay, int hour})?> _openSpreadDialog() {
    final AppPalette palette = context.palette;
    int days = 3;
    int perDay = 2;
    int hour = 20;

    return showDialog<({int days, int perDay, int hour})>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) {
          return AlertDialog(
            backgroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: palette.border),
            ),
            title: Text('分散复习负载', style: context.texts.titleLarge),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('分散天数', style: context.texts.labelSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final int value in <int>[2, 3, 5, 7])
                        AppChip(
                          label: '$value 天',
                          dense: true,
                          filled: value == days,
                          color: palette.accent,
                          onTap: () => setLocal(() => days = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('每天最多', style: context.texts.labelSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final int value in <int>[1, 2, 3])
                        AppChip(
                          label: '$value 条',
                          dense: true,
                          filled: value == perDay,
                          color: palette.accent,
                          onTap: () => setLocal(() => perDay = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('安排在', style: context.texts.labelSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final int value in <int>[19, 20, 21, 22])
                        AppChip(
                          label: '${AppDate.two(value)}:00',
                          dense: true,
                          filled: value == hour,
                          color: palette.accent,
                          onTap: () => setLocal(() => hour = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '这些只是默认值，之后仍可在时间盒里逐条调整。',
                    style: context.texts.labelSmall,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              AppGhostButton(
                label: '取消',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              AppPrimaryButton(
                label: '确认分散',
                onPressed: () => Navigator.of(dialogContext).pop(
                  (days: days, perDay: perDay, hour: hour),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _savePreviousOutcome() async {
    final ReviewLog? previous = _previousLog;
    if (previous == null) return;
    await context.read<ReviewLogRepository>().save(
          previous.copyWith(actualOutcome: _actual.text),
        );
    if (!mounted) return;
    _toast('已记录上期调整的实际效果');
  }

  Future<void> _undoItem(ReviewItem item) async {
    final ReviewService service = context.read<ReviewService>();
    final Future<void> Function()? restore = _undo.remove(item.id);
    if (restore != null) await restore();
    await service.unmarkHandled(_window, item.id);
    if (!mounted) return;
    setState(() {
      _handled.remove(item.id);
      _handledItems.remove(item.id);
    });
    _toast('已撤销该项处理');
  }

  Color _kindTone(AppPalette palette, ReviewItemKind kind) {
    switch (kind) {
      case ReviewItemKind.unfinishedBlock:
        return palette.warning;
      case ReviewItemKind.overdueReview:
        return palette.accent;
      case ReviewItemKind.lowHabit:
        return palette.accent;
      case ReviewItemKind.staleTask:
        return palette.textTertiary;
      case ReviewItemKind.learningBlindSpot:
        return palette.accent;
    }
  }

  String _actionToast(String action) {
    switch (action) {
      case 'scheduleBlock':
        return '已安排到所选日期与时间';
      case 'scheduleReview':
        return '已安排复习，并同步到时间盒';
      case 'decompose':
        return '已跳到图谱对应任务，去那里拆解';
      case 'skip':
        return '已记录：暂不调整（维持现状）';
      case 'inbox':
        return '已暂存回任务池';
      case 'cancel':
        return '已取消该时间块';
      case 'archive':
        return '已归档，腾出时间盒空间';
      case 'blind':
        return '已生成回炉补盲任务，已放入任务池';
      case 'spread':
        return '已按你的设置分散复习';
      default:
        return '已处理';
    }
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
        width: 320,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _Question {
  const _Question(this.title, this.hint, this.controller);

  final String title;
  final String hint;
  final TextEditingController controller;
}

class _MiniActionLinePainter extends CustomPainter {
  const _MiniActionLinePainter({
    required this.plot,
    required this.line,
    required this.accent,
    required this.success,
    required this.danger,
    required this.axis,
  });

  final Rect plot;
  final ActionLineModel line;
  final Color accent;
  final Color success;
  final Color danger;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(plot, Paint()..color = danger.withValues(alpha: 0.04));

    final Path curve = Path();
    for (int i = 0; i <= 40; i++) {
      final double ability = i / 40 * 10;
      final Offset point = Offset(
        plot.left + ability / 10 * plot.width,
        plot.bottom - line.requiredMotivation(ability) / 10 * plot.height,
      );
      if (i == 0) {
        curve.moveTo(point.dx, point.dy);
      } else {
        curve.lineTo(point.dx, point.dy);
      }
    }
    final Path aboveArea = Path.from(curve)
      ..lineTo(plot.right, plot.top)
      ..lineTo(plot.left, plot.top)
      ..close();
    canvas.drawPath(
      aboveArea,
      Paint()..color = success.withValues(alpha: 0.06),
    );

    final Paint axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axisPaint,
    );

    canvas.drawPath(
      curve,
      Paint()
        ..color = accent.withValues(alpha: 0.7)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniActionLinePainter oldDelegate) =>
      oldDelegate.plot != plot ||
      oldDelegate.line.threshold != line.threshold ||
      oldDelegate.line.curvature != line.curvature ||
      oldDelegate.accent != accent;
}

/// 低饱和能力配色，避免时间分布条变成高饱和色块。
const List<Color> _sliceTones = <Color>[
  Color(0xFF7E90A8),
  Color(0xFF8B9E87),
  Color(0xFFA89785),
  Color(0xFF9B8DA8),
  Color(0xFF9FA79C),
  Color(0xFFB0A293),
];