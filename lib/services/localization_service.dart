import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/language.dart';

enum AppLocale {
  english,
  russian,
  kazakh,
}

extension AppLocaleExtension on AppLocale {
  String get languageCode {
    switch (this) {
      case AppLocale.english:
        return 'en';
      case AppLocale.russian:
        return 'ru';
      case AppLocale.kazakh:
        return 'kk';
    }
  }

  static AppLocale fromLanguageCode(String code) {
    switch (code) {
      case 'en':
        return AppLocale.english;
      case 'ru':
        return AppLocale.russian;
      case 'kk':
        return AppLocale.kazakh;
      default:
        return AppLocale.english;
    }
  }

  static AppLocale fromLanguage(Language language) {
    switch (language) {
      case Language.english:
        return AppLocale.english;
      case Language.russian:
        return AppLocale.russian;
      case Language.kazakh:
        return AppLocale.kazakh;
    }
  }
}

class AppLocalizations {
  final AppLocale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(
      AppLocaleExtension.fromLanguageCode(Localizations.localeOf(context).languageCode),
    );
  }

  static const Map<AppLocale, Map<String, String>> _translations = {
    AppLocale.english: {
      // App
      'app_name': 'ORTA',
      'about_orta_title': 'About ORTA',
      'about_orta_description': 'ORTA helps you learn a language by bringing small language interactions into your everyday life.',
      'version': 'Version',
      
      // Navigation
      'nav_home': 'Home',
      'nav_ai': 'AI',
      'nav_library': 'Library',
      'nav_settings': 'Settings',
      
      // Onboarding
      'onboarding_welcome_title': 'ORTA',
      'onboarding_welcome_subtitle': 'Learn a language by living with it.',
      'onboarding_continue': 'Continue',
      'onboarding_back': 'Back',
      'onboarding_native_language': 'What is your native language?',
      'onboarding_native_language_subtitle': 'Select the language you speak fluently.',
      'onboarding_learning_language': 'What language do you want to learn?',
      'onboarding_learning_language_subtitle': 'Select the language you want to practice.',
      'onboarding_name': 'What should ORTA call you?',
      'onboarding_name_subtitle': 'Enter your name or nickname.',
      'onboarding_name_hint': 'Your name',
      'onboarding_level': 'What is your current level?',
      'onboarding_level_subtitle': 'Select your approximate level in the language you want to learn.',
      'onboarding_wake_time': 'When are you usually awake?',
      'onboarding_wake_time_subtitle': 'ORTA will use this to send language interactions during appropriate hours.',
      'onboarding_wake_up': 'Wake-up time',
      'onboarding_sleep': 'Sleep time',
      'onboarding_summary': 'You\'re all set!',
      'onboarding_summary_subtitle': 'Here\'s a summary of your profile:',
      'onboarding_start': 'Start ORTA',
      'onboarding_name_error': 'Please enter your name',
      'onboarding_ai_assessment': 'AI Level Assessment',
      'onboarding_ai_assessment_placeholder': 'AI level assessment will be available soon.',
      'onboarding_ok': 'OK',
      
      // Summary
      'summary_name': 'Name',
      'summary_native_language': 'Native language',
      'summary_learning_language': 'Learning language',
      'summary_level': 'Level',
      'summary_not_selected': 'Not selected',
      
      // Home
      'home_good_morning': 'Good morning',
      'home_good_afternoon': 'Good afternoon',
      'home_good_evening': 'Good evening',
      'home_today_task': 'Today\'s Task',
      'home_do_with_ai': 'Do it with AI',
      'home_progress': 'Progress',
      'home_to_next_level': 'to next level',
      'home_activity': 'Activity',
      'home_day_streak': 'Day streak',
      'home_words': 'Words',
      'home_conversations': 'Conversations',
      'home_weekly_conversation': 'Weekly conversation',
      'home_weekly_conversation_progress': '/ 1',
      'home_orta_today': 'ORTA today',
      'home_morning_checkin': 'Morning check-in',
      'home_how_did_you_sleep': 'How did you sleep?',
      'home_mini_interaction': 'Mini interaction',
      'home_describe_around': 'Describe what is around you.',
      'home_quick_moment': 'Quick English moment',
      'home_tell_orta': 'Tell ORTA what you are doing.',
      'home_this_week': 'This week',
      'home_conversation_with_orta': 'Conversation with ORTA',
      'home_completed': 'completed',
      
      // AI Chat
      'ai_chat_title': 'AI Chat',
      'ai_message_hint': 'Type a message...',
      'ai_task_greeting': 'Great. Look around you and describe three things you can see. Don\'t worry about mistakes — I\'ll help you.',
      
      // Library
      'library_coming_soon': 'Library is coming soon',
      'library_stories': 'Stories adapted to your level',
      'library_articles': 'Articles and reading content',
      'library_exercises': 'Interactive reading exercises',
      
      // Settings
      'settings_profile': 'Profile',
      'settings_name': 'Name',
      'settings_native_language': 'Native language',
      'settings_learning_language': 'Learning language',
      'settings_current_level': 'Current level',
      'settings_learning': 'Learning',
      'settings_wake_up_time': 'Wake-up time',
      'settings_sleep_time': 'Sleep time',
      'settings_notifications': 'Notifications',
      'settings_enable_interactions': 'Enable ORTA interactions',
      'settings_app': 'App',
      'settings_about_orta': 'About ORTA',
      'settings_reset_onboarding': 'Reset onboarding',
      'settings_reset_subtitle': 'Clear all data and start over',
      'settings_reset_confirmation': 'Reset Onboarding',
      'settings_reset_message': 'This will clear all your data and return you to the onboarding flow. Are you sure?',
      'settings_cancel': 'Cancel',
      'settings_reset': 'Reset',
      'settings_close': 'Close',
      
      // Responses
      'response_well': 'Well',
      'response_not_great': 'Not great',
      
      // Levels
      'level_a0': 'A0 — Beginner',
      'level_a1': 'A1',
      'level_a2': 'A2',
      'level_b1': 'B1',
      'level_b2': 'B2',
      'level_c1': 'C1',
      'level_c2': 'C2',
      'level_unknown': 'I don\'t know my level',
      'level_mastery': 'Mastery achieved',
      
      // Languages
      'lang_english': 'English',
      'lang_kazakh': 'Қазақша',
      'lang_russian': 'Русский',
    },
    AppLocale.russian: {
      // App
      'app_name': 'ORTA',
      'about_orta_title': 'О ORTA',
      'about_orta_description': 'ORTA помогает вам изучать язык, внося небольшие языковые взаимодействия в вашу повседневную жизнь.',
      'version': 'Версия',
      
      // Navigation
      'nav_home': 'Главная',
      'nav_ai': 'ИИ',
      'nav_library': 'Библиотека',
      'nav_settings': 'Настройки',
      
      // Onboarding
      'onboarding_welcome_title': 'ORTA',
      'onboarding_welcome_subtitle': 'Изучайте язык, живя им.',
      'onboarding_continue': 'Продолжить',
      'onboarding_back': 'Назад',
      'onboarding_native_language': 'Какой ваш родной язык?',
      'onboarding_native_language_subtitle': 'Выберите язык, которым вы владеете свободно.',
      'onboarding_learning_language': 'Какой язык вы хотите изучать?',
      'onboarding_learning_language_subtitle': 'Выберите язык, который вы хотите практиковать.',
      'onboarding_name': 'Как ORTA может к вам обращаться?',
      'onboarding_name_subtitle': 'Введите ваше имя или никнейм.',
      'onboarding_name_hint': 'Ваше имя',
      'onboarding_level': 'Какой у вас текущий уровень?',
      'onboarding_level_subtitle': 'Выберите ваш приблизительный уровень в языке, который вы хотите изучать.',
      'onboarding_wake_time': 'Когда вы обычно бодрствуете?',
      'onboarding_wake_time_subtitle': 'ORTA будет использовать это для отправки языковых взаимодействий в подходящее время.',
      'onboarding_wake_up': 'Время пробуждения',
      'onboarding_sleep': 'Время сна',
      'onboarding_summary': 'Всё готово!',
      'onboarding_summary_subtitle': 'Вот краткое описание вашего профиля:',
      'onboarding_start': 'Начать ORTA',
      'onboarding_name_error': 'Пожалуйста, введите ваше имя',
      'onboarding_ai_assessment': 'Оценка уровня ИИ',
      'onboarding_ai_assessment_placeholder': 'Оценка уровня ИИ будет доступна в ближайшее время.',
      'onboarding_ok': 'ОК',
      
      // Summary
      'summary_name': 'Имя',
      'summary_native_language': 'Родной язык',
      'summary_learning_language': 'Изучаемый язык',
      'summary_level': 'Уровень',
      'summary_not_selected': 'Не выбран',
      
      // Home
      'home_good_morning': 'Доброе утро',
      'home_good_afternoon': 'Добрый день',
      'home_good_evening': 'Добрый вечер',
      'home_today_task': 'Задача на сегодня',
      'home_do_with_ai': 'Выполнить с ИИ',
      'home_progress': 'Прогресс',
      'home_to_next_level': 'до следующего уровня',
      'home_activity': 'Активность',
      'home_day_streak': 'Дней подряд',
      'home_words': 'Слова',
      'home_conversations': 'Разговоры',
      'home_weekly_conversation': 'Еженедельный разговор',
      'home_weekly_conversation_progress': '/ 1',
      'home_orta_today': 'ORTA сегодня',
      'home_morning_checkin': 'Утренняя проверка',
      'home_how_did_you_sleep': 'Как вы спали?',
      'home_mini_interaction': 'Мини-взаимодействие',
      'home_describe_around': 'Опишите, что вокруг вас.',
      'home_quick_moment': 'Быстрый английский момент',
      'home_tell_orta': 'Расскажите ORTA, что вы делаете.',
      'home_this_week': 'На этой неделе',
      'home_conversation_with_orta': 'Разговор с ORTA',
      'home_completed': 'выполнено',
      
      // AI Chat
      'ai_chat_title': 'Чат с ИИ',
      'ai_message_hint': 'Введите сообщение...',
      'ai_task_greeting': 'Отлично. Посмотрите вокруг и опишите три вещи, которые вы видите. Не переживайте о ошибках — я помогу вам.',
      
      // Library
      'library_coming_soon': 'Библиотека скоро появится',
      'library_stories': 'Истории, адаптированные под ваш уровень',
      'library_articles': 'Статьи и материалы для чтения',
      'library_exercises': 'Интерактивные упражнения для чтения',
      
      // Settings
      'settings_profile': 'Профиль',
      'settings_name': 'Имя',
      'settings_native_language': 'Родной язык',
      'settings_learning_language': 'Изучаемый язык',
      'settings_current_level': 'Текущий уровень',
      'settings_learning': 'Обучение',
      'settings_wake_up_time': 'Время пробуждения',
      'settings_sleep_time': 'Время сна',
      'settings_notifications': 'Уведомления',
      'settings_enable_interactions': 'Включить взаимодействия ORTA',
      'settings_app': 'Приложение',
      'settings_about_orta': 'О ORTA',
      'settings_reset_onboarding': 'Сбросить onboard',
      'settings_reset_subtitle': 'Очистить все данные и начать заново',
      'settings_reset_confirmation': 'Сбросить onboard',
      'settings_reset_message': 'Это очистит все ваши данные и вернет вас к процессу onboard. Вы уверены?',
      'settings_cancel': 'Отмена',
      'settings_reset': 'Сбросить',
      'settings_close': 'Закрыть',
      
      // Responses
      'response_well': 'Хорошо',
      'response_not_great': 'Не очень',
      
      // Levels
      'level_a0': 'A0 — Начинающий',
      'level_a1': 'A1',
      'level_a2': 'A2',
      'level_b1': 'B1',
      'level_b2': 'B2',
      'level_c1': 'C1',
      'level_c2': 'C2',
      'level_unknown': 'Я не знаю свой уровень',
      'level_mastery': 'Мастерство достигнуто',
      
      // Languages
      'lang_english': 'English',
      'lang_kazakh': 'Қазақша',
      'lang_russian': 'Русский',
    },
    AppLocale.kazakh: {
      // App
      'app_name': 'ORTA',
      'about_orta_title': 'ORTA туралы',
      'about_orta_description': 'ORTA сізге тілді оқып үйренуге күнделікті өміріңізге кішкентай тілдік әрекеттерді енгізу арқылы көмектеседі.',
      'version': 'Нұсқа',
      
      // Navigation
      'nav_home': 'Басты бет',
      'nav_ai': 'ЖИ',
      'nav_library': 'Кітапхана',
      'nav_settings': 'Баптаулар',
      
      // Onboarding
      'onboarding_welcome_title': 'ORTA',
      'onboarding_welcome_subtitle': 'Тілді өмір сүру арқылы үйреніңіз.',
      'onboarding_continue': 'Жалғастыру',
      'onboarding_back': 'Артқа',
      'onboarding_native_language': 'Ана тіліңіз қандай?',
      'onboarding_native_language_subtitle': 'Еркін сөйлейтін тіліңізді таңдаңыз.',
      'onboarding_learning_language': 'Қандай тілді үйренгіңіз келеді?',
      'onboarding_learning_language_subtitle': 'Практика жасағыңыз келетін тілді таңдаңыз.',
      'onboarding_name': 'ORTA сізге қалай айтуы керек?',
      'onboarding_name_subtitle': 'Атыңызды немесе никнейміңізді енгізіңіз.',
      'onboarding_name_hint': 'Атыңыз',
      'onboarding_level': 'Қазіргі деңгейіңіз қандай?',
      'onboarding_level_subtitle': 'Үйренгіңіз келетін тілдегі шамамен деңгейіңізді таңдаңыз.',
      'onboarding_wake_time': 'Сіз әдетте қашан ояласыз?',
      'onboarding_wake_time_subtitle': 'ORTA бұл мәліметті тиімді уақытта тілдік әрекеттер жіберу үшін қолданады.',
      'onboarding_wake_up': 'Ояну уақыты',
      'onboarding_sleep': 'Ұйқы уақыты',
      'onboarding_summary': 'Бәрі дайын!',
      'onboarding_summary_subtitle': 'Профиліңіздің қысқаша сипаттамасы:',
      'onboarding_start': 'ORTA-ны бастау',
      'onboarding_name_error': 'Атыңызды енгізіңіз',
      'onboarding_ai_assessment': 'ЖИ деңгейін бағалау',
      'onboarding_ai_assessment_placeholder': 'ЖИ деңгейін бағалау жақында қолжетімді болады.',
      'onboarding_ok': 'OK',
      
      // Summary
      'summary_name': 'Аты',
      'summary_native_language': 'Ана тілі',
      'summary_learning_language': 'Үйренетін тіл',
      'summary_level': 'Деңгей',
      'summary_not_selected': 'Таңдалмаған',
      
      // Home
      'home_good_morning': 'Қайырлы таң',
      'home_good_afternoon': 'Қайырлы күн',
      'home_good_evening': 'Қайырлы кеш',
      'home_today_task': 'Бүгінгі тапсырма',
      'home_do_with_ai': 'ЖИ-мен орындау',
      'home_progress': 'Прогресс',
      'home_to_next_level': 'келесі деңгейге',
      'home_activity': 'Белсенділік',
      'home_day_streak': 'Күндер',
      'home_words': 'Сөздер',
      'home_conversations': 'Сөйлесулер',
      'home_weekly_conversation': 'Апталық сөйлесу',
      'home_weekly_conversation_progress': '/ 1',
      'home_orta_today': 'ORTA бүгін',
      'home_morning_checkin': 'Таңғы тексеру',
      'home_how_did_you_sleep': 'Қалай ұйықтадыңыз?',
      'home_mini_interaction': 'Мини-әрекеттесу',
      'home_describe_around': 'Айналасындағыны сипаттаңыз.',
      'home_quick_moment': 'Жылдам ағылшын моменті',
      'home_tell_orta': 'ORTA-ға не істеп жатқаныңызды айтыңыз.',
      'home_this_week': 'Бұл апта',
      'home_conversation_with_orta': 'ORTA-мен сөйлесу',
      'home_completed': 'орындалды',
      
      // AI Chat
      'ai_chat_title': 'ЖИ чаты',
      'ai_message_hint': 'Хабарлама енгізіңіз...',
      'ai_task_greeting': 'Үлкен. Айналасыңызға қарап, көрген үш нәрсені сипаттаңыз. қателер туралы алаңдамаңыз — мен көмектесемін.',
      
      // Library
      'library_coming_soon': 'Кітапхана жақында пайда болады',
      'library_stories': 'Деңгейіңізге бейімделген әңгімелер',
      'library_articles': 'Мақалалар және оқу материалдары',
      'library_exercises': 'Интерактивті оқу жаттығулары',
      
      // Settings
      'settings_profile': 'Профиль',
      'settings_name': 'Аты',
      'settings_native_language': 'Ана тілі',
      'settings_learning_language': 'Үйренетін тіл',
      'settings_current_level': 'Ағымдағы деңгей',
      'settings_learning': 'Оқыту',
      'settings_wake_up_time': 'Ояну уақыты',
      'settings_sleep_time': 'Ұйқы уақыты',
      'settings_notifications': 'Хабарландырулар',
      'settings_enable_interactions': 'ORTA әрекеттерін қосу',
      'settings_app': 'Қолданба',
      'settings_about_orta': 'ORTA туралы',
      'settings_reset_onboarding': 'Onboard-ды қайта орнату',
      'settings_reset_subtitle': 'Барлық деректірді жою және бастау',
      'settings_reset_confirmation': 'Onboard-ды қайта орнату',
      'settings_reset_message': 'Бұл барлық деректеріңізді жояды және сізді onboard процесіне қайтарады. Сенімдісіз бе?',
      'settings_cancel': 'Болдырмау',
      'settings_reset': 'Қайта орнату',
      'settings_close': 'Жабу',
      
      // Responses
      'response_well': 'Жақсы',
      'response_not_great': 'Қанағатсыз',
      
      // Levels
      'level_a0': 'A0 — Бастаушы',
      'level_a1': 'A1',
      'level_a2': 'A2',
      'level_b1': 'B1',
      'level_b2': 'B2',
      'level_c1': 'C1',
      'level_c2': 'C2',
      'level_unknown': 'Деңгейімді білмеймін',
      'level_mastery': 'Шеберлік қол жеткізілді',
      
      // Languages
      'lang_english': 'English',
      'lang_kazakh': 'Қазақша',
      'lang_russian': 'Русский',
    },
  };

  String get(String key) {
    return _translations[locale]?[key] ?? _translations[AppLocale.english]?[key] ?? key;
  }

  String get appName => get('app_name');
  String get aboutOrtaTitle => get('about_orta_title');
  String get aboutOrtaDescription => get('about_orta_description');
  String get version => get('version');
  
  // Navigation
  String get navHome => get('nav_home');
  String get navAi => get('nav_ai');
  String get navLibrary => get('nav_library');
  String get navSettings => get('nav_settings');
  
  // Onboarding
  String get onboardingWelcomeTitle => get('onboarding_welcome_title');
  String get onboardingWelcomeSubtitle => get('onboarding_welcome_subtitle');
  String get onboardingContinue => get('onboarding_continue');
  String get onboardingBack => get('onboarding_back');
  String get onboardingNativeLanguage => get('onboarding_native_language');
  String get onboardingNativeLanguageSubtitle => get('onboarding_native_language_subtitle');
  String get onboardingLearningLanguage => get('onboarding_learning_language');
  String get onboardingLearningLanguageSubtitle => get('onboarding_learning_language_subtitle');
  String get onboardingName => get('onboarding_name');
  String get onboardingNameSubtitle => get('onboarding_name_subtitle');
  String get onboardingNameHint => get('onboarding_name_hint');
  String get onboardingLevel => get('onboarding_level');
  String get onboardingLevelSubtitle => get('onboarding_level_subtitle');
  String get onboardingWakeTime => get('onboarding_wake_time');
  String get onboardingWakeTimeSubtitle => get('onboarding_wake_time_subtitle');
  String get onboardingWakeUp => get('onboarding_wake_up');
  String get onboardingSleep => get('onboarding_sleep');
  String get onboardingSummary => get('onboarding_summary');
  String get onboardingSummarySubtitle => get('onboarding_summary_subtitle');
  String get onboardingStart => get('onboarding_start');
  String get onboardingNameError => get('onboarding_name_error');
  String get onboardingAiAssessment => get('onboarding_ai_assessment');
  String get onboardingAiAssessmentPlaceholder => get('onboarding_ai_assessment_placeholder');
  String get onboardingOk => get('onboarding_ok');
  
  // Summary
  String get summaryName => get('summary_name');
  String get summaryNativeLanguage => get('summary_native_language');
  String get summaryLearningLanguage => get('summary_learning_language');
  String get summaryLevel => get('summary_level');
  String get summaryNotSelected => get('summary_not_selected');
  
  // Home
  String get homeGoodMorning => get('home_good_morning');
  String get homeGoodAfternoon => get('home_good_afternoon');
  String get homeGoodEvening => get('home_good_evening');
  String get homeTodayTask => get('home_today_task');
  String get homeDoWithAi => get('home_do_with_ai');
  String get homeProgress => get('home_progress');
  String get homeToNextLevel => get('home_to_next_level');
  String get homeActivity => get('home_activity');
  String get homeDayStreak => get('home_day_streak');
  String get homeWords => get('home_words');
  String get homeConversations => get('home_conversations');
  String get homeWeeklyConversation => get('home_weekly_conversation');
  String get homeWeeklyConversationProgress => get('home_weekly_conversation_progress');
  String get homeOrtaToday => get('home_orta_today');
  String get homeMorningCheckin => get('home_morning_checkin');
  String get homeHowDidYouSleep => get('home_how_did_you_sleep');
  String get homeMiniInteraction => get('home_mini_interaction');
  String get homeDescribeAround => get('home_describe_around');
  String get homeQuickMoment => get('home_quick_moment');
  String get homeTellOrta => get('home_tell_orta');
  String get homeThisWeek => get('home_this_week');
  String get homeConversationWithOrta => get('home_conversation_with_orta');
  String get homeCompleted => get('home_completed');
  
  // AI Chat
  String get aiChatTitle => get('ai_chat_title');
  String get aiMessageHint => get('ai_message_hint');
  String get aiTaskGreeting => get('ai_task_greeting');
  
  // Library
  String get libraryComingSoon => get('library_coming_soon');
  String get libraryStories => get('library_stories');
  String get libraryArticles => get('library_articles');
  String get libraryExercises => get('library_exercises');
  
  // Settings
  String get settingsProfile => get('settings_profile');
  String get settingsName => get('settings_name');
  String get settingsNativeLanguage => get('settings_native_language');
  String get settingsLearningLanguage => get('settings_learning_language');
  String get settingsCurrentLevel => get('settings_current_level');
  String get settingsLearning => get('settings_learning');
  String get settingsWakeUpTime => get('settings_wake_up_time');
  String get settingsSleepTime => get('settings_sleep_time');
  String get settingsNotifications => get('settings_notifications');
  String get settingsEnableInteractions => get('settings_enable_interactions');
  String get settingsApp => get('settings_app');
  String get settingsAboutOrta => get('settings_about_orta');
  String get settingsResetOnboarding => get('settings_reset_onboarding');
  String get settingsResetSubtitle => get('settings_reset_subtitle');
  String get settingsResetConfirmation => get('settings_reset_confirmation');
  String get settingsResetMessage => get('settings_reset_message');
  String get settingsCancel => get('settings_cancel');
  String get settingsReset => get('settings_reset');
  String get settingsClose => get('settings_close');
  
  // Responses
  String get responseWell => get('response_well');
  String get responseNotGreat => get('response_not_great');
  
  // Levels
  String get levelA0 => get('level_a0');
  String get levelA1 => get('level_a1');
  String get levelA2 => get('level_a2');
  String get levelB1 => get('level_b1');
  String get levelB2 => get('level_b2');
  String get levelC1 => get('level_c1');
  String get levelC2 => get('level_c2');
  String get levelUnknown => get('level_unknown');
  String get levelMastery => get('level_mastery');
  
  // Languages
  String get langEnglish => get('lang_english');
  String get langKazakh => get('lang_kazakh');
  String get langRussian => get('lang_russian');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru', 'kk'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(
      AppLocaleExtension.fromLanguageCode(locale.languageCode),
    ));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
