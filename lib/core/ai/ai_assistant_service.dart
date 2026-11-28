import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ai_draft_applier.dart';
import 'ai_models.dart';
import 'ai_settings_controller.dart';
import 'ai_tool_registry.dart';
import 'openai_provider.dart';

/// 会话编排：系统提示 + 历史 + 工具循环；写工具只产生草稿，确认后统一执行。
class AiAssistantService extends ChangeNotifier {
  AiAssistantService({
    required AiSettingsController settings,
    required AiToolRegistry tools,
    required AiProvider provider,
    required AiDraftApplier applier,
  }) : _settings = settings,
       _tools = tools,
       _provider = provider,
       _applier = applier;

  static const String _systemPrompt =
      '你是「人生规划」应用内的个人成长助手。\n'
      '职责：帮助用户澄清愿景、拆解能力与任务、制定学习计划、给出复盘建议。\n'
      '规则：\n'
      '1. 需要事实时先调用只读工具查询，不要编造 id、标题或数据。\n'
      '2. 需要创建愿景/能力/阶段成果/项目/任务/排期时，调用对应写工具生成草稿；写工具不会立刻落库，用户确认后才执行。\n'
      '3. 一次回复里不要重复生成同一项草稿；生成后向用户简要说明将创建什么。\n'
      '4. 回答使用简体中文，先给结论，再给理由/步骤，避免空话。\n'
      '5. 信息不足时先问 1-2 个关键问题，不要假设。';

  final AiSettingsController _settings;
  final AiToolRegistry _tools;
  final AiProvider _provider;
  final AiDraftApplier _applier;

  bool _busy = false;
  List<AiDraft> _drafts = <AiDraft>[];

  bool get busy => _busy;

  List<AiDraft> get drafts => List<AiDraft>.unmodifiable(_drafts);

  bool get canUndo => _applier.canUndo;

  Future<AiMessage> send(String text) async {
    final String input = text.trim();
    if (input.isEmpty) {
      throw const AiException('请输入内容');
    }
    if (!_settings.isConfigured) {
      throw const AiNotConfiguredException();
    }
    if (_busy) {
      throw const AiException('正在回复中，请稍候');
    }

    _busy = true;
    notifyListeners();
    try {
      final List<AiMessage> messages = <AiMessage>[
        AiMessage.system(_systemPrompt),
        ..._settings.messages,
        AiMessage.user(input),
      ];

      String content = '';
      for (int round = 0; round < 5; round++) {
        final AiChatResult result = await _provider.complete(
          config: _settings.config,
          apiKey: _settings.apiKey!,
          messages: messages,
          tools: _tools.specs,
        );

        if (result.toolCalls.isEmpty) {
          content = result.content.trim();
          break;
        }

        messages.add(
          AiMessage(
            role: 'assistant',
            content: result.content,
            toolCalls: result.toolCalls,
          ),
        );
        for (final AiToolCall call in result.toolCalls) {
          final Map<String, dynamic> output = await _tools.execute(
            call.name,
            call.arguments,
          );
          _collectDraft(output);
          messages.add(
            AiMessage.toolResult(
              toolCallId: call.id,
              name: call.name,
              content: jsonEncode(output),
            ),
          );
        }
      }

      if (content.isEmpty) {
        content = '我已读取相关数据，但这次没有生成结论。可以换一种问法，或让我先给你一个分析框架。';
      }
      final AiMessage reply = AiMessage.assistant(content);
      await _settings.appendMessages(<AiMessage>[AiMessage.user(input), reply]);
      return reply;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _collectDraft(Map<String, dynamic> output) {
    final Object? raw = output['draft'];
    if (raw is! Map) return;
    final AiDraft? draft = AiDraft.fromJson(raw.cast<String, dynamic>());
    if (draft == null) return;
    if (_drafts.any((AiDraft item) => item.id == draft.id)) return;
    _drafts = <AiDraft>[..._drafts, draft];
  }

  /// 用户确认后执行全部草稿；成功后草稿清空，可用 undoLast 撤销。
  Future<AiApplyResult> applyDrafts() async {
    if (_drafts.isEmpty) {
      return const AiApplyResult(created: 0, errors: <String>[]);
    }
    final AiApplyResult result = await _applier.apply(_drafts);
    _drafts = <AiDraft>[];
    notifyListeners();
    return result;
  }

  void removeDraft(String id) {
    final List<AiDraft> next = _drafts
        .where((AiDraft item) => item.id != id)
        .toList(growable: false);
    if (next.length == _drafts.length) return;
    _drafts = next;
    notifyListeners();
  }

  void clearDrafts() {
    if (_drafts.isEmpty) return;
    _drafts = <AiDraft>[];
    notifyListeners();
  }

  Future<void> undoLast() async {
    if (!_applier.canUndo) return;
    await _applier.undoLast();
    notifyListeners();
  }
}
