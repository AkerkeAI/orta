abstract class LifeContextInterpreter {
  List<String> interpret(String description);
}

/// Local keyword suggestions, not AI inference or verified facts about the user.
/// The original note stays in LifeContext; these keys only offer tentative topics.
class MockLifeContextInterpreter implements LifeContextInterpreter {
  static final _words = RegExp(r'[a-zа-яёәғқңөұүһі]+', unicode: true);
  static final _clauses = RegExp(r'[.!?;,\n]+|\s+(?:but|но|бірақ)\s+');

  @override
  List<String> interpret(String description) {
    final suggestions = <String>{};
    for (final clause in description.toLowerCase().split(_clauses)) {
      final words = _words.allMatches(clause).map((m) => m.group(0)!).toList();
      final text = words.join(' ');
      // A negated clause does not establish an activity or a plan.
      if (_isNegated(words, text)) continue;
      bool exact(List<String> values) => words.any(values.contains);
      bool stem(List<String> values) =>
          words.any((word) => values.any(word.startsWith));
      bool phrase(List<String> values) =>
          values.any((value) => ' $text '.contains(' $value '));

      if (phrase([
        'gap year',
        'year off',
        'year break',
        'год перерыва',
        'годовой перерыв',
        'перерыв на год',
        'год отдыха',
        'үзіліс жылы',
        'бір жыл үзіліс',
        'бір жылдық үзіліс',
        'бір жылға үзіліс',
        'бір жыл демалыс',
      ])) {
        suggestions.add('gap_year');
      }
      final education =
          exact(['university', 'college', 'school']) ||
          stem(['университет', 'колледж', 'школ', 'мектеп']);
      final preparation =
          exact([
            'prepare',
            'preparing',
            'preparation',
            'apply',
            'applying',
            'admission',
          ]) ||
          stem([
            'поступ',
            'подготов',
            'готов',
            'дайындал',
            'түсу',
            'түсем',
            'түсуді',
            'түспек',
          ]);
      if (education && preparation) suggestions.add('preparing_university');

      final creative = exact(['art', 'design']) || stem(['дизайн', 'өнер']);
      final developing =
          exact([
            'build',
            'building',
            'develop',
            'developing',
            'create',
            'creating',
          ]) ||
          stem(['созда', 'развив', 'жасап', 'құрып', 'дамыт']);
      if (stem(['portfolio', 'портфолио']) || creative && developing) {
        suggestions.add('portfolio_development');
      }
      if (exact(['work', 'working', 'job', 'jobs', 'career']) ||
          stem(['работ', 'карьер', 'мансап', 'қызмет']) ||
          words.any(
            (word) => word.startsWith('жұмыс') && !word.startsWith('жұмыссыз'),
          )) {
        suggestions.add('work_experience');
      }
      if (exact(['project', 'projects', 'business']) ||
          stem(['проект', 'бизнес', 'жоба', 'кәсіп'])) {
        suggestions.add('project_development');
      }
    }
    return suggestions.isEmpty
        ? ['personal_development']
        : suggestions.toList();
  }

  bool _isNegated(List<String> words, String text) =>
      words.any(
        (word) =>
            const [
              'no',
              'not',
              'never',
              'neither',
              'нет',
              'не',
              'без',
              'никогда',
              'ешқашан',
            ].contains(word) ||
            word.startsWith('жоқ') ||
            word.startsWith('емес'),
      ) ||
      text.contains('don t') ||
      text.contains('doesn t') ||
      text.contains('didn t');
}
