import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'ai_key_store.dart';
import 'ai_models.dart';
import 'openai_provider.dart';

/// AI 配置、Key 状态与多会话。会话持久化在独立 Hive box。
class AiSettingsController extends ChangeNotifier {
  AiSettingsController({
    required Box<dynamic> box,
    required Box<String> conversations,
    required AiKeyStore keyStore,
    required AiProvider provider,
  }) : _box = box,
       _conversationsBox = conversations,
       _keyStore = keyStore,
       _provider = provider;

  static const String _kBaseUrl = 'ai.baseUrl';
  static const String _kModel = 'ai.model';
  static const String _kReadOnly = 'ai.readOnly';
  static const String _kCurrentConversation = 'ai.currentConversation';
  static const String _kLegacyMessages = 'ai.messages';

  final Box<dynamic> _box;
  final Box<String> _conversationsBox;
  final AiKeyStore _keyStore;
  final AiProvider _provider;

  String _baseUrl = '';
  String _model = '';
  bool _readOnly = true;
  String? _apiKey;
  List<AiConversation> _conversations = <AiConversation>[];
  String? _currentId;

  String get baseUrl => _baseUrl;
  String get model => _model;
  bool get readOnly => _readOnly;
  bool get hasKey => (_apiKey ?? '').isNotEmpty;
  String? get apiKey => _apiKey;
  AiConfig get config => AiConfig(baseUrl: _baseUrl, model: _model);
  bool get isConfigured => config.isReady && hasKey;

  List<AiConversation> get conversations =>
      List<AiConversation>.unmodifiable(_conversations);

  AiConversation? get currentConversation =>
      _currentId == null ? null : _find(_currentId!);

  String get currentTitle => currentConversation?.title ?? '新对话';

  List<AiMessage> get messages =>
      currentConversation?.messages ?? const <AiMessage>[];

  Future<void> load() async {
    _baseUrl = '${_box.get(_kBaseUrl) ?? ''}'.trim();
    _model = '${_box.get(_kModel) ?? ''}'.trim();
    _readOnly = (_box.get(_kReadOnly) as bool?) ?? true;
    _apiKey = await _keyStore.read();

    final List<AiConversation> loaded = <AiConversation>[];
    for (final Object? key in _conversationsBox.keys) {
      final Object? value = _conversationsBox.get(key);
      if (value is! String) continue;
      final AiConversation? conversation = _parseConversation(value);
      if (conversation != null) loaded.add(conversation);
    }
    _conversations = loaded
      ..sort(
        (AiConversation a, AiConversation b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );

    final String stored = '${_box.get(_kCurrentConversation) ?? ''}';
    _currentId = stored.isEmpty || _find(stored) == null
        ? (_conversations.isEmpty ? null : _conversations.first.id)
        : stored;

    await _migrateLegacyMessages();
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

  Future<AiConversation> createConversation({String title = '新对话'}) async {
    final AiConversation current =
        currentConversation ?? AiConversation.create(title: title);
    if (current.messages.isEmpty && current.title == title) {
      await _setCurrent(current.id);
      return current;
    }
    final AiConversation conversation = AiConversation.create(title: title);
    await _saveConversation(conversation);
    await _setCurrent(conversation.id);
    return conversation;
  }

  Future<void> selectConversation(String id) async {
    if (_find(id) == null) return;
    await _setCurrent(id);
  }

  Future<void> deleteConversation(String id) async {
    await _conversationsBox.delete(id);
    _conversations = _conversations
        .where((AiConversation item) => item.id != id)
        .toList(growable: false);
    if (_currentId == id) {
      _currentId = _conversations.isEmpty ? null : _conversations.first.id;
      await _persistCurrent();
    }
    notifyListeners();
  }

  Future<void> appendMessages(List<AiMessage> extra) async {
    AiConversation conversation =
        currentConversation ?? AiConversation.create();
    String title = conversation.title;
    if (title == '新对话') {
      final String first = extra
          .where((AiMessage item) => item.role == 'user')
          .map((AiMessage item) => item.content.trim())
          .firstWhere((String value) => value.isNotEmpty, orElse: () => '');
      if (first.isNotEmpty) {
        title = first.length > 18 ? '${first.substring(0, 18)}…' : first;
      }
    }
    conversation = conversation.copyWith(
      title: title,
      messages: <AiMessage>[...conversation.messages, ...extra],
      updatedAt: DateTime.now(),
    );
    await _saveConversation(conversation);
    await _setCurrent(conversation.id);
  }

  Future<void> clearConversation() async {
    final AiConversation? conversation = currentConversation;
    if (conversation == null) return;
    await _saveConversation(
      conversation.copyWith(
        title: '新对话',
        messages: const <AiMessage>[],
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
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

  Future<List<String>> fetchModels() async {
    if (_baseUrl.trim().isEmpty || !hasKey) {
      throw const AiNotConfiguredException();
    }
    return _provider.listModels(config: config, apiKey: _apiKey!);
  }

  AiConversation? _find(String id) {
    for (final AiConversation item in _conversations) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _saveConversation(AiConversation conversation) async {
    await _conversationsBox.put(
      conversation.id,
      jsonEncode(conversation.toJson()),
    );
    _conversations =
        <AiConversation>[
          conversation,
          ..._conversations.where(
            (AiConversation item) => item.id != conversation.id,
          ),
        ]..sort(
          (AiConversation a, AiConversation b) =>
              b.updatedAt.compareTo(a.updatedAt),
        );
  }

  Future<void> _setCurrent(String id) async {
    _currentId = id;
    await _persistCurrent();
    notifyListeners();
  }

  Future<void> _persistCurrent() async {
    if (_currentId == null) {
      await _box.delete(_kCurrentConversation);
    } else {
      await _box.put(_kCurrentConversation, _currentId);
    }
  }

  Future<void> _migrateLegacyMessages() async {
    final Object? legacy = _box.get(_kLegacyMessages);
    if (legacy is! String) return;
    if (_conversations.isEmpty) {
      final List<AiMessage> messages = _decodeMessages(legacy);
      if (messages.isNotEmpty) {
        final AiConversation conversation = AiConversation.create(title: '历史对话')
            .copyWith(messages: messages);
        await _saveConversation(conversation);
        await _setCurrent(conversation.id);
      }
    }
    await _box.delete(_kLegacyMessages);
  }

  AiConversation? _parseConversation(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AiConversation.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  List<AiMessage> _decodeMessages(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <AiMessage>[];
      return decoded
          .whereType<Map>()
          .map((Map item) => AiMessage.fromJson(item.cast<String, dynamic>()))
          .whereType<AiMessage>()
          .toList(growable: false);
    } catch (_) {
      return const <AiMessage>[];
    }
  }
}
