import '../models/user_profile.dart';
import 'localization_service.dart';

class MockAiService {
  static const List<String> _followUpQuestions = [
    "Can you tell me more about that?",
    "What else can you add?",
    "How does that make you feel?",
    "Why do you think that is?",
    "What happened next?",
  ];

  static const List<String> _encouragements = [
    "Great job! Keep going.",
    "That's really good!",
    "You're doing well.",
    "Excellent work!",
    "Nice one!",
  ];

  static const List<String> _expansions = [
    "Try to make that sentence a bit longer.",
    "Can you add more details?",
    "Expand on that a bit more.",
    "Tell me a bit more about it.",
    "Could you describe it in more detail?",
  ];

  static const List<String> _corrections = [
    "That's good! Just a small tip: try using past tense here.",
    "Good attempt! Remember to add 'the' before the noun.",
    "Nice! You could also say it this way...",
    "Well done! Pay attention to word order.",
    "Great! Don't forget the article.",
  ];

  static String getResponse(
    String userMessage,
    UserProfile userProfile,
    AppLocale locale,
  ) {
    // Simple logic to vary responses based on message length and randomness
    final random = userMessage.length % 4;
    
    switch (random) {
      case 0:
        return _getRandomFollowUp(locale);
      case 1:
        return _getRandomEncouragement(locale);
      case 2:
        return _getRandomExpansion(locale);
      case 3:
        return _getRandomCorrection(locale);
      default:
        return _getRandomFollowUp(locale);
    }
  }

  static String getTaskGreeting(
    String task,
    UserProfile userProfile,
    AppLocale locale,
  ) {
    // Context-specific greeting based on task
    if (task.contains('describe') || task.contains('around')) {
      switch (locale) {
        case AppLocale.english:
          return "Great. Look around you and describe three things you can see. Don't worry about mistakes — I'll help you.";
        case AppLocale.russian:
          return "Отлично. Посмотрите вокруг и опишите три вещи, которые вы видите. Не переживайте о ошибках — я помогу вам.";
        case AppLocale.kazakh:
          return "Үлкен. Айналасыңызға қарап, көрген үш нәрсені сипаттаңыз. қателер туралы алаңдамаңыз — мен көмектесемін.";
      }
    }
    
    // Default task greeting
    switch (locale) {
      case AppLocale.english:
        return "Let's practice! I'll help you with this task. Take your time and do your best.";
      case AppLocale.russian:
        return "Давайте практиковаться! Я помогу вам с этой задачей. Не торопитесь и делайте всё, что можете.";
      case AppLocale.kazakh:
        return "Практика жасайық! Мен бұл тапсырмаға көмектесемін. Уақытыңызды алыңыз және үлесіңізді қылыңыз.";
    }
  }

  static String _getRandomFollowUp(AppLocale locale) {
    final index = DateTime.now().millisecond % _followUpQuestions.length;
    final question = _followUpQuestions[index];
    
    switch (locale) {
      case AppLocale.english:
        return question;
      case AppLocale.russian:
        return _translateToRussian(question);
      case AppLocale.kazakh:
        return _translateToKazakh(question);
    }
  }

  static String _getRandomEncouragement(AppLocale locale) {
    final index = DateTime.now().millisecond % _encouragements.length;
    final encouragement = _encouragements[index];
    
    switch (locale) {
      case AppLocale.english:
        return encouragement;
      case AppLocale.russian:
        return _translateToRussian(encouragement);
      case AppLocale.kazakh:
        return _translateToKazakh(encouragement);
    }
  }

  static String _getRandomExpansion(AppLocale locale) {
    final index = DateTime.now().millisecond % _expansions.length;
    final expansion = _expansions[index];
    
    switch (locale) {
      case AppLocale.english:
        return expansion;
      case AppLocale.russian:
        return _translateToRussian(expansion);
      case AppLocale.kazakh:
        return _translateToKazakh(expansion);
    }
  }

