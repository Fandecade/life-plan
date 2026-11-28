import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ai_models.dart';
import 'ai_settings_controller.dart';
import 'ai_tool_registry.dart';
import 'openai_provider.dart';

/// 会话编排：系统提示 + 历史 + 工具循环。P0 只允许读工具。
class AiAssistantService extends ChangeNotifier {
  AiAssistantService({
    required AiSettingsController settings,
    required AiToolRegistry tools,
    required AiProvider provider,
  }) : _settings = settings,
       _tools = tools,
       _provider = provider;

  static const String _systemPrompt =
      '你是「人生规划」应用内的个人成长助手。\n'
      '职责：帮助用户澄清愿景、拆解能力与任务、制定学习计划、给出复盘建议。\n'
      '规则：\n'
      '1. 需要事实时先调用只读工具查询，不要编造 id、标题或数据。\n'
      '2. 当前版本只能分析与建议，不会直接修改数据；如需落地，请给出清晰可执行的步骤。\n'
      '3. 回答使用简体中文，先给结论，再给理由/步骤，避免空话。\n'
      '4. 信息不足时先问 1-2 个关键问题，不要假设。';

  final AiSettingsController _settings;
  final AiToolRegistry _tools;
  final AiProvider _provider;

  bool _busy = false;
  bool get busy => _busy;

  /// 发送一条消息，返回最终 assistant 文本（已写入会话）。
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
}
