import 'dart:convert';

import 'learning_models.dart';

/// 单个步骤的方法论定义：步骤名 + 2 行引导 + 输入提示。
class LearningStepTemplate {
  const LearningStepTemplate({
    required this.key,
    required this.title,
    required this.guide,
    required this.placeholder,
  });

  final String key;
  final String title;
  final String guide;
  final String placeholder;
}

/// 一类学习目标的完整方法论：步骤流 + 间隔复习节点。
class LearningMethodTemplate {
  const LearningMethodTemplate({
    required this.type,
    required this.steps,
    required this.intervals,
  });

  final LearningType type;
  final List<LearningStepTemplate> steps;
  final List<int> intervals;

  bool get supportsQuick => type.supportsQuick;

  int get stepCount => steps.length;

  LearningStepTemplate stepAt(int index) =>
      steps[index.clamp(0, steps.length - 1)];
}

const LearningStepTemplate quickOutputStep = LearningStepTemplate(
  key: 'quick',
  title: '5 分钟微输出',
  guide: '合上资料，用一句话写下核心结论，再记下一个卡壳点。',
  placeholder: '一句话核心结论…',
);

/// 五类学习目标的专属方法与复习间隔（来自规格）。
const Map<LearningType, LearningMethodTemplate> learningMethods =
    <LearningType, LearningMethodTemplate>{
      LearningType.declarative: LearningMethodTemplate(
        type: LearningType.declarative,
        intervals: <int>[1, 3, 7, 15, 30],
        steps: <LearningStepTemplate>[
          LearningStepTemplate(
            key: 'question',
            title: '课前/读前设问',
            guide: '快速浏览目录与小标题，写出 1–3 个核心问题。带着问题进入，拒绝被动浏览。',
            placeholder: '例：这个概念解决什么问题？它和我已知的什么相似？',
          ),
          LearningStepTemplate(
            key: 'network',
            title: '定向输入与建网',
            guide: '围绕问题阅读/听课，禁止逐字抄书；用类比、自我参照或逻辑框架串联新旧知识。',
            placeholder: '串联：它和我已知的 ____ 的关系是…（疑点先记不纠缠）',
          ),
          LearningStepTemplate(
            key: 'output',
            title: '独立输出（费曼/摘要）',
            guide: '合上原资料，用自己的话写摘要或模拟向别人讲解。写不出来的地方就是盲区。',
            placeholder: '在 Obsidian/Notion 写完后，把要点摘要或链接放这里…',
          ),
          LearningStepTemplate(
            key: 'check',
            title: '输出校验与间隔排期',
            guide: '自问：能否不看资料讲清概念与适用边界？通过后生成 1/3/7/15/30 天主动回忆提醒。',
            placeholder: '哪一部分讲不顺畅？它的适用边界是什么？',
          ),
        ],
      ),
      LearningType.procedural: LearningMethodTemplate(
        type: LearningType.procedural,
        intervals: <int>[1, 3, 7],
        steps: <LearningStepTemplate>[
          LearningStepTemplate(
            key: 'target',
            title: '锁定单一短板',
            guide: '明确本次只攻克一个题型或技能薄弱点，保持在舒适区边缘，不泛泛刷题。',
            placeholder: '本次只攻克的题型/薄弱点：',
          ),
          LearningStepTemplate(
            key: 'practice',
            title: '闭卷实战与反馈',
            guide: '不看答案独立写代码或推导，运行测试用例 / 核对标准答案获取即时反馈。',
            placeholder: '闭卷结果：通过 / 卡在哪一步？',
          ),
          LearningStepTemplate(
            key: 'error',
            title: '错因归因输出',
            guide: '记录错因分类（概念盲区 / 步骤遗漏 / 思路误区）+ 正确思路 + 同类判断条件。',
            placeholder: '错因分类：… 正确思路：… 下次如何识别同类题？',
          ),
          LearningStepTemplate(
            key: 'drill',
            title: '薄弱点重练排期',
            guide: '系统按 1/3/7 天生成同类短板闭卷重做提醒，避免重复刷已熟练内容。',
            placeholder: '下一轮要重练的具体变式：',
          ),
        ],
      ),
      LearningType.project: LearningMethodTemplate(
        type: LearningType.project,
        intervals: <int>[1, 7, 15, 30],
        steps: <LearningStepTemplate>[
          LearningStepTemplate(
            key: 'skeleton',
            title: '搭建最小骨架',
            guide: '用最少前置理论搭出可运行的最小框架，不要等看完所有教程再动手。',
            placeholder: '最小骨架包含：入口 / 数据流 / 一个可验证的输出',
          ),
          LearningStepTemplate(
            key: 'gap',
            title: '按需定向补盲',
            guide: '推进功能时遇到知识缺口，记录当前问题，只针对该缺口查资料。',
            placeholder: '当前卡住的知识缺口：… 我查到的结论：…',
          ),
          LearningStepTemplate(
            key: 'prototype',
            title: '产出可运行原型',
            guide: '先出粗糙可用版本，提交代码或导出 Demo，把产物链接挂在这里。',
            placeholder: '仓库 / Demo / 截图链接：',
          ),
          LearningStepTemplate(
            key: 'retro',
            title: '边界与迁移总结',
            guide: '记录踩坑、技术适用边界与可复用经验，并拆出下一轮迭代任务。',
            placeholder: '踩坑：… 适用边界：… 下一轮迭代：…',
          ),
        ],
      ),
      LearningType.language: LearningMethodTemplate(
        type: LearningType.language,
        intervals: <int>[1, 3, 7, 15],
        steps: <LearningStepTemplate>[
          LearningStepTemplate(
            key: 'listen',
            title: '盲听与精听拆解',
            guide: '先抓主干大意，再对照文本标记连读、弱读与核心表达。',
            placeholder: '这段的主干大意：… 标记的连读/弱读：…',
          ),
          LearningStepTemplate(
            key: 'shadow',
            title: '影子跟述训练',
            guide: '同步跟读模仿语音语调，聚焦过程时长，不纠结一次完美。',
            placeholder: '跟述时长 / 最不顺的句子：',
          ),
          LearningStepTemplate(
            key: 'retell',
            title: '脱稿复述与造句',
            guide: '合上文本，用自己的话口头复述段落或用新句型造句，录音/文本留在外部。',
            placeholder: '复述要点或新造句（外部录音/文本链接可放下面）：',
          ),
          LearningStepTemplate(
            key: 'corpus',
            title: '语料检索排期',
            guide: '系统按 1/3/7/15 天生成高频表达主动回忆提醒。',
            placeholder: '要进入复习队列的高频表达：',
          ),
        ],
      ),
      LearningType.custom: LearningMethodTemplate(
        type: LearningType.custom,
        intervals: <int>[1, 3, 7, 15, 30],
        steps: <LearningStepTemplate>[
          LearningStepTemplate(
            key: 'goal',
            title: '目标与输入',
            guide: '说清这次要解决的具体问题，再开始定向输入。',
            placeholder: '本次目标：… 输入材料：…',
          ),
          LearningStepTemplate(
            key: 'produce',
            title: '独立输出',
            guide: '合上资料，用自己的话产出结果；外部成果放链接。',
            placeholder: '输出要点：…',
          ),
          LearningStepTemplate(
            key: 'check',
            title: '自检与补盲',
            guide: '检查能否脱离资料独立复现；不确定的部分立即记录。',
            placeholder: '讲不清 / 做不出的地方：…',
          ),
          LearningStepTemplate(
            key: 'schedule',
            title: '总结与排期',
            guide: '写下一句结论，并确认进入间隔复习队列。',
            placeholder: '一句话结论：…',
          ),
        ],
      ),
    };

