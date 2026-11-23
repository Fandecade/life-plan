import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/habit_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';


/// 打开「配方」流程：行为候选 → 焦点地图 → 5 维降阻 → 锚点与庆祝。
Future<bool> showHabitRecipeDialog(
  BuildContext context, {
  FoggHabit? habit,
  String? linkedActionItemId,
}) async {
  final bool? changed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _HabitRecipeDialog(
      habit: habit,
      linkedActionItemId: linkedActionItemId,
    ),
  );
  return changed ?? false;
}

class _HabitRecipeDialog extends StatefulWidget {
  const _HabitRecipeDialog({this.habit, this.linkedActionItemId});

  final FoggHabit? habit;
  final String? linkedActionItemId;

  @override
  State<_HabitRecipeDialog> createState() => _HabitRecipeDialogState();
}

class _HabitRecipeDialogState extends State<_HabitRecipeDialog> {
  late final TextEditingController _anchor;
  late final TextEditingController _tiny;
  late final TextEditingController _celebration;
  late final TextEditingController _frictionNote;
  late final TextEditingController _candidateInput;
  late AnchorPeriod _period;
  late FrictionProfile _frictions;
  late String? _actionItemId;
  bool _saving = false;
  bool _advancing = false;
  bool _mapDragging = false;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final FoggHabit? habit = widget.habit;
    _anchor = TextEditingController(text: habit?.anchorPrompt ?? '');
    _tiny = TextEditingController(text: habit?.tinyBehavior ?? '');
    _celebration = TextEditingController(
      text: habit?.celebration ?? '握拳，默念：我做到了',
    );
    _frictions = habit?.frictions ?? const FrictionProfile();
    _frictionNote = TextEditingController(text: _frictions.note);
    _candidateInput = TextEditingController();
    _period = habit?.anchorPeriod ?? AnchorPeriod.anytime;
    _actionItemId = habit?.linkedActionItemId ?? widget.linkedActionItemId;
  }

  @override
  void dispose() {
    _anchor.dispose();
    _tiny.dispose();
    _celebration.dispose();
    _frictionNote.dispose();
    _candidateInput.dispose();
    super.dispose();
  }

  FrictionProfile _currentFrictions() => _frictions.copyWith(
        note: _frictionNote.text.trim(),
      );

  Future<void> _addCandidate() async {
    final String title = _candidateInput.text.trim();
    if (title.isEmpty) return;
    await context.read<BehaviorCandidateRepository>().add(
          title: title,
          impact: 4,
          effort: 2,
        );
    _candidateInput.clear();
  }

  Future<void> _save() async {
    final String anchor = _anchor.text.trim();
    final String tiny = _tiny.text.trim();
    if (anchor.isEmpty || tiny.isEmpty) return;
    setState(() => _saving = true);

    final FoggHabitRepository habits = context.read<FoggHabitRepository>();
    final HabitService service = context.read<HabitService>();
    final FrictionProfile frictions = _currentFrictions();

    final FoggHabit target;
    if (_isEditing) {
      target = widget.habit!.copyWith(
        anchorPrompt: anchor,
        tinyBehavior: tiny,
        celebration: _celebration.text.trim(),
        anchorPeriod: _period,
        frictions: frictions,
        linkedActionItemId: _actionItemId,
        clearLinkedActionItem: _actionItemId == null,
      );
    } else {
      target = await habits.create(
        anchorPrompt: anchor,
        tinyBehavior: tiny,
        celebration: _celebration.text.trim().isEmpty
            ? '握拳，默念：我做到了'
            : _celebration.text.trim(),
        anchorPeriod: _period,
        frictions: frictions,
        linkedActionItemId: _actionItemId,
      );
    }

    await service.saveRecipe(
      target,
      note: _isEditing ? '更新配方' : '首次创建配方',
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _advance() async {
    if (_advancing) return;
    setState(() => _advancing = true);
    final FoggHabitRepository habits = context.read<FoggHabitRepository>();
    final HabitService service = context.read<HabitService>();
    final FoggHabit? existing =
        widget.habit ?? habits.forActionItem(_actionItemId ?? '');
    final FoggHabit source = existing ??
        FoggHabit.create(
          anchorPrompt: _anchor.text.trim(),
          tinyBehavior: _tiny.text.trim(),
        );
    await service.saveRecipe(
      source.copyWith(
        tinyBehavior: _progressivelySmaller(source.tinyBehavior),
        motivationNote: '动作升级：稳定后小幅提升',
      ),
      note: '稳定执行后升级动作',
    );
    if (!mounted) return;
    setState(() => _advancing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已生成升级版配方，并留存版本记录')),
    );
  }

  String _progressivelySmaller(String text) {
    if (text.isEmpty) return '打开文档，写下 1 句话';
    return '$text（先做一半）';
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<ActionItem> actions = context.watch<ActionItemRepository>().all;
    final List<BehaviorCandidate> candidates =
        context.watch<BehaviorCandidateRepository>().all;

    String actionTitle = '不关联任务';
    for (final ActionItem action in actions) {
      if (action.id == _actionItemId) {
        actionTitle = action.title;
        break;
      }
    }

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
      title: Row(
        children: <Widget>[
          Text(
            _isEditing ? '调整配方' : '新建微习惯',
            style: context.texts.titleLarge,
          ),
          const Spacer(),
          if (_isEditing)
            AppGhostButton(
              label: '动作升级',
              icon: Icons.trending_up_rounded,
              dense: true,
              onPressed: _advancing ? null : _advance,
            ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 640,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          child: SingleChildScrollView(
            physics: _mapDragging
                ? const NeverScrollableScrollPhysics()
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _label(context, '锚点场景（首选提示）'),
                AppTextField(
                  key: const ValueKey<String>('habit-anchor'),
                  controller: _anchor,
                  hintText: '例如：早上泡好咖啡后 / 晚饭后坐到书桌前',
                ),
                const SizedBox(height: AppSpacing.md),
                _label(context, '微行为（15 秒～2 分钟可启动）'),
                AppTextField(
                  key: const ValueKey<String>('habit-tiny'),
                  controller: _tiny,
                  hintText: '例如：打开文档写 3 行要点',
                ),
                const SizedBox(height: AppSpacing.md),
                _label(context, '即时庆祝'),
                AppTextField(
                  controller: _celebration,
                  hintText: '握拳 / 默念短句 / 微笑',
                ),
                const SizedBox(height: AppSpacing.md),
                _label(context, '锚点时段'),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final AnchorPeriod period in AnchorPeriod.values)
                      AppChip(
                        label: period.label,
                        dense: true,
                        filled: _period == period,
                        color: palette.accent,
                        onTap: () => setState(() => _period = period),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _label(context, '5 维阻力检查（勾选后先降阻，再谈坚持）'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _frictionChip(context, '时间', _frictions.time, (v) {
                      setState(() => _frictions = _frictions.copyWith(time: v));
                    }),
                    _frictionChip(context, '金钱', _frictions.money, (v) {
                      setState(() => _frictions = _frictions.copyWith(money: v));
                    }),
                    _frictionChip(context, '体力', _frictions.energy, (v) {
                      setState(() => _frictions = _frictions.copyWith(energy: v));
                    }),
                    _frictionChip(context, '脑力', _frictions.brain, (v) {
                      setState(() => _frictions = _frictions.copyWith(brain: v));
                    }),
                    _frictionChip(context, '日程习惯', _frictions.routine, (v) {
                      setState(() => _frictions = _frictions.copyWith(routine: v));
                    }),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _frictionNote,
                  dense: true,
                  hintText: '降阻准备：提前把笔记本摊在桌上…',
                ),
                const SizedBox(height: AppSpacing.lg),
                _label(context, '行为集群与焦点地图'),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _candidateInput,
                        dense: true,
                        hintText: '输入候选行为，回车加入',
                        onSubmitted: (_) => _addCandidate(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppGhostButton(
                      label: '加入',
                      icon: Icons.add_rounded,
                      dense: true,
                      onPressed: _addCandidate,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 226,
                  child: _FocusMap(
                    candidates: candidates,
                    onInteracting: (bool active) {
                      if (_mapDragging == active) return;
                      setState(() => _mapDragging = active);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '点击节点确认是否放入焦点地图；拖动可调整难度与影响力，左上为「高影响 · 易起步」黄金行为区。',
                  style: context.texts.labelSmall,
                ),
                if (candidates.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final BehaviorCandidate candidate in candidates)
                        AppChip(
                          label: candidate.title,
                          dense: true,
                          filled: candidate.isSelected,
                          color: candidate.isGolden
                              ? palette.success
                              : palette.accent,
                          onTap: () async {
                            await context
                                .read<BehaviorCandidateRepository>()
                                .save(
                                  candidate.copyWith(
                                    isSelected: !candidate.isSelected,
                                  ),
                                );
                            if (candidate.isSelected) return;
                            _tiny.text = candidate.title;
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: palette.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        actionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall,
                      ),
                    ),
                    AppGhostButton(
                      label: '更换',
                      dense: true,
                      onPressed: () => _pickAction(actions),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      actions: <Widget>[
        if (_isEditing)
          AppGhostButton(
            label: '停用',
            tone: palette.danger,
            onPressed: () async {
              await context.read<FoggHabitRepository>().save(
                    widget.habit!.copyWith(isActive: false),
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            },
          ),
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(
          label: _isEditing ? '保存配方' : '创建习惯',
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _pickAction(List<ActionItem> actions) async {
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          title: Text('关联任务（可选）', style: dialogContext.texts.titleLarge),
          content: SizedBox(
            width: 420,
            height: MediaQuery.sizeOf(dialogContext).height * 0.45,
            child: ListView(
              children: <Widget>[
                ListTile(
                  title: Text('不关联任务', style: dialogContext.texts.bodyMedium),
                  onTap: () => Navigator.of(dialogContext).pop(''),
                ),
                for (final ActionItem action in actions)
                  ListTile(
                    title: Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dialogContext.texts.bodyMedium,
                    ),
                    onTap: () => Navigator.of(dialogContext).pop(action.id),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _actionItemId = picked.isEmpty ? null : picked);
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: context.texts.labelMedium),
    );
  }

  Widget _frictionChip(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final AppPalette palette = context.palette;
    return AppChip(
      label: label,
      dense: true,
      filled: value,
      color: value ? palette.warning : palette.textSecondary,
      onTap: () => onChanged(!value),
    );
  }
}

/// 焦点地图节点的文字最大宽度，超出后省略。
const double _focusNodeMaxTextWidth = 168;

/// 四象限焦点地图（左上/右上为高影响区）。
///
/// 横轴：左「难做」右「易做」；纵轴：上「高影响」下「低影响」。
/// 拖动为连续坐标，松手即停在原地，不再吸附跳位。
class _FocusMap extends StatefulWidget {
  const _FocusMap({required this.candidates, this.onInteracting});

  final List<BehaviorCandidate> candidates;

  /// 指针落在地图上时通知外层暂停滚动，避免竖向拖动被滚动容器抢走。
  final ValueChanged<bool>? onInteracting;

  @override
  State<_FocusMap> createState() => _FocusMapState();
}

class _FocusMapState extends State<_FocusMap> {
  static const EdgeInsets _plotPadding = EdgeInsets.all(6);

  String? _dragId;
  Offset _dragDelta = Offset.zero;

  Rect _plotRect(Size size) => Rect.fromLTRB(
        _plotPadding.left,
        _plotPadding.top,
        size.width - _plotPadding.right,
        size.height - _plotPadding.bottom,
      );

  /// 按文本实际宽度测量节点尺寸，名字多长卡片就多宽（单字即窄卡）。
  Size _nodeSize(BuildContext context, BehaviorCandidate candidate) {
    final TextStyle style =
        context.texts.labelSmall ?? const TextStyle(fontSize: 10.5);
    final TextPainter painter = TextPainter(
      text: TextSpan(text: candidate.title, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: _focusNodeMaxTextWidth);
    return Size(painter.width + 14, painter.height + 4);
  }

  /// 档位中心坐标：横轴左难右易（effort 5→1），纵轴上高下低（impact 5→1）。
  Offset _slotCenter(BehaviorCandidate candidate, Size size) {
    final Rect plot = _plotRect(size);
    return Offset(
      plot.left + (4 - (candidate.effort - 1)) * (plot.width / 4),
      plot.top + (4 - (candidate.impact - 1)) * (plot.height / 4),
    );
  }

  /// 未拖动过的同档位节点自动散开；拖动过（有连续坐标）的节点尊重用户摆放。
  Map<String, Offset> _spread(Size size, Map<String, Size> sizes) {
    final Rect plot = _plotRect(size);
    final Map<String, List<BehaviorCandidate>> groups =
        <String, List<BehaviorCandidate>>{};
    for (final BehaviorCandidate candidate in widget.candidates) {
      if (candidate.mapX != null && candidate.mapY != null) continue;
      groups
          .putIfAbsent(
            '${candidate.effort}-${candidate.impact}',
            () => <BehaviorCandidate>[],
          )
          .add(candidate);
    }

    final Map<String, Offset> result = <String, Offset>{};
    for (final List<BehaviorCandidate> group in groups.values) {
      group.sort((BehaviorCandidate a, BehaviorCandidate b) =>
          a.id.compareTo(b.id));
      if (group.length == 1) {
        result[group.first.id] = Offset.zero;
        continue;
      }
      double tallest = 0;
      for (final BehaviorCandidate candidate in group) {
        final Size nodeSize = sizes[candidate.id]!;
        if (nodeSize.height > tallest) tallest = nodeSize.height;
      }
      final Offset base = _slotCenter(group.first, size);
      final double step = tallest + 3;
      final double span = (group.length - 1) * step;
      final bool fitsVertical =
          base.dy - span / 2 - tallest / 2 >= plot.top &&
              base.dy + span / 2 + tallest / 2 <= plot.bottom;
      for (int i = 0; i < group.length; i++) {
        final double k = i - (group.length - 1) / 2;
        result[group[i].id] =
            fitsVertical ? Offset(0, k * step) : Offset(k * 62, 0);
      }
    }
    return result;
  }

  Offset _positionOf(
    BehaviorCandidate candidate,
    Size size,
    Map<String, Size> sizes,
    Map<String, Offset> spread,
  ) {
    final Rect plot = _plotRect(size);
    final Size nodeSize = sizes[candidate.id]!;
    final Offset anchor = (candidate.mapX != null && candidate.mapY != null)
        ? Offset(
            plot.left + candidate.mapX!.clamp(0, 1) * plot.width,
            plot.top + candidate.mapY!.clamp(0, 1) * plot.height,
          )
        : _slotCenter(candidate, size) +
            (spread[candidate.id] ?? Offset.zero);
    final Offset raw =
        anchor + (_dragId == candidate.id ? _dragDelta : Offset.zero);
    final double minX = plot.left + nodeSize.width / 2;
    final double maxX = plot.right - nodeSize.width / 2;
    final double minY = plot.top + nodeSize.height / 2;
    final double maxY = plot.bottom - nodeSize.height / 2;
    return Offset(
      maxX < minX ? plot.center.dx : raw.dx.clamp(minX, maxX),
      maxY < minY ? plot.center.dy : raw.dy.clamp(minY, maxY),
    );
  }

  Future<void> _toggleSelection(BehaviorCandidate candidate) {
    return context.read<BehaviorCandidateRepository>().save(
          candidate.copyWith(isSelected: !candidate.isSelected),
        );
  }

  void _finishDrag(
    BehaviorCandidate candidate,
    Size size,
    Map<String, Size> sizes,
    Map<String, Offset> spread,
  ) {
    final Rect plot = _plotRect(size);
    final Offset target = _positionOf(candidate, size, sizes, spread);
    final double mapX = ((target.dx - plot.left) / plot.width).clamp(0, 1);
    final double mapY = ((target.dy - plot.top) / plot.height).clamp(0, 1);
    final int effort = (5 - (mapX * 4).round()).clamp(1, 5);
    final int impact = (5 - (mapY * 4).round()).clamp(1, 5);

    setState(() {
      _dragId = null;
      _dragDelta = Offset.zero;
    });

    context.read<BehaviorCandidateRepository>().save(
          candidate.copyWith(
            mapX: mapX,
            mapY: mapY,
            effort: effort,
            impact: impact,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('影响力 · 高', style: context.texts.labelSmall),
            const Spacer(),
            Text(
              '黄金区',
              style: context.texts.labelSmall?.copyWith(
                color: palette.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 13,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text('难做', style: context.texts.labelSmall),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: _canvas(context, palette)),
              const SizedBox(width: 4),
              SizedBox(
                width: 13,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text('易做', style: context.texts.labelSmall),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text('影响力 · 低', style: context.texts.labelSmall),
      ],
    );
  }

  Widget _canvas(BuildContext context, AppPalette palette) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final Rect plot = _plotRect(size);
        final Map<String, Size> sizes = <String, Size>{
          for (final BehaviorCandidate candidate in widget.candidates)
            candidate.id: _nodeSize(context, candidate),
        };
        final Map<String, Offset> spread = _spread(size, sizes);

        return Container(
          key: const ValueKey<String>('focus-map'),
          decoration: BoxDecoration(
            color: palette.surfaceMuted.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: palette.hairline),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _FocusMapPainter(plot: plot, axis: palette.border),
                ),
              ),
              for (final BehaviorCandidate candidate in widget.candidates)
                _node(context, palette, candidate, size, sizes, spread),
            ],
          ),
        );
      },
    );
  }

  Widget _node(
    BuildContext context,
    AppPalette palette,
    BehaviorCandidate candidate,
    Size size,
    Map<String, Size> sizes,
    Map<String, Offset> spread,
  ) {
    final Size nodeSize = sizes[candidate.id]!;
    final Offset center = _positionOf(candidate, size, sizes, spread);
    final bool dragging = _dragId == candidate.id;
    final bool active = candidate.isSelected || dragging;

    return Positioned(
      left: center.dx - nodeSize.width / 2,
      top: center.dy - nodeSize.height / 2,
      child: Listener(
        onPointerDown: (_) => widget.onInteracting?.call(true),
        onPointerUp: (_) => widget.onInteracting?.call(false),
        onPointerCancel: (_) => widget.onInteracting?.call(false),
        child: GestureDetector(
          key: ValueKey<String>('focus-node-${candidate.id}'),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: () => _toggleSelection(candidate),
          onPanStart: (_) => setState(() {
            _dragId = candidate.id;
            _dragDelta = Offset.zero;
          }),
          onPanUpdate: (DragUpdateDetails details) =>
              setState(() => _dragDelta += details.delta),
          onPanEnd: (_) => _finishDrag(candidate, size, sizes, spread),
          onPanCancel: () => setState(() {
            _dragId = null;
            _dragDelta = Offset.zero;
          }),
          child: MouseRegion(
            cursor: dragging
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: active ? 1 : 0.55,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                constraints: const BoxConstraints(
                  maxWidth: _focusNodeMaxTextWidth + 14,
                ),
                decoration: BoxDecoration(
                  color: candidate.isGolden
                      ? palette.success.withValues(alpha: 0.16)
                      : palette.surface,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: dragging
                      ? <BoxShadow>[
                          BoxShadow(
                            color: palette.textPrimary.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                  border: Border.all(
                    color: active
                        ? (candidate.isGolden
                            ? palette.success
                            : palette.accent)
                        : palette.border,
                    width: dragging ? 1.4 : 1,
                  ),
                ),
                child: Text(
                  candidate.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 坐标轴：中间十字主轴（横轴难度、纵轴影响力），沿轴标注 5 档刻度。
class _FocusMapPainter extends CustomPainter {
  const _FocusMapPainter({required this.plot, required this.axis});

  final Rect plot;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.1;

    // 十字主轴
    canvas.drawLine(
      Offset(plot.center.dx, plot.top),
      Offset(plot.center.dx, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.center.dy),
      Offset(plot.right, plot.center.dy),
      axisPaint,
    );

    // 5 档刻度：横向沿横轴、纵向沿纵轴
    final double xStep = plot.width / 4;
    final double yStep = plot.height / 4;
    for (int i = 0; i < 5; i++) {
      final double x = plot.left + i * xStep;
      canvas.drawLine(
        Offset(x, plot.center.dy - 3),
        Offset(x, plot.center.dy + 3),
        axisPaint,
      );
      final double y = plot.top + i * yStep;
      canvas.drawLine(
        Offset(plot.center.dx - 3, y),
        Offset(plot.center.dx + 3, y),
        axisPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusMapPainter oldDelegate) =>
      oldDelegate.plot != plot || oldDelegate.axis != axis;
}
