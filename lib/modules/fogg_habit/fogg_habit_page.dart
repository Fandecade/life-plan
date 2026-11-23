import 'package:flutter/material.dart';

import '../shared/module_placeholder.dart';

class FoggHabitPage extends StatelessWidget {
  const FoggHabitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      icon: Icons.loop_outlined,
      title: '福格习惯',
      subtitle: '基于 B = MAP 的温和习惯系统：锚点提示 → 2 分钟微动作 → 降低阻力 → 动机来源。',
      milestone: 'Milestone 4',
      points: <String>[
        'FoggHabit 与 HabitLog 实体已就绪，含日期键与调整备注字段',
        '温和断签提示所需的 adjustmentNote 已预留，不做惩罚性清零',
        '下一步：锚点卡片、打卡微动效、14/30 天点阵节奏图与一键缩小动作',
      ],
    );
  }
}