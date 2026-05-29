import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class LocaleTextLookup {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<String> tr(
    String languageCode,
    String key, {
    Map<String, String>? params,
  }) async {
    final normalized = languageCode == 'en' ? 'en' : 'zh_CN';
    final table = await _loadTable(normalized);
    final raw = _resolve(table, key);
    final fallback = key;
    var value = raw is String ? raw : fallback;

    if (params != null && params.isNotEmpty) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }

  static dynamic _resolve(Map<String, dynamic> table, String key) {
    dynamic current = table;
    for (final part in key.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  static Future<Map<String, dynamic>> _loadTable(String languageCode) async {
    if (_cache.containsKey(languageCode)) {
      return _cache[languageCode]!;
    }

    final path = 'assets/i18n/$languageCode.json';
    final content = await rootBundle.loadString(path);
    final decoded = jsonDecode(content);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    _cache[languageCode] = map;
    return map;
  }
}
