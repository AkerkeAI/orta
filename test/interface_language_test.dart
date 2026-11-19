import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orta/models/language.dart';
import 'package:orta/services/admissions_strings.dart';
import 'package:orta/services/interface_language.dart';
import 'package:orta/services/localization_service.dart';

void main() {
  test('profile locale is loaded from interface_language', () {
    expect(
      interfaceLocaleFromProfile({'interface_language': 'ru'}),
      const Locale('ru'),
    );
    expect(
      interfaceLocaleFromProfile({'interface_language': 'kk'}),
      const Locale('kk'),
    );
    expect(interfaceLocaleFromProfile({}), const Locale('en'));
    expect(
      interfaceLocaleFromProfile({'interface_language': 'unknown'}),
      const Locale('en'),
    );
  });

  for (final language in Language.values) {
    test(
      'selecting ${language.code} waits for persistence then applies it',
      () async {
        String? persisted;
        final selected = await persistInterfaceLanguage(
          language,
          persist: (code) async {
            persisted = code;
          },
        );
        expect(persisted, language.code);
        expect(selected, Locale(language.code));
        expect(
          interfaceLocaleFromProfile({'interface_language': persisted}),
          selected,
        );
      },
    );
  }

  test('failed save does not return a new locale', () async {
    var applied = const Locale('en');
    await expectLater(
      persistInterfaceLanguage(
        Language.russian,
        persist: (_) => Future<void>.error(StateError('save failed')),
      ).then((locale) => applied = locale),
      throwsStateError,
    );
    expect(applied, const Locale('en'));
  });

  test(
    'all visible admissions strings are translated for each interface locale',
    () {
      for (final locale in AppLocale.values) {
        final strings = AdmissionsStrings(locale);
        for (final key in AdmissionsStrings.translationKeys) {
          expect(
            strings.hasTranslation(key),
            isTrue,
            reason: '${locale.name}: $key',
          );
          expect(
            strings.text(key).trim(),
            isNotEmpty,
            reason: '${locale.name}: $key',
          );
        }
      }
      expect(AdmissionsStrings(AppLocale.russian).text('signIn'), 'Войти');
      expect(AdmissionsStrings(AppLocale.kazakh).text('signIn'), 'Кіру');
    },
  );
}
