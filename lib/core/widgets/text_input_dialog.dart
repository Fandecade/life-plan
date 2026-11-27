import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import 'app_button.dart';

/// 通用文本输入对话框：controller 由对话框自身管理，避免关闭动画期间被提前 dispose。
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String initial,
  String? hintText,
  String? suffixText,
  TextInputType? keyboardType,
  bool digitsOnly = false,
  String? Function(String value)? validate,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _TextInputDialog(
      title: title,
      initial: initial,
      hintText: hintText,
      suffixText: suffixText,
      keyboardType: keyboardType,
      digitsOnly: digitsOnly,
      validate: validate,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initial,
    this.hintText,
    this.suffixText,
    this.keyboardType,
    this.digitsOnly = false,
    this.validate,
  });

  final String title;
  final String initial;
  final String? hintText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final bool digitsOnly;
  final String? Function(String value)? validate;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    final String? error = widget.validate?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: palette.border),
      ),
      title: Text(widget.title, style: context.texts.titleLarge),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.digitsOnly
            ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          hintText: widget.hintText,
          suffixText: widget.suffixText,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(label: '确定', onPressed: _submit),
      ],
    );
  }
}