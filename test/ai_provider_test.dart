import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_planner/core/ai/ai_models.dart';
import 'package:life_planner/core/ai/openai_provider.dart';

void main() {
  test('resolveEndpoint 兼容 baseUrl / v1 / 完整路径', () {
    expect(
      OpenAiCompatibleProvider.resolveEndpoint('https://api.deepseek.com'),
      'https://api.deepseek.com/v1/chat/completions',
    );
    expect(
      OpenAiCompatibleProvider.resolveEndpoint('https://api.openai.com/v1'),
      'https://api.openai.com/v1/chat/completions',
    );
    expect(
      OpenAiCompatibleProvider.resolveEndpoint(
        'https://proxy.example.com/chat/completions',
      ),
      'https://proxy.example.com/chat/completions',
    );
    expect(
      OpenAiCompatibleProvider.resolveEndpoint('https://x.example.com/'),
      'https://x.example.com/v1/chat/completions',
    );
  });

  test('解析内容、模型名与 tool_calls', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'model': 'deepseek-chat',
          'choices': <dynamic>[
            <String, dynamic>{
              'message': <String, dynamic>{
                'content': null,
                'tool_calls': <dynamic>[
                  <String, dynamic>{
                    'id': 'call_1',
                    'type': 'function',
                    'function': <String, dynamic>{
                      'name': 'list_tasks',
                      'arguments': '{"limit":5}',
                    },
                  },
                ],
              },
            },
          ],
        }),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    final OpenAiCompatibleProvider provider = OpenAiCompatibleProvider(
      client: client,
    );

    final AiChatResult result = await provider.complete(
      config: const AiConfig(
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
      ),
      apiKey: 'sk-test',
      messages: <AiMessage>[AiMessage.user('hi')],
      tools: const <AiToolSpec>[
        AiToolSpec(
          name: 'list_tasks',
          description: 'list',
          parameters: <String, dynamic>{'type': 'object'},
        ),
      ],
    );

    expect(
      captured.headers['Authorization'] ?? captured.headers['authorization'],
      'Bearer sk-test',
    );
    expect(captured.body, contains('"tools"'));
    expect(result.model, 'deepseek-chat');
    expect(result.toolCalls.single.name, 'list_tasks');
    expect(result.toolCalls.single.arguments['limit'], 5);
  });

  test('HTTP 错误转成 AiException', () async {
    final http.Client client = MockClient(
      (http.Request request) async => http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{'message': 'invalid api key'},
        }),
        401,
      ),
    );
    final OpenAiCompatibleProvider provider = OpenAiCompatibleProvider(
      client: client,
    );

    await expectLater(
      provider.complete(
        config: const AiConfig(baseUrl: 'https://x', model: 'm'),
        apiKey: 'k',
        messages: <AiMessage>[AiMessage.user('hi')],
      ),
      throwsA(
        isA<AiException>().having(
          (AiException error) => error.message,
          'message',
          contains('invalid api key'),
        ),
      ),
    );
  });

  test('resolveModelsEndpoint 兼容 baseUrl / v1 / 完整路径', () {
    expect(
      OpenAiCompatibleProvider.resolveModelsEndpoint(
        'https://api.deepseek.com',
      ),
      'https://api.deepseek.com/v1/models',
    );
    expect(
      OpenAiCompatibleProvider.resolveModelsEndpoint(
        'https://api.openai.com/v1',
      ),
      'https://api.openai.com/v1/models',
    );
    expect(
      OpenAiCompatibleProvider.resolveModelsEndpoint(
        'https://proxy.example.com/chat/completions',
      ),
      'https://proxy.example.com/v1/models',
    );
  });

  test('拉取模型列表并排序', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <dynamic>[
            <String, dynamic>{'id': 'b-model'},
            <String, dynamic>{'id': 'a-model'},
          ],
        }),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    final OpenAiCompatibleProvider provider = OpenAiCompatibleProvider(
      client: client,
    );
    final List<String> models = await provider.listModels(
      config: const AiConfig(baseUrl: 'https://api.deepseek.com', model: ''),
      apiKey: 'sk-test',
    );
    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'https://api.deepseek.com/v1/models');
    expect(models, <String>['a-model', 'b-model']);
  });
}
