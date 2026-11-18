import 'package:flutter_test/flutter_test.dart';

import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/services/goal_suggestion_service.dart';
import 'package:orta/services/life_context_interpreter.dart';
import 'package:orta/services/localization_service.dart';
import 'package:orta/services/orta_localization.dart';

void main() {
  final interpreter = MockLifeContextInterpreter();
  const studyAndPortfolio = [
    'I am taking a year off and building my portfolio before applying to art school.',
    'Беру год перерыва и развиваю портфолио перед поступлением в университет.',
    'Оқудан бір жыл үзіліс алып, портфолио жасап, университетке түсуге дайындалып жүрмін.',
  ];
  for (var index = 0; index < studyAndPortfolio.length; index++) {
    test(
      'recognizes explicit education, break and portfolio topics in locale $index',
      () {
        expect(
          interpreter.interpret(studyAndPortfolio[index]),
          containsAll([
            'gap_year',
            'preparing_university',
            'portfolio_development',
          ]),
        );
      },
    );
  }

  for (final description in [
    'I am working on my project and business.',
    'Я работаю над проектом и развиваю бизнес.',
    'Жұмыс істеп, жеке жоба мен кәсіп дамытып жүрмін.',
  ]) {
    test('recognizes work and project topics: $description', () {
      expect(
        interpreter.interpret(description),
        containsAll(['work_experience', 'project_development']),
      );
    });
  }

  test('ambiguous notes and substring matches stay generic', () {
    for (final description in [
      '',
      'I feel overwhelmed.',
      'I am starting to think about moving to Singapore.',
      'There is a gap in my calendar.',
      'Сейчас сложно понять, чего я хочу.',
      'Қазір не істеу керегін білмеймін.',
      'I visited an art museum.',
    ]) {
      expect(interpreter.interpret(description), [
        'personal_development',
      ], reason: description);
    }
  });

  test('an institution alone does not invent an admission plan', () {
    for (final description in [
      'I am at university.',
      'Я учусь в университете.',
      'Мен университетте оқимын.',
    ]) {
      expect(interpreter.interpret(description), ['personal_development']);
    }
  });

  test('negated topics do not invent activities in any locale', () {
    for (final description in [
      'I do not work and I am not applying to university.',
      "I don't have a business.",
      'Я не работаю и не готовлюсь поступать в университет.',
      'Жұмысым жоқ. Университетке дайындалып жүрген жоқпын.',
      'Жұмыссызбын.',
    ]) {
      expect(interpreter.interpret(description), [
        'personal_development',
      ], reason: description);
    }
  });

  test(
    'a positive clause can still suggest a topic after a negated clause',
    () {
      expect(
        interpreter.interpret(
          'I am not applying to university, but I am building a portfolio.',
        ),
        ['portfolio_development'],
      );
      expect(interpreter.interpret('Я не работаю, но развиваю свой проект.'), [
        'project_development',
      ]);
    },
  );

  test('repeated mentions never duplicate suggestions', () {
    expect(
      interpreter.interpret('Portfolio. Портфолио. Портфолио жасап жүрмін.'),
      ['portfolio_development'],
    );
  });

  test(
    'all built-in goals, life domains and interpretation topics are localized',
    () {
      final life = LifeContext(
        name: 'Әлия',
        interfaceLanguage: Language.english,
        currentLifeAreas: LifeArea.values.toSet(),
        goals: const [
          GoalContext(
            id: 'language_keep',
            titleKey: 'language_keep',
            areaKey: 'language',
          ),
        ],
      );
      final goals = GoalSuggestionService.suggestionsFor(life);
      for (final locale in AppLocale.values) {
        final strings = AppLocalizations(locale);
        for (final goal in goals) {
          expect(
            strings.goal(goal.titleKey),
            isNot(goal.titleKey),
            reason: '${locale.name}: ${goal.titleKey}',
          );
        }
        for (final domain in LifeDomain.values) {
          expect(
            strings.lifeDomain(domain.name),
            isNot(domain.name),
            reason: '${locale.name}: ${domain.name}',
          );
        }
        for (final key in [
          'gap_year',
          'preparing_university',
          'portfolio_development',
          'work_experience',
          'project_development',
          'personal_development',
        ]) {
          expect(strings.interpretation(key), isNot(key));
        }
        expect(strings.goal('My first solo show'), 'My first solo show');
      }
      expect(
        AppLocalizations(AppLocale.kazakh).lifeArea(LifeArea.gapYear),
        'Оқудан бір жылдық үзіліс',
      );
      expect(
        AppLocalizations(AppLocale.kazakh).interpretation('gap_year'),
        'Оқудан бір жылдық үзіліс',
      );
      expect(
        AppLocalizations(AppLocale.english)
            .interpretation('personal_development'),
        'Current situation',
      );
    },
  );
}
