import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_models.dart';
import 'openai_provider.dart';

/// Anthropic Messages API 适配。
class AnthropicProvider implements AiProvider {
  AnthropicProvider({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 60);

  final http.Client _client;
  final Duration _timeout;

  static const String _version = '2023-06-01';

  static String resolveEndpoint(String baseUrl) {
    String url = _strip(baseUrl);
    if (url.endsWith('/messages')) return url;
    if (url.endsWith('/v1')) return '$url/messages';
    return '$url/v1/messages';
  }

  static String resolveModelsEndpoint(String baseUrl) {
    String url = _strip(baseUrl);
    if (url.endsWith('/models')) return url;
    if (url.endsWith('/v1')) return '$url/models';
    return '$url/v1/models';
  }

  static String _strip(String value) {
    String url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  @override
  Future<AiChatResult> complete({
    required AiConfig config,
    required String apiKey,
    required List<AiMessage> messages,
    List<AiToolSpec> tools = const <AiToolSpec>[],
  }) async {
    final String system = messages
        .where((AiMessage item) => item.role == 'system')
        .map((AiMessage item) => item.content.trim())
        .where((String value) => value.isNotEmpty)
        .join('\n\n');
    final List<Map<String, dynamic>> converted = <Map<String, dynamic>>[
      for (final AiMessage message in messages)
        if (message.role != 'system') _convertMessage(message),
    ];
    final Map<String, dynamic> body = <String, dynamic>{
      'model': config.model,
      'max_tokens': 2048,
      'temperature': 0.4,
      'messages': converted,
      if (system.isNotEmpty) 'system': system,
      if (tools.isNotEmpty)
        'tools': tools
            .map(
              (AiToolSpec spec) => <String, dynamic>{
                'name': spec.name,
                'description': spec.description,
                'input_schema': spec.parameters,
              },
            )
            .toList(growable: false),
    };

    final http.Response response = await _post(
      resolveEndpoint(config.baseUrl),
      apiKey,
      body,
    );
    final Map<String, dynamic> json = _decode(response);
    final List<dynamic> content =
        (json['content'] as List<dynamic>?) ?? const <dynamic>[];
    final StringBuffer text = StringBuffer();
    final List<AiToolCall> calls = <AiToolCall>[];
    for (final dynamic block in content) {
      if (block is! Map) continue;
      final String type = '${block['type'] ?? ''}';
      if (type == 'text') {
        text.write('${block['text'] ?? ''}');
      } else if (type == 'tool_use') {
        calls.add(
          AiToolCall(
            id: '${block['id'] ?? ''}',
            name: '${block['name'] ?? ''}',
            arguments:
                (block['input'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{},
          ),
        );
      }
    }
    return AiChatResult(
      content: text.toString().trim(),
      toolCalls: calls,
      model: '${json['model'] ?? config.model}',
    );
  }

  @override
  Future<List<String>> listModels({
    required AiConfig config,
    required String apiKey,
  }) async {
    late http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse(resolveModelsEndpoint(config.baseUrl)),
            headers: <String, String>{
              'x-api-key': apiKey,
              'anthropic-version': _version,
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException('获取模型超时');
    } catch (error) {
      throw AiException('获取模型失败：$error');
    }
    final Map<String, dynamic> json = _decode(response);
    final List<dynamic> data =
        (json['data'] as List<dynamic>?) ?? const <dynamic>[];
    final List<String> models = <String>{
      for (final Object? item in data)
        if (item is Map && '${item['id'] ?? ''}'.trim().isNotEmpty)
          '${item['id']}'.trim(),
    }.toList()..sort();
    if (models.isEmpty) throw const AiException('服务端没有返回可用模型');
    return models;
  }

  Map<String, dynamic> _convertMessage(AiMessage message) {
    if (message.role == 'tool') {
      return <String, dynamic>{
        'role': 'user',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'tool_result',
            'tool_use_id': message.toolCallId,
            'content': message.content,
          },
        ],
      };
    }
    if (message.role == 'assistant') {
      final List<Map<String, dynamic>> blocks = <Map<String, dynamic>>[];
      if (message.content.trim().isNotEmpty) {
        blocks.add(<String, dynamic>{'type': 'text', 'text': message.content});
      }
      for (final AiToolCall call in message.toolCalls) {
        blocks.add(<String, dynamic>{
          'type': 'tool_use',
          'id': call.id,
          'name': call.name,
          'input': call.arguments,
        });
      }
      if (blocks.isEmpty) {
        blocks.add(<String, dynamic>{'type': 'text', 'text': ''});
      }
      return <String, dynamic>{'role': 'assistant', 'content': blocks};
    }
    return <String, dynamic>{
      'role': 'user',
      'content': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': message.content},
      ],
    };
  }

  Future<http.Response> _post(
    String endpoint,
    String apiKey,
    Map<String, dynamic> body,
  ) async {
    try {
      final http.Response response = await _client
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'x-api-key': apiKey,
              'anthropic-version': _version,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiException(
          _errorMessage(response.body) ?? 'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const AiException('请求超时');
    } on AiException {
      rethrow;
    } catch (error) {
      throw AiException('请求失败：$error');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return (decoded as Map).cast<String, dynamic>();
    } catch (_) {
      throw const AiException('返回内容不是合法 JSON');
    }
  }

  String? _errorMessage(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map) {
        final Object? error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return '${error['message']}';
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }
}
