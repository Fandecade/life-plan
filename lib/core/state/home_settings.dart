import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 主页卡片：前六项默认开启，后三项为可选图表。
enum HomeCard {
  overview,
  heatmap,
  rhythm,
  todos,
  habits,
  shortcuts,
  trend,
  weekly,
  capability,
}

extension HomeCardMeta on HomeCard {
  String get label {
    switch (this) {
      case HomeCard.overview:
        return '今日概览';
      case HomeCard.heatmap:
        return '热力图';
      case HomeCard.rhythm:
        return '节奏指标';
      case HomeCard.todos:
        return '今日待办';
      case HomeCard.habits:
        return '今日习惯';
      case HomeCard.shortcuts:
        return '快捷入口';
      case HomeCard.trend:
        return '近 14 天趋势';
      case HomeCard.weekly:
        return '近四周对比';
      case HomeCard.capability:
        return '能力投入分布';
    }
  }

  String get description {
    switch (this) {
      case HomeCard.overview:
        return '完成任务、打卡、学习与完成时间块';
      case HomeCard.heatmap:
        return '最近 12 周的活跃度';
      case HomeCard.rhythm:
        return '连续记录、本周完成率与学习时长';
      case HomeCard.todos:
        return '当天安排的待办事项';
      case HomeCard.habits:
        return '今日打卡情况';
      case HomeCard.shortcuts:
        return '可自定义的常用模块入口';
      case HomeCard.trend:
        return '任务完成与学习投入的逐日走势';
      case HomeCard.weekly:
        return '最近四周的任务与学习对比';
      case HomeCard.capability:
        return '近 30 天完成任务的能力占比';
    }
  }

  bool get defaultEnabled => index < 6;

  bool get isChart => index >= 6;
}

/// 卡片尺寸：影响内边距与桌面端是否跨两列。
enum HomeCardSize { compact, regular, large }

extension HomeCardSizeMeta on HomeCardSize {
  String get label {
    switch (this) {
      case HomeCardSize.compact:
        return '小';
      case HomeCardSize.regular:
        return '标准';
      case HomeCardSize.large:
        return '大';
    }
  }

  double get padding {
    switch (this) {
      case HomeCardSize.compact:
        return 12;
      case HomeCardSize.regular:
        return 16;
      case HomeCardSize.large:
        return 20;
    }
  }
}

/// 主页偏好：卡片顺序、尺寸、开关、快捷入口与底部导航模块。
class HomeSettings extends ChangeNotifier {
  HomeSettings(this._settings) {
    _cards = _readCards();
    _order = _readOrder();
    _sizes = _readSizes();
    _shortcutIds = _readShortcutIds();
    _bottomModules = _readBottomModules();
  }

  static const String _cardsKey = 'app.home.cards';
  static const String _orderKey = 'app.home.order';
  static const String _sizesKey = 'app.home.sizes';
  static const String _shortcutsKey = 'app.home.shortcuts';
  static const String _bottomKey = 'app.home.bottomModules';
  static const int maxBottomModules = 3;
  static const int maxShortcuts = 6;

  static const List<String> defaultShortcuts = <String>[
    'time_box',
    'output_learning',
    'projects',
    'review',
  ];

  final Box<dynamic> _settings;
  late Set<HomeCard> _cards;
  late List<HomeCard> _order;
  late Map<HomeCard, HomeCardSize> _sizes;
  late List<String> _shortcutIds;
  late List<String> _bottomModules;

  Set<HomeCard> get cards => Set<HomeCard>.unmodifiable(_cards);

  List<HomeCard> get order => List<HomeCard>.unmodifiable(_order);

  List<String> get shortcutIds => List<String>.unmodifiable(_shortcutIds);

  List<String> get bottomModules => List<String>.unmodifiable(_bottomModules);

  bool isEnabled(HomeCard card) => _cards.contains(card);

  HomeCardSize sizeOf(HomeCard card) =>
      _sizes[card] ?? _defaultSize(card);

  Future<void> setCardEnabled(HomeCard card, bool enabled) async {
    if (enabled == _cards.contains(card)) return;
    if (enabled) {
      _cards.add(card);
    } else {
      _cards.remove(card);
    }
    notifyListeners();
    await _settings.put(
      _cardsKey,
      _cards.map((HomeCard card) => card.name).join(','),
    );
  }

