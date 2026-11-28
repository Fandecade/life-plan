import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/learning_mastery.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/state_views.dart';
import 'learning_common.dart';

/// 沉浸引导流：单屏聚焦 + 步骤条 + 卡点/链接 + 完成前自检门禁。
class LearningSessionFlow extends StatefulWidget {
  const LearningSessionFlow({
    super.key,
    required this.task,
    required this.session,
    required this.onClose,
    required this.onArchived,
  });

  final ActionItem task;
  final LearningSession session;
  final VoidCallback onClose;
  final VoidCallback onArchived;

  @override
  State<LearningSessionFlow> createState() => _LearningSessionFlowState();
}

class _LearningSessionFlowState extends State<LearningSessionFlow> {
  late LearningDraft _draft;
  final List<TextEditingController> _pointControllers =
      <TextEditingController>[];
  final List<FocusNode> _pointFocusNodes = <FocusNode>[];
  late final TextEditingController _blocker;
  late final TextEditingController _link;
  Timer? _debounce;
  Timer? _ticker;
  bool _timing = false;
  int _elapsed = 0;
  int _live = 0;
  late LearningSessionRepository _sessions;
  bool _busy = false;

  int get _totalSeconds => _elapsed + _live;

  @override
  void initState() {
    super.initState();
    _sessions = context.read<LearningSessionRepository>();
    _elapsed = widget.session.elapsedSeconds;
    _draft = LearningDraft.decode(
      widget.session.stepsDataJson,
      widget.session.learningType,
    );
    _rebuildPointEditors(_draft.textOfActiveStep());
    _blocker = TextEditingController(text: _draft.blocker);
    _link = TextEditingController(text: _draft.link);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_live > 0) {
      unawaited(_persistElapsed(_live));
    }
    _debounce?.cancel();
    for (final TextEditingController controller in _pointControllers) {
      controller.dispose();
    }
    for (final FocusNode node in _pointFocusNodes) {
      node.dispose();
    }
    _blocker.dispose();
    _link.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  Future<void> _saveNow() async {
    if (!mounted) return;
    final LearningSessionRepository repo = context
        .read<LearningSessionRepository>();
    final LearningSession current =
        repo.byId(widget.session.id) ?? widget.session;
    await repo.put(
      current.copyWith(
        stepsDataJson: _draft.encode(),
        currentStepIndex: _draft.activeIndex,
        mode: _draft.mode,
        syncStatus: SyncStatus.pendingUpdate,
      ),
    );
  }

  List<String> _pointsOf(String text) {
    final List<String> points = text.split('\n');
    return points.isEmpty ? <String>[''] : points;
  }

