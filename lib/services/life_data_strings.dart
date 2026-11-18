import '../models/language.dart';

String lifeDataText(Language language, String key) {
  const values = {
    'add': ['Add record', 'Добавить запись', 'Жазба қосу'],
    'title': ['Title', 'Название', 'Атауы'],
    'date': [
      'Date (YYYY-MM-DD, optional)',
      'Дата (ГГГГ-ММ-ДД, необязательно)',
      'Күні (ЖЖЖЖ-АА-КК, міндетті емес)',
    ],
    'start': ['Start (HH:mm)', 'Начало (ЧЧ:мм)', 'Басталуы (СС:мм)'],
    'end': ['End (HH:mm)', 'Конец (ЧЧ:мм)', 'Аяқталуы (СС:мм)'],
    'goal': ['Goal', 'Цель', 'Мақсат'],
    'exam': ['Exam', 'Экзамен', 'Емтихан'],
    'project': ['Project', 'Проект', 'Жоба'],
    'task': ['Task', 'Задача', 'Тапсырма'],
    'event': ['Calendar event', 'Событие', 'Күнтізбе оқиғасы'],
    'save': ['Save', 'Сохранить', 'Сақтау'],
    'cancel': ['Cancel', 'Отмена', 'Бас тарту'],
    'saved': [
      'Saved on this device.',
      'Сохранено на устройстве.',
      'Осы құрылғыда сақталды.',
    ],
    'error': [
      'Could not save. Your previous data is intact. Please try again.',
      'Не удалось сохранить. Прежние данные сохранены. Попробуйте снова.',
      'Сақтау мүмкін болмады. Алдыңғы деректер сақталған. Қайта көріңіз.',
    ],
    'required': ['Enter a title.', 'Введите название.', 'Атауын енгізіңіз.'],
    'invalidDate': [
      'Enter a valid full date: YYYY-MM-DD.',
      'Введите полную дату: ГГГГ-ММ-ДД.',
      'Толық күнді енгізіңіз: ЖЖЖЖ-АА-КК.',
    ],
    'invalidTime': [
      'Use HH:mm and an end after the start.',
      'Формат ЧЧ:мм; конец должен быть позже начала.',
      'СС:мм пішімі; аяқталу басталудан кейін болуы керек.',
    ],
    'none': ['No link', 'Без связи', 'Байланыссыз'],
    'tasks': ['Tasks', 'Задачи', 'Тапсырмалар'],
    'completed': ['Completed', 'Выполнено', 'Орындалды'],
    'noProgress': [
      'No completed tasks yet. Complete a task in Plan to record progress.',
      'Пока нет выполненных задач. Завершите задачу в Плане.',
      'Әзірге орындалған тапсырма жоқ. Жоспардағы тапсырманы аяқтаңыз.',
    ],
    'unknownDate': ['Date not set', 'Дата не указана', 'Күні көрсетілмеген'],
    'ask': [
      'Ask ORTA about this',
      'Спросить ORTA об этом',
      'ORTA-дан осы туралы сұрау',
    ],
    'markPractice': [
      'Mark practice done',
      'Отметить занятие выполненным',
      'Сабақты орындалды деп белгілеу',
    ],
    'practiceDone': [
      'Practice marked done',
      'Занятие отмечено выполненным',
      'Сабақ орындалды деп белгіленді',
    ],
    'practice': [
      'Saved practice sessions',
      'Сохранённые занятия',
      'Сақталған сабақтар',
    ],
    'noLanguageMap': [
      'Not enough practice data to measure progress yet.',
      'Пока недостаточно данных для оценки прогресса.',
      'Ілгерілеуді бағалау үшін деректер әзірге жеткіліксіз.',
    ],
    'moment': [
      'Write a language moment',
      'Запишите языковой момент',
      'Тілдік сәтті жазыңыз',
    ],
    'chatSaveError': [
      'Could not save the conversation. Please retry.',
      'Не удалось сохранить беседу. Повторите попытку.',
      'Әңгімені сақтау мүмкін болмады. Қайта көріңіз.',
    ],
  };
  final index = language == Language.russian
      ? 1
      : language == Language.kazakh
      ? 2
      : 0;
  return (values[key] ?? [key, key, key])[index];
}
