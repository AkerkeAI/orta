import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/services/life_data_strings.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/localization_service.dart';
import 'package:orta/services/orta_localization.dart';
import 'package:orta/services/planning_strings.dart';
import 'package:orta/services/scheduling_engine.dart';
import 'package:orta/services/storage_service.dart';
import 'package:orta/widgets/life_record_dialog.dart';
import 'package:orta/widgets/planning_views.dart';

class _Storage implements LifeDataStorage {
  LifeData data;
  _Storage(this.data);
  @override
  Future<LifeData> loadLifeData() async => data;
  @override
  Future<void> saveLifeData(LifeData value) async => data = value;
}

LifeData _data(Language language) => LifeData(
  onboardingCompleted: true,
  life: LifeContext(
    name: 'Әлия',
    interfaceLanguage: language,
    goals: const [
      GoalContext(id: 'builtin', titleKey: 'career_advance', areaKey: 'career'),
      GoalContext(
        id: 'custom',
        titleKey: 'My first solo show',
        areaKey: 'personal',
      ),
    ],
  ),
);

Widget _app(Widget home) => MaterialApp(
  // The selected interface language must win over the root/device language.
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('ru'), Locale('kk')],
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

Widget _dialogApp(Widget dialog) => _app(
  Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            showDialog<void>(context: context, builder: (_) => dialog),
        child: const Text('Open'),
      ),
    ),
  ),
);

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  for (final language in Language.values) {
    final strings = AppLocalizations(AppLocaleExtension.fromLanguage(language));

    testWidgets(
      'overview goal recommendations localize and preserve custom titles in ${language.name}',
      (tester) async {
        await tester.pumpWidget(
          _app(Scaffold(body: DailyOverview(data: _data(language)))),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            '${planningText(language, 'goal')}: ${strings.goal('career_advance')}',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('career_advance'), findsNothing);
        final customFirst = _data(language);
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: DailyOverview(
                data: customFirst.copyWith(
                  life: customFirst.life.copyWith(
                    goals: customFirst.life.goals.reversed.toList(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('${planningText(language, 'goal')}: My first solo show'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'goal selection translates labels and saves the original ID in ${language.name}',
      (tester) async {
        final storage = _Storage(_data(language));
        final repository = await LifeRepository.open(storage);
        addTearDown(repository.dispose);
        await tester.pumpWidget(
          _dialogApp(
            LifeRecordDialog(repository: repository, initialType: 'task'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          _field(lifeDataText(language, 'title')),
          'Read notes',
        );
        final dropdown = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == lifeDataText(language, 'goal'),
        );
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        expect(find.text(strings.goal('career_advance')).last, findsOneWidget);
        expect(find.text('My first solo show').last, findsOneWidget);
        expect(find.text('career_advance'), findsNothing);
        await tester.tap(find.text(strings.goal('career_advance')).last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(ElevatedButton, lifeDataText(language, 'save')),
        );
        await tester.pumpAndSettle();
        expect(storage.data.tasks.single.goalId, 'builtin');
        expect(storage.data.life.goals.first.titleKey, 'career_advance');
        expect(find.byType(LifeRecordDialog), findsNothing);
      },
    );

    testWidgets(
      'calendar date picker uses selected ${language.name} instead of the root locale',
      (tester) async {
        final data = _data(language);
        final today = SchedulingEngine(data).today;
        await tester.pumpWidget(
          _app(Scaffold(body: PlanningCalendar(data: data))),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(TextButton, planningDate(language, today)),
        );
        await tester.pumpAndSettle();
        final picker = tester.element(find.byType(DatePickerDialog));
        expect(Localizations.localeOf(picker).languageCode, language.code);
        final cancel = MaterialLocalizations.of(picker).cancelButtonLabel;
        expect(find.text(cancel), findsOneWidget);
        await tester.tap(find.text(cancel));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
      },
    );

    testWidgets(
      'calendar events label and enforce a required date in ${language.name}',
      (tester) async {
        final storage = _Storage(_data(language));
        final repository = await LifeRepository.open(storage);
        addTearDown(repository.dispose);
        await tester.pumpWidget(
          _dialogApp(
            LifeRecordDialog(repository: repository, initialType: 'event'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        const required = {
          Language.english: 'Date (YYYY-MM-DD, required)',
          Language.russian: 'Дата (ГГГГ-ММ-ДД, обязательно)',
          Language.kazakh: 'Күні (ЖЖЖЖ-АА-КК, міндетті)',
        };
        expect(_field(required[language]!), findsOneWidget);
        expect(_field(lifeDataText(language, 'date')), findsNothing);
        await tester.enterText(
          _field(lifeDataText(language, 'title')),
          'Appointment',
        );
        final allDay = find.widgetWithText(
          CheckboxListTile,
          planningText(language, 'allDay'),
        );
        await tester.ensureVisible(allDay);
        await tester.tap(allDay);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(ElevatedButton, lifeDataText(language, 'save')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(lifeDataText(language, 'invalidDate')),
          findsOneWidget,
        );
        expect(storage.data.events, isEmpty);
        expect(find.byType(LifeRecordDialog), findsOneWidget);
      },
    );
  }
}
