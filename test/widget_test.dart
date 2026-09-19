import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orta/main.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/screens/core/orta_shell.dart';
import 'package:orta/services/goal_suggestion_service.dart';
import 'package:orta/services/life_context_interpreter.dart';
import 'package:orta/services/localization_service.dart';
import 'package:orta/services/orta_agent_service.dart';
import 'package:orta/services/orta_localization.dart';
import 'package:orta/services/storage_service.dart';

LifeContext contextFor(
  Set<LifeArea> areas, {
  List<GoalContext> goals = const [],
}) => LifeContext(
  name: 'Akerke',
  interfaceLanguage: Language.english,
  currentLifeAreas: areas,
  goals: goals,
);

void main() {
  test('goal suggestions combine life areas without duplicates', () {
    final context = contextFor({LifeArea.university, LifeArea.project});
    final suggestions = GoalSuggestionService.suggestionsFor(context);
    final ids = suggestions.map((goal) => goal.id).toList();

    expect(ids.toSet().length, ids.length);
    expect(
      suggestions.any((goal) => goal.id == 'university_internship'),
      isTrue,
    );
    expect(suggestions.any((goal) => goal.id == 'project_develop'), isTrue);
    expect(suggestions.last.id, 'other_goal');
  });

  test('mock interpreter returns suggestions for an Other description', () {
    final result = MockLifeContextInterpreter().interpret(
      'I am taking a year off and building my portfolio before applying to art school.',
    );

    expect(
      result,
      containsAll(<String>[
        'gap_year',
        'preparing_university',
        'portfolio_development',
      ]),
    );
  });

  test('working-only context has no university admission suggestion', () {
    final suggestions = GoalSuggestionService.suggestionsFor(
      contextFor({LifeArea.work}),
    );
    expect(suggestions.any((goal) => goal.id.contains('university')), isFalse);
    expect(suggestions.any((goal) => goal.id == 'career_advance'), isTrue);
  });

  testWidgets('neutral Home does not render project or language sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeView(
            lifeContext: contextFor({LifeArea.work}),
            plan: const [],
          ),
        ),
      ),
    );

    expect(find.text('Projects'), findsNothing);
    expect(find.text('Language practice'), findsNothing);
    expect(find.text('Upcoming exams'), findsNothing);
  });

  test('agent asks for the missing ENT date and creates a proposal after confirmation choice', () async {
    final service = MockOrtaAgentService();
    final context = contextFor({LifeArea.school});
    final agentContext = AgentContext(
      currentScreen: 'HOME',
      relevantLifeContext: context,
    );

    final missingDate = await service.respond(
      "I'm taking ENT in May just to see how I'll do. It's not essential.",
      agentContext,
      const AgentDraft(),
    );
    expect(missingDate.response, 'Do you know the exact date?');

    final dateProvided = await service.respond(
      '2027-05-20',
      agentContext,
      missingDate.draft,
    );
    expect(dateProvided.response, contains('prepare'));

    final proposal = await service.respond(
      'JUST ADD IT',
      agentContext,
      dateProvided.draft,
    );
    expect(proposal.proposal, isNotNull);
    expect(proposal.proposal!.action.type, 'addExam');
  });

  test('LifeContext persistence survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final context = contextFor(
      {LifeArea.work},
      goals: const [
        GoalContext(
          id: 'career_advance',
          titleKey: 'career_advance',
          areaKey: 'career',
        ),
      ],
    );

    await storage.saveLifeContext(context);
    final restored = await storage.getLifeContext();

    expect(restored!.currentLifeAreas, contains(LifeArea.work));
    expect(restored.goals.single.id, 'career_advance');
  });

  test('goal IDs stay stable while labels change by locale', () {
    final context = contextFor({LifeArea.school});
    final goal = GoalSuggestionService.suggestionsFor(context)
        .firstWhere((item) => item.id == 'school_university');
    expect(
      AppLocalizations(AppLocale.english).goal(goal.titleKey),
      'Get into university',
    );
    expect(
      AppLocalizations(AppLocale.russian).goal(goal.titleKey),
      'Поступить в университет',
    );
    expect(
      AppLocalizations(AppLocale.kazakh).goal(goal.titleKey),
      'Университетке түсу',
    );
    expect(goal.id, 'school_university');
  });

  test('Italian and German definitions remain distinct target languages', () {
    final italian = LanguageContext(languageCode: 'it', level: 'A1');
    final german = LanguageContext(languageCode: 'de', level: 'B2');
    expect(italian.definition.englishName, 'Italian');
    expect(german.definition.englishName, 'German');
    expect(italian.languageCode, isNot(german.languageCode));
  });

  testWidgets('ORTA app loads a persisted neutral LifeContext', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'life_context': '{"name":"Akerke","interfaceLanguage":"en","currentLifeAreas":["work"],"goals":[]}',
    });

    await tester.pumpWidget(const OrtaAppWrapper());
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('LIFE'), findsOneWidget);
    expect(find.text('Projects'), findsNothing);
  });
}
