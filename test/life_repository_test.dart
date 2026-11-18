import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/models/orta_models.dart';
import 'package:orta/services/storage_service.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/agent_context_builder.dart';
import 'package:orta/services/localization_service.dart';
import 'package:orta/screens/core/orta_shell.dart';

const initialLife = LifeContext(
  name: 'Storage Test',
  interfaceLanguage: Language.russian,
  currentLifeAreas: {LifeArea.work},
  otherDescription: 'Working and studying',
  preferences: {'timezone': 'Asia/Aqtau', 'wakeUpTime': '07:00'},
  goals: [
    GoalContext(
      id: 'goal-1',
      titleKey: 'IELTS preparation',
      areaKey: 'education',
    ),
  ],
  exams: [ExamContext(id: 'exam-1', name: 'IELTS', date: '2027-06-12')],
  projects: [ProjectContext(id: 'project-1', name: 'Portfolio')],
);

class FailingStorage implements LifeDataStorage {
  LifeData saved = LifeData(life: initialLife, onboardingCompleted: true);
  bool fail = false;
  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(saved.toJson());
  @override
  Future<void> saveLifeData(LifeData data) async {
    if (fail) throw StateError('Disk write failed');
    saved = LifeData.fromJson(data.toJson());
  }
}

late Directory testDirectory;
StorageService testStorage() => StorageService(directory: testDirectory);
Future<LifeRepository> fresh() async {
  SharedPreferences.setMockInitialValues({});
  final repository = await LifeRepository.open(testStorage());
  await repository.completeOnboarding(initialLife);
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp('orta-storage-test-');
  });
  tearDown(() async {
    await testDirectory.delete(recursive: true);
  });

  test('A–D: onboarding, preferences, goals, exams, projects survive repository restart', () async {
    final repo = await fresh();
    await repo.saveGoal(
      const GoalContext(
        id: 'goal-2',
        titleKey: 'Write essay',
        areaKey: 'university',
      ),
    );
    await repo.saveExam(
      const ExamContext(id: 'exam-2', name: 'ENT', date: '2027-05-20'),
    );
    await repo.saveProject(
      const ProjectContext(id: 'project-2', name: 'ORTA project'),
    );
    repo.dispose();
    final restored = await LifeRepository.open(testStorage());
    expect(restored.data.onboardingCompleted, isTrue);
    expect(restored.data.life.name, 'Storage Test');
    expect(restored.data.life.interfaceLanguage, Language.russian);
    expect(restored.data.life.preferences['timezone'], 'Asia/Aqtau');
    expect(restored.data.life.otherDescription, 'Working and studying');
    expect(restored.data.life.goals.map((g) => g.id), ['goal-1', 'goal-2']);
    expect(restored.data.life.exams.map((e) => e.id), ['exam-1', 'exam-2']);
    expect(restored.data.life.projects.map((p) => p.id), [
      'project-1',
      'project-2',
    ]);
    restored.dispose();
  });

  test(
    'E–G: task/event relationships and actual completion survive restart',
    () async {
      final repo = await fresh();
      await repo.saveTask(
        Task(
          id: 'task-1',
          title: 'Practice listening',
          category: 'Preparation',
          goalId: 'goal-1',
          examId: 'exam-1',
          projectId: 'project-1',
          dueDate: '2027-06-10',
          domain: LifeDomain.education,
        ),
      );
      await repo.saveEvent(
        CalendarEvent(
          id: 'event-1',
          title: 'Listening session',
          date: '2027-06-01',
          startTime: '18:00',
          endTime: '18:30',
          category: 'Preparation',
          taskId: 'task-1',
          examId: 'exam-1',
        ),
      );
      expect(repo.data.completedTasks, isEmpty);
      await repo.completeTask('task-1', true);
      final completedAt = repo.data.completedTasks.single.completedAt;
      await repo.completeTask('task-1', true);
      expect(repo.data.completedTasks.single.completedAt, completedAt);
      repo.dispose();
      final restored = await LifeRepository.open(testStorage());
      expect(restored.data.completedTasks.single.id, 'task-1');
      expect(restored.data.tasks.single.domain, LifeDomain.education);
      expect(restored.data.tasks.single.goalId, 'goal-1');
      expect(restored.data.events.single.taskId, 'task-1');
      expect(restored.data.events.single.examId, 'exam-1');
      await restored.completeTask('task-1', false);
      expect(restored.data.completedTasks, isEmpty);
      restored.dispose();
    },
  );

  test('H: Life and Plan share the same exam ID, update and delete without duplicate events', () async {
    final repo = await fresh();
    expect(
      AgentContextBuilder.plan(repo.data).single.id,
      repo.data.life.exams.single.id,
    );
    await repo.saveExam(
      const ExamContext(
        id: 'exam-1',
        name: 'IELTS updated',
        date: '2027-07-12',
      ),
      create: false,
    );
    final plan = AgentContextBuilder.plan(repo.data);
    expect(plan.length, 1);
    expect(plan.single.title, 'IELTS updated');
    expect(plan.single.date, '2027-07-12');
    expect(repo.data.events, isEmpty);
    await repo.deleteRecord('exam', 'exam-1');
    expect(AgentContextBuilder.plan(repo.data), isEmpty);
    repo.dispose();
  });

  test('I: bounded Agent context reflects freshly persisted tasks, schedule and selected item', () async {
    final repo = await fresh();
    await repo.saveProject(
      const ProjectContext(id: 'project-latest', name: 'New stored project'),
    );
    await repo.saveTask(
      Task(
        id: 'task-latest',
        title: 'New stored deadline',
        category: 'Task',
        projectId: 'project-latest',
        dueDate: '2027-06-11',
      ),
    );
    await repo.saveEvent(
      CalendarEvent(
        id: 'event-latest',
        title: 'New stored session',
        date: '2027-06-01',
        startTime: '18:00',
        endTime: '19:00',
        category: 'Study',
        projectId: 'project-latest',
      ),
    );
    final reopened = await LifeRepository.open(testStorage());
    final context = AgentContextBuilder.build(
      reopened.data,
      screen: 'life',
      entityType: 'project',
      entityId: 'project-latest',
      now: DateTime(2027, 5, 1),
    );
    expect(context.currentEntityId, 'project-latest');
    expect(
      context.relevantLifeContext.projects.first.name,
      'New stored project',
    );
    expect(jsonEncode(context.visibleData), contains('New stored deadline'));
    expect(jsonEncode(context.visibleData), contains('New stored session'));
    expect(jsonEncode(context.toJson()).length, lessThan(18000));
    repo.dispose();
    reopened.dispose();
  });

  test('J: language levels, moments, maps and practice counts stay separate and cannot mutate Core', () async {
    final repo = await fresh();
    final before = jsonEncode(repo.data.life.toJson());
    await repo.saveLanguageProgress(
      LanguageProgress(
        languageCode: 'it',
        level: 'A1',
        lifeMap: [
          LifeMapCategory(
            name: 'Conversation',
            value: 20,
            description: 'Recorded assessment',
          ),
        ],
      ),
    );
    await repo.saveLanguageProgress(
      LanguageProgress(languageCode: 'de', level: 'B2'),
    );
    await repo.addLanguageMoment('it', 'Ciao');
    await repo.addLanguageMoment('de', 'Hallo');
    await repo.recordPractice('it');
    expect(jsonEncode(repo.data.life.toJson()), before);
    repo.dispose();
    final restored = await LifeRepository.open(testStorage());
    expect(restored.languageProgress('it').memories.single.phrase, 'Ciao');
    expect(restored.languageProgress('de').memories.single.phrase, 'Hallo');
    expect(restored.languageProgress('it').completedSessions, 1);
    expect(restored.languageProgress('de').completedSessions, 0);
    expect(restored.languageProgress('it').level, 'A1');
    expect(restored.languageProgress('de').level, 'B2');
    expect(restored.languageProgress('it').lifeMap.single.value, 20);
    await expectLater(
      restored.saveLanguageProgress(
        LanguageProgress(
          languageCode: 'it',
          memories: [
            LanguageMemory(
              id: 'invalid',
              title: 'Wrong',
              context: '',
              phrase: 'Hallo',
              meaning: '',
              language: 'de',
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
    restored.dispose();
  });

  test('K: migration preserves legacy raw data and assigns stable IDs without dropping records', () async {
    final legacy = initialLife.toJson();
    legacy['projects'] = [
      {'name': 'First'},
      {'id': 'same', 'name': 'Second'},
      {'id': 'same', 'name': 'Third'},
    ];
    legacy['customLegacyField'] = 'keep in original recovery key';
    final raw = jsonEncode(legacy);
    SharedPreferences.setMockInitialValues({
      'life_context': raw,
      'onboarding_completed': true,
      'user_profile': '{"name":"Legacy backup"}',
    });
    final repo = await LifeRepository.open(testStorage());
    expect(repo.data.life.projects.length, 3);
    final ids = repo.data.life.projects.map((p) => p.id).toList();
    expect(ids.toSet().length, 3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('life_context'), raw);
    expect(prefs.getString('user_profile'), '{"name":"Legacy backup"}');
    repo.dispose();
    final restored = await LifeRepository.open(testStorage());
    expect(restored.data.life.projects.map((p) => p.id), ids);
    expect(restored.data.life.goals.single.id, 'goal-1');
    restored.dispose();
  });

  test('L: API credential fields and recognizable secret values are rejected before persistence', () async {
    final repo = await fresh();
    await expectLater(
      repo.updateLife(
        (life) =>
            life.copyWith(preferences: {'GROQ_API_KEY': 'not-a-real-secret'}),
      ),
      throwsFormatException,
    );
    final fakeCredential = 'gsk_${List.filled(30, 'x').join()}';
    await expectLater(
      repo.appendMessage(fakeCredential, isUser: true),
      throwsFormatException,
    );
    expect(repo.data.conversation, isEmpty);
    expect(
      await File('${testDirectory.path}/orta/life-data.json').readAsString(),
      isNot(contains(fakeCredential)),
    );
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(
        file.readAsStringSync(),
        isNot(
          matches(RegExp(r'gsk_[A-Za-z0-9]{20,}|sk-proj-[A-Za-z0-9_-]{20,}')),
        ),
        reason: file.path,
      );
    }
    repo.dispose();
  });

  test('conversation persists without proposals or execution rights and is bounded to 50 messages', () async {
    final repo = await fresh();
    for (var i = 0; i < 55; i++) {
      await repo.appendMessage('Message $i', isUser: i.isEven);
    }
    repo.dispose();
    final restored = await LifeRepository.open(testStorage());
    expect(restored.data.conversation.length, 50);
    expect(restored.data.conversation.first.text, 'Message 5');
    expect(restored.data.conversation.last.text, 'Message 54');
    expect(
      restored.data.conversation.every(
        (m) => m.id != null && m.proposal == null,
      ),
      isTrue,
    );
    restored.dispose();
  });

  test('failed writes retain old state, send no notification, and permit later recovery', () async {
    final storage = FailingStorage();
    final repo = await LifeRepository.open(storage);
    var notifications = 0;
    repo.addListener(() => notifications++);
    storage.fail = true;
    await expectLater(
      repo.saveProject(const ProjectContext(id: 'failed', name: 'Unsaved')),
      throwsStateError,
    );
    expect(repo.data.life.projects.length, 1);
    expect(notifications, 0);
    storage.fail = false;
    await repo.saveProject(const ProjectContext(id: 'saved', name: 'Saved'));
    expect(notifications, 1);
    expect((await storage.loadLifeData()).life.projects.last.id, 'saved');
    repo.dispose();
  });

  test('serialized concurrent writes do not lose records', () async {
    final storage = FailingStorage();
    final repo = await LifeRepository.open(storage);
    await Future.wait(
      List.generate(
        10,
        (i) => repo.saveProject(ProjectContext(id: 'p$i', name: 'Project $i')),
      ),
    );
    expect(repo.data.life.projects.length, 11);
    expect((await storage.loadLifeData()).life.projects.length, 11);
    repo.dispose();
  });

  test('duplicate creates, orphan links, invalid dates and deleting referenced records fail safely', () async {
    final repo = await fresh();
    await expectLater(
      repo.saveProject(
        const ProjectContext(id: 'project-1', name: 'Duplicate'),
      ),
      throwsStateError,
    );
    await expectLater(
      repo.saveTask(
        Task(
          id: 'orphan',
          title: 'Orphan',
          category: 'Task',
          projectId: 'missing',
        ),
      ),
      throwsFormatException,
    );
    await expectLater(
      repo.saveExam(
        const ExamContext(id: 'invalid', name: 'Invalid', date: '2027-02-30'),
      ),
      throwsFormatException,
    );
    await repo.saveTask(
      Task(
        id: 'linked',
        title: 'Linked',
        category: 'Task',
        projectId: 'project-1',
      ),
    );
    await expectLater(
      repo.deleteRecord('project', 'project-1'),
      throwsFormatException,
    );
    await repo.deleteRecord('task', 'linked');
    await repo.deleteRecord('project', 'project-1');
    expect(repo.data.life.projects, isEmpty);
    repo.dispose();
  });

  test('corrupt and future-version state remains untouched rather than being reset', () async {
    for (final raw in ['broken json', '{"schemaVersion":99}']) {
      SharedPreferences.setMockInitialValues({
        'life_context': jsonEncode(initialLife.toJson()),
      });
      final file = File('${testDirectory.path}/orta/life-data.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(raw, flush: true);
      await expectLater(
        LifeRepository.open(testStorage()),
        throwsA(isA<FormatException>()),
      );
      expect(
        await File('${testDirectory.path}/orta/life-data.json').readAsString(),
        raw,
      );
    }
  });

  test('native file-write failure preserves the primary snapshot and recovers after retry', () async {
    final repo = await fresh();
    final file = File('${testDirectory.path}/orta/life-data.json');
    final before = await file.readAsString();
    final blocker = Directory('${file.path}.pending');
    await blocker.create();
    await expectLater(
      repo.saveProject(
        const ProjectContext(id: 'failed-file', name: 'Unsaved file record'),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.readAsString(), before);
    expect(repo.data.life.projects.map((p) => p.id), ['project-1']);
    await blocker.delete();
    await repo.saveProject(
      const ProjectContext(id: 'retry-file', name: 'Saved after retry'),
    );
    final restored = await LifeRepository.open(testStorage());
    expect(restored.data.life.projects.last.id, 'retry-file');
    repo.dispose();
    restored.dispose();
  });

  test('selected old record is included before context limits, without sending language history', () async {
    final repo = await fresh();
    for (var i = 0; i < 20; i++) {
      await repo.saveExam(
        ExamContext(id: 'many-exam-$i', name: 'Exam $i', date: '2027-06-12'),
      );
    }
    await repo.addLanguageMoment('de', 'Private language-only phrase');
    final context = AgentContextBuilder.build(
      repo.data,
      screen: 'life',
      entityType: 'exam',
      entityId: 'many-exam-19',
      now: DateTime(2028),
    );
    expect(
      context.relevantLifeContext.exams.any((e) => e.id == 'many-exam-19'),
      isTrue,
    );
    expect(
      jsonEncode(context.toJson()),
      isNot(contains('Private language-only phrase')),
    );
    repo.dispose();
  });

  testWidgets(
    'completing a task in Plan updates Progress and survives widget recreation',
    (tester) async {
      final storage = FailingStorage();
      final repo = await LifeRepository.open(storage);
      await repo.saveTask(
        Task(id: 'ui-task', title: 'Visible completed task', category: 'Task'),
      );
      Widget shell(LifeRepository r) => MaterialApp(
        home: OrtaShell(
          repository: r,
          onResetOnboarding: () {},
          currentLocale: AppLocale.english,
        ),
      );
      await tester.pumpWidget(shell(repo));
      await tester.tap(find.text('PLAN'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      // The real application listens to the repository; recreate the wrapper to verify saved state.
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      final restored = await LifeRepository.open(storage);
      await tester.pumpWidget(shell(restored));
      await tester.tap(find.text('PROGRESS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Visible completed task'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      restored.dispose();
    },
  );
}
