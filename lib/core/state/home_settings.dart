import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 主页卡片：设置里可逐项开关。
enum HomeCard { overview, heatmap, rhythm, todos, habits, shortcuts }

/// 主页偏好：卡片开关与底部导航里额外显示的模块（最多 3 个）。
class HomeSettings extends ChangeNotifier {
  HomeSettings(this._settings) {
    _cards = _readCards();
    _bottomModules = _readBottomModules();
  }

  static const String _cardsKey = 'app.home.cards';
  static const String _bottomKey = 'app.home.bottomModules';
  static const int maxBottomModules = 3;

  final Box<dynamic> _settings;
  late Set<HomeCard> _cards;
  late List<String> _bottomModules;

  Set<HomeCard> get cards => Set<HomeCard>.unmodifiable(_cards);

  List<String> get bottomModules =>
      List<String>.unmodifiable(_bottomModules);

  bool isEnabled(HomeCard card) => _cards.contains(card);

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
    if (raw is! String || raw.isEmpty) return HomeCard.values.toSet();
    final Set<HomeCard> result = <HomeCard>{};
    for (final String name in raw.split(',')) {
      for (final HomeCard card in HomeCard.values) {
        if (card.name == name) result.add(card);
      }
    }
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
}