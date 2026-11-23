import 'package:flutter/material.dart';

import '../shared/module_placeholder.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      icon: Icons.insights_outlined,
      title: '及时复盘',
      subtitle: '日 / 周 / 月 / 年 四级复盘：自动汇总统计，再把结论向下传导成具体的改期、拆分、调习惯或归档。',
      milestone: 'Milestone 5',
      points: <String>[
        'ReviewLog 已预留 periodType / periodKey / 三段文本与统计快照',
        '完成任务数、时间块时长、学习输出数可直接从现有仓储聚合',
        '下一步：四周期切换、数据摘要卡、向下传导一键动作',
      ],
    );
  }
}