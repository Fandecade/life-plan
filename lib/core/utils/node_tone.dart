import 'package:flutter/painting.dart';

/// 四类导图节点的类型色：愿景 / 能力 / 任务 / 子任务。
/// 导图画布与时间盒共用，保证同一类型的颜色一致。
class NodeTone {
  const NodeTone._();

  static const Color vision = Color(0xFF4A5F7A);
  static const Color capability = Color(0xFF6B7F62);
  static const Color task = Color(0xFF9A795C);
  static const Color subtask = Color(0xFF8A6E86);

  static Color taskOrSubtask({required bool isSubtask}) =>
      isSubtask ? subtask : task;
}