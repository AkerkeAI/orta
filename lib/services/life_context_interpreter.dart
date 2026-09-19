abstract class LifeContextInterpreter {
  List<String> interpret(String description);
}

class MockLifeContextInterpreter implements LifeContextInterpreter {
  @override
  List<String> interpret(String description) {
    final text = description.toLowerCase();
    final suggestions = <String>[];
    if (text.contains('year off') || text.contains('gap')) {
      suggestions.add('gap_year');
    }
    if (text.contains('university') ||
        text.contains('college') ||
        text.contains('school')) {
      suggestions.add('preparing_university');
    }
    if (text.contains('portfolio') ||
        text.contains('art') ||
        text.contains('design')) {
      suggestions.add('portfolio_development');
    }
    if (text.contains('work') || text.contains('job')) {
      suggestions.add('work_experience');
    }
    if (text.contains('project') || text.contains('business')) {
      suggestions.add('project_development');
    }
    return suggestions.isEmpty ? ['personal_development'] : suggestions;
  }
}
