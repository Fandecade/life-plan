import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_planner/core/ai/ai_models.dart';
import 'package:life_planner/core/ai/anthropic_provider.dart';
import 'package:life_planner/core/ai/gemini_provider.dart';

void main() {
  test('Anthropic 请求与 tool_use 解析', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'model': 'claude-sonnet',
          'content': <dynamic>[
            <String, dynamic>{'type': 'text', 'text': '你好'},
            <String, dynamic>{
              'type': 'tool_use',
              'id': 'tool_1',
              'name': 'list_tasks',
              'input': <String, dynamic>{'limit': 3},
            },
          ],
        }),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    final AnthropicProvider provider = AnthropicProvider(client: client);

    final AiChatResult result = await provider.complete(
      config: const AiConfig(
        baseUrl: 'https://api.anthropic.com',
        model: 'claude-sonnet',
        provider: AiProviderKind.anthropic,
      ),
      apiKey: 'sk-ant',
      messages: <AiMessage>[AiMessage.system('system'), AiMessage.user('hi')],
      tools: const <AiToolSpec>[
        AiToolSpec(
          name: 'list_tasks',
          description: 'list',
          parameters: <String, dynamic>{'type': 'object'},
        ),
      ],
    );

    expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(captured.headers['x-api-key'], 'sk-ant');
    expect(captured.headers['anthropic-version'], '2023-06-01');
    expect(captured.body, contains('"input_schema"'));
    expect(result.content, '你好');
    expect(result.toolCalls.single.name, 'list_tasks');
    expect(result.toolCalls.single.arguments['limit'], 3);
  });

  test('Anthropic 模型列表', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <dynamic>[
            <String, dynamic>{'id': 'claude-b'},
            <String, dynamic>{'id': 'claude-a'},
          ],
        }),
        200,
      );
    });
    final AnthropicProvider provider = AnthropicProvider(client: client);
    final List<String> models = await provider.listModels(
      config: const AiConfig(
        baseUrl: 'https://api.anthropic.com',
        model: '',
        provider: AiProviderKind.anthropic,
      ),
      apiKey: 'sk-ant',
    );
    expect(captured.url.toString(), 'https://api.anthropic.com/v1/models');
    expect(models, <String>['claude-a', 'claude-b']);
  });

  test('Gemini 请求、query key 与 functionCall 解析', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'modelVersion': 'gemini-2.0',
          'candidates': <dynamic>[
            <String, dynamic>{
              'content': <String, dynamic>{
                'parts': <dynamic>[
                  <String, dynamic>{'text': '好'},
                  <String, dynamic>{
                    'functionCall': <String, dynamic>{
                      'name': 'list_tasks',
                      'args': <String, dynamic>{'limit': 2},
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
    final GeminiProvider provider = GeminiProvider(client: client);

    final AiChatResult result = await provider.complete(
      config: const AiConfig(
        baseUrl: 'https://generativelanguage.googleapis.com',
        model: 'gemini-2.0',
        provider: AiProviderKind.gemini,
      ),
      apiKey: 'key-123',
      messages: <AiMessage>[AiMessage.user('hi')],
      tools: const <AiToolSpec>[
        AiToolSpec(
          name: 'list_tasks',
          description: 'list',
          parameters: <String, dynamic>{'type': 'object'},
        ),
      ],
    );

    expect(captured.url.queryParameters['key'], 'key-123');
    expect(
      captured.url.path,
      contains('/v1beta/models/gemini-2.0:generateContent'),
    );
    expect(captured.body, contains('functionDeclarations'));
    expect(result.content, '好');
    expect(result.toolCalls.single.name, 'list_tasks');
    expect(result.toolCalls.single.arguments['limit'], 2);
  });

  test('Gemini 模型列表去掉 models/ 前缀', () async {
    final http.Client client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'models': <dynamic>[
            <String, dynamic>{'name': 'models/gemini-b'},
            <String, dynamic>{'name': 'models/gemini-a'},
          ],
        }),
        200,
      );
    });
    final GeminiProvider provider = GeminiProvider(client: client);
    final List<String> models = await provider.listModels(
      config: const AiConfig(
        baseUrl: 'https://generativelanguage.googleapis.com',
        model: '',
        provider: AiProviderKind.gemini,
      ),
      apiKey: 'key-123',
    );
    expect(models, <String>['gemini-a', 'gemini-b']);
  });
}
