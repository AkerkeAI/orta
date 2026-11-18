import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/models/orta_models.dart';
import 'package:orta/models/user_profile.dart';
import 'package:orta/screens/language_orta/language_orta_screen.dart';
import 'package:orta/services/language_orta_strings.dart';
import 'package:orta/services/language_practice_service.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/localization_service.dart';
import 'package:orta/services/storage_service.dart';

const _life = LifeContext(
  name: 'Private name',
  interfaceLanguage: Language.russian,
  currentLifeAreas: {LifeArea.university, LifeArea.project},
  otherDescription: 'Private health detail',
  goals: [
    GoalContext(
      id: 'goal-private',
      titleKey: 'Private goal title',
      areaKey: 'education',
      details: {'notes': 'Private notes'},
    ),
  ],
  projects: [
    ProjectContext(id: 'project-private', name: 'Private project name'),
  ],
  exams: [ExamContext(id: 'exam-private', name: 'Private exam name')],
  languages: [
    LanguageContext(languageCode: 'it', level: 'A2'),
    LanguageContext(languageCode: 'de', level: 'B1'),
  ],
  commitments: ['Private commitment'],
);

UserProfile get _profile => UserProfile(
  name: _life.name,
  nativeLanguage: Language.russian,
  learningLanguage: Language.english,
  level: LanguageLevel.c1,
  wakeUpTime: '07:00',
  sleepTime: '23:00',
);

class _Storage implements LifeDataStorage {
  LifeData value = LifeData(life: _life, onboardingCompleted: true);
  bool fail = false;
  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(value.toJson());
  @override
  Future<void> saveLifeData(LifeData data) async {
    if (fail) throw StateError('Storage failed');
    value = LifeData.fromJson(data.toJson());
  }
}

