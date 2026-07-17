import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesDatasource {
  RecentSearchesDatasource(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'recent_searches';
  static const _maxItems = 8;

  List<String> getRecent() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String term) async {
    final cleaned = term.trim();
    if (cleaned.isEmpty) return;

    final current = getRecent()
        .where((e) => e.toLowerCase() != cleaned.toLowerCase())
        .toList();
    final next = [cleaned, ...current].take(_maxItems).toList();
    await _prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
