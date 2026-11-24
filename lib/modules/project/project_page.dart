import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/state_views.dart';

const _uuid = Uuid();

/// 项目：综合实践载体，连接能力、阶段、验收标准与产物证据。
class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  ProjectStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<Project> all = context.watch<ProjectRepository>().all;
    final List<Project> projects = _filter == null
        ? all
        : all.where((Project item) => item.status == _filter).toList();

    return Column(
      children: <Widget>[
        Padding(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('项目', style: context.texts.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          '通过什么综合实践形成与验证能力；阶段是检查点，不是待办。',
                          style: context.texts.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AppPrimaryButton(
                    label: '新建项目',
                    dense: true,
                    onPressed: () => _openEditor(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    AppChip(
                      label: '全部',
                      dense: true,
                      filled: _filter == null,
                      color: palette.accent,
                      onTap: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 6),
                    for (final ProjectStatus status in ProjectStatus.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: AppChip(
                          label: status.label,
                          dense: true,
                          filled: _filter == status,
                          color: _statusTone(palette, status),
                          onTap: () => setState(() => _filter = status),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: palette.hairline, height: 1),
        Expanded(
          child: projects.isEmpty
              ? const EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: '还没有项目',
                  description: '用一个项目把多项能力、阶段与产物串起来。',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    for (final Project project in projects)
                      _projectCard(context, palette, project),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _projectCard(
    BuildContext context,
    AppPalette palette,
    Project project,
  ) {
    final List<Capability> capabilities =
        context.watch<CapabilityRepository>().all;
    final List<Capability> linked = <Capability>[
      for (final Capability capability in capabilities)
        if (project.capabilityIds.contains(capability.id)) capability,
    ];
    final int taskCount = context
        .watch<ActionItemRepository>()
        .all
        .where((ActionItem item) => item.projectId == project.id)
        .length;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _openEditor(context, project),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppChip(
                label: project.status.label,
                dense: true,
                filled: true,
                color: _statusTone(palette, project.status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
              ),
              Text(
                '阶段 ${project.doneStages}/${project.stages.length}',
                style: context.texts.labelSmall,
              ),
            ],
          ),
          if (project.goal.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              project.goal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final Capability capability in linked.take(3))
                AppChip(
                  label: capability.title,
                  dense: true,
                  color: palette.accent,
                ),
              if (taskCount > 0)
                AppChip(
                  label: '$taskCount 个任务',
                  dense: true,
                  color: palette.textSecondary,
                ),
              if (project.artifactUrl.isNotEmpty)
                AppChip(
                  label: '有产物',
                  dense: true,
                  color: palette.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ProgressHairline(value: project.stageProgress, color: palette.accent),
        ],
      ),
    );
  }

  Color _statusTone(AppPalette palette, ProjectStatus status) {
    switch (status) {
      case ProjectStatus.active:
        return palette.accent;
      case ProjectStatus.paused:
        return palette.textTertiary;
      case ProjectStatus.completed:
        return palette.success;
      case ProjectStatus.archived:
        return palette.textTertiary;
    }
  }

  Future<void> _openEditor(BuildContext context, [Project? project]) async {
    final bool changed = await showProjectEditorDialog(
      context,
      project: project,
    );
    if (!mounted || !changed) return;
    setState(() {});
  }
}

/// 新建 / 编辑项目。
Future<bool> showProjectEditorDialog(
  BuildContext context, {
  Project? project,
}) async {
  final bool? changed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _ProjectDialog(project: project),
  );
  return changed ?? false;
}

class _ProjectDialog extends StatefulWidget {
  const _ProjectDialog({this.project});

  final Project? project;

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  late final TextEditingController _title;
  late final TextEditingController _goal;
  late final TextEditingController _acceptance;
  late final TextEditingController _artifactUrl;
  late final TextEditingController _stageInput;
  late ProjectStatus _status;
  late Set<String> _capabilityIds;
  late List<ProjectStage> _stages;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Project? project = widget.project;
    _title = TextEditingController(text: project?.title ?? '');
    _goal = TextEditingController(text: project?.goal ?? '');
    _acceptance = TextEditingController(text: project?.acceptance ?? '');
    _artifactUrl = TextEditingController(text: project?.artifactUrl ?? '');
    _stageInput = TextEditingController();
    _status = project?.status ?? ProjectStatus.active;
    _capabilityIds = <String>{...?project?.capabilityIds};
    _stages = <ProjectStage>[...?project?.stages];
  }

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    _acceptance.dispose();
    _artifactUrl.dispose();
    _stageInput.dispose();
    super.dispose();
  }

  void _addStage() {
    final String title = _stageInput.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _stages.add(ProjectStage(id: _uuid.v4(), title: title));
      _stageInput.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final String title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final ProjectRepository repo = context.read<ProjectRepository>();
    if (widget.project == null) {
      await repo.create(
        title: title,
        goal: _goal.text,
        status: _status,
        capabilityIds: _capabilityIds.toList(),
        stages: _stages,
        acceptance: _acceptance.text,
        artifactUrl: _artifactUrl.text,
      );
    } else {
      await repo.save(
        widget.project!.copyWith(
          title: title,
          goal: _goal.text,
          status: _status,
          capabilityIdsJson: jsonEncode(_capabilityIds.toList()),
          stagesJson: jsonEncode(
            _stages.map((ProjectStage stage) => stage.toJson()).toList(),
          ),
          acceptance: _acceptance.text,
          artifactUrl: _artifactUrl.text,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final Project? project = widget.project;
    if (project == null) return;
    final AppPalette palette = context.palette;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: palette.border),
        ),
        title: Text('删除这个项目？', style: dialogContext.texts.titleLarge),
        content: Text(
          '项目采用软删除，历史数据仍保留在本地；关联任务不会被删除。',
          style: dialogContext.texts.bodyMedium,
        ),
        actions: <Widget>[
          AppGhostButton(
            label: '取消',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppPrimaryButton(
            label: '删除',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ProjectRepository>().softDelete(project.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<Capability> capabilities =
        context.watch<CapabilityRepository>().all;
    final bool editing = widget.project != null;

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
      title: Text(editing ? '编辑项目' : '新建项目', style: context.texts.titleLarge),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 620,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('项目名称', style: context.texts.labelSmall),
                const SizedBox(height: 4),
                AppTextField(
                  key: const ValueKey<String>('project-title'),
                  controller: _title,
                  hintText: '例：群智能算法求解 SAT',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('目标（这个项目要证明什么）', style: context.texts.labelSmall),
                const SizedBox(height: 4),
                AppTextField(
                  controller: _goal,
                  maxLines: 2,
                  minLines: 1,
                  hintText: '例：独立实现算法并对比实验效果',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('状态', style: context.texts.labelSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final ProjectStatus status in ProjectStatus.values)
                      AppChip(
                        label: status.label,
                        dense: true,
                        filled: _status == status,
                        color: _statusTone(palette, status),
                        onTap: () => setState(() => _status = status),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('关联能力', style: context.texts.labelSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final Capability capability in capabilities)
                      AppChip(
                        label: capability.title,
                        dense: true,
                        filled: _capabilityIds.contains(capability.id),
                        color: palette.accent,
                        onTap: () => setState(() {
                          if (!_capabilityIds.add(capability.id)) {
                            _capabilityIds.remove(capability.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('阶段（检查点）', style: context.texts.labelSmall),
                const SizedBox(height: 4),
                for (final ProjectStage stage in _stages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: <Widget>[
                        AppCheckCircle(
                          checked: stage.done,
                          size: 18,
                          padding: 0,
                          onTap: () => setState(() {
                            final int index = _stages.indexOf(stage);
                            _stages[index] =
                                stage.copyWith(done: !stage.done);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stage.title,
                            style: context.texts.bodyMedium?.copyWith(
                              decoration: stage.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: palette.textTertiary,
                            ),
                          ),
                        ),
                        AppIconButton(
                          icon: Icons.close_rounded,
                          iconSize: 13,
                          size: 24,
                          tooltip: '删除阶段',
                          onPressed: () =>
                              setState(() => _stages.remove(stage)),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        key: const ValueKey<String>('project-stage-input'),
                        controller: _stageInput,
                        hintText: '添加阶段，例：算法实现',
                        onSubmitted: (_) => _addStage(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppGhostButton(
                      label: '添加',
                      dense: true,
                      onPressed: _addStage,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('验收标准', style: context.texts.labelSmall),
                const SizedBox(height: 4),
                AppTextField(
                  controller: _acceptance,
                  maxLines: 3,
                  minLines: 2,
                  hintText: '例：能解释核心流程、通过正确性测试、分析复杂度',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('产物链接（可选）', style: context.texts.labelSmall),
                const SizedBox(height: 4),
                AppTextField(
                  controller: _artifactUrl,
                  hintText: 'GitHub / 文档 / 演示地址',
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
        if (editing)
          AppGhostButton(
            label: '删除',
            tone: palette.danger,
            onPressed: _delete,
          ),
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppPrimaryButton(
          label: _saving ? '保存中…' : '保存项目',
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Color _statusTone(AppPalette palette, ProjectStatus status) {
    switch (status) {
      case ProjectStatus.active:
        return palette.accent;
      case ProjectStatus.paused:
        return palette.textTertiary;
      case ProjectStatus.completed:
        return palette.success;
      case ProjectStatus.archived:
        return palette.textTertiary;
    }
  }
}