  void _rebuildPointEditors(String text) {
    final List<TextEditingController> oldControllers =
        List<TextEditingController>.from(_pointControllers);
    final List<FocusNode> oldNodes = List<FocusNode>.from(_pointFocusNodes);

    _pointControllers.clear();
    _pointFocusNodes.clear();
    for (final String point in _pointsOf(text)) {
      _pointControllers.add(TextEditingController(text: point));
      _pointFocusNodes.add(FocusNode());
    }
    if (_pointControllers.isEmpty) {
      _pointControllers.add(TextEditingController());
      _pointFocusNodes.add(FocusNode());
    }

    if (oldControllers.isEmpty && oldNodes.isEmpty) return;
    // 等这一帧用新控制器重建完成后再释放旧的，避免「已 dispose 的 FocusNode 仍在使用」。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final TextEditingController controller in oldControllers) {
        controller.dispose();
      }
      for (final FocusNode node in oldNodes) {
        node.dispose();
      }
    });
  }

  void _syncPointsToDraft() {
    _draft = _draft.withActiveText(
      _pointControllers
          .map((TextEditingController controller) => controller.text)
          .join('\n'),
    );
    _scheduleSave();
  }

  /// 回车把一个点落成一行，并聚焦到下一个点。
  void _submitPoint(int index) {
    if (_pointControllers[index].text.trim().isEmpty) return;
    if (index == _pointControllers.length - 1) {
      setState(() {
        _pointControllers.add(TextEditingController());
        _pointFocusNodes.add(FocusNode());
      });
      _syncPointsToDraft();
      final int nextIndex = _pointControllers.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pointFocusNodes[nextIndex].requestFocus();
      });
    } else {
      _pointFocusNodes[index + 1].requestFocus();
    }
  }

  void _syncText() {
    _rebuildPointEditors(_draft.textOfActiveStep());
  }

  void _goTo(int index) {
    if (index == _draft.activeIndex) return;
    setState(() {
      _draft = _draft.withActiveIndex(index);
      _syncText();
    });
    _saveNow();
  }

  void _toggleMode() {
    final LearningMode next = _draft.isQuick
        ? LearningMode.full
        : LearningMode.quick;
    setState(() {
      _draft = _draft.withMode(next);
      _syncText();
    });
    _saveNow();
  }

  void _next() {
    if (_draft.isLastStep) {
      _openGate();
    } else {
      _goTo(_draft.activeIndex + 1);
    }
  }

  void _close() {
    _pauseTiming();
    _saveNow();
    widget.onClose();
  }

  String _clockLabel(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remain = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${remain.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remain.toString().padLeft(2, '0')}';
  }

  void _toggleTiming() {
    if (_timing) {
      _pauseTiming();
    } else {
      _startTiming();
    }
  }

  void _startTiming() {
    if (_timing) return;
    setState(() => _timing = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _live++);
      if (_live % 30 == 0) {
        final int delta = _takeLiveSeconds();
        unawaited(_persistElapsed(delta));
      }
    });
  }

  /// 取走未结算的秒数并立即反映到本地显示（不阻塞 UI）。
  int _takeLiveSeconds() {
    final int delta = _live;
    _live = 0;
    _elapsed += delta;
    return delta;
  }

  void _pauseTiming() {
    if (!_timing) return;
    _ticker?.cancel();
    _ticker = null;
    final int delta = _takeLiveSeconds();
    setState(() => _timing = false);
    unawaited(_persistElapsed(delta));
  }

  /// 后台把增量写入会话；失败不影响界面（本地数据，下次保存会补齐）。
  Future<void> _persistElapsed(int delta) async {
    if (delta <= 0) return;
    final LearningSession current =
        _sessions.byId(widget.session.id) ?? widget.session;
    await _sessions.put(
      current.copyWith(
        elapsedSeconds: current.elapsedSeconds + delta,
        syncStatus: SyncStatus.pendingUpdate,
      ),
    );
  }

  Future<void> _openGate() async {
    _pauseTiming();
    _saveNow();
    if (!mounted) return;

    final GateDecision? decision = await showAppSheet<GateDecision>(
      context,
      builder: (BuildContext dialogContext) => _GateDialog(type: _draft.type),
    );
    if (decision == null || !mounted) return;

    switch (decision.choice) {
      case GateChoice.passed:
        await _archive();
      case GateChoice.blocked:
        await _handleBlocked();
      case GateChoice.later:
        _saveNow();
        if (!mounted) return;
        _toast('已保留草稿，下次从断点继续');
        widget.onClose();
    }
  }

  Future<void> _archive() async {
    if (_busy) return;
    _ticker?.cancel();
    _ticker = null;
    final int tailSeconds = _takeLiveSeconds();
    setState(() {
      _timing = false;
      _busy = true;
    });

    final LearningSessionRepository sessions = context
        .read<LearningSessionRepository>();
    final LearningReviewRepository reviews = context
        .read<LearningReviewRepository>();
    final ActionItemRepository actions = context.read<ActionItemRepository>();

    final LearningSession latest =
        sessions.byId(widget.session.id) ?? widget.session;
    await sessions.finish(
      latest.copyWith(
        stepsDataJson: _draft.encode(),
        currentStepIndex: _draft.activeIndex,
        mode: _draft.mode,
        elapsedSeconds: latest.elapsedSeconds + tailSeconds,
      ),
    );
    final List<LearningReview> createdReviews = await reviews.scheduleFor(
      sessionId: widget.session.id,
      actionItemId: widget.task.id,
      type: _draft.type,
    );
    // 复习节点同步落到时间盒：当天 20:00 一个轻量复习块，点开可直接回忆。
    final TimeBlockRepository blocks = context.read<TimeBlockRepository>();
    for (final LearningReview review in createdReviews) {
      final DateTime day = AppDate.startOfDay(review.dueDate);
      await blocks.schedule(
        title: '复习：${widget.task.title} (D${review.intervalDays})',
        startAt: DateTime(day.year, day.month, day.day, 20),
        durationMinutes: 30,
        learningReviewId: review.id,
      );
    }
    final ActionItemStatus targetStatus = LearningMastery.initialStatusFor(
      _draft.type,
    );
    await actions.setStatus(widget.task.id, targetStatus);

    if (!mounted) return;
    setState(() => _busy = false);
    final String nextStep = targetStatus == ActionItemStatus.completed
        ? '项目式已直接完成'
        : '转入待巩固，等待复习节点';
    _toast('已归档 · ${intervalsOf(_draft.type).join(' / ')} 天后复习 · $nextStep');
    widget.onArchived();
  }

  Future<void> _handleBlocked() async {
    if (_busy) return;
    setState(() => _busy = true);

    final ActionItemRepository actions = context.read<ActionItemRepository>();
    await actions.create(
      title: '回炉补盲：${widget.task.title}',
      capabilityId: widget.task.capabilityId,
      parentId: widget.task.id,
      estimatedMinutes: 30,
    );
    await actions.create(
      title: '费曼简化：${widget.task.title}',
      capabilityId: widget.task.capabilityId,
      parentId: widget.task.id,
      estimatedMinutes: 20,
    );
    await _saveNow();

    if (!mounted) return;
    setState(() => _busy = false);
    _toast('已生成回炉补盲与费曼简化待办，本次保留草稿');
    widget.onClose();
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

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tone = LearningVisuals.toneOf(_draft.type);

    return Column(
      children: <Widget>[
        _header(context, tone),
        Divider(color: palette.hairline, height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _stepper(context, tone),
                    const SizedBox(height: AppSpacing.lg),
                    _guideCard(context, tone),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Text('本步记录', style: context.texts.labelMedium),
                        const SizedBox(width: 6),
                        Text(
                          '每行一个要点 · 回车新增下一点',
                          style: context.texts.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (
                      int index = 0;
                      index < _pointControllers.length;
                      index++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: StatusDot(color: tone, size: 4),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppTextField(
                                controller: _pointControllers[index],
                                focusNode: _pointFocusNodes[index],
                                transparent: true,
                                dense: true,
                                textInputAction: TextInputAction.next,
                                hintText: index == 0
                                    ? _draft.activeTemplate.placeholder
                                    : '回车继续下一个点…',
                                onChanged: (_) => _syncPointsToDraft(),
                                onSubmitted: (_) => _submitPoint(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(title: '卡点速记', subtitle: '1–3 句即可，供日后主动回忆自测'),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _blocker,
                      maxLines: 3,
                      minLines: 2,
                      hintText: '哪里卡住了？什么讲不清？',
                      onChanged: (String value) {
                        _draft = _draft.copyWith(blocker: value);
                        _scheduleSave();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionHeader(
                      title: '外部成果链接',
                      subtitle: '笔记 / 代码 / 录音等专业工具产物',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _link,
                      hintText: 'Obsidian / Notion / GitHub / 本地文件链接',
                      prefixIcon: Icons.link_rounded,
                      onChanged: (String value) {
                        _draft = _draft.copyWith(link: value);
                        _scheduleSave();
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        StatusDot(
                          color: _timing
                              ? palette.success
                              : palette.textTertiary,
                          size: 4,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _timing
                                ? '专注计时中 · 正在记录本次学习时长（暂停不计时）'
                                : '点「开始计时」记录真实学习时长；专注时关闭无关通知',
                            style: context.texts.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Divider(color: palette.hairline, height: 1),
        _footer(context, tone),
      ],
    );
  }

  Widget _header(BuildContext context, Color tone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回工作台（自动保存）',
            onPressed: _close,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              widget.task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.titleMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppChip(
            label: _draft.type.tag,
            dense: true,
            filled: true,
            color: tone,
          ),
          const Spacer(),
          AppChip(
            label: _timing
                ? _clockLabel(_totalSeconds)
                : (_totalSeconds > 0
                      ? '计时 ${_clockLabel(_totalSeconds)}'
                      : '开始计时'),
            dense: true,
            icon: Icons.timer_outlined,
            color: _timing ? context.palette.success : null,
            onTap: _toggleTiming,
          ),
        ],
      ),
    );
  }

  Widget _stepper(BuildContext context, Color tone) {
    final LearningMethodTemplate template = methodOf(_draft.type);
    final int count = _draft.isQuick ? 1 : template.stepCount;
    final int current = _draft.activeIndex;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (int index = 0; index < count; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 6),
            AppChip(
              label: index == 0 && _draft.isQuick
                  ? quickOutputStep.title
                  : '${index + 1} ${template.stepAt(index).title}',
              dense: true,
              filled: index == current,
              color: tone,
              onTap: () => _goTo(index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guideCard(BuildContext context, Color tone) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusDot(color: tone, size: 5),
              const SizedBox(width: 6),
              Text(
                _draft.activeTemplate.title,
                style: context.texts.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _draft.activeTemplate.guide,
            style: context.texts.bodyMedium?.copyWith(
              color: palette.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, Color tone) {
    final bool supportsQuick = methodOf(_draft.type).supportsQuick;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          if (supportsQuick)
            AppGhostButton(
              label: _draft.isQuick ? '切换完整 4 步' : '切换 5m 轻量',
              icon: Icons.bolt_outlined,
              dense: true,
              onPressed: _toggleMode,
            ),
          AppGhostButton(
            label: '暂存断点',
            icon: Icons.save_outlined,
            dense: true,
            onPressed: () {
              _saveNow();
              _toast('已保存到断点');
            },
          ),
          AppPrimaryButton(
            label: _draft.isLastStep ? '完成本次学习' : '完成本步 →',
            icon: _draft.isLastStep ? Icons.check_rounded : null,
            dense: true,
            onPressed: _busy ? null : _next,
          ),
        ],
      ),
    );
  }
}

enum GateChoice { passed, blocked, later }

class GateDecision {
  const GateDecision(this.choice);

  final GateChoice choice;
}

class _GateDialog extends StatefulWidget {
  const _GateDialog({required this.type});

  final LearningType type;

  @override
  State<_GateDialog> createState() => _GateDialogState();
}

class _GateDialogState extends State<_GateDialog> {
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return AppSheetContent(
      title: '完成前的自检',
      heightFactor: null,
      actions: <Widget>[
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('我能否不看原资料，独立把核心内容输出出来？', style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _option(
            context,
            title: '通过 · 已独立输出',
            note: widget.type == LearningType.project
                ? '归档本次学习；项目式以原型交付为完成标准，任务直接完成'
                : '归档本次学习，任务转入「待巩固」，并按 ${intervalsOf(widget.type).join(' / ')} 天生成复习提醒',
            tone: palette.success,
            onTap: () =>
                Navigator.of(context)
                    .pop(const GateDecision(GateChoice.passed)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _option(
            context,
            title: '存在盲区 · 卡壳',
            note: '记录卡点，生成「24h 回炉补盲」与「费曼简化」待办；本次不归档',
            tone: palette.warning,
            onTap: () =>
                Navigator.of(context)
                    .pop(const GateDecision(GateChoice.blocked)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _option(
            context,
            title: '暂未完成',
            note: '保留草稿，下次从断点继续，不算失败',
            tone: palette.textSecondary,
            onTap: () =>
                Navigator.of(context).pop(const GateDecision(GateChoice.later)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.type == LearningType.project
                ? '项目式：原型 + 边界复盘交付即视为完成，复习仅作可选回顾。'
                : '说明：通过后先进入「待巩固」，完成核心复习节点并顺畅回忆后才算彻底完成。',
            style: context.texts.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String title,
    required String note,
    required Color tone,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            StatusDot(color: tone, size: 6),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: context.texts.titleSmall?.copyWith(color: tone),
                  ),
                  const SizedBox(height: 2),
                  Text(note, style: context.texts.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: tone),
          ],
        ),
      ),
    );
  }
}
