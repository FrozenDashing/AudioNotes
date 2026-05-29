import 'package:flutter/widgets.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

extension AppI18nX on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    return FlutterI18n.translate(this, key, translationParams: params);
  }
}
