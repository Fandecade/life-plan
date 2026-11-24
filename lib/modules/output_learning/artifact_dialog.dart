import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';

/// 从一次学习成果中沉淀「能力证据」（Artifact）。
Future<Artifact?> showArtifactFromLearningDialog(
  BuildContext context, {
  required LearningSession session,
  required ActionItem task,
  required LearningDraft draft,
}) {
  return showDialog<Artifact>(
    context: context,
    builder: (BuildContext dialogContext) => _ArtifactDialog(
      session: session,
      task: task,
      draft: draft,
    ),
  );
}

ArtifactType _defaultTypeFor(LearningType type) {
  switch (type) {
    case LearningType.project:
      return ArtifactType.project;
    case LearningType.language:
      return ArtifactType.presentation;
    case LearningType.procedural:
      return ArtifactType.exercise;
    case LearningType.declarative:
    case LearningType.custom:
      return ArtifactType.explanation;
  }
}

class _ArtifactDialog extends StatefulWidget {
  const _ArtifactDialog({
    required this.session,
    required this.task,
    required this.draft,
  });

  final LearningSession session;
  final ActionItem task;
  final LearningDraft draft;

  @override
  State<_ArtifactDialog> createState() => _ArtifactDialogState();
}

class _ArtifactDialogState extends State<_ArtifactDialog> {
  late final TextEditingController _title;
  late final TextEditingController _url;
  late final TextEditingController _note;
  late ArtifactType _type;
  String? _capabilityId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _url = TextEditingController(text: widget.draft.link);
    _note = TextEditingController();
    _type = _defaultTypeFor(widget.session.learningType);
    _capabilityId = widget.task.capabilityId;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final String title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final Artifact artifact = await context.read<ArtifactRepository>().create(
          title: title,
          type: _type,
          capabilityId: _capabilityId,
          actionItemId: widget.task.id,
          sessionId: widget.session.id,
          url: _url.text,
          note: _note.text,
        );
    if (!mounted) return;
    Navigator.of(context).pop(artifact);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<Capability> capabilities =
        context.watch<CapabilityRepository>().all;

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
      title: Text('记为能力成果', style: context.texts.titleLarge),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '成果是能力的证据：把「学习过程」变成可复用、可验证的产出。',
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('成果名称', style: context.texts.labelSmall),
            const SizedBox(height: 4),
            AppTextField(
              key: const ValueKey<String>('artifact-title'),
              controller: _title,
              hintText: '例：DPLL 算法实现与正确性验证',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('成果类型', style: context.texts.labelSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final ArtifactType type in ArtifactType.values)
                  AppChip(
                    label: type.label,
                    dense: true,
                    filled: _type == type,
                    color: palette.accent,
                    onTap: () => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('关联能力（决定它成为哪项能力的证据）', style: context.texts.labelSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                AppChip(
                  label: '不关联',
                  dense: true,
                  filled: _capabilityId == null,
                  color: palette.textSecondary,
                  onTap: () => setState(() => _capabilityId = null),
                ),
                for (final Capability capability in capabilities)
                  AppChip(
                    label: capability.title,
                    dense: true,
                    filled: _capabilityId == capability.id,
                    color: palette.accent,
                    onTap: () =>
                        setState(() => _capabilityId = capability.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('成果链接（可选）', style: context.texts.labelSmall),
            const SizedBox(height: 4),
            AppTextField(
              key: const ValueKey<String>('artifact-url'),
              controller: _url,
              hintText: 'GitHub / 文档 / 录音地址',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('备注（可选）', style: context.texts.labelSmall),
            const SizedBox(height: 4),
            AppTextField(
              controller: _note,
              maxLines: 2,
              minLines: 1,
              hintText: '验收标准、关键结论或下一步',
            ),
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
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(
          label: _saving ? '保存中…' : '保存成果',
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}