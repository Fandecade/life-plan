import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'app_module_descriptor.dart';

/// 插件注册中心：负责模块启用状态、导航入口与详情扩展槽位的统一管理。
///
/// 关闭某个非核心模块时：
/// 1. 导航入口立即消失；
/// 2. 详情抽屉不再渲染该模块的扩展槽位；
/// 3. 历史数据保留在本地，重新启用后自动恢复。
class ModuleRegistry extends ChangeNotifier {
  ModuleRegistry({
    required List<AppModuleDescriptor> modules,
    required Box<dynamic> settings,
  })  : _modules = List<AppModuleDescriptor>.unmodifiable(modules),
        _settings = settings {
    for (final AppModuleDescriptor module in _modules) {
      _enabled[module.id] = _readEnabled(module);
    }
  }

  static const String _settingPrefix = 'module.enabled.';

  final List<AppModuleDescriptor> _modules;
  final Box<dynamic> _settings;
  final Map<String, bool> _enabled = <String, bool>{};

  bool _readEnabled(AppModuleDescriptor module) {
    if (module.isCore) return true;
    final Object? stored = _settings.get('$_settingPrefix${module.id}');
    if (stored is bool) return stored;
    return module.defaultEnabled;
  }

  List<AppModuleDescriptor> get all => _modules;

  List<AppModuleDescriptor> get enabled =>
      _modules.where((AppModuleDescriptor module) => isEnabled(module.id)).toList();

  List<AppModuleDescriptor> get toggleable => _modules
      .where((AppModuleDescriptor module) => !module.isCore)
      .toList(growable: false);

  List<AppModuleDescriptor> get detailSlotModules => enabled
      .where((AppModuleDescriptor module) => module.detailSlotBuilder != null)
      .toList(growable: false);

  bool isEnabled(String id) => _enabled[id] ?? false;

  AppModuleDescriptor? byId(String id) {
    for (final AppModuleDescriptor module in _modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  /// 首个可用模块作为初始路由；理论上 settings 为核心模块，恒可用。
  String get initialRoute =>
      enabled.isEmpty ? '/settings' : enabled.first.routeName;

  Future<void> setEnabled(String id, bool enabled) async {
    final AppModuleDescriptor? module = byId(id);
    if (module == null || module.isCore || _enabled[id] == enabled) return;
    _enabled[id] = enabled;
    await _settings.put('$_settingPrefix$id', enabled);
    notifyListeners();
  }
}