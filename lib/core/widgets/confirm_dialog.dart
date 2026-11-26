import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import 'app_button.dart';

/// 通用「撤销已完成」确认：完成动作可逆，但回退会联动进度与统计，
/// 因此再次点击已完成圆圈时必须显式确认。
Future<bool> showRollbackConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String keepLabel = '保持完成',
  String confirmLabel = '取消完成',
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppPalette palette = dialogContext.palette;
      return AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: palette.border),
        ),
        title: Text(title, style: dialogContext.texts.titleLarge),
        content: Text(
          message,
          style: dialogContext.texts.bodyMedium
              ?.copyWith(color: palette.textSecondary),
        ),
        actions: <Widget>[
          AppGhostButton(
            label: keepLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppPrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 任务 / 时间块取消完成。
Future<bool> confirmCancelCompletion(BuildContext context) {
  return showRollbackConfirm(
    context,
    title: '取消完成？',
    message: '取消后这个事项会回到待办，相关进度与统计会同步回退。',
    keepLabel: '保持完成',
    confirmLabel: '取消完成',
  );
}

/// 微习惯取消今日打卡。
Future<bool> confirmCancelHabitCheckIn(BuildContext context) {
  return showRollbackConfirm(
    context,
    title: '取消今天的打卡？',
    message: '取消会移除今天的打卡记录，连续天数和完成率会相应变化。',
    keepLabel: '保持打卡',
    confirmLabel: '取消打卡',
  );
}

/// 能力阶段成果取消达成。
Future<bool> confirmCancelMilestone(BuildContext context) {
  return showRollbackConfirm(
    context,
    title: '取消达成？',
    message: '取消后该阶段成果会回到未达成状态。',
    keepLabel: '保持达成',
    confirmLabel: '取消达成',
  );
}