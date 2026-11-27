import '../models/language.dart';

const Map<String, List<String>> productCopy = {
  "home": ["Home", "Главная", "Басты бет"],
  "plan": ["Plan", "План", "Жоспар"],
  "life": ["Life", "Жизнь", "Өмір"],
  "progress": ["Progress", "Прогресс", "Жетістіктер"],
  "settings": ["Settings", "Настройки", "Баптаулар"],
  "interfaceLanguage": [
    "Interface language",
    "Язык интерфейса",
    "Интерфейс тілі",
  ],
  "privacy": [
    "Your records and conversations are stored on this device. When you message ORTA, relevant context is sent to the AI provider.",
    "Записи и разговоры хранятся на этом устройстве. Когда вы пишете ORTA, необходимый контекст отправляется провайдеру ИИ.",
    "Жазбалар мен әңгімелер осы құрылғыда сақталады. ORTA-ға хабарлама жібергенде тиісті контекст ЖИ провайдеріне жіберіледі.",
  ],
  "lifeIntro": [
    "What ORTA currently knows about you.",
    "Что ORTA сейчас знает о вас.",
    "ORTA сіз туралы қазір не біледі.",
  ],
  "currentLife": ["Current situation", "Текущая ситуация", "Қазіргі жағдай"],
  "noAreas": [
    "No life areas added yet.",
    "Сферы жизни ещё не добавлены.",
    "Өмір салалары әлі қосылмаған.",
  ],
  "goals": ["Goals", "Цели", "Мақсаттар"],
  "universities": ["Universities", "Университеты", "Университеттер"],
  "career": ["Career", "Карьера", "Мансап"],
  "projects": ["Projects", "Проекты", "Жобалар"],
  "exams": ["Exams", "Экзамены", "Емтихандар"],
  "languages": ["Languages", "Языки", "Тілдер"],
  "unknownLevel": [
    "Level not specified",
    "Уровень не указан",
    "Деңгей көрсетілмеген",
  ],
  "addArea": ["Add life area", "Добавить сферу жизни", "Өмір саласын қосу"],
  "addLanguage": [
    "Add language goal",
    "Добавить языковую цель",
    "Тіл мақсатын қосу",
  ],
  "openLanguage": [
    "Open Language ORTA",
    "Открыть Language ORTA",
    "Language ORTA ашу",
  ],
  "reset": ["Reset ORTA", "Сбросить ORTA", "ORTA деректерін тазарту"],
  "resetTitle": [
    "Reset saved data?",
    "Сбросить сохранённые данные?",
    "Сақталған деректерді тазарту керек пе?",
  ],
  "resetBody": [
    "This removes your local life records, plans, progress, language practice and conversations, then returns to onboarding.",
    "Это удалит локальные записи, планы, прогресс, языковую практику и разговоры, затем откроет начальную настройку.",
    "Бұл жергілікті жазбаларды, жоспарларды, жетістіктерді, тілдік жаттығуларды және әңгімелерді жойып, бастапқы баптауды ашады.",
  ],
  "cancel": ["Cancel", "Отмена", "Бас тарту"],
  "close": ["Close", "Закрыть", "Жабу"],
  "newChat": ["New conversation", "Новый разговор", "Жаңа әңгіме"],
  "history": ["Conversation history", "История разговоров", "Әңгімелер тарихы"],
  "untitled": ["New conversation", "Новый разговор", "Жаңа әңгіме"],
  "retention": [
    "Up to 20 conversations, with the latest 50 messages in each.",
    "До 20 разговоров, последние 50 сообщений в каждом.",
    "20 әңгімеге дейін, әрқайсысының соңғы 50 хабарламасы.",
  ],
  "expand": ["Expand conversation", "Развернуть разговор", "Әңгімені кеңейту"],
  "collapse": [
    "Collapse conversation",
    "Свернуть разговор",
    "Әңгімені кішірейту",
  ],
  "message": ["Message ORTA", "Напишите ORTA", "ORTA-ға жазыңыз"],
  "send": ["Send message", "Отправить сообщение", "Хабарлама жіберу"],
  "attachImage": ["Attach an image", "Прикрепить изображение", "Сурет тіркеу"],
  "removeImage": ["Remove image", "Убрать изображение", "Суретті алып тастау"],
  "imageTooLarge": [
    "Choose an image smaller than 5 MB.",
    "Выберите изображение размером до 5 МБ.",
    "5 МБ-тан кіші суретті таңдаңыз.",
  ],
  "unsupportedImage": [
    "Choose a JPG, PNG or WebP image.",
    "Выберите изображение JPG, PNG или WebP.",
    "JPG, PNG немесе WebP суретін таңдаңыз.",
  ],
  "imageAttached": [
    "Image attached",
    "Изображение прикреплено",
    "Сурет тіркелді",
  ],
  "imageQuestion": [
    "Please analyze this image and tell me how you can help.",
    "Пожалуйста, проанализируй изображение и предложи, чем можешь помочь.",
    "Осы суретті талдап, қалай көмектесе алатыныңды айт.",
  ],
  "imageError": [
    "Could not open that image. Try another one.",
    "Не удалось открыть изображение. Попробуйте другое.",
    "Суретті ашу мүмкін болмады. Басқасын көріңіз.",
  ],
  "providerError": [
    "Image analysis needs the connected ORTA AI service.",
    "Для анализа изображения нужно подключение к ORTA AI.",
    "Суретті талдау үшін ORTA AI қызметіне қосылу қажет.",
  ],
  "thinking": ["ORTA is thinking…", "ORTA думает…", "ORTA ойланып жатыр…"],
  "welcome": [
    "What would you like to talk about?",
    "О чём хотите поговорить?",
    "Не туралы сөйлескіңіз келеді?",
  ],
  "viewing": ["Viewing: {name}", "Открыто: {name}", "Ашық: {name}"],
  "newChatError": [
    "Could not open this conversation. Your saved history is unchanged. The local limit is 20 conversations.",
    "Не удалось открыть разговор. История не изменена. Локальный предел — 20 разговоров.",
    "Әңгімені ашу мүмкін болмады. Тарих өзгерген жоқ. Жергілікті шек — 20 әңгіме.",
  ],
  "retry": ["Try again", "Попробовать снова", "Қайта көріңіз"],
  "tooLong": [
    "Please keep the message under 8,000 characters.",
    "Сообщение должно быть короче 8000 символов.",
    "Хабарлама 8000 таңбадан қысқа болуы керек.",
  ],
  "linkCopied": ["Link copied", "Ссылка скопирована", "Сілтеме көшірілді"],
  "linkUnavailable": [
    "This link cannot be copied.",
    "Эту ссылку нельзя скопировать.",
    "Бұл сілтемені көшіру мүмкін емес.",
  ],
  "imageOmitted": ["Image attachment", "Изображение", "Сурет"],
  "preview": [
    "Preview responses",
    "Ответы в режиме просмотра",
    "Алдын ала қарау жауаптары",
  ],
};

String productText(Language language, String key, {String? name}) {
  final values = productCopy[key];
  if (values == null) throw ArgumentError('Unknown product copy key: $key');
  final index = language == Language.russian
      ? 1
      : language == Language.kazakh
      ? 2
      : 0;
  return values[index].replaceAll('{name}', name ?? '');
}
