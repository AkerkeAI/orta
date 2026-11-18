import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/services/action_agent.dart';
import 'package:orta/services/agent_context_builder.dart';
import 'package:orta/services/ai_actions.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/planning_strings.dart';
import 'package:orta/services/remote_orta_agent_service.dart';
import 'package:orta/services/storage_service.dart';

class _Storage implements LifeDataStorage {
  LifeData value;
  _Storage([Language language = Language.english])
    : value = LifeData(
        life: LifeContext(name: 'Approval test', interfaceLanguage: language),
      );
  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(value.toJson());
  @override
  Future<void> saveLifeData(LifeData data) async {
    value = LifeData.fromJson(data.toJson());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final group in [false, true]) {
    for (final appended in [false, true]) {
      for (final approve in [false, true]) {
        for (final stale in [false, true]) {
          test(
            '${group ? 'group' : 'single'} ${approve ? 'approval' : 'rejection'} '
            '${stale ? 'cannot reuse review after a failed user message' : 'accepts the immediately preceding review'} '
            '(${appended ? 'current message saved' : 'direct caller'})',
            () async {
              final repository = await LifeRepository.open(_Storage());
              addTearDown(repository.dispose);
              final registry = await ToolRegistry.load();
              final count = group ? 2 : 1;
              await repository.proposeTools(registry, [
                for (var index = 0; index < count; index++)
                  {
                    'name': 'create_project',
                    'arguments': {'name': 'Proposed project $index'},
                  },
              ]);
              final ids = repository.data.currentProposals
                  .map((p) => p.id)
                  .toList();
              await repository.appendMessage(
                actionText(Language.english, 'review'),
                isUser: false,
              );
              if (stale) {
                // A failed request is saved without an assistant response. It
                // changes the conversation intent even though the old proposals
                // are still pending locally.
                await repository.appendMessage(
                  'Forget that plan. Can we talk about something else?',
                  isUser: true,
                );
              }
              final message = group
                  ? approve
                        ? 'approve all'
                        : 'reject all'
                  : approve
                  ? 'yes'
                  : 'cancel';
              if (appended) {
                await repository.appendMessage(message, isUser: true);
              }
              final before = jsonEncode(repository.data.life.toJson());
              var requests = 0;
              final tool = group
                  ? approve
                        ? 'approve_actions'
                        : 'reject_actions'
                  : approve
                  ? 'approve_action'
                  : 'reject_action';
              final arguments = group
                  ? {'actionIds': ids}
                  : {'actionId': ids.single};
              final client = MockClient((request) async {
                requests++;
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(
                  (body['pendingActions'] as List).every(
                    (pending) => pending['decisionEligible'] == !stale,
                  ),
                  isTrue,
                );
                return http.Response(
                  jsonEncode(
                    requests == 1
                        ? {
                            'message': '',
                            'toolCalls': [
                              {
                                'id': 'decision-call',
                                'name': tool,
                                'arguments': arguments,
                              },
                            ],
                            'rawCalls': [
                              {
                                'id': 'decision-call',
                                'type': 'function',
                                'function': {
                                  'name': tool,
                                  'arguments': jsonEncode(arguments),
                                },
                              },
                            ],
                          }
                        : {
                            'message':
                                'Review the current proposal before deciding.',
                            'toolCalls': [],
                          },
                  ),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              });
              addTearDown(client.close);
              final agent = ActionAgent(
                repository,
                RemoteOrtaAgentService(client: client, baseUrl: 'http://test'),
                registry,
              );
              await agent.respond(
                message,
                () =>
                    AgentContextBuilder.build(repository.data, screen: 'life'),
              );
              expect(
                repository.data.currentProposals.every(
                  (proposal) =>
                      proposal.status ==
                      (stale
                          ? 'pending'
                          : approve
                          ? 'executed'
                          : 'rejected'),
                ),
                isTrue,
              );
              expect(
                repository.data.life.projects.length,
                !stale && approve ? count : 0,
              );
              if (stale || !approve) {
                expect(jsonEncode(repository.data.life.toJson()), before);
              }
              expect(requests, stale ? 2 : 1);
            },
          );
        }
      }
    }
  }
  for (final language in Language.values) {
    test(
      'mixed valid and invalid writes fail safely in ${language.code}',
      () async {
        final repository = await LifeRepository.open(_Storage(language));
        addTearDown(repository.dispose);
        final registry = await ToolRegistry.load();
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': '',
              'toolCalls': [
                {
                  'id': 'valid-write',
                  'name': 'create_project',
                  'arguments': {'name': 'A valid project'},
                },
                {
                  'id': 'invalid-write',
                  'name': 'create_project',
                  'arguments': {'name': ''},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        addTearDown(client.close);
        final agent = ActionAgent(
          repository,
          RemoteOrtaAgentService(client: client, baseUrl: 'http://test'),
          registry,
        );
        final before = jsonEncode(repository.data.toJson());
        final response = await agent.respond(
          'Create these projects',
          () => AgentContextBuilder.build(repository.data, screen: 'life'),
        );
        expect(jsonEncode(repository.data.toJson()), before);
        expect(repository.data.currentProposals, isEmpty);
        expect(response, startsWith(actionText(language, 'failed')));
        expect(
          response,
          contains(planningErrorText(language, 'invalid_arguments')),
        );
        expect(response, isNot(contains('name must')));
      },
    );
  }
  for (final reviewLanguage in Language.values) {
    for (final currentLanguage in Language.values) {
      if (reviewLanguage == currentLanguage) {
        continue;
      }
      for (final stale in [false, true]) {
        for (final appended in [false, true]) {
          test(
            'review in ${reviewLanguage.code} ${stale ? 'stays stale' : 'allows approval'} '
            'after switching to ${currentLanguage.code} '
            '(${appended ? 'current message saved' : 'direct caller'})',
            () async {
              final repository = await LifeRepository.open(
                _Storage(reviewLanguage),
              );
              addTearDown(repository.dispose);
              final registry = await ToolRegistry.load();
              await repository.proposeTools(registry, [
                {
                  'name': 'create_project',
                  'arguments': {'name': 'A reviewed project'},
                },
              ]);
              final actionId = repository.data.currentProposals.single.id;
              await repository.appendMessage(
                actionText(reviewLanguage, 'review'),
                isUser: false,
              );
              await repository.updateLife(
                (life) => life.copyWith(interfaceLanguage: currentLanguage),
              );
              if (stale) {
                await repository.appendMessage(
                  'Forget that plan. This message did not receive a response.',
                  isUser: true,
                );
              }
              final message = switch (currentLanguage) {
                Language.english => 'yes',
                Language.russian => 'Да',
                Language.kazakh => 'Иә',
              };
              if (appended) {
                await repository.appendMessage(message, isUser: true);
              }
              final before = jsonEncode(repository.data.life.toJson());
              var requests = 0;
              final client = MockClient((request) async {
                requests++;
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['locale'], currentLanguage.code);
                expect(
                  (body['pendingActions'] as List).single['decisionEligible'],
                  !stale,
                );
                return http.Response(
                  jsonEncode(
                    requests == 1
                        ? {
                            'message': '',
                            'toolCalls': [
                              {
                                'id': 'approve-current',
                                'name': 'approve_action',
                                'arguments': {'actionId': actionId},
                              },
                            ],
                            'rawCalls': [
                              {
                                'id': 'approve-current',
                                'type': 'function',
                                'function': {
                                  'name': 'approve_action',
                                  'arguments': jsonEncode({
                                    'actionId': actionId,
                                  }),
                                },
                              },
                            ],
                          }
                        : {
                            'message': 'Please review the proposal again.',
                            'toolCalls': [],
                          },
                  ),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              });
              addTearDown(client.close);
              final agent = ActionAgent(
                repository,
                RemoteOrtaAgentService(client: client, baseUrl: 'http://test'),
                registry,
              );
              await agent.respond(
                message,
                () =>
                    AgentContextBuilder.build(repository.data, screen: 'life'),
              );
              expect(
                repository.data.currentProposals.single.status,
                stale ? 'pending' : 'executed',
              );
              expect(repository.data.life.projects.length, stale ? 0 : 1);
              expect(repository.data.life.interfaceLanguage, currentLanguage);
              if (stale) {
                expect(jsonEncode(repository.data.life.toJson()), before);
              }
              expect(requests, stale ? 2 : 1);
            },
          );
        }
      }
    }
  }
}
