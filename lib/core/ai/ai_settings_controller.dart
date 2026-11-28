import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'ai_key_store.dart';
import 'ai_models.dart';
import 'openai_provider.dart';

/// AI 配置、Key 状态与本地会话。单 profile，P0 够用；多 profile 后续加。
class AiSettingsController extends ChangeNotifier {
  AiSettingsController({
    required Box<dynamic> box,
    required AiKeyStore keyStore,
    required AiProvider provider,
  }) : _box = box,
       _keyStore = keyStore,
       _provider = provider;

  static const String _kBaseUrl = 'ai.baseUrl';
  static const String _kModel = 'ai.model';
  static const String _kReadOnly = 'ai.readOnly';
  static const String _kMessages = 'ai.messages';

  final Box<dynamic> _box;
  final AiKeyStore _keyStore;
  final AiProvider _provider;

  String _baseUrl = '';
  String _model = '';
  bool _readOnly = true;
  String? _apiKey;
  List<AiMessage> _messages = <AiMessage>[];

  String get baseUrl => _baseUrl;
  String get model => _model;
  bool get readOnly => _readOnly;
  bool get hasKey => (_apiKey ?? '').isNotEmpty;
  String? get apiKey => _apiKey;
  List<AiMessage> get messages => List<AiMessage>.unmodifiable(_messages);
  AiConfig get config => AiConfig(baseUrl: _baseUrl, model: _model);
  bool get isConfigured => config.isReady && hasKey;

  Future<void> load() async {
    _baseUrl = '${_box.get(_kBaseUrl) ?? ''}'.trim();
    _model = '${_box.get(_kModel) ?? ''}'.trim();
    _readOnly = (_box.get(_kReadOnly) as bool?) ?? true;
    _apiKey = await _keyStore.read();
    _messages = _decodeMessages(_box.get(_kMessages));
    notifyListeners();
  }

  Future<void> saveProfile({
    required String baseUrl,
    required String model,
  }) async {
    _baseUrl = baseUrl.trim();
    _model = model.trim();
    await _box.put(_kBaseUrl, _baseUrl);
    await _box.put(_kModel, _model);
    notifyListeners();
  }

  Future<void> saveKey(String key) async {
    final String value = key.trim();
    _apiKey = value.isEmpty ? null : value;
    if (value.isEmpty) {
      await _keyStore.delete();
    } else {
      await _keyStore.write(value);
    }
    notifyListeners();
  }

  Future<void> clearKey() => saveKey('');

  Future<void> setReadOnly(bool value) async {
    if (_readOnly == value) return;
    _readOnly = value;
    await _box.put(_kReadOnly, value);
    notifyListeners();
  }

  Future<void> appendMessages(List<AiMessage> extra) async {
    _messages = <AiMessage>[..._messages, ...extra];
    if (_messages.length > 200) {
      _messages = _messages.sublist(_messages.length - 200);
    }
    await _persistMessages();
    notifyListeners();
  }

  Future<void> clearConversation() async {
    _messages = <AiMessage>[];
    await _persistMessages();
    notifyListeners();
  }

  /// 连通性测试：发一条最小请求，返回模型名或错误文案。
  /// 拉取服务端模型列表；仅需 baseUrl 与 Key。
  Future<List<String>> fetchModels() async {
    if (_baseUrl.trim().isEmpty || !hasKey) {
      throw const AiNotConfiguredException();
    }
    return _provider.listModels(config: config, apiKey: _apiKey!);
  }

  Future<String> testConnection() async {
    if (!isConfigured) return '请先填写服务地址、模型与 API Key';
    try {
      final AiChatResult result = await _provider.complete(
        config: config,
        apiKey: _apiKey!,
        messages: <AiMessage>[
          AiMessage.system('你是一个连通性测试助手，只回答“连接正常”。'),
          AiMessage.user('请回复：连接正常'),
        ],
      );
      return '连接正常 · ${result.model}';
    } on AiException catch (error) {
      return '连接失败：${error.message}';
    }
  }

  Future<void> _persistMessages() async {
    final String raw = jsonEncode(
      _messages
          .where(
            (AiMessage message) =>
                message.role == 'user' || message.role == 'assistant',
          )
          .map((AiMessage message) => message.toJson())
          .toList(growable: false),
    );
    await _box.put(_kMessages, raw);
  }

  List<AiMessage> _decodeMessages(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return <AiMessage>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <AiMessage>[];
      return decoded
          .whereType<Map>()
          .map((Map item) => AiMessage.fromJson(item.cast<String, dynamic>()))
          .whereType<AiMessage>()
          .toList(growable: false);
    } catch (_) {
      return <AiMessage>[];
    }
  }
}
