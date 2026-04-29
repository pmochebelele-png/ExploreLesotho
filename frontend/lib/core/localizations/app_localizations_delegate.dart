import 'package:flutter/material.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'st'].contains(locale.languageCode);
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return Future.value(
      const DefaultMaterialLocalizations(),
    );
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
