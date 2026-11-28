import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API Key 存系统安全存储（Android Keystore / macOS Keychain）。
///
/// Web 端受浏览器限制，仅作降级保存，并在设置页提示风险。
class AiKeyStore {
  AiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'ai.apiKey';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String value) async {
    try {
      await _storage.write(key: _key, value: value);
    } catch (_) {
      // 无安全存储的环境（部分 Web / 测试）静默失败，由界面提示未保存。
    }
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // ignore
    }
  }
}
