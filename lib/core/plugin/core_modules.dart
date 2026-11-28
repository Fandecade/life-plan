import 'package:flutter/material.dart';

import '../../app/router/module_routes.dart';
import '../../modules/ai_assistant/ai_assistant_page.dart';
import '../../modules/fogg_habit/fogg_habit_page.dart';
import '../../modules/fogg_habit/habit_detail_slot.dart';
import '../../modules/output_learning/learning_detail_slot.dart';
import '../../modules/output_learning/output_learning_page.dart';
import '../../modules/project/project_page.dart';
import '../../modules/review/review_page.dart';
import '../../modules/settings/settings_page.dart';
import '../../modules/time_box/time_box_page.dart';
import '../../modules/vision_map/vision_map_page.dart';
import '../models/models.dart';

import 'app_module_descriptor.dart';

/// 内置模块清单。后续新增模块只需在此追加描述符，Shell 与详情抽屉自动挂载。
List<AppModuleDescriptor> buildModuleDescriptors() => <AppModuleDescriptor>[
  AppModuleDescriptor(
    id: 'vision_map',
    title: '人生规划',
    icon: Icons.account_tree_outlined,
    routeName: AppRoutes.visionMap,
    pageBuilder: (BuildContext context) => const VisionMapPage(),
    description: '愿景 → 能力 → 任务的三级成长图谱',
    milestone: 'Milestone 2',
  ),
  AppModuleDescriptor(
    id: 'projects',
    title: '项目',
    icon: Icons.workspace_premium_outlined,
    routeName: AppRoutes.projects,
    pageBuilder: (BuildContext context) => const ProjectPage(),
    description: '综合实践：能力 → 阶段 → 验收与产物',
    milestone: 'Milestone 6',
  ),
  AppModuleDescriptor(
    id: 'time_box',
    title: '时间盒',
    icon: Icons.calendar_view_week_outlined,
    routeName: AppRoutes.timeBox,
    pageBuilder: (BuildContext context) => const TimeBoxPage(),
    description: '日 / 周 / 月 / 年 四级时间视图',
    milestone: 'Milestone 3',
  ),
  AppModuleDescriptor(
    id: 'output_learning',
    title: '输出式学习',
    icon: Icons.auto_stories_outlined,
    routeName: AppRoutes.outputLearning,
    pageBuilder: (BuildContext context) => const OutputLearningPage(),
    description: '完整四步 / 5 分钟微输出的双档引导',
    milestone: 'Milestone 4',
    detailSlotBuilder: (BuildContext context, ActionItem item) =>
        LearningDetailSlot(task: item),
  ),
  AppModuleDescriptor(
    id: 'fogg_habit',
    title: '福格习惯',
    icon: Icons.loop_outlined,
    routeName: AppRoutes.foggHabit,
    pageBuilder: (BuildContext context) => const FoggHabitPage(),
    description: '锚点 → 微动作的温和习惯系统',
    milestone: 'Milestone 4',
    detailSlotBuilder: (BuildContext context, ActionItem item) =>
        HabitDetailSlot(task: item),
  ),
  AppModuleDescriptor(
    id: 'review',
    title: '及时复盘',
    icon: Icons.insights_outlined,
    routeName: AppRoutes.review,
    pageBuilder: (BuildContext context) => const ReviewPage(),
    description: '日 / 周 / 月 / 年 自动汇总与向下传导',
    milestone: 'Milestone 5',
  ),
  AppModuleDescriptor(
    id: 'ai_assistant',
    title: 'AI 助手',
    icon: Icons.auto_awesome_outlined,
    routeName: AppRoutes.aiAssistant,
    pageBuilder: (BuildContext context) => const AiAssistantPage(),
    description: '接入大模型：梳理愿景、拆解任务、学习计划与复盘建议',
    milestone: 'AI',
  ),
  AppModuleDescriptor(
    id: 'settings',
    title: '设置',
    icon: Icons.tune_outlined,
    routeName: AppRoutes.settings,
    pageBuilder: (BuildContext context) => const SettingsPage(),
    isCore: true,
    description: '外观、模块管理与本地数据',
  ),
];
