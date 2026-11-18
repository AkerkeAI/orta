import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orta/app/orta_app.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/screens/core/orta_shell.dart';
import 'package:orta/screens/onboarding/onboarding_screen.dart';
import 'package:orta/services/localization_service.dart';
import 'package:orta/services/orta_localization.dart';
import 'package:orta/services/storage_service.dart';
import 'package:orta/widgets/language_selector.dart';

class _MemoryStorage implements LifeDataStorage {
  LifeData data;
  bool failLoad = false;
  bool failSave = false;
  int writes = 0;

  _MemoryStorage([LifeData? initial]) : data = initial ?? LifeData.empty();

  @override
  Future<LifeData> loadLifeData() async {
    if (failLoad) throw StateError('Unavailable storage');
    return data;
  }

  @override
  Future<void> saveLifeData(LifeData value) async {
    if (failSave) throw StateError('Unavailable storage');
    writes++;
    data = value;
  }
}

Widget _app(Widget home, AppLocale locale) => MaterialApp(
  locale: Locale(locale.languageCode),
  supportedLocales: const [Locale('en'), Locale('ru'), Locale('kk')],
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

Future<void> _continue(WidgetTester tester, AppLocalizations strings) async {
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(
      ElevatedButton,
      strings.get('life_onboarding_continue'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseWork(WidgetTester tester, AppLocalizations strings) async {
  await _continue(tester, strings);
  await tester.enterText(find.byType(TextField), 'Әлия');
  await _continue(tester, strings);
  await _continue(tester, strings);
  final work = find.widgetWithText(
    CheckboxListTile,
    strings.lifeArea(LifeArea.work),
  );
  await tester.ensureVisible(work);
  await tester.tap(work);
  await _continue(tester, strings);
}

void main() {
  for (final locale in AppLocale.values) {
    testWidgets(
      'onboarding validates, shows goals and summary in ${locale.name}',
      (tester) async {
        final strings = AppLocalizations(locale);
        LifeContext? completed;
        await tester.pumpWidget(
          _app(
            OnboardingScreen(
              currentLocale: locale,
              onLocaleChange: (_) {},
              onComplete: (value) => completed = value,
            ),
            AppLocale.english,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(strings.get('life_onboarding_welcome')),
          findsOneWidget,
        );
        await _continue(tester, strings);
        await _continue(tester, strings);
        expect(find.text(strings.onboardingNameError), findsOneWidget);
        expect(
          find.text(strings.get('life_onboarding_nameHint')),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), ' Әлия ');
        await _continue(tester, strings);
        await _continue(tester, strings);
        await _continue(tester, strings);
        expect(
          find.text(strings.get('life_onboarding_lifeError')),
          findsOneWidget,
        );
        final work = find.widgetWithText(
          CheckboxListTile,
          strings.lifeArea(LifeArea.work),
        );
        await tester.ensureVisible(work);
        await tester.tap(work);
        await _continue(tester, strings);
        final firstGoal = find.widgetWithText(
          CheckboxListTile,
          strings.goal('career_advance'),
        );
        expect(firstGoal, findsOneWidget);
        expect(tester.widget<CheckboxListTile>(firstGoal).value, isTrue);
        expect(find.text(strings.get('life_onboarding_build')), findsNothing);
        await tester.tap(firstGoal);
        await _continue(tester, strings);
        expect(completed, isNull);
        expect(
          find.text(strings.get('life_onboarding_summary')),
          findsOneWidget,
        );
        expect(
          find.text(strings.get('life_onboarding_summaryLife')),
          findsOneWidget,
        );
        expect(
          find.text(strings.get('life_onboarding_summaryGoals')),
          findsOneWidget,
        );
        expect(find.text('Әлия'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(
            ElevatedButton,
            strings.get('life_onboarding_build'),
          ),
        );
        expect(completed!.interfaceLanguage.code, locale.languageCode);
        expect(completed!.currentLifeAreas, {LifeArea.work});
        expect(completed!.goals.map((goal) => goal.id), [
          'career_job',
          'career_skills',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'language selection searches translated names in ${locale.name}',
      (tester) async {
        final strings = AppLocalizations(locale);
        await tester.pumpWidget(
          _app(LanguageSelectorDialog(locale: locale), AppLocale.english),
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.get('select_language')), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          strings.languageName('it'),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ListTile, strings.languageName('it')),
          findsOneWidget,
        );
        expect(find.text('Italiano'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'zzzzzzzz');
        await tester.pumpAndSettle();
        expect(find.text(strings.get('no_languages')), findsOneWidget);
        expect(find.text(strings.get('cancel')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('load failure preserves data and retries in ${locale.name}', (
      tester,
    ) async {
      final strings = AppLocalizations(locale);
      final storage = _MemoryStorage()..failLoad = true;
      await tester.pumpWidget(_app(OrtaApp(storage: storage), locale));
      await tester.pumpAndSettle();
      expect(find.text(strings.get('data_load_error')), findsOneWidget);
      expect(storage.writes, 0);
      storage.failLoad = false;
      await tester.tap(find.text(strings.get('retry')));
      await tester.pumpAndSettle();
      expect(find.text(strings.get('life_onboarding_welcome')), findsOneWidget);
      expect(storage.writes, 0);
    });

    testWidgets(
      'save failure keeps the summary and can retry in ${locale.name}',
      (tester) async {
        final strings = AppLocalizations(locale);
        final storage = _MemoryStorage()..failSave = true;
        await tester.pumpWidget(_app(OrtaApp(storage: storage), locale));
        await tester.pumpAndSettle();
        await _chooseWork(tester, strings);
        await _continue(tester, strings);
        final build = find.widgetWithText(
          ElevatedButton,
          strings.get('life_onboarding_build'),
        );
        await tester.tap(build);
        await tester.pumpAndSettle();
        expect(find.text(strings.get('data_save_error')), findsOneWidget);
        expect(
          find.text(strings.get('life_onboarding_summary')),
          findsOneWidget,
        );
        expect(storage.data.onboardingCompleted, isFalse);
        storage.failSave = false;
        await tester.tap(find.text(strings.get('retry')));
        await tester.pumpAndSettle();
        expect(storage.data.onboardingCompleted, isTrue);
        expect(storage.data.life.name, 'Әлия');
        expect(storage.data.life.interfaceLanguage.code, locale.languageCode);
        expect(find.byType(OrtaShell), findsOneWidget);
      },
    );
  }

  testWidgets(
    'revisiting life keeps choices and removes obsolete goals and notes',
    (tester) async {
      final strings = AppLocalizations(AppLocale.english);
      LifeContext? completed;
      await tester.pumpWidget(
        _app(
          OnboardingScreen(
            onLocaleChange: (_) {},
            onComplete: (life) => completed = life,
          ),
          AppLocale.english,
        ),
      );
      await _chooseWork(tester, strings);
      final firstGoal = find.widgetWithText(
        CheckboxListTile,
        strings.goal('career_advance'),
      );
      await tester.tap(firstGoal);
      await tester.tap(find.text(strings.get('life_onboarding_back')));
      await tester.pumpAndSettle();
      await _continue(tester, strings);
      expect(tester.widget<CheckboxListTile>(firstGoal).value, isFalse);
      await tester.tap(find.text(strings.get('life_onboarding_back')));
      await tester.pumpAndSettle();
      final work = find.widgetWithText(
        CheckboxListTile,
        strings.lifeArea(LifeArea.work),
      );
      await tester.ensureVisible(work);
      await tester.tap(work);
      final other = find.widgetWithText(
        CheckboxListTile,
        strings.lifeArea(LifeArea.other),
      );
      await tester.ensureVisible(other);
      await tester.tap(other);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'I am building a portfolio',
      );
      await _continue(tester, strings);
      expect(find.text(strings.goal('career_job')), findsNothing);
      await tester.tap(find.text(strings.get('life_onboarding_back')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(other);
      await tester.tap(other);
      await tester.ensureVisible(work);
      await tester.tap(work);
      await _continue(tester, strings);
      await _continue(tester, strings);
      expect(find.text('I am building a portfolio'), findsNothing);
      await tester.tap(
        find.widgetWithText(
          ElevatedButton,
          strings.get('life_onboarding_build'),
        ),
      );
      expect(completed!.otherDescription, isEmpty);
      expect(completed!.interpretedSuggestions, isEmpty);
      expect(completed!.goals, isEmpty);
    },
  );

  testWidgets('onboarding name entry fits with a keyboard on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.reset);
    final strings = AppLocalizations(AppLocale.kazakh);
    await tester.pumpWidget(
      _app(
        OnboardingScreen(
          currentLocale: AppLocale.kazakh,
          onLocaleChange: (_) {},
          onComplete: (_) {},
        ),
        AppLocale.kazakh,
      ),
    );
    await _continue(tester, strings);
    await tester.enterText(find.byType(TextField), 'Әлия');
    await _continue(tester, strings);
    expect(find.text(strings.get('life_onboarding_language')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing onboarding language updates every visible life label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(OrtaApp(storage: _MemoryStorage()), AppLocale.english),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<Language>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Қазақша').last);
    await tester.pumpAndSettle();
    final strings = AppLocalizations(AppLocale.kazakh);
    expect(find.text(strings.get('life_onboarding_welcome')), findsOneWidget);
    await _chooseWork(tester, strings);
    expect(find.text(strings.goal('career_advance')), findsOneWidget);
    expect(find.text('Advance my career'), findsNothing);
  });

  testWidgets(
    'persisted interface locale is inherited and updates after a change',
    (tester) async {
      final storage = _MemoryStorage(
        LifeData.empty().copyWith(
          onboardingCompleted: true,
          life: LifeContext(name: 'Әлия', interfaceLanguage: Language.russian),
        ),
      );
      await tester.pumpWidget(
        _app(OrtaApp(storage: storage), AppLocale.english),
      );
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.byType(OrtaShell)))
            .languageCode,
        'ru',
      );
      final repository = tester
          .widget<OrtaShell>(find.byType(OrtaShell))
          .repository;
      await repository.updateLife(
        (life) => life.copyWith(interfaceLanguage: Language.kazakh),
      );
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.byType(OrtaShell)))
            .languageCode,
        'kk',
      );
      expect(storage.data.life.interfaceLanguage, Language.kazakh);
    },
  );

  testWidgets('language dialog fits with the keyboard on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const LanguageSelectorDialog(locale: AppLocale.kazakh),
        AppLocale.kazakh,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Итальян');
    await tester.pumpAndSettle();
    expect(find.text('Итальян тілі'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
