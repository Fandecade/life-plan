import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_models.dart';
import 'openai_provider.dart';

/// Google Gemini generateContent 适配。
class GeminiProvider implements AiProvider {
  GeminiProvider({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 60);

  final http.Client _client;
  final Duration _timeout;

  static String resolveEndpoint(String baseUrl, String model) {
    String url = _strip(baseUrl);
    if (url.endsWith('/models')) return '$url/$model:generateContent';
    if (url.endsWith('/v1beta') || url.endsWith('/v1')) {
      return '$url/models/$model:generateContent';
    }
    return '$url/v1beta/models/$model:generateContent';
  }

  static String resolveModelsEndpoint(String baseUrl) {
    String url = _strip(baseUrl);
    if (url.endsWith('/models')) return url;
    if (url.endsWith('/v1beta') || url.endsWith('/v1')) return '$url/models';
    return '$url/v1beta/models';
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

    final List<Map<String, dynamic>> contents = <Map<String, dynamic>>[];
    for (final AiMessage message in messages) {
      if (message.role == 'system') continue;
      contents.add(_convertMessage(message));
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'contents': contents,
      if (system.isNotEmpty)
        'systemInstruction': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': system},
          ],
        },
      'generationConfig': <String, dynamic>{'temperature': 0.4},
      if (tools.isNotEmpty)
        'tools': <Map<String, dynamic>>[
          <String, dynamic>{
            'functionDeclarations': tools
                .map(
                  (AiToolSpec spec) => <String, dynamic>{
                    'name': spec.name,
                    'description': spec.description,
                    'parameters': spec.parameters,
                  },
                )
                .toList(growable: false),
          },
        ],
    };

    final Uri uri = Uri.parse(resolveEndpoint(config.baseUrl, config.model))
        .replace(queryParameters: <String, String>{'key': apiKey});

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException('请求超时');
    } catch (error) {
      throw AiException('请求失败：$error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        _errorMessage(response.body) ?? 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> json = _decode(response);
    final List<dynamic> candidates =
        (json['candidates'] as List<dynamic>?) ?? const <dynamic>[];
    if (candidates.isEmpty) throw const AiException('模型没有返回任何结果');
    final Map<String, dynamic> content =
        ((candidates.first as Map)['content'] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final List<dynamic> parts =
        (content['parts'] as List<dynamic>?) ?? const <dynamic>[];
    final StringBuffer text = StringBuffer();
    final List<AiToolCall> calls = <AiToolCall>[];
    int index = 0;
    for (final dynamic part in parts) {
      if (part is! Map) continue;
      if (part['text'] != null) text.write('${part['text']}');
      final Object? call = part['functionCall'];
      if (call is Map) {
        calls.add(
          AiToolCall(
            id: 'call_${index++}',
            name: '${call['name'] ?? ''}',
            arguments:
                (call['args'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{},
          ),
        );
      }
    }
    return AiChatResult(
      content: text.toString().trim(),
      toolCalls: calls,
      model: '${json['modelVersion'] ?? config.model}',
    );
  }

  @override
  Future<List<String>> listModels({
    required AiConfig config,
    required String apiKey,
  }) async {
    final Uri uri = Uri.parse(resolveModelsEndpoint(config.baseUrl))
        .replace(queryParameters: <String, String>{'key': apiKey});
    late http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const AiException('获取模型超时');
    } catch (error) {
      throw AiException('获取模型失败：$error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        _errorMessage(response.body) ?? 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    final Map<String, dynamic> json = _decode(response);
    final List<dynamic> models =
        (json['models'] as List<dynamic>?) ?? const <dynamic>[];
    final List<String> names = <String>{
      for (final Object? item in models)
        if (item is Map && '${item['name'] ?? ''}'.trim().isNotEmpty)
          '${item['name']}'.replaceFirst('models/', '').trim(),
    }.toList()..sort();
    if (names.isEmpty) throw const AiException('服务端没有返回可用模型');
    return names;
  }

  Map<String, dynamic> _convertMessage(AiMessage message) {
    if (message.role == 'tool') {
      return <String, dynamic>{
        'role': 'user',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{
            'functionResponse': <String, dynamic>{
              'name': message.name ?? 'tool',
              'response': <String, dynamic>{'result': message.content},
            },
          },
        ],
      };
    }
    if (message.role == 'assistant') {
      final List<Map<String, dynamic>> parts = <Map<String, dynamic>>[];
      if (message.content.trim().isNotEmpty) {
        parts.add(<String, dynamic>{'text': message.content});
      }
      for (final AiToolCall call in message.toolCalls) {
        parts.add(<String, dynamic>{
          'functionCall': <String, dynamic>{
            'name': call.name,
            'args': call.arguments,
          },
        });
      }
      if (parts.isEmpty) parts.add(<String, dynamic>{'text': ''});
      return <String, dynamic>{'role': 'model', 'parts': parts};
    }
    return <String, dynamic>{
      'role': 'user',
      'parts': <Map<String, dynamic>>[
        <String, dynamic>{'text': message.content},
      ],
    };
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
