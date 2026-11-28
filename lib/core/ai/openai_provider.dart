import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_models.dart';

/// 统一的对话提供方接口。
abstract class AiProvider {
  Future<AiChatResult> complete({
    required AiConfig config,
    required String apiKey,
    required List<AiMessage> messages,
    List<AiToolSpec> tools = const <AiToolSpec>[],
  });

  /// 拉取服务端可用模型（OpenAI 兼容 `GET /models`）。
  Future<List<String>> listModels({
    required AiConfig config,
    required String apiKey,
  });
}

/// OpenAI 兼容协议：覆盖 OpenAI / DeepSeek / Kimi / 通义 / GLM / 自建代理。
class OpenAiCompatibleProvider implements AiProvider {
  OpenAiCompatibleProvider({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 60);

  final http.Client _client;
  final Duration _timeout;

  /// baseUrl 可填 `https://api.deepseek.com`、`.../v1` 或完整 `.../chat/completions`。
  static String resolveEndpoint(String baseUrl) {
    String url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/chat/completions')) return url;
    if (url.endsWith('/v1')) return '$url/chat/completions';
    return '$url/v1/chat/completions';
  }

  /// 模型列表端点：兼容 baseUrl、/v1 与完整 chat/completions 路径。
  static String resolveModelsEndpoint(String baseUrl) {
    String url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/chat/completions')) {
      url = url.substring(0, url.length - '/chat/completions'.length);
    }
    if (url.endsWith('/models')) return url;
    if (url.endsWith('/v1')) return '$url/models';
    return '$url/v1/models';
  }

  @override
  Future<List<String>> listModels({
    required AiConfig config,
    required String apiKey,
  }) async {
    final Uri uri = Uri.parse(resolveModelsEndpoint(config.baseUrl));
    late http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException('获取模型超时，请检查网络或服务地址');
    } catch (error) {
      throw AiException('获取模型失败：$error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        _errorMessage(response.body) ?? 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> data = decoded is Map
        ? ((decoded['data'] as List<dynamic>?) ?? const <dynamic>[])
        : (decoded is List ? decoded : const <dynamic>[]);
    final List<String> models = <String>{
      for (final Object? item in data)
        if (item is Map && '${item['id'] ?? ''}'.trim().isNotEmpty)
          '${item['id']}'.trim(),
    }.toList()..sort();
    if (models.isEmpty) {
      throw const AiException('服务端没有返回可用模型');
    }
    return models;
  }

  @override
  Future<AiChatResult> complete({
    required AiConfig config,
    required String apiKey,
    required List<AiMessage> messages,
    List<AiToolSpec> tools = const <AiToolSpec>[],
  }) async {
    final Uri uri = Uri.parse(resolveEndpoint(config.baseUrl));
    final Map<String, dynamic> body = <String, dynamic>{
      'model': config.model,
      'messages': messages
          .map((AiMessage message) => message.toOpenAi())
          .toList(growable: false),
      'temperature': 0.4,
      'stream': false,
    };
    if (tools.isNotEmpty) {
      body['tools'] = tools
          .map((AiToolSpec spec) => spec.toOpenAi())
          .toList(growable: false);
      body['tool_choice'] = 'auto';
    }

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException('请求超时，请检查网络或服务地址');
    } catch (error) {
      throw AiException('请求失败：$error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        _errorMessage(response.body) ?? 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> json;
    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      json = (decoded as Map).cast<String, dynamic>();
    } catch (_) {
      throw const AiException('返回内容不是合法 JSON');
    }

    final List<dynamic> choices =
        (json['choices'] as List<dynamic>?) ?? const <dynamic>[];
    if (choices.isEmpty) {
      throw const AiException('模型没有返回任何结果');
    }
    final Map<String, dynamic> message =
        ((choices.first as Map)['message'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final String content = '${message['content'] ?? ''}'.trim();
    final List<dynamic> rawCalls =
        (message['tool_calls'] as List<dynamic>?) ?? const <dynamic>[];
    final List<AiToolCall> calls = rawCalls
        .whereType<Map>()
        .map((Map item) => AiToolCall.fromOpenAi(item.cast<String, dynamic>()))
        .toList(growable: false);

    return AiChatResult(
      content: content,
      toolCalls: calls,
      model: '${json['model'] ?? config.model}',
    );
  }

  String? _errorMessage(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map) {
        final Object? error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return '${error['message']}';
        }
        if (decoded['message'] != null) return '${decoded['message']}';
      }
    } catch (_) {
      // ignore
    }
    if (body.trim().isEmpty || body.length > 200) return null;
    return body.trim();
  }
}