  static String _getRandomCorrection(AppLocale locale) {
    final index = DateTime.now().millisecond % _corrections.length;
    final correction = _corrections[index];
    
    switch (locale) {
      case AppLocale.english:
        return correction;
      case AppLocale.russian:
        return _translateToRussian(correction);
      case AppLocale.kazakh:
        return _translateToKazakh(correction);
    }
  }

  // Simple translations for mock responses
  static String _translateToRussian(String text) {
    if (text.contains("Can you tell me more")) return "Можете рассказать подробнее?";
    if (text.contains("What else can you add")) return "Что еще можно добавить?";
    if (text.contains("How does that make you feel")) return "Как это вас заставляет чувствовать?";
    if (text.contains("Why do you think that is")) return "Почему вы так думаете?";
    if (text.contains("What happened next")) return "Что случилось дальше?";
    if (text.contains("Great job")) return "Отличная работа! Продолжайте.";
    if (text.contains("That's really good")) return "Это действительно хорошо!";
    if (text.contains("You're doing well")) return "Вы хорошо справляетесь.";
    if (text.contains("Excellent work")) return "Превосходная работа!";
    if (text.contains("Nice one")) return "Отлично!";
    if (text.contains("Try to make that sentence")) return "Попробуйте сделать это предложение немного длиннее.";
    if (text.contains("Can you add more details")) return "Можете добавить больше деталей?";
    if (text.contains("Expand on that")) return "Раскройте это немного больше.";
    if (text.contains("Tell me a bit more")) return "Расскажите мне немного подробнее.";
    if (text.contains("Could you describe")) return "Не могли бы вы описать это более подробно?";
    if (text.contains("small tip")) return "Это хорошо! Небольшой совет: попробуйте использовать прошедшее время здесь.";
    if (text.contains("Remember to add")) return "Хорошая попытка! Помните добавить 'the' перед существительным.";
    if (text.contains("You could also say")) return "Неплохо! Можно также сказать так...";
    if (text.contains("Pay attention")) return "Хорошо сделано! Обратите внимание на порядок слов.";
    if (text.contains("Don't forget")) return "Отлично! Не забудьте артикль.";
    return text;
  }

  static String _translateToKazakh(String text) {
    if (text.contains("Can you tell me more")) return "Көбірек айта аласыз ба?";
    if (text.contains("What else can you add")) return "Басқа не қоса аласыз?";
    if (text.contains("How does that make you feel")) return "Бұл сізді қандай сезімге келтіреді?";
    if (text.contains("Why do you think that is")) return "Неліктен олай ойлайсыз?";
    if (text.contains("What happened next")) return "Кейін не болды?";
    if (text.contains("Great job")) return "Үлкен жұмыс! Жалғастырыңыз.";
    if (text.contains("That's really good")) return "Бұл шынымен жақсы!";
    if (text.contains("You're doing well")) return "Сіз жақсы істеп жатырсыз.";
    if (text.contains("Excellent work")) return "Тамаша жұмыс!";
    if (text.contains("Nice one")) return "Жақсы!";
    if (text.contains("Try to make that sentence")) return "Осы сөйлемді біршама ұзартуға тырысыңыз.";
    if (text.contains("Can you add more details")) return "Көбірек егжей-тегжей қоса аласыз ба?";
    if (text.contains("Expand on that")) return "Оны біршама кеңейтіңіз.";
    if (text.contains("Tell me a bit more")) return "Маған сәл көбірек айтыңыз.";
    if (text.contains("Could you describe")) return "Оны егжей-тегжейлі сипаттай аласыз ба?";
    if (text.contains("small tip")) return "Бұл жақсы! Кішкентай кеңес: мұнда өткен шақты қолдануға тырысыңыз.";
    if (text.contains("Remember to add")) return "Жақсы әрекет! Есімде сақтаңыз, зат есімнен бұрын 'the' қосыңыз.";
    if (text.contains("You could also say")) return "Жақсы! Мұны былай да айтуға болады...";
    if (text.contains("Pay attention")) return "Жақсы істедіңіз! Сөз тәртібіне назар аударыңыз.";
    if (text.contains("Don't forget")) return "Тамаша! Артикльді ұмытпаңыз.";
    return text;
  }
}
