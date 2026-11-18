import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/models/orta_models.dart';
import 'package:orta/models/scheduling_preferences.dart';
import 'package:orta/services/ai_actions.dart';
import 'package:orta/services/orta_agent_service.dart';
import 'package:orta/services/agent_context_builder.dart';
import 'package:orta/screens/core/orta_shell.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/storage_service.dart';
import 'package:orta/services/scheduling_engine.dart';
import 'package:orta/services/planning_tools.dart';
import 'package:orta/services/planning_strings.dart';
import 'package:orta/widgets/planning_views.dart';

class TestStorage implements LifeDataStorage {
  LifeData data;
  bool fail = false;
  TestStorage(this.data);
  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(data.toJson());
  @override
  Future<void> saveLifeData(LifeData value) async {
    if (fail) throw StateError('Disk failed');
    data = LifeData.fromJson(value.toJson());
  }
}

SchedulingPreferences preferences({
  List<int> days = const [1, 2, 3, 4, 5],
  List<int> off = const [],
  int workload = 120,
  int pause = 15,
  List<Map<String, String>> unavailable = const [],
  String zone = 'Asia/Aqtau',
}) => SchedulingPreferences(
  timezone: zone,
  studyStart: '18:00',
  studyEnd: '21:00',
  workStart: '16:00',
  workEnd: '20:00',
  weekdays: days,
  daysOff: off,
  maxDailyMinutes: workload,
  breakMinutes: pause,
  sessionMinutes: 60,
  notAfter: '21:00',
  unavailable: unavailable,
);
LifeData initial({
  List<CalendarEvent> events = const [],
  List<Task> tasks = const [],
  SchedulingPreferences? prefs,
}) => LifeData(
  life: const LifeContext(
    name: 'Planner',
    interfaceLanguage: Language.english,
    goals: [GoalContext(id: 'g', titleKey: 'IELTS', areaKey: 'education')],
  ),
  scheduling: prefs ?? preferences(),
  events: events,
  tasks: tasks,
);
CalendarEvent event(
  String id,
  String date,
  String start,
  String end, {
  String? title,
  String zone = 'Asia/Aqtau',
  String kind = '',
  bool allDay = false,
  String? task,
}) => CalendarEvent(
  id: id,
  title: title ?? id,
  date: date,
  startTime: start,
  endTime: end,
  category: 'Event',
  timezone: zone,
  planningKind: kind,
  isAllDay: allDay,
  taskId: task,
);
SchedulingEngine engine(LifeData data) =>
    SchedulingEngine(data, nowOverride: DateTime.utc(2027, 1, 4, 6));
