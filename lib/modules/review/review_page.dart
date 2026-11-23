import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/review_service.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/state_views.dart';
import '../fogg_habit/habit_action_line_dialog.dart';

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

  final Set<String> _handled = <String>{};

  /// 本次会话内已处理的事项快照：动作后数据可能移出窗口，
  /// 但仍以「已划掉」的形式留在列表里，便于确认处理结果。
  final Map<String, ReviewItem> _handledItems = <String, ReviewItem>{};
  Timer? _saveTimer;
  bool _initialized = false;

  ReviewWindow get _window => ReviewWindow.of(_type, _anchor);

  /// 周期越长，未完成事项顺延的粒度越粗（下周 / 下月 / 明年）。
  String get _pushLabel {
    switch (_type) {
      case ReviewPeriodType.daily:
        return '排入明日';
      case ReviewPeriodType.weekly:
        return '排入下周';
      case ReviewPeriodType.monthly:
        return '排入下月';
      case ReviewPeriodType.yearly:
        return '排入明年';
    }
  }

  DateTime get _pushTarget {
    final DateTime now = DateTime.now();
    switch (_type) {
      case ReviewPeriodType.daily:
        return now.add(const Duration(days: 1));
      case ReviewPeriodType.weekly:
        return AppDate.startOfWeek(now).add(const Duration(days: 7));
      case ReviewPeriodType.monthly:
        return DateTime(now.year, now.month + 1, 1);
      case ReviewPeriodType.yearly:
        return DateTime(now.year + 1, 1, 1);
    }
  }

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
    _handled
      ..clear()
      ..addAll(log?.handledItems ?? const <String>[]);
    _handledItems.clear();
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
    context.watch<FoggHabitRepository>();
    context.watch<LearningReviewRepository>();
    context.watch<LearningSessionRepository>();

    final ReviewSnapshot snapshot = service.snapshot(_window);
    final List<ReviewItem> live = service.pending(_window, snapshot);
    final Set<String> liveIds =
        live.map((ReviewItem item) => item.id).toSet();
    final List<ReviewItem> items = <ReviewItem>[
      ...live,
      for (final ReviewItem item in _handledItems.values)
        if (!liveIds.contains(item.id)) item,
    ];
    final int openItems =
        items.where((ReviewItem item) => !_handled.contains(item.id)).length;

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
              _metrics(context, palette, snapshot),
              const SizedBox(height: AppSpacing.md),
              _capabilityBar(context, palette, snapshot),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget reflection = _reflectionCard(context, palette);
                  final Widget pending =
                      _pendingCard(context, palette, items, openItems);
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
                    ? null
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
              '本期还有 $openItems 项待校准，处理完后复盘才算真正结束。',
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
  ) {
    final List<Widget> cards = <Widget>[
      _metricCard(
        context,
        palette,
        label: '时间投入',
        value: '${snapshot.completedHours.toStringAsFixed(1)}h',
        detail: '计划 ${snapshot.plannedHours.toStringAsFixed(1)}h · '
            '完成率 ${(snapshot.blockRate * 100).round()}%',
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
            '${snapshot.lowHabits.length} 项需调配方',
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
          const SizedBox(height: AppSpacing.sm),
          ProgressHairline(value: progress, color: tone),
        ],
      ),
    );
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
                        onTap: () => context
                            .read<UiController>()
                            .setRoute('/vision-map'),
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
                  onTap: () =>
                      context.read<UiController>().setRoute('/vision-map'),
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
          const SizedBox(height: AppSpacing.sm),
          for (final _Question question in questions) ...<Widget>[
            Text(question.title, style: context.texts.labelSmall),
            const SizedBox(height: 4),
            AppTextField(
              controller: question.controller,
              hintText: question.hint,
              maxLines: 3,
              minLines: 2,
              onChanged: (_) => _scheduleSave(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
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
        ];
      case ReviewPeriodType.monthly:
        return <_Question>[
          _Question('能力推进评估', '哪些能力有实质突破？哪些连续两周停滞？', _wins),
          _Question('停滞与偏离', '沉没成本止损：哪些目标已不合时宜？', _blockers),
          _Question('目标减法（Stop Doing）', '决定暂停或归档什么，给核心能力腾空间', _adjustments),
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
            Text('本期没有需要处理的事项。', style: context.texts.bodySmall)
          else
            for (final ReviewItem item in items) ...<Widget>[
              _pendingRow(context, palette, item),
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
  ) {
    final bool handled = _handled.contains(item.id);
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
          Text('已处理', style: context.texts.labelSmall)
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
              label: _pushLabel,
              dense: true,
              onPressed: () => _runItem(item, 'push'),
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
        return AppGhostButton(
          label: '排入明日',
          dense: true,
          onPressed: () => _runItem(item, 'postpone'),
        );
      case ReviewItemKind.lowHabit:
        return AppGhostButton(
          label: '调配方',
          dense: true,
          onPressed: () => _runItem(item, 'habit'),
        );
      case ReviewItemKind.staleTask:
        return AppGhostButton(
          label: '归档',
          dense: true,
          onPressed: () => _runItem(item, 'archive'),
        );
    }
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
          value: 'shrink',
          height: 38,
          child: Text('拆小任务', style: context.texts.bodyMedium),
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
      ],
    );
  }

  Future<void> _runItem(ReviewItem item, String action) async {
    final ReviewService service = context.read<ReviewService>();

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

    switch (action) {
      case 'push':
        if (block != null) await service.pushBlockToDay(block, day: _pushTarget);
      case 'shrink':
        if (task != null) {
          await service.shrinkTask(task);
        } else if (block != null) {
          await service.pushBlockToDay(block);
        }
      case 'inbox':
        if (block != null) {
          await service.returnBlockToInbox(block);
        } else if (task != null) {
          await service.returnToInbox(task);
        }
      case 'cancel':
        if (block != null) await service.cancelBlock(block);
      case 'archive':
        if (task != null) await service.archiveTask(task);
      case 'postpone':
        if (review != null) await service.postponeReview(review);
    }

    await service.markHandled(_window, item.id);
    if (!mounted) return;
    setState(() {
      _handled.add(item.id);
      _handledItems[item.id] = item;
    });
    _toast(_actionToast(action));
  }

  Color _kindTone(AppPalette palette, ReviewItemKind kind) {
    switch (kind) {
      case ReviewItemKind.unfinishedBlock:
        return palette.warning;
      case ReviewItemKind.overdueReview:
        return palette.accent;
      case ReviewItemKind.lowHabit:
        return palette.warning;
      case ReviewItemKind.staleTask:
        return palette.textTertiary;
    }
  }

  String _actionToast(String action) {
    switch (action) {
      case 'push':
        return '已排入明日时间盒';
      case 'shrink':
        return '已拆小并生成启动版任务';
      case 'inbox':
        return '已暂存回任务池';
      case 'cancel':
        return '已取消该时间块';
      case 'archive':
        return '已归档，腾出时间盒空间';
      case 'postpone':
        return '已顺延到明日 20:00';
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

/// 低饱和能力配色，避免时间分布条变成高饱和色块。
const List<Color> _sliceTones = <Color>[
  Color(0xFF7E90A8),
  Color(0xFF8B9E87),
  Color(0xFFA89785),
  Color(0xFF9B8DA8),
  Color(0xFF9FA79C),
  Color(0xFFB0A293),
];