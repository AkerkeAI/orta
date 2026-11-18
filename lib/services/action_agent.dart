import 'planning_tools.dart';
import 'scheduling_engine.dart';
import 'planning_strings.dart';

import 'dart:convert';

import '../models/life_context.dart';
import '../models/language.dart';
import 'ai_actions.dart';
import 'life_repository.dart';
import 'remote_orta_agent_service.dart';

String actionText(Language language, String key) {
  const labels = {
    'conversationChanged': [
      'This request stopped because you switched conversations. No changes were made.',
      'Запрос остановлен, потому что вы сменили разговор. Данные не изменены.',
      'Басқа әңгімеге ауысқандықтан сұрау тоқтатылды. Деректер өзгерген жоқ.',
    ],
    'review': [
      'Review the proposed changes. Nothing has been saved yet.',
      'Проверьте предложенные изменения. Данные ещё не изменены.',
      'Ұсынылған өзгерістерді тексеріңіз. Деректер әлі өзгерген жоқ.',
    ],
    'confirm': ['Confirm', 'Подтвердить', 'Растау'],
    'cancel': ['Cancel', 'Отменить', 'Бас тарту'],
    'success': [
      'Saved successfully',
      'Изменение сохранено',
      'Өзгеріс сақталды',
    ],
    'rejected': [
      'Cancelled. No data changed.',
      'Отменено. Данные не изменены.',
      'Бас тартылды. Деректер өзгерген жоқ.',
    ],
    'failed': ['Action failed', 'Действие не выполнено', 'Әрекет орындалмады'],
    'approveAll': ['Approve all', 'Подтвердить всё', 'Барлығын растау'],
    'rejectAll': ['Reject all', 'Отменить всё', 'Барлығынан бас тарту'],
    'retry': [
      'Could not save. Nothing changed; the proposal is still pending. Try again.',
      'Не удалось сохранить. Данные не изменены; предложение ожидает подтверждения. Повторите попытку.',
      'Сақтау мүмкін болмады. Деректер өзгерген жоқ; ұсыныс растауды күтуде. Қайта көріңіз.',
    ],
  };
  return labels[key]![language == Language.russian
      ? 1
      : language == Language.kazakh
      ? 2
      : 0];
}

