enum Language {
  english,
  kazakh,
  russian,
}

extension LanguageExtension on Language {
  String get displayName {
    switch (this) {
      case Language.english:
        return 'English';
      case Language.kazakh:
        return 'Қазақша';
      case Language.russian:
        return 'Русский';
    }
  }

  String get code {
    switch (this) {
      case Language.english:
        return 'en';
      case Language.kazakh:
        return 'kk';
      case Language.russian:
        return 'ru';
    }
  }

  static Language fromCode(String code) {
    switch (code) {
      case 'en':
        return Language.english;
      case 'kk':
        return Language.kazakh;
      case 'ru':
        return Language.russian;
      default:
        return Language.english;
    }
  }
}
