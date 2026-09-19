import '../models/life_context.dart';

class MockAgentResult {
  final String response;
  final ActionProposal? proposal;
  final AgentDraft draft;

  const MockAgentResult({
    required this.response,
    this.proposal,
    required this.draft,
  });
}

class AgentDraft {
  final String? examName;
  final String? date;
  final bool choosingPreparation;

  const AgentDraft({
    this.examName,
    this.date,
    this.choosingPreparation = false,
  });
}

abstract class OrtaAgentService {
  Future<MockAgentResult> respond(
    String message,
    AgentContext context,
    AgentDraft draft, {
    List<AgentMessage> conversation = const [],
  });
}

class MockOrtaAgentService implements OrtaAgentService {
  @override
  Future<MockAgentResult> respond(
    String message,
    AgentContext context,
    AgentDraft draft, {
    List<AgentMessage> conversation = const [],
  }) async {
    final text = message.trim();
    final normalized = text.toLowerCase();

    if (draft.examName != null && draft.date == null) {
      final date = _findDate(text);
      if (date == null) {
        return MockAgentResult(
          response: 'Do you know the exact date?',
          draft: draft,
        );
      }
      final next = AgentDraft(examName: draft.examName, date: date);
      return MockAgentResult(
        response: 'Do you want to prepare for it, or should I only add the exam to your plan?',
        draft: next,
      );
    }

    if (draft.examName != null &&
        draft.date != null &&
        !draft.choosingPreparation) {
      if (normalized.contains('prepare')) {
        return MockAgentResult(
          response: 'What preparation intensity fits you?',
          draft: AgentDraft(
            examName: draft.examName,
            date: draft.date,
            choosingPreparation: true,
          ),
        );
      }
      if (normalized.contains('just') ||
          normalized.contains('only') ||
          normalized.contains('add')) {
        return _examProposal(draft, false);
      }
      return MockAgentResult(
        response: 'Would you like to prepare for it, or only add the exam to your plan?',
        draft: draft,
      );
    }

    if (draft.examName != null &&
        draft.date != null &&
        draft.choosingPreparation) {
      final intensity = normalized.contains('intensive')
          ? 'Intensive'
          : normalized.contains('regular')
          ? 'Regular'
          : 'Light';
      return _examProposal(draft, true, intensity: intensity);
    }

    if (normalized.contains('ent')) {
      final date = _findDate(text);
      final examName = 'ENT';
      final next = AgentDraft(examName: examName, date: date);
      if (date == null) {
        return MockAgentResult(
          response: 'Do you know the exact date?',
          draft: next,
        );
      }
      return MockAgentResult(
        response: 'Do you want to prepare for it, or should I only add the exam to your plan?',
        draft: next,
      );
    }

    if (normalized.contains('what is that') &&
        context.currentEntityType != null) {
      return MockAgentResult(
        response:
            'It refers to the ${context.visibleSection ?? 'detail'} shown on this ${context.currentEntityType} page.',
        draft: draft,
      );
    }

    return MockAgentResult(
      response:
          'I am looking at ${context.currentScreen}. I can help turn a goal into a clear next action.',
      draft: draft,
    );
  }

  MockAgentResult _examProposal(
    AgentDraft draft,
    bool prepare, {
    String intensity = 'Light',
  }) {
    final action = AgentAction(
      type: prepare ? 'proposeStudyPlan' : 'addExam',
      arguments: {
        'name': draft.examName,
        'date': draft.date,
        'importance': 'low',
        if (prepare) 'intensity': intensity,
      },
      status: ActionStatus.awaitingApproval,
    );
    return MockAgentResult(
      response: prepare
          ? 'I prepared a local $intensity plan around your free windows.'
          : 'Here is the local exam proposal.',
      proposal: ActionProposal(
        title: prepare ? '${draft.examName} preparation' : draft.examName!,
        description: prepare
            ? '${draft.examName} on ${draft.date}. $intensity preparation sessions will be added after confirmation.'
            : '${draft.examName} on ${draft.date}. Preparation: None.',
        action: action,
      ),
      draft: draft,
    );
  }

  String? _findDate(String text) {
    final match = RegExp(r'\b(20\d{2}[-/]\d{1,2}[-/]\d{1,2})\b')
        .firstMatch(text);
    return match?.group(1);
  }
}
