import 'package:flutter/widgets.dart';

import '../models/action_item.dart';

/// 可插拔模块描述符。
///
/// 主壳层只依赖这份描述：导航入口、页面构建器与详情抽屉扩展槽位
/// 全部由描述符提供，新增模块无需修改 Shell 代码。
class AppModuleDescriptor {
  const AppModuleDescriptor({
    required this.id,
    required this.title,
    required this.icon,
    required this.routeName,
    required this.pageBuilder,
    this.isCore = false,
    this.defaultEnabled = true,
    this.description = '',
    this.milestone = '',
    this.detailSlotBuilder,
  });

  final String id;
  final String title;
  final IconData icon;
  final String routeName;
  final WidgetBuilder pageBuilder;

  /// 核心模块不可关闭（导航骨架依赖它）。
  final bool isCore;
  final bool defaultEnabled;
  final String description;

  /// 所属里程碑，用于占位页提示（如 M2）。
  final String milestone;

  /// 详情抽屉扩展槽位：模块可向通用行动单元详情注入自己的区块。
  final Widget Function(BuildContext context, ActionItem item)? detailSlotBuilder;
}