LearningMethodTemplate methodOf(LearningType type) =>
    learningMethods[type] ?? learningMethods[LearningType.declarative]!;

List<int> intervalsOf(LearningType type) => methodOf(type).intervals;

/// 主动回忆结果决定下一次复习间隔：顺畅 ×2（上限 60 天）、模糊保持、遗忘回到 1 天。
int nextIntervalDays(int current, ReviewOutcome outcome) {
  switch (outcome) {
    case ReviewOutcome.smooth:
      return (current * 2).clamp(1, 60);
    case ReviewOutcome.vague:
      return current.clamp(1, 60);
    case ReviewOutcome.forgotten:
      return 1;
  }
}

/// 单步草稿。
class LearningStepDraft {
  const LearningStepDraft({required this.key, this.text = ''});

  final String key;
  final String text;

  LearningStepDraft copyWith({String? text}) =>
      LearningStepDraft(key: key, text: text ?? this.text);

  Map<String, dynamic> toJson() => <String, dynamic>{'key': key, 'text': text};

  factory LearningStepDraft.fromJson(Map<String, dynamic> json) =>
      LearningStepDraft(
        key: json['key'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
}

/// 自定义步骤的种子：标题 + 初始内容。
class LearningStepSeed {
  const LearningStepSeed({required this.title, this.content = ''});

  final String title;
  final String content;
}

/// 一次会话的全部草稿：完整档与微输出档分开保存，切换模式不丢内容。
class LearningDraft {
  const LearningDraft({
    required this.type,
    this.mode = LearningMode.full,
    this.fullSteps = const <LearningStepDraft>[],
    this.quickSteps = const <LearningStepDraft>[],
    this.fullIndex = 0,
    this.quickIndex = 0,
    this.blocker = '',
    this.link = '',
    this.customTitles = const <String>[],
  });

  final LearningType type;
  final LearningMode mode;
  final List<LearningStepDraft> fullSteps;
  final List<LearningStepDraft> quickSteps;
  final int fullIndex;
  final int quickIndex;

  /// 卡点速记（供日后主动回忆自测，仅 1–3 句）。
  final String blocker;

  /// 外部产出链接（Obsidian / Notion / GitHub / 本地文件）。
  final String link;

  /// 自定义步骤标题；为空时回退到学习方法模板。
  final List<String> customTitles;

  bool get isQuick => mode == LearningMode.quick;

  List<LearningStepDraft> get activeSteps => isQuick ? quickSteps : fullSteps;

  int get activeIndex => isQuick ? quickIndex : fullIndex;

  int get activeStepCount => isQuick ? quickSteps.length : fullSteps.length;

  LearningStepTemplate get activeTemplate {
    if (isQuick) return quickOutputStep;
    final int index = activeIndex;
    if (customTitles.isNotEmpty) {
      final int safe = index.clamp(0, customTitles.length - 1);
      return LearningStepTemplate(
        key: 'custom-$safe',
        title: customTitles[safe],
        guide: '按你为这一步设定的目标自由输出。',
        placeholder: '写下这一步的输出…',
      );
    }
    return methodOf(type).stepAt(index);
  }

  String titleAt(int index) {
    if (customTitles.isNotEmpty) {
      return customTitles[index.clamp(0, customTitles.length - 1)];
    }
    return methodOf(type).stepAt(index).title;
  }

  bool get isLastStep => activeIndex >= activeStepCount - 1;

  int get filledStepCount => fullSteps
      .where((LearningStepDraft step) => step.text.trim().isNotEmpty)
      .length;

  bool get hasContent =>
      filledStepCount > 0 ||
      blocker.trim().isNotEmpty ||
      link.trim().isNotEmpty;

  String textOfActiveStep() {
    final List<LearningStepDraft> steps = activeSteps;
    if (steps.isEmpty) return '';
    return steps[activeIndex.clamp(0, steps.length - 1)].text;
  }

  LearningDraft withActiveText(String text) {
    if (isQuick) {
      final List<LearningStepDraft> next = List<LearningStepDraft>.from(
        quickSteps,
      );
      if (next.isEmpty) {
        next.add(const LearningStepDraft(key: 'quick'));
      }
      next[0] = next[0].copyWith(text: text);
      return copyWith(quickSteps: next);
    }
    final List<LearningStepDraft> next = List<LearningStepDraft>.from(
      fullSteps,
    );
    if (next.isEmpty) return this;
    final int index = activeIndex.clamp(0, next.length - 1);
    next[index] = next[index].copyWith(text: text);
    return copyWith(fullSteps: next);
  }

  LearningDraft withActiveIndex(int index) {
    final int clamped = index.clamp(0, activeStepCount - 1);
    return isQuick
        ? copyWith(quickIndex: clamped)
        : copyWith(fullIndex: clamped);
  }

  LearningDraft withMode(LearningMode next) => copyWith(mode: next);

  LearningDraft copyWith({
    LearningType? type,
    LearningMode? mode,
    List<LearningStepDraft>? fullSteps,
    List<LearningStepDraft>? quickSteps,
    int? fullIndex,
    int? quickIndex,
    String? blocker,
    String? link,
    List<String>? customTitles,
  }) {
    return LearningDraft(
      type: type ?? this.type,
      mode: mode ?? this.mode,
      fullSteps: fullSteps ?? this.fullSteps,
      quickSteps: quickSteps ?? this.quickSteps,
      fullIndex: fullIndex ?? this.fullIndex,
      quickIndex: quickIndex ?? this.quickIndex,
      blocker: blocker ?? this.blocker,
      link: link ?? this.link,
      customTitles: customTitles ?? this.customTitles,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'mode': mode.name,
    'full': <String, dynamic>{
      'steps': fullSteps
          .map((LearningStepDraft step) => step.toJson())
          .toList(growable: false),
      'index': fullIndex,
    },
    'quick': <String, dynamic>{
      'steps': quickSteps
          .map((LearningStepDraft step) => step.toJson())
          .toList(growable: false),
      'index': quickIndex,
    },
    'blocker': blocker,
    'link': link,
    'customTitles': customTitles,
  };

  String encode() => jsonEncode(toJson());

  factory LearningDraft.initial(
    LearningType type, {
    LearningMode mode = LearningMode.full,
  }) {
    final LearningMethodTemplate template = methodOf(type);
    return LearningDraft(
      type: type,
      mode: mode,
      fullSteps: template.steps
          .map((LearningStepTemplate step) => LearningStepDraft(key: step.key))
          .toList(growable: false),
      quickSteps: const <LearningStepDraft>[LearningStepDraft(key: 'quick')],
    );
  }

  /// 完全自定义步骤：标题与初始内容都由用户 / AI 提供。
  factory LearningDraft.custom({
    required LearningType type,
    required List<LearningStepSeed> steps,
    LearningMode mode = LearningMode.full,
  }) {
    return LearningDraft(
      type: type,
      mode: mode,
      fullSteps: <LearningStepDraft>[
        for (int index = 0; index < steps.length; index++)
          LearningStepDraft(key: 'custom-$index', text: steps[index].content),
      ],
      quickSteps: const <LearningStepDraft>[LearningStepDraft(key: 'quick')],
      customTitles: steps
          .map((LearningStepSeed step) => step.title)
          .toList(growable: false),
    );
  }

  factory LearningDraft.fromJson(Map<String, dynamic> json) {
    final LearningType type = LearningType.fromName(json['type']);
    final List<LearningStepDraft> full = _stepsOf(json['full']);
    final List<LearningStepDraft> quick = _stepsOf(json['quick']);
    final LearningDraft seed = LearningDraft.initial(type);
    return LearningDraft(
      type: type,
      mode: LearningMode.fromName(json['mode']),
      fullSteps: full.isEmpty ? seed.fullSteps : full,
      quickSteps: quick.isEmpty ? seed.quickSteps : quick,
      fullIndex: _indexOf(json['full']),
      quickIndex: _indexOf(json['quick']),
      blocker: json['blocker'] as String? ?? '',
      link: json['link'] as String? ?? '',
      customTitles:
          (json['customTitles'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
    );
  }

  /// 容错解码：旧数据（数组）或损坏时回退到初始草稿。
  static LearningDraft decode(String raw, LearningType fallbackType) {
    try {
      final Object? json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return LearningDraft.fromJson(json);
      }
      if (json is Map) {
        return LearningDraft.fromJson(json.cast<String, dynamic>());
      }
    } catch (_) {
      // 回退到初始草稿，避免单条坏数据影响整个学习台。
    }
    return LearningDraft.initial(fallbackType);
  }

  static List<LearningStepDraft> _stepsOf(Object? value) {
    if (value is Map && value['steps'] is List) {
      final List<dynamic> list = value['steps'] as List<dynamic>;
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) =>
                LearningStepDraft.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    }
    return const <LearningStepDraft>[];
  }

  static int _indexOf(Object? value) {
    if (value is Map && value['index'] is num) {
      return (value['index'] as num).toInt();
    }
    return 0;
  }
}
