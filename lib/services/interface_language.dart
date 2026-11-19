import 'package:flutter/material.dart';

import '../models/language.dart';
import 'localization_service.dart';

Locale interfaceLocaleFromProfile(Map<String, dynamic> profile) {
  final code = profile['interface_language'] as String? ?? 'en';
  return Locale(LanguageExtension.fromCode(code).code);
}

Locale interfaceLocaleAfterSelection(Language language) =>
    Locale(language.code);

/// Persists a profile preference before applying it to the running interface.
/// If persistence fails, the currently selected locale remains unchanged.
Future<Locale> persistInterfaceLanguage(
  Language language, {
  required Future<void> Function(String code) persist,
}) async {
  await persist(language.code);
  return interfaceLocaleAfterSelection(language);
}

AppLocale appLocaleFromProfile(Map<String, dynamic> profile) =>
    AppLocaleExtension.fromLanguage(
      LanguageExtension.fromCode(
        profile['interface_language'] as String? ?? 'en',
      ),
    );
