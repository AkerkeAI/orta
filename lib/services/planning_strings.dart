import '../models/language.dart';
import 'scheduling_engine.dart';

String planningText(Language language, String key) {
  const values = {
    'invalid_arguments': [
      'Check the proposed details. Nothing changed.',
      'Проверьте предложенные данные. Ничего не изменено.',
      'Ұсынылған деректерді тексеріңіз. Ештеңе өзгерген жоқ.',
    ],
    'invalid_date': [
      'Provide a valid full date.',
      'Укажите корректную полную дату.',
      'Дұрыс толық күнді көрсетіңіз.',
    ],
    'invalid_time': [
      'Provide valid start/end times.',
      'Укажите корректное время начала и окончания.',
      'Дұрыс басталу және аяқталу уақытын көрсетіңіз.',
    ],
    'missing_information': [
      'Please provide the missing required details.',
      'Укажите недостающие обязательные данные.',
      'Жетіспейтін міндетті мәліметтерді көрсетіңіз.',
    ],
    'unknown_tool': [
      'This action is unavailable.',
      'Это действие недоступно.',
      'Бұл әрекет қолжетімсіз.',
    ],
    'duplicate': [
      'This record or action already exists.',
      'Эта запись или действие уже существует.',
      'Бұл жазба не әрекет бұрыннан бар.',
    ],
    'permission': [
      'Use the proposal’s confirmation controls.',
      'Используйте кнопки подтверждения предложения.',
      'Ұсыныстың растау түймелерін пайдаланыңыз.',
    ],
    'plan': ['Plan', 'План', 'Жоспар'],
    'tasks': [
      'Unscheduled / selected-day tasks',
      'Задачи без времени / выбранного дня',
      'Уақыты белгіленбеген / таңдалған күн тапсырмалары',
    ],
    'previousWeek': ['Previous week', 'Предыдущая неделя', 'Алдыңғы апта'],
    'nextWeek': ['Next week', 'Следующая неделя', 'Келесі апта'],
    'workFree': [
      'Available work windows',
      'Доступное рабочее время',
      'Жұмысқа қолжетімді уақыт',
    ],
    'today': ['Today', 'Сегодня', 'Бүгін'],
    'day': ['Day', 'День', 'Күн'],
    'week': ['Week', 'Неделя', 'Апта'],
    'preferences': [
      'Planning preferences',
      'Настройки планирования',
      'Жоспарлау баптаулары',
    ],
    'timezone': [
      'Time zone (IANA, e.g. Asia/Aqtau)',
      'Часовой пояс (IANA, например Asia/Aqtau)',
      'Уақыт белдеуі (IANA, мысалы Asia/Aqtau)',
    ],
    'studyStart': [
      'Study availability starts',
      'Начало доступного времени для учёбы',
      'Оқуға қолжетімді уақыттың басы',
    ],
    'studyEnd': [
      'Study availability ends',
      'Конец доступного времени для учёбы',
      'Оқуға қолжетімді уақыттың соңы',
    ],
    'workStart': [
      'Work availability starts (optional)',
      'Начало рабочего времени (необязательно)',
      'Жұмыс уақытының басы (міндетті емес)',
    ],
    'workEnd': [
      'Work availability ends (optional)',
      'Конец рабочего времени (необязательно)',
      'Жұмыс уақытының соңы (міндетті емес)',
    ],
    'weekdays': [
      'Available weekdays (1=Mon … 7=Sun)',
      'Доступные дни (1=пн … 7=вс)',
      'Қолжетімді күндер (1=дс … 7=жс)',
    ],
    'daysOff': ['Days off (1–7)', 'Выходные (1–7)', 'Демалыс күндері (1–7)'],
    'maxDailyMinutes': [
      'Maximum planned minutes per day',
      'Максимум минут запланированных занятий в день',
      'Күніне жоспарланған сабақтардың ең көп минуты',
    ],
    'breakMinutes': [
      'Minimum break (minutes)',
      'Минимальный перерыв (минуты)',
      'Ең қысқа үзіліс (минут)',
    ],
    'sessionMinutes': [
      'Preferred session length (minutes)',
      'Длительность занятия (минуты)',
      'Сабақтың қалаулы ұзақтығы (минут)',
    ],
    'notAfter': [
      'No planning after (HH:mm)',
      'Не планировать после (ЧЧ:мм)',
      'Осы уақыттан кейін жоспарламау (СС:мм)',
    ],
    'intensity': [
      'Preparation intensity',
      'Интенсивность подготовки',
      'Дайындық қарқындылығы',
    ],
    'light': ['Light', 'Лёгкая', 'Жеңіл'],
    'regular': ['Regular', 'Обычная', 'Қалыпты'],
    'intensive': ['Intensive', 'Интенсивная', 'Қарқынды'],
    'unavailable': [
      'Unavailable periods, one per line: YYYY-MM-DD HH:mm-HH:mm',
      'Недоступное время, по строке: ГГГГ-ММ-ДД ЧЧ:мм-ЧЧ:мм',
      'Қолжетімсіз уақыт, әр жолда: ЖЖЖЖ-АА-КК СС:мм-СС:мм',
    ],
    'save': ['Save', 'Сохранить', 'Сақтау'],
    'cancel': ['Cancel', 'Отмена', 'Бас тарту'],
    'invalidPreferences': [
      'Check the time zone, dates, hours and limits. Nothing was saved.',
      'Проверьте часовой пояс, даты, часы и ограничения. Ничего не сохранено.',
      'Уақыт белдеуін, күндерді, сағаттарды және шектеулерді тексеріңіз. Ештеңе сақталмады.',
    ],
    'saveFailed': [
      'Could not save. Try again.',
      'Не удалось сохранить. Повторите попытку.',
      'Сақтау мүмкін болмады. Қайта көріңіз.',
    ],
    'availability': [
      'Set your availability and time zone before planning. An empty calendar does not prove you are free.',
      'Укажите доступное время и часовой пояс. Пустой календарь не означает, что вы свободны.',
      'Жоспарлау алдында қолжетімді уақытыңыз бен уақыт белдеуін орнатыңыз. Бос күнтізбе бос уақытыңыз бар дегенді білдірмейді.',
    ],
    'range': [
      'Specify a valid date range of at most 32 days.',
      'Укажите корректный период не более 32 дней.',
      '32 күннен аспайтын дұрыс мерзімді көрсетіңіз.',
    ],
    'effort': [
      'How many sessions do you want, or how much effort does this task need?',
      'Сколько занятий вы хотите или сколько времени нужно на задачу?',
      'Қанша сабақ қажет немесе тапсырмаға қанша уақыт керек?',
    ],
    'insufficient': [
      'There is not enough permitted time for the whole plan. No sessions were saved. Adjust availability or reduce the workload.',
      'Для всего плана недостаточно доступного времени. Занятия не сохранены. Измените доступное время или нагрузку.',
      'Бүкіл жоспарға рұқсат етілген уақыт жеткіліксіз. Сабақтар сақталмады. Қолжетімді уақытты не жүктемені өзгертіңіз.',
    ],
    'constraints': [
      'This session violates your availability, break or end-time constraints.',
      'Занятие нарушает ограничения доступности, перерыва или времени окончания.',
      'Сабақ қолжетімділік, үзіліс не аяқталу уақытының шектеулерін бұзады.',
    ],
    'timezoneError': [
      'The time zone or daylight-saving time is ambiguous. Choose another time.',
      'Часовой пояс или время перевода часов неоднозначны. Выберите другое время.',
      'Уақыт белдеуі не сағат ауысуы екіұшты. Басқа уақытты таңдаңыз.',
    ],
    'workload': [
      'This day would exceed your planned workload limit.',
      'Будет превышен лимит запланированной нагрузки на день.',
      'Күндік жоспарланған жүктеме шегі асып кетеді.',
    ],
    'deadline': [
      'There is a deadline to consider',
      'Учитывайте срок',
      'Мерзімді ескеріңіз',
    ],
    'deadlineError': [
      'The plan must finish before the exam or task deadline.',
      'План должен завершиться до экзамена или срока задачи.',
      'Жоспар емтиханға не тапсырма мерзіміне дейін аяқталуы тиіс.',
    ],
    'missing_record': [
      'The selected record no longer exists.',
      'Выбранная запись больше не существует.',
      'Таңдалған жазба енді жоқ.',
    ],
    'covered': [
      'Enough task effort is already completed or reserved. Review the existing sessions.',
      'Достаточное время на задачу уже выполнено или запланировано. Проверьте существующие занятия.',
      'Тапсырмаға жеткілікті уақыт орындалған не жоспарланған. Бар сабақтарды тексеріңіз.',
    ],
    'completed': [
      'This task is already completed.',
      'Эта задача уже завершена.',
      'Бұл тапсырма аяқталған.',
    ],
    'keepBoth': [
      'Save both conflicting commitments? Neither record will be overwritten.',
      'Сохранить оба конфликтующих события? Ни одна запись не будет перезаписана.',
      'Қайшы екі міндетті де сақтау керек пе? Ешбір жазба қайта жазылмайды.',
    ],
    'conflict': [
      'Scheduling conflict',
      'Конфликт расписания',
      'Кесте қайшылығы',
    ],
    'conflictError': [
      'This session conflicts with a saved event. Nothing was changed.',
      'Занятие конфликтует с сохранённым событием. Данные не изменены.',
      'Сабақ сақталған оқиғамен қайшы келеді. Деректер өзгерген жоқ.',
    ],
    'overload': [
      'Planned workload exceeds the daily limit',
      'Запланированная нагрузка превышает дневной лимит',
      'Жоспарланған жүктеме күндік шектен асады',
    ],
    'overdue': [
      'Past deadline, still incomplete',
      'Срок прошёл, задача не завершена',
      'Мерзімі өтті, тапсырма аяқталмаған',
    ],
    'unscheduledDeadline': [
      'Upcoming deadline; no work session is saved',
      'Скоро срок; рабочие занятия не запланированы',
      'Мерзімі жақын; жұмыс сабағы жоспарланбаған',
    ],
    'important': [
      'Important task without a scheduled session',
      'Важная задача без запланированного занятия',
      'Жоспарланған сабағы жоқ маңызды тапсырма',
    ],
    'exam': ['Upcoming exam', 'Предстоящий экзамен', 'Алдағы емтихан'],
    'goal': [
      'Choose a next step for this goal',
      'Выберите следующий шаг для цели',
      'Мақсатқа келесі қадамды таңдаңыз',
    ],
    'focus': [
      'Suggested next actions',
      'Предлагаемые следующие шаги',
      'Ұсынылған келесі қадамдар',
    ],
    'commitments': [
      'Today’s commitments',
      'Сегодняшние события',
      'Бүгінгі міндеттер',
    ],
    'taskDueToday': ['Task due today', 'Задача на сегодня', 'Бүгінгі тапсырма'],
    'openTasks': ['Open tasks', 'Активные задачи', 'Белсенді тапсырмалар'],
    'empty': [
      'No saved commitments for this period',
      'В этом периоде нет сохранённых событий',
      'Бұл мерзімде сақталған міндеттер жоқ',
    ],
    'free': [
      'Available study windows',
      'Доступное время для учёбы',
      'Оқуға қолжетімді уақыт',
    ],
    'none': [
      'No permitted window remains',
      'Доступного времени не осталось',
      'Рұқсат етілген уақыт қалмады',
    ],
    'suggestions': [
      'Pending suggestions — not saved events',
      'Предложения — ещё не сохранённые события',
      'Ұсыныстар — әлі сақталған оқиғалар емес',
    ],
    'confirmed': [
      'Saved commitments',
      'Сохранённые события',
      'Сақталған міндеттер',
    ],
    'allDay': ['All day', 'Весь день', 'Күні бойы'],
    'close': ['Close', 'Закрыть', 'Жабу'],
    'approveAll': ['Approve all', 'Подтвердить всё', 'Барлығын растау'],
    'rejectAll': ['Reject all', 'Отменить всё', 'Барлығынан бас тарту'],
    'batchFailed': [
      'The group could not be applied. No pending action was executed; inspect the warning and request a revised plan.',
      'Группа не применена. Ожидающие действия не выполнены; проверьте предупреждение и измените план.',
      'Топ қолданылмады. Күтудегі әрекеттер орындалмады; ескертуді тексеріп, жоспарды өзгертіңіз.',
    ],
    'expired': [
      'Expired. Request a new proposal.',
      'Срок предложения истёк. Запросите новое.',
      'Ұсыныстың мерзімі өтті. Жаңасын сұраңыз.',
    ],
    'stale': [
      'Preferences or records changed. Review a fresh proposal.',
      'Настройки или записи изменились. Проверьте новое предложение.',
      'Баптаулар не жазбалар өзгерді. Жаңа ұсынысты тексеріңіз.',
    ],
    'completeSession': [
      'Mark session completed',
      'Отметить занятие завершённым',
      'Сабақты аяқталған деп белгілеу',
    ],
    'progress': [
      'Completed activity',
      'Завершённая активность',
      'Аяқталған әрекеттер',
    ],
    'unknownProgress': [
      'No completion has been recorded yet',
      'Завершённые действия ещё не отмечены',
      'Аяқталған әрекеттер әлі белгіленбеген',
    ],
    'greeting': [
      'Good to see you',
      'Рады видеть вас',
      'Сізді көргенімізге қуаныштымыз',
    ],
    'date': ['Date', 'Дата', 'Күні'],
  };
  final index = language == Language.russian
      ? 1
      : language == Language.kazakh
      ? 2
      : 0;
  return (values[key] ?? values['saveFailed']!)[index];
}

String planningErrorText(Language l, String code) => planningText(
  l,
  {
        'timezone': 'timezoneError',
        'deadline': 'deadlineError',
        'conflict': 'conflictError',
      }[code] ??
      code,
);
String planningDate(Language l, String date, {bool short = false}) {
  final d = SchedulingEngine.day(date);
  const days = [
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    ['Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сб', 'Жс'],
  ];
  final index = l == Language.russian
      ? 1
      : l == Language.kazakh
      ? 2
      : 0;
  return '${days[index][d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}${short ? '' : '.${d.year}'}';
}

String recommendationText(Language l, Recommendation r) =>
    '${planningText(l, r.code)}: ${r.title}${r.date == null ? '' : ' · ${planningDate(l, r.date!)}'}';