class ActionAgent {
  final LifeRepository repository;
  final RemoteOrtaAgentService service;
  final ToolRegistry registry;
  ActionAgent(this.repository, this.service, this.registry);
  Future<String> respond(
    String text,
    AgentContext Function() contextBuilder,
  ) async {
    final turns = <Map<String, dynamic>>[];
    final conversationId = repository.data.activeConversationId;
    final language = repository.data.life.interfaceLanguage;
    final pending = repository.data.currentProposals
        .where((p) => p.status == 'pending' && !p.expired(DateTime.now()))
        .toList();
    // Model may revise pending proposals; local approval still requires an explicit decision following the review.
    final decision =
        explicitDecision(text, true) ||
        explicitDecision(text, false) ||
        groupDecision(text, true) ||
        groupDecision(text, false);
    // The UI saves the current user message before this turn. Direct callers
    // may not have saved it yet. In either case, only the immediately preceding
    // assistant review can authorize a decision; failed intervening messages
    // must not revive an older review.
    final messages = repository.data.conversation;
    final currentAlreadySaved =
        messages.lastOrNull?.isUser == true &&
        messages.lastOrNull?.text == text;
    final preceding = currentAlreadySaved
        ? messages.take(messages.length - 1).lastOrNull
        : messages.lastOrNull;
    // A saved review keeps its original interface language after a locale
    // change. Accept only exact review messages from the supported locales.
    final precedingIsReview =
        preceding?.isUser == false &&
        Language.values.any(
          (reviewLanguage) =>
              preceding?.text == actionText(reviewLanguage, 'review'),
        );
    final eligible = decision && pending.isNotEmpty && precedingIsReview
        ? pending
        : <ToolProposal>[];
    for (var step = 0; step < 4; step++) {
      if (repository.data.activeConversationId != conversationId) {
        return actionText(language, 'conversationChanged');
      }
      final response = await service.toolTurn(
        text,
        contextBuilder(),
        repository.data.conversation,
        turns,
        pending
            .map(
              (p) => {
                'actionId': p.id,
                'tool': p.tool,
                'arguments': p.arguments,
                'summary': p.summary,
                'status': p.status,
                'decisionEligible': eligible.contains(p),
              },
            )
            .toList(),
      );
      if (repository.data.activeConversationId != conversationId) {
        return actionText(language, 'conversationChanged');
      }
      final calls = response['toolCalls'] as List;
      if (calls.isEmpty) return response['message'] as String;
      final writes = <Map<String, dynamic>>[];
      final results = <Map<String, dynamic>>[];
      for (final raw in calls) {
        final call = Map<String, dynamic>.from(raw as Map);
        final name = call['name'] as String;
        final args = Map<String, dynamic>.from(call['arguments'] as Map);
        try {
          registry.validate(name, args);
          final permission = registry.permission(name);
          if (permission == 'planning') {
            writes.addAll(PlanningTools.calculate(repository.data, name, args));
            results.add({'ok': true, 'status': 'awaiting_approval'});
          } else if (permission == 'approval') {
            writes.add(call);
            results.add({
              'ok': true,
              'status': 'awaiting_approval',
              'tool': name,
            });
          } else if (permission == 'decision') {
            if (name == 'approve_actions' || name == 'reject_actions') {
              final approve = name == 'approve_actions';
              final ids = List<String>.from(args['actionIds'] as List);
              if (calls.length != 1 ||
                  eligible.isEmpty ||
                  !groupDecision(text, approve) ||
                  ids
                      .toSet()
                      .difference(eligible.map((p) => p.id).toSet())
                      .isNotEmpty ||
                  ids.length != eligible.length) {
                throw const ToolFailure(
                  'permission',
                  'Select the specific group using Approve all / Reject all.',
                );
              }
              return resultMessage(
                language,
                await repository.resolveActions(
                  registry,
                  ids,
                  approve: approve,
                ),
              );
            }
            final approve = name == 'approve_action';
            if (calls.length != 1 ||
                eligible.length != 1 ||
                args['actionId'] != eligible.single.id ||
                !explicitDecision(text, approve)) {
              throw const ToolFailure(
                'permission',
                'Use the proposal Confirm/Cancel buttons or explicitly confirm the single pending proposal.',
              );
            }
            final result = await repository.resolveAction(
              registry,
              eligible.single.id,
              approve: approve,
            );
            return resultMessage(language, result);
          } else {
            results.add(registry.read(repository.data, name, args));
          }
        } on PlanningError catch (error) {
          results.add({
            'ok': false,
            'code': error.code,
            'detail': planningErrorText(language, error.code),
          });
        } on ToolFailure catch (error) {
          results.add({
            'ok': false,
            'code': error.code,
            'detail': planningErrorText(language, error.code),
          });
        }
      }
      if (writes.isNotEmpty) {
        if (results.any((r) => r['ok'] == false)) {
          final failure = results.firstWhere((result) => result['ok'] == false);
          return '${actionText(language, 'failed')}: ${planningErrorText(language, failure['code'] as String? ?? 'saveFailed')}';
        }
        // Validate whole group before publishing any proposals or changes.
        try {
          await repository.proposeTools(
            registry,
            writes,
            conversationId: conversationId,
          );
        } on ToolFailure catch (error) {
          return '${actionText(language, 'failed')}: ${planningErrorText(language, error.code)}';
        } on FormatException {
          return '${actionText(language, 'failed')}: ${planningText(language, 'invalidPreferences')}';
        }
        return actionText(language, 'review');
      }
      turns.add({
        'role': 'assistant',
        'content': response['message'],
        'tool_calls': response['rawCalls'],
      });
      for (var i = 0; i < calls.length; i++) {
        turns.add({
          'role': 'tool',
          'tool_call_id': calls[i]['id'],
          'content': jsonEncode(results[i]),
        });
      }
    }
    return '${actionText(language, 'failed')}: ${planningText(language, 'range')}';
  }

  static String resultMessage(Language language, Map<String, dynamic> result) =>
      result['ok'] == true
      ? '${actionText(language, 'success')}:\n${result['summary'] ?? result['tool']}'
      : result['code'] == 'rejected'
      ? actionText(language, 'rejected')
      : '${actionText(language, 'failed')}: ${result['code'] == 'batchFailed' ? '${planningText(language, 'batchFailed')} ${planningErrorText(language, result['reason'] as String? ?? 'saveFailed')}' : planningErrorText(language, result['code'] as String? ?? 'saveFailed')}';
}