  Future<void> setOrder(List<HomeCard> cards) async {
    final List<HomeCard> normalized = <HomeCard>[];
    for (final HomeCard card in cards) {
      if (!normalized.contains(card)) normalized.add(card);
    }
    for (final HomeCard card in HomeCard.values) {
      if (!normalized.contains(card)) normalized.add(card);
    }
    if (listEquals(normalized, _order)) return;
    _order = normalized;
    notifyListeners();
    await _settings.put(
      _orderKey,
      normalized.map((HomeCard card) => card.name).join(','),
    );
  }

  Future<void> setSize(HomeCard card, HomeCardSize size) async {
    if (sizeOf(card) == size) return;
    _sizes[card] = size;
    notifyListeners();
    await _settings.put(
      _sizesKey,
      _sizes.entries
          .map((MapEntry<HomeCard, HomeCardSize> entry) =>
              '${entry.key.name}:${entry.value.name}')
          .join(','),
    );
  }

  Future<void> setShortcutIds(List<String> ids) async {
    final List<String> normalized = <String>[];
    for (final String id in ids) {
      if (id.isEmpty || normalized.contains(id)) continue;
      normalized.add(id);
      if (normalized.length >= maxShortcuts) break;
    }
    if (listEquals(normalized, _shortcutIds)) return;
    _shortcutIds = normalized;
    notifyListeners();
    await _settings.put(_shortcutsKey, normalized.join(','));
  }

  Future<void> setBottomModules(List<String> ids) async {
    final List<String> normalized = <String>[];
    for (final String id in ids) {
      if (id.isEmpty || normalized.contains(id)) continue;
      normalized.add(id);
      if (normalized.length >= maxBottomModules) break;
    }
    if (listEquals(normalized, _bottomModules)) return;
    _bottomModules = normalized;
    notifyListeners();
    await _settings.put(_bottomKey, normalized.join(','));
  }

  Set<HomeCard> _readCards() {
    final Object? raw = _settings.get(_cardsKey);
    if (raw is! String || raw.isEmpty) {
      return HomeCard.values
          .where((HomeCard card) => card.defaultEnabled)
          .toSet();
    }
    final Set<HomeCard> result = <HomeCard>{};
    for (final String name in raw.split(',')) {
      for (final HomeCard card in HomeCard.values) {
        if (card.name == name) result.add(card);
      }
    }
    return result;
  }

  List<HomeCard> _readOrder() {
    final Object? raw = _settings.get(_orderKey);
    final List<HomeCard> result = <HomeCard>[];
    if (raw is String && raw.isNotEmpty) {
      for (final String name in raw.split(',')) {
        for (final HomeCard card in HomeCard.values) {
          if (card.name == name && !result.contains(card)) result.add(card);
        }
      }
    }
    for (final HomeCard card in HomeCard.values) {
      if (!result.contains(card)) result.add(card);
    }
    return result;
  }

  Map<HomeCard, HomeCardSize> _readSizes() {
    final Map<HomeCard, HomeCardSize> result = <HomeCard, HomeCardSize>{};
    final Object? raw = _settings.get(_sizesKey);
    if (raw is String && raw.isNotEmpty) {
      for (final String entry in raw.split(',')) {
        final List<String> parts = entry.split(':');
        if (parts.length != 2) continue;
        for (final HomeCard card in HomeCard.values) {
          if (card.name != parts[0]) continue;
          for (final HomeCardSize size in HomeCardSize.values) {
            if (size.name == parts[1]) result[card] = size;
          }
        }
      }
    }
    return result;
  }

  List<String> _readShortcutIds() {
    final Object? raw = _settings.get(_shortcutsKey);
    if (raw is! String) return List<String>.from(defaultShortcuts);
    final List<String> result = raw
        .split(',')
        .where((String id) => id.isNotEmpty)
        .take(maxShortcuts)
        .toList(growable: false);
    return result;
  }

  List<String> _readBottomModules() {
    final Object? raw = _settings.get(_bottomKey);
    if (raw is! String) return <String>['time_box'];
    final List<String> result = raw
        .split(',')
        .where((String id) => id.isNotEmpty)
        .take(maxBottomModules)
        .toList(growable: false);
    return result.isEmpty ? <String>['time_box'] : result;
  }

  HomeCardSize _defaultSize(HomeCard card) {
    if (card == HomeCard.overview || card == HomeCard.heatmap) {
      return HomeCardSize.large;
    }
    return HomeCardSize.regular;
  }
}