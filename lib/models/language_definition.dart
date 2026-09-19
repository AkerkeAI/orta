class LanguageDefinition {
  final String code;
  final String englishName;
  final String nativeName;

  const LanguageDefinition({
    required this.code,
    required this.englishName,
    required this.nativeName,
  });

  static const all = <LanguageDefinition>[
    LanguageDefinition(
      code: 'en',
      englishName: 'English',
      nativeName: 'English',
    ),
    LanguageDefinition(
      code: 'kk',
      englishName: 'Kazakh',
      nativeName: 'Қазақша',
    ),
    LanguageDefinition(
      code: 'ru',
      englishName: 'Russian',
      nativeName: 'Русский',
    ),
    LanguageDefinition(
      code: 'it',
      englishName: 'Italian',
      nativeName: 'Italiano',
    ),
    LanguageDefinition(
      code: 'de',
      englishName: 'German',
      nativeName: 'Deutsch',
    ),
    LanguageDefinition(
      code: 'fr',
      englishName: 'French',
      nativeName: 'Français',
    ),
    LanguageDefinition(
      code: 'es',
      englishName: 'Spanish',
      nativeName: 'Español',
    ),
    LanguageDefinition(
      code: 'pt',
      englishName: 'Portuguese',
      nativeName: 'Português',
    ),
    LanguageDefinition(
      code: 'zh',
      englishName: 'Chinese (Mandarin)',
      nativeName: '中文',
    ),
    LanguageDefinition(code: 'ja', englishName: 'Japanese', nativeName: '日本語'),
    LanguageDefinition(code: 'ko', englishName: 'Korean', nativeName: '한국어'),
    LanguageDefinition(
      code: 'ar',
      englishName: 'Arabic',
      nativeName: 'العربية',
    ),
    LanguageDefinition(
      code: 'tr',
      englishName: 'Turkish',
      nativeName: 'Türkçe',
    ),
    LanguageDefinition(code: 'pl', englishName: 'Polish', nativeName: 'Polski'),
    LanguageDefinition(
      code: 'nl',
      englishName: 'Dutch',
      nativeName: 'Nederlands',
    ),
    LanguageDefinition(
      code: 'sv',
      englishName: 'Swedish',
      nativeName: 'Svenska',
    ),
    LanguageDefinition(
      code: 'no',
      englishName: 'Norwegian',
      nativeName: 'Norsk',
    ),
    LanguageDefinition(code: 'fi', englishName: 'Finnish', nativeName: 'Suomi'),
    LanguageDefinition(code: 'da', englishName: 'Danish', nativeName: 'Dansk'),
    LanguageDefinition(code: 'cs', englishName: 'Czech', nativeName: 'Čeština'),
    LanguageDefinition(
      code: 'el',
      englishName: 'Greek',
      nativeName: 'Ελληνικά',
    ),
    LanguageDefinition(code: 'hi', englishName: 'Hindi', nativeName: 'हिन्दी'),
    LanguageDefinition(
      code: 'id',
      englishName: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
    ),
    LanguageDefinition(
      code: 'vi',
      englishName: 'Vietnamese',
      nativeName: 'Tiếng Việt',
    ),
    LanguageDefinition(code: 'th', englishName: 'Thai', nativeName: 'ไทย'),
    LanguageDefinition(
      code: 'uk',
      englishName: 'Ukrainian',
      nativeName: 'Українська',
    ),
  ];

  static LanguageDefinition byCode(String code) =>
      all.firstWhere((item) => item.code == code, orElse: () => all.first);
}
