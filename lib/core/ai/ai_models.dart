import 'dart:convert';

/// AI 连接配置（Key 单独存安全存储，不进入这里）。
class AiConfig {
  const AiConfig({required this.baseUrl, required this.model});

  final String baseUrl;
  final String model;

  bool get isReady => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;
}

/// 模型提出的写操作草稿：确认前不落库。
class AiDraft {
  const AiDraft({
    required this.id,
    required this.tool,
    required this.args,
    required this.summary,
  });

  final String id;
  final String tool;
  final Map<String, dynamic> args;
  final String summary;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'tool': tool,
    'args': args,
    'summary': summary,
  };

  static AiDraft? fromJson(Map<String, dynamic> json) {
    final String tool = '${json['tool'] ?? ''}'.trim();
    if (tool.isEmpty) return null;
    return AiDraft(
      id: '${json['id'] ?? ''}',
      tool: tool,
      args:
          (json['args'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      summary: '${json['summary'] ?? tool}',
    );
  }
}

class AiApplyResult {
  const AiApplyResult({required this.created, required this.errors});

  final int created;
  final List<String> errors;

  bool get ok => errors.isEmpty;
}

/// OpenAI function calling 的一次工具调用。
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  Map<String, dynamic> toOpenAi() => <String, dynamic>{
    'id': id,
    'type': 'function',
    'function': <String, dynamic>{
      'name': name,
      'arguments': jsonEncode(arguments),
    },
  };

  static AiToolCall fromOpenAi(Map<String, dynamic> json) {
    final Map<String, dynamic> fn =
        (json['function'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final Object? raw = fn['arguments'];
    Map<String, dynamic> args = <String, dynamic>{};
    if (raw is Map) {
      args = raw.cast<String, dynamic>();
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) args = decoded.cast<String, dynamic>();
      } catch (_) {
        args = <String, dynamic>{};
      }
    }
    return AiToolCall(
      id: '${json['id'] ?? ''}',
      name: '${fn['name'] ?? ''}',
      arguments: args,
    );
  }
}

/// 对话消息，可承载 assistant 的 tool_calls 与 tool 结果。
class AiMessage {
  const AiMessage({
    required this.role,
    this.content = '',
    this.toolCalls = const <AiToolCall>[],
    this.toolCallId,
    this.name,
  });

  final String role;
  final String content;
  final List<AiToolCall> toolCalls;
  final String? toolCallId;
  final String? name;

  factory AiMessage.system(String content) =>
      AiMessage(role: 'system', content: content);

  factory AiMessage.user(String content) =>
      AiMessage(role: 'user', content: content);

  factory AiMessage.assistant(String content) =>
      AiMessage(role: 'assistant', content: content);

  factory AiMessage.toolResult({
    required String toolCallId,
    required String name,
    required String content,
  }) => AiMessage(
    role: 'tool',
    toolCallId: toolCallId,
    name: name,
    content: content,
  );

  Map<String, dynamic> toOpenAi() {
    final Map<String, dynamic> map = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (toolCalls.isNotEmpty) {
      map['tool_calls'] = toolCalls
          .map((AiToolCall call) => call.toOpenAi())
          .toList(growable: false);
    }
    if (role == 'tool') {
      map['tool_call_id'] = toolCallId;
      if (name != null) map['name'] = name;
    }
    return map;
  }

  /// 仅持久化可展示的文本消息（user / assistant）。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'content': content,
  };

  static AiMessage? fromJson(Map<String, dynamic> json) {
    final String role = '${json['role'] ?? ''}';
    if (role != 'user' && role != 'assistant') return null;
    return AiMessage(role: role, content: '${json['content'] ?? ''}');
  }
}

/// 供模型调用的工具描述（JSON Schema）。
class AiToolSpec {
  const AiToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toOpenAi() => <String, dynamic>{
    'type': 'function',
    'function': <String, dynamic>{
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

class AiChatResult {
  const AiChatResult({
    required this.content,
    required this.toolCalls,
    this.model = '',
  });

  final String content;
  final List<AiToolCall> toolCalls;
  final String model;
}

class AiException implements Exception {
  const AiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AiNotConfiguredException extends AiException {
  const AiNotConfiguredException() : super('请先在「设置 → AI 助手」填写服务地址、模型与 API Key');
}
