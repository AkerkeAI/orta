import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orta/models/admissions_models.dart';
import 'package:orta/models/language_orta_models.dart';
import 'package:orta/screens/language_orta/language_orta_workspace.dart';
import 'package:orta/services/language_orta_access.dart';
import 'package:orta/services/language_orta_store.dart';

void main() {
  group('LanguageOrtaAccess', () {
    test('only the student role can open the module', () {
      expect(LanguageOrtaAccess.canOpen(OrtaRole.student), isTrue);
      expect(LanguageOrtaAccess.canOpen(OrtaRole.founder), isFalse);
      expect(LanguageOrtaAccess.canOpen(OrtaRole.mentor), isFalse);
      expect(LanguageOrtaAccess.canOpenRole('student'), isTrue);
      expect(LanguageOrtaAccess.canOpenRole('founder'), isFalse);
      expect(LanguageOrtaAccess.canOpenRole('mentor'), isFalse);
      expect(LanguageOrtaAccess.canOpenRole(''), isFalse);
    });

    test('navigation sections include Language ORTA only for students', () {
      const base = ['Dashboard', 'Tasks'];
      final student = LanguageOrtaAccess.sectionsForRole('student', base);
      expect(student, contains(LanguageOrtaAccess.moduleName));
      for (final role in ['founder', 'mentor', 'parent']) {
        expect(
          LanguageOrtaAccess.sectionsForRole(role, base),
          isNot(contains(LanguageOrtaAccess.moduleName)),
        );
      }
    });

    test('assertStudent rejects non-students and empty ids', () {
      expect(
        () => LanguageOrtaAccess.assertStudent(
          role: 'founder',
          studentId: 'user-1',
        ),
        throwsA(isA<LanguageOrtaDenied>()),
      );
      expect(
        () => LanguageOrtaAccess.assertStudent(role: 'student', studentId: ''),
        throwsA(isA<LanguageOrtaDenied>()),
      );
      expect(
        () => LanguageOrtaAccess.assertStudent(
          role: 'student',
          studentId: 'user-1',
        ),
        returnsNormally,
      );
    });
  });

  group('StudentLanguageOrtaStore ownership', () {
    test('cannot be constructed for founder or mentor roles', () {
      expect(
        () => StudentLanguageOrtaStore(studentId: 's1', role: 'founder'),
        throwsA(isA<LanguageOrtaDenied>()),
      );
      expect(
        () => StudentLanguageOrtaStore(studentId: 's1', role: 'mentor'),
        throwsA(isA<LanguageOrtaDenied>()),
      );
    });

    test('one student cannot read or write another student\'s data', () async {
      final storeA = StudentLanguageOrtaStore(
        studentId: 'student-a',
        role: 'student',
      );
      final storeB = StudentLanguageOrtaStore(
        studentId: 'student-b',
        role: 'student',
      );
      final added = await storeA.addLanguage('en');
      final second = await storeA.addLanguage('de');
      expect(
        (await storeA.profiles()).map((item) => item.languageCode),
        containsAll(['en', 'de']),
      );
      expect((await storeA.profiles()).length, 2);
      expect((await storeA.addLanguage('en')).id, added.id);
      expect(second.languageCode, 'de');
      expect(await storeB.profiles(), isEmpty);
      await expectLater(
        storeB.saveProfile(added),
        throwsA(isA<LanguageOrtaDenied>()),
      );
      await expectLater(
        storeB.saveSession(
          LanguagePracticeSession(
            id: 'sess-1',
            studentId: 'student-a',
            profileId: added.id,
            skill: PracticeSkill.writing,
            scenario: PracticeScenario.everyday,
            prompt: 'p',
            createdAt: DateTime.utc(2026),
          ),
        ),
        throwsA(isA<LanguageOrtaDenied>()),
      );
      await expectLater(
        storeB.saveResult(
          LanguageSessionResult(
            id: 'res-1',
            sessionId: 'sess-1',
            studentId: 'student-a',
            originalResponse: 'hi',
            createdAt: DateTime.utc(2026),
          ),
        ),
        throwsA(isA<LanguageOrtaDenied>()),
      );
    });

    test(
      'completed sessions persist and feed per-language skill progress',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        const key = 'language_orta_test_student';
        Future<StudentLanguageOrtaStore> open() async =>
            StudentLanguageOrtaStore(
              studentId: 's1',
              role: 'student',
              memory: MemoryLanguageSnapshotStore(
                StudentLanguageOrtaStore.loadFromPrefs(prefs, key),
              ),
              prefs: prefs,
              prefsKey: key,
            );
        final store = await open();
        final profile = await store.addLanguage('en');
        final session = LanguagePracticeSession(
          id: 'sess-1',
          studentId: 's1',
          profileId: profile.id,
          skill: PracticeSkill.writing,
          scenario: PracticeScenario.everyday,
          prompt: 'Write a sentence.',
          createdAt: DateTime.utc(2026),
        );
        await store.saveSession(session);
        await store.saveSession(session.copyWith(status: 'completed'));
        await store.saveResult(
          LanguageSessionResult(
            id: 'res-1',
            sessionId: session.id,
            studentId: 's1',
            originalResponse: 'I study.',
            createdAt: DateTime.utc(2026),
          ),
        );
        final reloaded = await open();
        final sessions = await reloaded.sessions(profileId: profile.id);
        expect(sessions.single.completed, isTrue);
        expect(
          (await reloaded.resultFor(session.id))?.originalResponse,
          'I study.',
        );
        final progress = (await reloaded.profiles()).single;
        expect(progress.skillProgress['writing'], 1);
      },
    );
  });

  group('DeniedLanguageOrtaStore', () {
    test('every operation throws', () async {
      const store = DeniedLanguageOrtaStore();
      await expectLater(store.profiles(), throwsA(isA<LanguageOrtaDenied>()));
      await expectLater(
        store.addLanguage('en'),
        throwsA(isA<LanguageOrtaDenied>()),
      );
      await expectLater(store.sessions(), throwsA(isA<LanguageOrtaDenied>()));
    });
  });

  group('LanguageOrtaWorkspace gating', () {
    Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets(
      'founder and mentor see the denied state, never practice data',
      (tester) async {
        for (final role in ['founder', 'mentor']) {
          await tester.pumpWidget(
            app(
              LanguageOrtaWorkspace(
                role: role,
                studentId: 'someone-else',
                studentName: 'Founder',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('languageOrtaDenied')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('startLanguagePractice')),
            findsNothing,
          );
        }
      },
    );

    testWidgets('student sees the language home with an add-language action', (
      tester,
    ) async {
      final store = StudentLanguageOrtaStore(studentId: 's1', role: 'student');
      await tester.pumpWidget(
        app(
          LanguageOrtaWorkspace(
            role: 'student',
            studentId: 's1',
            studentName: 'Arujan',
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('languageOrtaDenied')), findsNothing);
      expect(find.byKey(const ValueKey('addLanguageOrta')), findsOneWidget);
    });
  });
}
