class AssistantCommand {
  final String intent;
  final String response;
  final List<String> suggestions;

  AssistantCommand({
    required this.intent,
    required this.response,
    this.suggestions = const [],
  });
}

class MockAssistantService {
  static AssistantCommand handle(String text) {
    final normalized = text.toLowerCase();

    if (normalized.contains('plan my day') || normalized.contains('plan')) {
      return AssistantCommand(
        intent: 'plan_day',
        response: 'You have 45 free minutes between 18:00 and 18:45. I suggest using 30 minutes for university research.',
        suggestions: ['View plan', 'Start university research'],
      );
    }

    if (normalized.contains('focus') ||
        normalized.contains('what should i focus')) {
      return AssistantCommand(
        intent: 'focus',
        response: 'Your project application deadline is closest. I recommend working on the project description next.',
        suggestions: ['Open application draft', 'Review project timeline'],
      );
    }

    if (normalized.contains('english')) {
      return AssistantCommand(
        intent: 'language',
        response: 'You have an English session planned today. Would you like to enter Language ORTA?',
        suggestions: ['Enter Language ORTA', 'Review plan'],
      );
    }

    if (normalized.contains('opportunity') || normalized.contains('project')) {
      return AssistantCommand(
        intent: 'opportunity',
        response: 'ORTA found 3 opportunities aligned with your AIqyn project. One program deadline is in 6 days.',
        suggestions: ['Open opportunities', 'Prepare application'],
      );
    }

    return AssistantCommand(
      intent: 'general',
      response: 'I can help you plan your day, review opportunities, or switch into Language ORTA for a practice session.',
      suggestions: ['Plan my day', 'Find opportunities', 'Start Language ORTA'],
    );
  }
}
