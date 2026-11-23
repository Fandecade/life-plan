import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'learning_common.dart';
import 'learning_review_flow.dart';
import 'learning_session_flow.dart';

enum LearningFilter { today, reviews, drafts, archive }

/// 学习监督台：今日待学 / 间隔复习 / 进行中草稿 / 输出成果库。
class OutputLearningPage extends StatefulWidget {
  const OutputLearningPage({super.key});

  @override
  State<OutputLearningPage> createState() => _OutputLearningPageState();
}

class _OutputLearningPageState extends State<OutputLearningPage> {
  LearningFilter _filter = LearningFilter.today;
  String? _activeTaskId;
  String? _activeReviewId;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final UiController ui = context.watch<UiController>();
    final List<ActionItem> actions = context.watch<ActionItemRepository>().all;
    final LearningSessionRepository sessions =
        context.watch<LearningSessionRepository>();
    final LearningReviewRepository reviews =
        context.watch<LearningReviewRepository>();

    final String? pendingLearning = ui.learningTaskId;
    if (pendingLearning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _consumePending(pendingLearning, ui);
      });
    }

    final String? pendingReview = ui.learningReviewId;
    if (pendingReview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ui.consumeLearningReview();
        setState(() => _activeReviewId = pendingReview);
      });
    }

    if (_activeReviewId != null) {
      final LearningReview? review = reviews.byId(_activeReviewId);
      final ActionItem? task =
          review == null ? null : _findTask(actions, review.actionItemId);
      if (review != null && task != null) {
        return LearningReviewFlow(
          key: ValueKey<String>('review-${review.id}'),
          review: review,
          task: task,
          session: sessions.byId(review.sessionId),
          onClose: () => setState(() => _activeReviewId = null),
        );
      }
    }

    if (_activeTaskId != null) {
      final ActionItem? task = _findTask(actions, _activeTaskId!);
      final LearningSession? session = sessions.inProgressFor(_activeTaskId!);
      if (task != null && session != null) {
        return LearningSessionFlow(
          key: ValueKey<String>('learn-${session.id}'),
          task: task,
          session: session,
          onClose: () => setState(() => _activeTaskId = null),
          onArchived: () => setState(() {
            _activeTaskId = null;
            _filter = LearningFilter.archive;
          }),
        );
      }
    }

    final List<ActionItem> learningTasks = actions
        .where((ActionItem item) =>
            item.executionMode == ExecutionMode.outputLearning)
        .toList(growable: false);
    final List<ActionItem> todayTasks = learningTasks
        .where((ActionItem item) =>
            !item.isCompleted &&
            item.status != ActionItemStatus.consolidating &&
            sessions.inProgressFor(item.id) == null)
        .toList(growable: false);
    final List<LearningSession> draftSessions = sessions.inProgress;
    final List<LearningReview> dueReviews = reviews.dueBy(DateTime.now());
    final List<LearningSession> archiveSessions = sessions.finished;

    final Map<LearningFilter, int> counts = <LearningFilter, int>{
      LearningFilter.today: todayTasks.length,
      LearningFilter.reviews: dueReviews.length,
      LearningFilter.drafts: draftSessions.length,
      LearningFilter.archive: archiveSessions.length,
    };

    return Column(
      children: <Widget>[
        _header(context, counts),
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
              LearningFilter.today =>
                _todayWidgets(context, todayTasks, sessions),
              LearningFilter.reviews =>
                _reviewWidgets(context, dueReviews, sessions, actions),
              LearningFilter.drafts =>
                _draftWidgets(context, draftSessions, actions),
              LearningFilter.archive =>
                _archiveWidgets(context, archiveSessions, actions),
            },
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, Map<LearningFilter, int> counts) {
    final AppPalette palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              '选一种方法，把输入变成可复用的输出；笔记与产物留在外部工具。',
              style: context.texts.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: <Widget>[
                for (final LearningFilter filter in LearningFilter.values) ...[
                  AppChip(
                    label: '${_filterLabel(filter)} · ${counts[filter] ?? 0}',
                    dense: true,
                    filled: _filter == filter,
                    color: palette.accent,
                    onTap: () => setState(() => _filter = filter),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _todayWidgets(
    BuildContext context,
    List<ActionItem> todayTasks,
    LearningSessionRepository sessions,
  ) {
    if (todayTasks.isEmpty) {
      return <Widget>[
        const EmptyState(
          icon: Icons.auto_stories_outlined,
          title: '今天没有待开始的学习任务',
          description: '把任务的执行模式设为「输出式学习」，就会出现在这里。',
        ),
      ];
    }
    return <Widget>[
      SectionHeader(title: '今日待学 · ${todayTasks.length}'),
      const SizedBox(height: AppSpacing.sm),
      for (final ActionItem task in todayTasks)
        _taskCard(
          context,
          title: task.title,
          type: null,
          meta: '未开始 · 点击选择学习方法',
          actionLabel: '开始',
          onTap: () => _startOrContinue(task),
        ),
    ];
  }

  List<Widget> _reviewWidgets(
    BuildContext context,
    List<LearningReview> dueReviews,
    LearningSessionRepository sessions,
    List<ActionItem> actions,
  ) {
    if (dueReviews.isEmpty) {
      return <Widget>[
        const EmptyState(
          icon: Icons.event_available_outlined,
          title: '今天没有到期的复习',
          description: '完成学习后，系统会按 1/3/7/15/30 天自动排复习节点。',
        ),
      ];
    }
    final List<Widget> widgets = <Widget>[
      SectionHeader(title: '到期复习 · ${dueReviews.length}'),
      const SizedBox(height: AppSpacing.sm),
    ];
    for (final LearningReview review in dueReviews) {
      final ActionItem? task = _findTask(actions, review.actionItemId);
      if (task == null) continue;
      final LearningSession? session = sessions.byId(review.sessionId);
      widgets.add(
        _taskCard(
          context,
          title: task.title,
          type: session?.learningType,
          meta: '${reviewDueLabel(review)} · 间隔 ${review.intervalDays} 天',
          actionLabel: '开始回忆',
          onTap: () => setState(() => _activeReviewId = review.id),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _draftWidgets(
    BuildContext context,
    List<LearningSession> draftSessions,
    List<ActionItem> actions,
  ) {
    if (draftSessions.isEmpty) {
      return <Widget>[
        const EmptyState(
          icon: Icons.edit_note_outlined,
          title: '没有进行中的草稿',
          description: '学习中断也不会失败，草稿会在这里等待断点续写。',
        ),
      ];
    }
    final List<Widget> widgets = <Widget>[
      SectionHeader(title: '进行中 · ${draftSessions.length}'),
      const SizedBox(height: AppSpacing.sm),
    ];
    for (final LearningSession session in draftSessions) {
      final ActionItem? task = _findTask(actions, session.actionItemId);
      if (task == null) continue;
      final LearningDraft draft =
          LearningDraft.decode(session.stepsDataJson, session.learningType);
      widgets.add(
        GestureDetector(
          onSecondaryTapUp: (TapUpDetails details) =>
              _openDraftMenu(details.globalPosition, session, task),
          child: _taskCard(
            context,
            title: task.title,
            type: session.learningType,
            meta:
                '${stepProgressLabel(draft)} · 更新于 ${AppDate.friendlyDay(session.updatedAt)} ${AppDate.timeLabel(session.updatedAt)}',
            actionLabel: '继续',
            onTap: () => setState(() => _activeTaskId = task.id),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _archiveWidgets(
    BuildContext context,
    List<LearningSession> archiveSessions,
    List<ActionItem> actions,
  ) {
    if (archiveSessions.isEmpty) {
      return <Widget>[
        const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: '还没有归档的输出',
          description: '通过自检完成一次学习后，成果卡片会归档在这里。',
        ),
      ];
    }
    final List<Widget> widgets = <Widget>[
      SectionHeader(title: '输出成果 · ${archiveSessions.length}'),
      const SizedBox(height: AppSpacing.sm),
    ];
    for (final LearningSession session in archiveSessions) {
      final ActionItem? task = _findTask(actions, session.actionItemId);
      if (task == null) continue;
      final LearningDraft draft =
          LearningDraft.decode(session.stepsDataJson, session.learningType);
      final DateTime date = session.completedAt ?? session.updatedAt;
      widgets.add(
        _taskCard(
          context,
          title: task.title,
          type: session.learningType,
          meta: '${AppDate.monthDayLabel(date)} 完成 · ${draftSummary(draft)}',
          actionLabel: '查看',
          onTap: () => _showArchive(session, task, draft),
        ),
      );
    }
    return widgets;
  }

  Widget _taskCard(
    BuildContext context, {
    required String title,
    required LearningType? type,
    required String meta,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final Color tone = type == null
        ? context.palette.textTertiary
        : LearningVisuals.toneOf(type);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md + 2,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 2.5,
            height: 40,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyLarge,
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (type != null)
                      AppChip(
                        label: type.tag,
                        dense: true,
                        filled: true,
                        color: tone,
                      ),
                    MetaText(meta, maxLines: 2),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppGhostButton(label: actionLabel, dense: true, onPressed: onTap),
        ],
      ),
    );
  }

  Future<void> _consumePending(String taskId, UiController ui) async {
    ui.consumeLearningTask();
    final ActionItem? task = context.read<ActionItemRepository>().byId(taskId);
    if (task == null || !mounted) return;
    await _startOrContinue(task);
  }

  Future<void> _startOrContinue(ActionItem task) async {
    final LearningSessionRepository repo =
        context.read<LearningSessionRepository>();
    LearningSession? session = repo.inProgressFor(task.id);
    if (session == null) {
      final LearningType? type = await _pickType();
      if (type == null || !mounted) return;
      session = await repo.startFor(task, type: type);
      if (!mounted) return;
    }
    setState(() => _activeTaskId = task.id);
  }

  Future<LearningType?> _pickType() {
    return showDialog<LearningType>(
      context: context,
      builder: (BuildContext dialogContext) => const _TypePickerDialog(),
    );
  }

  Future<void> _showArchive(
    LearningSession session,
    ActionItem task,
    LearningDraft draft,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _ArchiveDialog(
        session: session,
        task: task,
        draft: draft,
        onDelete: () {
          Navigator.of(dialogContext).pop();
          _deleteSession(session);
        },
        onRestart: () {
          Navigator.of(dialogContext).pop();
          _restartLearning(task);
        },
      ),
    );
  }

  Future<void> _openDraftMenu(
    Offset globalPosition,
    LearningSession session,
    ActionItem task,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    );
    final AppPalette palette = context.palette;

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
          value: 'cancel',
          height: 40,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.delete_outline_rounded,
                size: 15,
                color: palette.danger,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('取消本次学习', style: context.texts.bodyMedium),
            ],
          ),
        ),
      ],
    );
    if (action == 'cancel' && mounted) {
      await _cancelSession(session, task);
    }
  }

  Future<void> _cancelSession(LearningSession session, ActionItem task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette p = dialogContext.palette;
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: p.border),
          ),
          title: Text('取消本次学习？', style: dialogContext.texts.titleLarge),
          content: Text(
            '已填写的步骤内容会被丢弃，任务回到「今日待学」，不会生成复习提醒。',
            style:
                dialogContext.texts.bodyMedium?.copyWith(color: p.textSecondary),
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '先保留',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppPrimaryButton(
              label: '确认取消',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await context.read<LearningSessionRepository>().softDelete(session.id);
    if (!mounted) return;
    setState(() {
      if (_activeTaskId == task.id) _activeTaskId = null;
    });
    _toast('已取消本次学习，任务回到待学');
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
        width: 280,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteSession(LearningSession session) async {
    await context.read<LearningSessionRepository>().softDelete(session.id);
    if (!mounted) return;
    _toast('已删除该条输出记录，学习状态不变');
  }

  /// 清空该任务的学习状态：会话、复习队列与复习时间块一并清理，任务回到进行中。
  Future<void> _restartLearning(ActionItem task) async {
    final LearningSessionRepository sessions =
        context.read<LearningSessionRepository>();
    final LearningReviewRepository reviews =
        context.read<LearningReviewRepository>();
    final TimeBlockRepository blocks = context.read<TimeBlockRepository>();
    final ActionItemRepository actions = context.read<ActionItemRepository>();

    for (final LearningSession item in sessions.forActionItem(task.id)) {
      await sessions.softDelete(item.id);
    }
    for (final LearningReview review in reviews.forActionItem(task.id)) {
      final TimeBlock? block = blocks.forReview(review.id);
      if (block != null) {
        await blocks.softDelete(block.id);
      }
      await reviews.softDelete(review.id);
    }
    await actions.setStatus(task.id, ActionItemStatus.inProgress);
    if (!mounted) return;
    setState(() => _filter = LearningFilter.today);
    _toast('已清空学习记录，可从今日待学重新开始');
  }

  ActionItem? _findTask(List<ActionItem> actions, String id) {
    for (final ActionItem item in actions) {
      if (item.id == id) return item;
    }
    return null;
  }

  String _filterLabel(LearningFilter filter) {
    switch (filter) {
      case LearningFilter.today:
        return '今日待学';
      case LearningFilter.reviews:
        return '间隔复习';
      case LearningFilter.drafts:
        return '进行中草稿';
      case LearningFilter.archive:
        return '输出成果库';
    }
  }
}

/// 成果查看：按学习步骤分块展示，每块可独立折叠，也可一键全部展开/收起。
class _ArchiveDialog extends StatefulWidget {
  const _ArchiveDialog({
    required this.session,
    required this.task,
    required this.draft,
    required this.onDelete,
    required this.onRestart,
  });

  final LearningSession session;
  final ActionItem task;
  final LearningDraft draft;
  final VoidCallback onDelete;
  final VoidCallback onRestart;

  @override
  State<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<_ArchiveDialog> {
  static const int _blockerSection = 100;
  static const int _linkSection = 101;

  late final Set<int> _expanded = <int>{
    for (int index = 0; index < widget.draft.fullSteps.length; index++) index,
    _blockerSection,
    _linkSection,
  };
  bool _allExpanded = true;

  int get _sectionCount => widget.draft.fullSteps.length + 2;

  void _toggleAll() {
    setState(() {
      _allExpanded = !_allExpanded;
      _expanded.clear();
      if (_allExpanded) {
        for (int index = 0; index < widget.draft.fullSteps.length; index++) {
          _expanded.add(index);
        }
        _expanded.addAll(<int>{_blockerSection, _linkSection});
      }
    });
  }

  void _toggleSection(int id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
      _allExpanded = _expanded.length == _sectionCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tone = LearningVisuals.toneOf(widget.session.learningType);
    final LearningMethodTemplate template =
        methodOf(widget.session.learningType);

    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: palette.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      title: Row(
        children: <Widget>[
          Text('输出成果', style: context.texts.titleLarge),
          const SizedBox(width: AppSpacing.sm),
          AppChip(
            label: widget.session.learningType.tag,
            dense: true,
            filled: true,
            color: tone,
          ),
          const Spacer(),
          AppGhostButton(
            label: _allExpanded ? '全部收起' : '全部展开',
            dense: true,
            onPressed: _toggleAll,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.task.title, style: context.texts.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '完成于 ${AppDate.fullDateLabel(widget.session.completedAt ?? widget.session.updatedAt)}',
                  style: context.texts.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (int index = 0;
                    index < widget.draft.fullSteps.length;
                    index++)
                  _section(
                    context,
                    sectionId: index,
                    title: '${index + 1} ${template.stepAt(index).title}',
                    content: widget.draft.fullSteps[index].text,
                    tone: tone,
                  ),
                _section(
                  context,
                  sectionId: _blockerSection,
                  title: '卡点速记',
                  content: widget.draft.blocker,
                  tone: tone,
                ),
                _section(
                  context,
                  sectionId: _linkSection,
                  title: '外部成果链接',
                  content: widget.draft.link,
                  tone: tone,
                  selectable: true,
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
        AppGhostButton(
          label: '删除记录',
          tone: palette.danger,
          onPressed: widget.onDelete,
        ),
        AppGhostButton(
          label: '重新学习',
          icon: Icons.refresh_rounded,
          onPressed: widget.onRestart,
        ),
        AppPrimaryButton(
          label: '关闭',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context, {
    required int sectionId,
    required String title,
    required String content,
    required Color tone,
    bool selectable = false,
  }) {
    final AppPalette palette = context.palette;
    final bool expanded = _expanded.contains(sectionId);
    final List<String> lines = content
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    final bool hasContent = lines.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: expanded
              ? palette.surfaceMuted.withValues(alpha: 0.35)
              : palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () => _toggleSection(sectionId),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                child: Row(
                  children: <Widget>[
                    StatusDot(
                      color: hasContent ? tone : palette.textTertiary,
                      size: 4,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(title, style: context.texts.titleSmall),
                    ),
                    Text(
                      hasContent ? '${lines.length} 条' : '未填写',
                      style: context.texts.labelSmall,
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: hasContent
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final String line in lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: StatusDot(color: tone, size: 3.5),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: selectable
                                        ? SelectableText(
                                            line,
                                            style: context.texts.bodyMedium,
                                          )
                                        : Text(
                                            line,
                                            style: context.texts.bodyMedium,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      )
                    : Text('（本次未填写）', style: context.texts.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypePickerDialog extends StatelessWidget {
  const _TypePickerDialog();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
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
      title: Text('选择学习类型', style: context.texts.titleLarge),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '系统会加载对应的方法论步骤流与复习间隔。',
                  style: context.texts.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final LearningType type in LearningType.values) ...<Widget>[
                  _option(context, type),
                  const SizedBox(height: AppSpacing.sm),
                ],
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
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _option(BuildContext context, LearningType type) {
    final Color tone = LearningVisuals.toneOf(type);
    final LearningMethodTemplate template = methodOf(type);
    return InkWell(
      onTap: () => Navigator.of(context).pop(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: <Widget>[
            StatusDot(color: tone, size: 6),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(type.label, style: context.texts.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${type.tag} · ${template.stepCount} 步 · 复习 ${template.intervals.join('/')} 天'
                    '${type.supportsQuick ? ' · 支持 5m 微输出' : ''}',
                    style: context.texts.bodySmall,
                  ),
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