Widget _app({
  String code = 'it',
  AppLocale locale = AppLocale.english,
  LifeRepository? repository,
  Future<void> Function(String, String, String)? onSave,
  Future<void> Function(String)? onMoment,
  List<LanguageMemory> memories = const [],
  double textScale = 1,
}) {
  final progress = repository?.languageProgress(code);
  return MaterialApp(
    locale: Locale(locale.languageCode),
    supportedLocales: const [Locale('en'), Locale('ru'), Locale('kk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: LanguageOrtaScreen(
      userProfile: _profile,
      languageCode: code,
      lifeContext: repository?.lifeView ?? _life,
      languageLevel: progress?.level,
      currentLocale: locale,
      practiceHistory: progress?.practiceHistory ?? const [],
      completedSessions: progress?.completedSessions ?? 0,
      memories: progress?.memories ?? memories,
      onSavePractice:
          onSave ??
          (repository == null
              ? null
              : (code, topic, response) => repository.recordPractice(
                  code,
                  topicKey: topic,
                  response: response,
                )),
      onAddMemory: onMoment,
      onBack: () {},
    ),
  );
}

Future<void> _save(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('saveLanguagePractice'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test('safe exercise topics use only broad categories', () {
    final before = jsonEncode(_life.toJson());
    final topics = LanguagePracticeService.topicsFor(_life);
    expect(topics, ['daily', 'education', 'exam', 'project', 'goal']);
    expect(
      LanguagePracticeService.topicsFor(
        _life.copyWith(
          name: 'A different private name',
          otherDescription: 'Different private details',
          commitments: ['A different commitment'],
          preferences: {'secret': 'never use this'},
        ),
      ),
      topics,
    );
    expect(topics.join(' '), isNot(contains('Private')));
    expect(jsonEncode(_life.toJson()), before);
    expect(() => topics.add('private'), throwsUnsupportedError);
    expect(LanguagePracticeService.topicsFor(null), ['daily']);
  });

  test('every Language ORTA string and topic exists in all three locales', () {
    final english = LanguageOrtaStrings.translations[AppLocale.english]!;
    for (final locale in AppLocale.values) {
      final translated = LanguageOrtaStrings.translations[locale]!;
      expect(translated.keys.toSet(), english.keys.toSet());
      expect(translated.values.every((value) => value.isNotEmpty), isTrue);
      for (final topic in LanguagePracticeService.supportedTopics) {
        expect(translated.containsKey(topic), isTrue);
        expect(translated.containsKey('${topic}Prompt'), isTrue);
      }
      expect(
        LanguageOrtaStrings(locale)
            .text('dailyPrompt', {'language': 'Italiano'}),
        isNot(contains('{language}')),
      );
    }
  });

  testWidgets('selected target and its level override the legacy profile', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: AppLocale.russian));
    await tester.pumpAndSettle();
    final name = AppLocalizations(AppLocale.russian).languageName('it');
    expect(find.text('LANGUAGE ORTA · $name'), findsOneWidget);
    expect(find.text('$name · A2'), findsOneWidget);
    expect(find.textContaining('C1'), findsNothing);
    expect(find.text('Письменная практика'), findsOneWidget);
    expect(find.textContaining('Private project'), findsNothing);
    expect(find.textContaining('Private name'), findsNothing);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('saveLanguagePractice')),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty practice cannot save and failed saving preserves the draft',
    (tester) async {
      var calls = 0;
      var fail = true;
      String? savedCode;
      String? savedResponse;
      await tester.pumpWidget(
        _app(
          onSave: (code, topic, response) async {
            calls++;
            savedCode = code;
            savedResponse = response;
            expect(topic, 'daily');
            if (fail) throw StateError('Failed write');
          },
        ),
      );
      await tester.pumpAndSettle();
      await _save(tester);
      expect(calls, 0);
      expect(find.text('Write a response before saving.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('languagePracticeResponse')),
        '  Oggi studio italiano.  ',
      );
      await _save(tester);
      expect(calls, 1);
      expect(savedCode, 'it');
      expect(savedResponse, 'Oggi studio italiano.');
      expect(find.textContaining('Could not save.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('languagePracticeResponse')),
            )
            .controller!
            .text,
        '  Oggi studio italiano.  ',
      );
      fail = false;
      await _save(tester);
      expect(calls, 2);
      expect(find.text('Practice saved'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('saveLanguagePractice')),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'practice survives reopen, stays per-language, and preserves Core',
    (tester) async {
      final storage = _Storage();
      final repository = await LifeRepository.open(storage);
      final before = jsonEncode(repository.data.life.toJson());
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('languagePracticeResponse')),
        'Oggi preparo un progetto.',
      );
      await _save(tester);
      expect(repository.languageProgress('it').completedSessions, 1);
      expect(repository.languageProgress('de').completedSessions, 0);
      expect(jsonEncode(repository.data.life.toJson()), before);
      expect(repository.data.tasks, isEmpty);
      expect(repository.data.events, isEmpty);
      expect(repository.data.conversation, isEmpty);
      final restored = await LifeRepository.open(storage);
      await tester.pumpWidget(_app(repository: restored));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practice history'));
      await tester.pumpAndSettle();
      expect(find.text('Oggi preparo un progetto.'), findsOneWidget);
      expect(find.text('Saved sessions: 1'), findsOneWidget);
      await tester.pumpWidget(_app(code: 'de', repository: restored));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practice history'));
      await tester.pumpAndSettle();
      expect(find.text('Oggi preparo un progetto.'), findsNothing);
      expect(find.text('Saved sessions: 0'), findsOneWidget);
      repository.dispose();
      restored.dispose();
    },
  );

  testWidgets('switching targets clears the previous language draft', (
    tester,
  ) async {
    await tester.pumpWidget(_app(onSave: (_, _, _) async {}));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('languagePracticeResponse')),
      'An Italian draft',
    );
    await tester.pumpWidget(_app(code: 'de', onSave: (_, _, _) async {}));
    await tester.pumpAndSettle();
    expect(find.text('German · B1'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('languagePracticeResponse')),
    );
    expect(field.controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending save cannot be submitted twice', (tester) async {
    final saved = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        onSave: (_, _, _) {
          calls++;
          return saved.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('languagePracticeResponse')),
      'Oggi studio.',
    );
    final button = find.byKey(const ValueKey('saveLanguagePractice'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
    saved.complete();
    await tester.pumpAndSettle();
    expect(find.text('Practice saved'), findsOneWidget);
  });

  for (final locale in AppLocale.values) {
    testWidgets('small-screen practice and moments fit in ${locale.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = LanguageOrtaStrings(locale);
      await tester.pumpWidget(
        _app(
          locale: locale,
          textScale: 1.4,
          onSave: (_, _, _) async {},
          onMoment: (_) async {},
          memories: [
            LanguageMemory(
              id: 'wrong-language',
              title: 'Moment',
              context: '',
              phrase: 'Das ist nur Deutsch',
              meaning: '',
              language: 'de',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Das ist nur Deutsch'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('languagePracticeResponse')),
        'Oggi imparo italiano.',
      );
      await _save(tester);
      expect(find.text(strings.text('savedPractice')), findsOneWidget);
      await tester.tap(find.text(strings.text('moments')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.text('addMoment')));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('momentAbout')), findsOneWidget);
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Buongiorno');
      await tester.pump();
      await tester.tap(find.text(strings.text('save')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(strings.text('momentSaved')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
