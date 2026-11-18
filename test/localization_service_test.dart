import 'package:flutter_test/flutter_test.dart';

import 'package:orta/models/language_definition.dart';
import 'package:orta/services/localization_service.dart';

void main() {
  test(
    'every shared string and target language exists in all interface locales',
    () {
      for (final locale in AppLocale.values) {
        final strings = AppLocalizations(locale);
        for (final key in AppLocalizations.translationKeys) {
          expect(
            strings.hasTranslation(key),
            isTrue,
            reason: '${locale.name}: $key',
          );
          expect(
            strings.get(key).trim(),
            isNotEmpty,
            reason: '${locale.name}: $key',
          );
        }
        for (final language in LanguageDefinition.all) {
          expect(strings.hasTranslation('language_${language.code}'), isTrue);
          expect(strings.languageName(language.code), isNot(language.code));
        }
      }
      expect(
        AppLocalizations(AppLocale.russian).languageName('it'),
        'Итальянский',
      );
      expect(
        AppLocalizations(AppLocale.kazakh).languageName('de'),
        'Неміс тілі',
      );
    },
  );
}
