import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';

class EditorField {
  const EditorField({
    required this.label,
    this.hint = '',
    this.initial = '',
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final String initial;
  final int maxLines;
}

/// 通用极简编辑对话框，返回按字段顺序排列的文本。
Future<List<String>?> showEditorDialog(
  BuildContext context, {
  required String title,
  required List<EditorField> fields,
  String confirmLabel = '保存',
}) {
  return showAppSheet<List<String>>(
    context,
    builder: (BuildContext dialogContext) =>
        _EditorDialog(title: title, fields: fields, confirmLabel: confirmLabel),
  );
}

class _EditorDialog extends StatefulWidget {
  const _EditorDialog({
    required this.title,
    required this.fields,
    required this.confirmLabel,
  });

  final String title;
  final List<EditorField> fields;
  final String confirmLabel;

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  late final List<TextEditingController> _controllers = widget.fields
      .map((EditorField field) => TextEditingController(text: field.initial))
      .toList();
  String? _error;

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final String first = _controllers.first.text.trim();
    if (first.isEmpty) {
      setState(() => _error = '${widget.fields.first.label}不能为空');
      return;
    }
    Navigator.of(context).pop(
      _controllers.map((TextEditingController c) => c.text.trim()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return AppSheetContent(
      title: widget.title,
      heightFactor: null,
      actions: <Widget>[
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(label: widget.confirmLabel, onPressed: _submit),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int index = 0; index < widget.fields.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.fields[index].label,
                    style: context.texts.labelMedium,
                  ),
                  const SizedBox(height: 5),
                  AppTextField(
                    controller: _controllers[index],
                    hintText: widget.fields[index].hint,
                    maxLines: widget.fields[index].maxLines,
                    minLines: widget.fields[index].maxLines > 1 ? 2 : 1,
                    autofocus: index == 0,
                    onSubmitted: index == widget.fields.length - 1
                        ? (_) => _submit()
                        : null,
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _error!,
                style: context.texts.bodySmall?.copyWith(color: palette.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class TaskDraft {
  const TaskDraft({required this.title, this.minutes});

  final String title;
  final int? minutes;
}

/// 新建任务：标题 + 预计时长。
Future<TaskDraft?> showTaskDialog(BuildContext context) {
  return showAppSheet<TaskDraft>(
    context,
    builder: (BuildContext dialogContext) => const _TaskDialog(),
  );
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog();

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final TextEditingController _title = TextEditingController();
  int? _minutes = 30;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '任务标题不能为空');
      return;
    }
    Navigator.of(context).pop(TaskDraft(title: title, minutes: _minutes));
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return AppSheetContent(
      title: '新建任务',
      heightFactor: null,
      actions: <Widget>[
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(label: '创建', onPressed: _submit),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('任务标题', style: context.texts.labelMedium),
          const SizedBox(height: 5),
          AppTextField(
            key: const ValueKey<String>('vision-task-title'),
            controller: _title,
            hintText: '一件可以直接开始做的事',
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('预计时长', style: context.texts.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            children: <Widget>[
              for (final int minutes in <int>[15, 30, 45, 60, 90])
                AppChip(
                  label: AppDate.durationLabel(minutes),
                  filled: _minutes == minutes,
                  color: palette.accent,
                  onTap: () => setState(() => _minutes = minutes),
                ),
              AppChip(
                label: '暂不估时',
                filled: _minutes == null,
                onTap: () => setState(() => _minutes = null),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                style: context.texts.bodySmall?.copyWith(color: palette.danger),
              ),
            ),
        ],
      ),
    );
  }
}