Map<String, dynamic> request({int? count = 3}) => {
  'title': 'IELTS study',
  'kind': 'study',
  'period': 'next_week',
  'count': ?count,
  'notAfter': '21:00',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolRegistry registry;
  setUp(() async => registry = await ToolRegistry.load());
  test('A B C: exact day/week boundaries and chronological ordering', () {
    final e = engine(
      initial(
        events: [
          event('late', '2027-01-05', '19:00', '20:00'),
          event('early', '2027-01-05', '18:00', '18:30'),
          event('outside', '2027-01-11', '18:00', '19:00'),
        ],
      ),
    );
    expect(e.onDay('2027-01-04'), isEmpty);
    expect(e.onDay('2027-01-05').map((r) => r.event.id), ['early', 'late']);
    expect(e.inWeek('2027-01-05').map((r) => r.event.id), ['early', 'late']);
    expect(e.inWeek('2027-01-11').single.event.id, 'outside');
  });
  test('D R: overlap detection retains both saved records; touching events are not overlaps', () {
    final data = initial(
      events: [
        event('one', '2027-01-05', '18:00', '19:00'),
        event('two', '2027-01-05', '18:30', '19:30'),
        event('touch', '2027-01-05', '19:30', '20:00'),
      ],
    );
    expect(engine(data).conflicts('2027-01-05').length, 1);
    expect(data.events.length, 3);
    expect(
      engine(data).recommendations().any((r) => r.code == 'conflict'),
      true,
    );
  });
  test('E F G H: confirmed windows subtract commitments, breaks and unavailable periods, obey days off', () {
    final data = initial(
      prefs: preferences(
        off: [3],
        unavailable: [
          {'date': '2027-01-05', 'startTime': '20:00', 'endTime': '20:30'},
        ],
      ),
      events: [
        event('school', '2027-01-05', '08:00', '15:00'),
        event('work', '2027-01-05', '16:00', '17:00'),
        event('meeting', '2027-01-05', '18:30', '19:00'),
      ],
    );
    final windows = engine(data).freeWindows('2027-01-05', 'study');
    expect(windows.map((w) => [w.start, w.end]), [
      [1080, 1095],
      [1155, 1200],
      [1230, 1260],
    ]);
    expect(engine(data).freeWindows('2027-01-06', 'study'), isEmpty);
    expect(engine(data).freeWindows('2027-01-09', 'study'), isEmpty);
    expect(windows.every((w) => w.start >= 1080 && w.end <= 1260), true);
  });
  test('missing availability is a clarification, never inferred free time', () {
    final data = initial(prefs: SchedulingPreferences());
    expect(
      () => engine(data).freeWindows('2027-01-05', 'study'),
      throwsA(isA<PlanningError>()),
    );
    expect(() => engine(data).plan(request()), throwsA(isA<PlanningError>()));
  });
  test('daily focus receives current local time and remaining confirmed windows instead of elapsed slots', () {
    final data = initial(
      prefs: SchedulingPreferences(
        timezone: 'Asia/Aqtau',
        studyStart: '18:00',
        studyEnd: '21:00',
        weekdays: [1, 2, 3, 4, 5],
        breakMinutes: 15,
        notAfter: '21:00',
      ),
      events: [event('commitment', '2026-10-12', '20:00', '20:30')],
      tasks: [
        Task(
          id: 'finished',
          title: 'Finished essay',
          category: 'Study',
          completed: true,
          dueDate: '2026-10-11',
        ),
      ],
    );
    final context = AgentContextBuilder.build(
      data,
      screen: 'home',
      now: DateTime.utc(2026, 10, 12, 14, 30),
    );
    final planning = context.visibleData['planning'] as Map;
    expect(planning['currentLocalTime'], '19:30');
    final availability = planning['todayAvailability'] as Map;
    expect((availability['study'] as Map)['confirmed'], true);
    expect((availability['study'] as Map)['windows'], [
      {'date': '2026-10-12', 'startTime': '19:31', 'endTime': '19:45'},
      {'date': '2026-10-12', 'startTime': '20:45', 'endTime': '21:00'},
    ]);
    expect((availability['work'] as Map)['confirmed'], false);
    expect((availability['work'] as Map)['windows'], isEmpty);
    expect(
      (planning['recommendations'] as List).any(
        (r) => r['title'] == 'Finished essay',
      ),
      false,
    );
    expect(
      (planning['todayCommitments'] as List).single['title'],
      'commitment',
    );
  });

  test('I O: recommendations use actual deadlines, importance, unscheduled activity and overload', () {
    final data = initial(
      tasks: [
        Task(
          id: 't',
          title: 'Essay',
          category: 'Task',
          dueDate: '2027-01-08',
          priority: 'high',
        ),
        Task(
          id: 'done',
          title: 'Done',
          category: 'Task',
          completed: true,
          completedAt: DateTime.utc(2027),
        ),
      ],
      events: [event('loaded', '2027-01-05', '18:00', '21:00', kind: 'study')],
    );
    final recommendations = engine(data).recommendations();
    expect(
      recommendations.any(
        (r) => r.code == 'unscheduledDeadline' && r.id == 't',
      ),
      true,
    );
    expect(recommendations.any((r) => r.code == 'overload'), true);
    expect(recommendations.any((r) => r.title == 'Done'), false);
  });
  test('J G H: three sessions are distributed across days within capacity and end-time limits', () {
    final calls = engine(initial()).plan(request());
    expect(calls.length, 3);
    expect(calls.map((r) => (r['arguments'] as Map)['date']), [
      '2027-01-11',
      '2027-01-12',
      '2027-01-13',
    ]);
    expect(
      calls.every(
        (r) =>
            (r['arguments'] as Map)['endTime'].toString().compareTo('21:00') <=
            0,
      ),
      true,
    );
    final oneDay = engine(initial(prefs: preferences(days: [2], workload: 180)))
        .plan(request(count: 2));
    final a = oneDay.first['arguments'] as Map,
        b = oneDay.last['arguments'] as Map;
    expect(
      clockMinutes(b['startTime'] as String) -
              clockMinutes(a['endTime'] as String) >=
          15,
      true,
    );
  });
  test('deadline and effort calculations avoid inventing dates or preparation status', () {
    final data = initial(
      tasks: [
        Task(
          id: 't',
          title: 'Essay',
          category: 'Task',
          dueDate: '2027-01-12',
          estimatedMinutes: 90,
        ),
      ],
    );
    final calls = engine(data).plan({...request(count: null), 'taskId': 't'});
    expect(calls.length, 2);
    expect((calls.last['arguments'] as Map)['endTime'], '18:30');
    expect(
      calls.every(
        (r) =>
            (r['arguments'] as Map)['date'].toString().compareTo(
              '2027-01-12',
            ) <=
            0,
      ),
      true,
    );
    expect(
      () => engine(initial()).plan(request(count: null)),
      throwsA(isA<PlanningError>()),
    );
  });
  test('impossible complete plan fails rather than returning partial invented slots', () {
    expect(
      () =>
          engine(initial(prefs: preferences(days: [2], workload: 60)))
              .plan(request()),
      throwsA(isA<PlanningError>()),
    );
  });
  test('K Q: pending multiple sessions do not mutate; reject-all never adds events', () async {
    final storage = TestStorage(initial());
    final repo = await LifeRepository.open(storage);
    await repo.proposeTools(registry, engine(repo.data).plan(request()));
    expect(repo.data.events, isEmpty);
    expect(repo.data.actionProposals.length, 3);
    await repo.resolveActions(
      registry,
      repo.data.actionProposals.map((p) => p.id).toList(),
      approve: false,
    );
    expect(repo.data.events, isEmpty);
    expect(
      repo.data.actionProposals.every((p) => p.status == 'rejected'),
      true,
    );
    repo.dispose();
  });
  test('L: modifying Tuesday pending session preserves the group and invalidates old approvals', () async {
    final repo = await LifeRepository.open(TestStorage(initial()));
    await repo.proposeTools(registry, engine(repo.data).plan(request()));
    final old = repo.data.actionProposals
        .where((p) => p.status == 'pending')
        .toList();
    final selected = old.singleWhere(
      (p) => p.arguments['date'] == '2027-01-12',
    );
    final calls = PlanningTools.calculate(repo.data, 'modify_pending_session', {
      'actionId': selected.id,
      'weekday': 4,
    });
    await repo.proposeTools(registry, calls);
    expect(
      repo.data.actionProposals.where((p) => p.status == 'pending').length,
      3,
    );
    expect(
      repo.data.actionProposals
          .where((p) => p.status == 'pending')
          .any((p) => p.arguments['date'] == '2027-01-12'),
      false,
    );
    expect(
      repo.data.actionProposals
          .where((p) => p.status == 'pending')
          .any((p) => p.arguments['date'] == '2027-01-14'),
      true,
    );
    expect(
      (await repo.resolveAction(registry, selected.id, approve: true))['ok'],
      false,
    );
    expect(repo.data.events, isEmpty);
    repo.dispose();
  });
  test('M N: atomic approve-all and durable receipts survive native restart without duplicates', () async {
    SharedPreferences.setMockInitialValues({});
    final folder = await Directory.systemTemp.createTemp('orta-planning-');
    final storage = StorageService(directory: folder);
    final repo = await LifeRepository.open(storage);
    await repo.saveSchedulingPreferences(preferences());
    await repo.proposeTools(registry, engine(repo.data).plan(request()));
    final ids = repo.data.actionProposals.map((p) => p.id).toList();
    expect(
      (await repo.resolveActions(registry, ids, approve: true))['ok'],
      true,
    );
    expect(repo.data.events.length, 3);
    final reopened = await LifeRepository.open(storage);
    expect(reopened.data.scheduling.notAfter, '21:00');
    expect(reopened.data.events.length, 3);
    await reopened.resolveActions(registry, ids, approve: true);
    expect(reopened.data.events.length, 3);
    repo.dispose();
    reopened.dispose();
    await folder.delete(recursive: true);
  });
  test('R: a new conflict before batch approval rolls back the whole group with no partial execution', () async {
    final repo = await LifeRepository.open(TestStorage(initial()));
    await repo.proposeTools(registry, engine(repo.data).plan(request()));
    await repo.saveEvent(event('new', '2027-01-12', '18:00', '19:00'));
    final ids = repo.data.actionProposals.map((p) => p.id).toList();
    expect(
      (await repo.resolveActions(registry, ids, approve: true))['ok'],
      false,
    );
    expect(repo.data.events.map((e) => e.id), ['new']);
    expect(repo.data.actionProposals.every((p) => p.status == 'failed'), true);
    repo.dispose();
  });
  test('storage failure publishes neither sessions nor approval receipts, and retry commits once', () async {
    final storage = TestStorage(initial()),
        repo = await LifeRepository.open(TestStorage(initial()));
    repo.dispose();
    final actual = await LifeRepository.open(storage);
    await actual.proposeTools(registry, engine(actual.data).plan(request()));
    final ids = actual.data.actionProposals.map((p) => p.id).toList();
    storage.fail = true;
    await expectLater(
      actual.resolveActions(registry, ids, approve: true),
      throwsStateError,
    );
    expect(actual.data.events, isEmpty);
    expect(
      actual.data.actionProposals.every((p) => p.status == 'pending'),
      true,
    );
    storage.fail = false;
    await actual.resolveActions(registry, ids, approve: true);
    expect(actual.data.events.length, 3);
    actual.dispose();
  });
  test('P: stored timezone changes the local day; foreign-zone events project to the correct date', () {
    final data = initial(
      events: [
        event(
          'foreign',
          '2027-01-04',
          '20:00',
          '21:00',
          zone: 'America/New_York',
        ),
      ],
    );
    final e = SchedulingEngine(
      data,
      nowOverride: DateTime.utc(2027, 1, 4, 21, 30),
    );
    expect(e.today, '2027-01-05');
    expect(e.onDay('2027-01-04'), isEmpty);
    expect(e.onDay('2027-01-05').single.start, 360);
    expect(e.onDay('2027-01-05').single.end, 420);
    final midnight = engine(
      initial(
        events: [
          event(
            'spans',
            '2027-01-04',
            '13:00',
            '15:00',
            zone: 'America/New_York',
          ),
        ],
      ),
    );
    expect(midnight.onDay('2027-01-04').single.end, 1440);
    expect(midnight.onDay('2027-01-05').single.end, 60);
  });
  test('DST: nonexistent and ambiguous wall-clock sessions are never normalized silently', () {
    final e = engine(initial(prefs: preferences(zone: 'America/New_York')));
    expect(e.stableClock('2027-03-14', 120, 180), false);
    expect(e.stableClock('2027-11-07', 60, 120), false);
    expect(e.stableClock('2027-03-14', 1080, 1140), true);
  });
  test(
    'all-day events block full dates and do not fabricate times or recurrence',
    () {
      final data = initial(
        events: [event('all', '2027-01-05', '', '', allDay: true)],
      );
      data.validate();
      expect(engine(data).onDay('2027-01-05').single.end, 1440);
      expect(engine(data).freeWindows('2027-01-05', 'study'), isEmpty);
      expect(
        () => registry.validate('create_calendar_event', {
          'title': 'Recurring',
          'date': '2027-01-05',
          'isAllDay': true,
          'recurrence': 'weekly',
        }),
        throwsA(isA<ToolFailure>()),
      );
    },
  );
  test('preference changes invalidate prior scheduling constraints; passed time does not complete sessions', () async {
    final repo = await LifeRepository.open(TestStorage(initial()));
    await repo.proposeTools(registry, engine(repo.data).plan(request()));
    await repo.saveSchedulingPreferences(preferences(pause: 30));
    expect(
      (await repo.resolveActions(
        registry,
        repo.data.actionProposals.map((p) => p.id).toList(),
        approve: true,
      ))['ok'],
      false,
    );
    expect(repo.data.events, isEmpty);
    final past = initial(
      events: [event('past', '2025-01-06', '18:00', '19:00', kind: 'study')],
    );
    expect(past.events.single.completedAt, isNull);
    repo.dispose();
  });
  test('schema 1/2 data is preserved; preference/array schemas reject invalid numbers and duplicates', () {
    for (final version in [1, 2]) {
      final j = initial().toJson()
        ..['schemaVersion'] = version
        ..remove('scheduling');
      expect(LifeData.fromJson(j).life.name, 'Planner');
    }
    for (final args in [
      {
        'weekdays': [1, 1],
      },
      {
        'weekdays': [8],
      },
      {'breakMinutes': -1},
      {'sessionMinutes': 15.5},
    ]) {
      expect(
        () => registry.validate('update_planning_preferences', args),
        throwsA(isA<ToolFailure>()),
      );
    }
    expect(
      () => preferences(zone: 'Invalid/Zone').validate(),
      throwsFormatException,
    );
    expect(jsonEncode(initial().toJson()), isNot(contains('GROQ_API_KEY')));
  });
  testWidgets(
    'A B O: calendar widgets filter real dates; Home renders actual recommendation facts',
    (tester) async {
      final now = SchedulingEngine(initial()).today,
          next = SchedulingEngine.shift(now, 7);
      final data = initial(
        events: [
          event('today', now, '18:00', '19:00', title: 'Today commitment'),
          event('later', next, '18:00', '19:00', title: 'Later commitment'),
        ],
        tasks: [
          Task(
            id: 'urgent',
            title: 'Real essay',
            category: 'Task',
            dueDate: SchedulingEngine.shift(now, 3),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlanningCalendar(data: data)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Today commitment'), findsOneWidget);
      expect(find.text('Later commitment'), findsNothing);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(find.text('Later commitment'), findsOneWidget);
      expect(find.text('Today commitment'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DailyOverview(data: data)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Real essay'), findsOneWidget);
      expect(find.text('Today commitment'), findsOneWidget);
    },
  );
  test(
    'all new planning messages and date labels are translated for en/ru/kk',
    () {
      for (final key in [
        'preferences',
        'availability',
        'constraints',
        'conflict',
        'approveAll',
        'batchFailed',
        'today',
        'free',
      ]) {
        expect(
          planningText(Language.english, key) !=
              planningText(Language.russian, key),
          true,
        );
        expect(
          planningText(Language.english, key) !=
              planningText(Language.kazakh, key),
          true,
        );
      }
      expect(planningDate(Language.russian, '2027-01-05'), startsWith('Вт'));
      expect(planningDate(Language.kazakh, '2027-01-05'), startsWith('Сс'));
    },
  );
  test('review regression: inferred effort credits completed and reserved intervals without double planning', () {
    final completed = CalendarEvent.fromJson({
      ...event('done', '2026-12-28', '18:00', '19:00', task: 'task').toJson(),
      'completedAt': '2026-12-28T15:00:00Z',
    });
    final reserved = event(
      'reserved',
      '2027-01-05',
      '18:00',
      '18:15',
      task: 'task',
    );
    final data = initial(
      tasks: [
        Task(
          id: 'task',
          title: 'Essay',
          category: 'Task',
          estimatedMinutes: 120,
        ),
      ],
      events: [completed, reserved],
    );
    expect(engine(data).remainingEffort('task', 120), 45);
    final calls = engine(data)
        .plan({...request(count: null), 'taskId': 'task'});
    expect(calls.length, 1);
    expect((calls.single['arguments'] as Map)['endTime'], '18:45');
    expect(
      () => engine(data).plan({
        ...request(count: null),
        'taskId': 'task',
        'durationMinutes': 15,
        'period': 'custom',
        'startDate': '2027-01-01',
        'endDate': '2027-01-31',
      }),
      returnsNormally,
    );
  });
  test('review regression: an explicit planning deadline survives pending edits and approval validation', () async {
    final repo = await LifeRepository.open(TestStorage(initial()));
    await repo.proposeTools(
      registry,
      engine(repo.data).plan({...request(count: 1), 'deadline': '2027-01-12'}),
    );
    final pending = repo.data.actionProposals.single;
    expect(pending.arguments['planningDeadline'], '2027-01-12');
    final revised = PlanningTools.calculate(
      repo.data,
      'modify_pending_session',
      {'actionId': pending.id, 'targetDate': '2027-01-13'},
    );
    await expectLater(
      repo.proposeTools(registry, revised),
      throwsA(isA<ToolFailure>()),
    );
    expect(repo.data.events, isEmpty);
    repo.dispose();
  });
  test('review regression: ordinary event DST gaps and thirty-minute folds fail before storage', () async {
    final repo = await LifeRepository.open(TestStorage(initial()));
    await expectLater(
      repo.proposeTools(registry, [
        {
          'name': 'create_calendar_event',
          'arguments': {
            'title': 'Invalid clock',
            'date': '2027-03-14',
            'startTime': '02:30',
            'endTime': '03:30',
            'timezone': 'America/New_York',
          },
        },
      ]),
      throwsA(isA<ToolFailure>()),
    );
    expect(
      engine(initial())
          .stableClock('2027-04-04', 90, 105, timezone: 'Australia/Lord_Howe'),
      false,
    );
    expect(repo.data.events, isEmpty);
    repo.dispose();
  });
  test('review regression: completing a linked task before approval invalidates its pending sessions', () async {
    final repo = await LifeRepository.open(
      TestStorage(
        initial(
          tasks: [Task(id: 'task', title: 'Essay', category: 'Task')],
        ),
      ),
    );
    await repo.proposeTools(
      registry,
      engine(repo.data).plan({...request(count: 1), 'taskId': 'task'}),
    );
    await repo.completeTask('task', true);
    expect(
      (await repo.resolveActions(
        registry,
        repo.data.actionProposals.map((p) => p.id).toList(),
        approve: true,
      ))['ok'],
      false,
    );
    expect(repo.data.events, isEmpty);
    repo.dispose();
  });
  test('review regression: reversed approval IDs execute dependent proposals in stored order', () async {
    final repo = await LifeRepository.open(TestStorage(initial()));
    await repo.proposeTools(registry, [
      {
        'name': 'update_planning_preferences',
        'arguments': {'breakMinutes': 30},
      },
      ...engine(repo.data).plan(request()),
    ]);
    final ids = repo.data.actionProposals
        .map((p) => p.id)
        .toList()
        .reversed
        .toList();
    expect(
      (await repo.resolveActions(registry, ids, approve: true))['ok'],
      true,
    );
    expect(repo.data.scheduling.breakMinutes, 30);
    expect(repo.data.events.length, 3);
    repo.dispose();
  });
  test('review regression: all-day events with floating legacy timezone can be moved', () async {
    final repo = await LifeRepository.open(
      TestStorage(
        initial(
          events: [event('all', '2027-01-11', '', '', allDay: true, zone: '')],
        ),
      ),
    );
    final calls = PlanningTools.calculate(
      repo.data,
      'reschedule_calendar_event',
      {'id': 'all', 'weekday': 4},
    );
    await repo.proposeTools(registry, calls);
    expect(
      (await repo.resolveAction(
        registry,
        repo.data.actionProposals.single.id,
        approve: true,
      ))['ok'],
      true,
    );
    expect(repo.data.events.single.date, '2027-01-14');
    expect(repo.data.events.single.isAllDay, true);
    repo.dispose();
  });
  testWidgets(
    'collapsed chat remains usable when the keyboard reduces the available height',
    (tester) async {
      final repo = await LifeRepository.open(TestStorage(initial()));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(520, 402),
                viewInsets: EdgeInsets.only(bottom: 150),
              ),
              child: AgentSheet(
                repository: repo,
                contextBuilder: () =>
                    AgentContextBuilder.build(repo.data, screen: 'home'),
                agentService: MockOrtaAgentService(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.send).hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );

  testWidgets(
    'real-layout regression: multi-action sheet can expand and collapse without overflowing',
    (tester) async {
      final repo = await LifeRepository.open(TestStorage(initial()));
      await repo.proposeTools(registry, engine(repo.data).plan(request()));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AgentSheet(
                    repository: repo,
                    contextBuilder: () =>
                        AgentContextBuilder.build(repo.data, screen: 'plan'),
                    agentService: MockOrtaAgentService(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Approve all'), findsOneWidget);
      await tester.tap(find.byTooltip('Collapse conversation'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
}
