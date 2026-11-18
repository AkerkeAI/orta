import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/models/orta_models.dart';
import 'package:orta/services/action_agent.dart';
import 'package:orta/services/agent_context_builder.dart';
import 'package:orta/services/ai_actions.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/planning_tools.dart';
import 'package:orta/services/remote_orta_agent_service.dart';
import 'package:orta/services/scheduling_engine.dart';
import 'package:orta/services/storage_service.dart';

class ConversationMemoryStorage implements LifeDataStorage {
  LifeData saved = LifeData.empty();

  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(saved.toJson());

  @override
  Future<void> saveLifeData(LifeData data) async {
    saved = LifeData.fromJson(data.toJson());
  }
}

Map<String, dynamic> projectCall(String title) => {
  'name': 'create_project',
  'arguments': {'name': title},
};

List<Map<String, dynamic>> messageJson(LifeData data, String conversationId) =>
    data.conversations
        .firstWhere((c) => c.id == conversationId)
        .messages
        .map((m) => m.toJson())
        .toList();

Matcher permissionFailure() =>
    isA<ToolFailure>().having((error) => error.code, 'code', 'permission');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolRegistry registry;
  late LifeRepository repo;
  late ConversationMemoryStorage storage;

  setUp(() async {
    registry = await ToolRegistry.load();
    storage = ConversationMemoryStorage();
    repo = await LifeRepository.open(storage);
  });

  tearDown(() => repo.dispose());

  test('schema 3 migration preserves exact legacy messages, Core records and action receipts in the legacy chat', () {
    final created = DateTime.utc(2026, 10, 12, 10);
    final messages = [
      AgentMessage(
        id: 'legacy-user',
        createdAt: created,
        text: 'My exact question\nwith a second line.',
        isUser: true,
      ),
      AgentMessage(
        id: 'legacy-answer',
        createdAt: created.add(const Duration(seconds: 1)),
        text: 'Дәл сақталған жауап.',
        isUser: false,
      ),
    ];
    final proposals = [
      for (final status in ['pending', 'executed', 'rejected'])
        ToolProposal(
          id: 'legacy-$status',
          tool: 'create_project',
          arguments: {'name': 'Legacy $status project'},
          summary: 'Legacy $status summary',
          status: status,
          createdAt: created,
          result: status == 'pending'
              ? null
              : {'ok': status == 'executed', 'code': status},
        ),
    ];
    final before = LifeData(
      life: const LifeContext(
        name: 'Migration fixture',
        interfaceLanguage: Language.kazakh,
        goals: [
          GoalContext(id: 'goal', titleKey: 'Admission', areaKey: 'education'),
        ],
        exams: [ExamContext(id: 'exam', name: 'IELTS', date: '2027-06-12')],
      ),
      tasks: [
        Task(
          id: 'task',
          title: 'Existing essay',
          category: 'Task',
          goalId: 'goal',
          examId: 'exam',
          dueDate: '2027-06-01',
        ),
      ],
      events: [
        CalendarEvent(
          id: 'event',
          title: 'Existing preparation',
          category: 'Study',
          date: '2027-05-31',
          startTime: '18:00',
          endTime: '19:00',
          taskId: 'task',
        ),
      ],
      conversation: messages,
      actionProposals: proposals,
    );
    final legacy = before.toJson()
      ..['schemaVersion'] = 3
      ..['conversation'] = messages.map((m) => m.toJson()).toList()
      ..remove('conversations')
      ..remove('activeConversationId');
    for (final proposal in legacy['actionProposals'] as List) {
      (proposal as Map).remove('conversationId');
    }
    final migrated = LifeData.fromJson(legacy);
    expect(LifeData.schemaVersion, 4);
    expect(migrated.activeConversationId, ConversationRecord.legacyId);
    expect(migrated.conversations.single.id, ConversationRecord.legacyId);
    expect(
      messageJson(migrated, ConversationRecord.legacyId),
      messages.map((m) => m.toJson()).toList(),
    );
    expect(
      migrated.currentProposals.map((p) => p.toJson()),
      proposals.map((p) => p.toJson()),
    );
    expect(migrated.life.toJson(), before.life.toJson());
    expect(
      migrated.tasks.map((t) => t.toJson()),
      before.tasks.map((t) => t.toJson()),
    );
    expect(
      migrated.events.map((e) => e.toJson()),
      before.events.map((e) => e.toJson()),
    );
    expect(LifeData.fromJson(migrated.toJson()).toJson(), migrated.toJson());
  });

  test('separate chats and resumed selection preserve exact messages through native file reopen', () async {
    SharedPreferences.setMockInitialValues({});
    final folder = await Directory.systemTemp.createTemp('orta-conversation-');
    final native = StorageService(directory: folder);
    final local = await LifeRepository.open(native);
    try {
      final first = local.data.activeConversationId;
      await local.appendMessage(
        'First conversation\nKeep this line exactly.',
        isUser: true,
      );
      await local.appendMessage(
        'Жақсы, осы әңгімені жалғастырайық.',
        isUser: false,
      );
      final firstMessages = messageJson(local.data, first);
      final second = await local.newConversation();
      expect(second, isNot(first));
      await local.appendMessage('A different conversation.', isUser: true);
      await local.appendMessage('Отдельный сохранённый ответ.', isUser: false);
      final secondMessages = messageJson(local.data, second);
      await local.resumeConversation(first);
      final reopened = await LifeRepository.open(native);
      try {
        expect(reopened.data.activeConversationId, first);
        expect(reopened.data.conversations.length, 2);
        expect(messageJson(reopened.data, first), firstMessages);
        expect(messageJson(reopened.data, second), secondMessages);
        await reopened.resumeConversation(second);
        expect(
          reopened.data.conversation.map((m) => m.toJson()).toList(),
          secondMessages,
        );
      } finally {
        reopened.dispose();
      }
    } finally {
      local.dispose();
      await folder.delete(recursive: true);
    }
  });

  test('currentProposals scopes to the selected chat and restores its association after reopen', () async {
    final first = repo.data.activeConversationId;
    await repo.proposeTools(registry, [projectCall('First chat project')]);
    final firstAction = repo.data.currentProposals.single;
    final second = await repo.newConversation();
    expect(repo.data.currentProposals, isEmpty);
    await repo.proposeTools(registry, [projectCall('Second chat project')]);
    final secondAction = repo.data.currentProposals.single;
    expect(firstAction.conversationId, first);
    expect(secondAction.conversationId, second);
    expect(repo.data.actionProposals.length, 2);
    final reopened = await LifeRepository.open(storage);
    try {
      expect(reopened.data.currentProposals.single.id, secondAction.id);
      await reopened.resumeConversation(first);
      expect(reopened.data.currentProposals.single.id, firstAction.id);
    } finally {
      reopened.dispose();
    }
  });

  test('old-chat proposals cannot be approved or rejected singly or in a group from a new chat', () async {
    final first = repo.data.activeConversationId;
    await repo.proposeTools(registry, [projectCall('Old chat proposal')]);
    final oldId = repo.data.currentProposals.single.id;
    final second = await repo.newConversation();
    await repo.proposeTools(registry, [projectCall('New chat proposal')]);
    final newId = repo.data.currentProposals.single.id;
    final before = jsonEncode(repo.data.toJson());
    for (final approve in [true, false]) {
      await expectLater(
        repo.resolveAction(registry, oldId, approve: approve),
        throwsA(permissionFailure()),
      );
      await expectLater(
        repo.resolveActions(registry, [oldId], approve: approve),
        throwsA(permissionFailure()),
      );
      await expectLater(
        repo.resolveActions(registry, [newId, oldId], approve: approve),
        throwsA(permissionFailure()),
      );
    }
    expect(repo.data.activeConversationId, second);
    expect(jsonEncode(repo.data.toJson()), before);
    expect(repo.data.life.projects, isEmpty);
    await repo.resumeConversation(first);
    expect(
      (await repo.resolveAction(registry, oldId, approve: true))['ok'],
      true,
    );
    expect(repo.data.life.projects.single.name, 'Old chat proposal');
  });

  test('new writes supersede only active pending actions while other conversations keep their proposals', () async {
    final first = repo.data.activeConversationId;
    await repo.proposeTools(registry, [projectCall('Keep old pending')]);
    final old = repo.data.currentProposals.single.toJson();
    await repo.newConversation();
    await repo.proposeTools(registry, [projectCall('Revise current pending')]);
    final currentId = repo.data.currentProposals.single.id;
    await repo.proposeTools(registry, [
      projectCall('Revised current proposal'),
    ]);
    final unchanged = repo.data.actionProposals.singleWhere(
      (p) => p.conversationId == first,
    );
    expect(unchanged.toJson(), old);
    final superseded = repo.data.currentProposals.singleWhere(
      (p) => p.id == currentId,
    );
    expect(superseded.status, 'rejected');
    expect(superseded.result?['code'], 'superseded');
    expect(
      repo.data.currentProposals
          .where((p) => p.status == 'pending')
          .single
          .arguments['name'],
      'Revised current proposal',
    );
  });

  test('a delayed message with its original conversationId cannot enter a newly selected chat', () async {
    final original = repo.data.activeConversationId;
    await repo.appendMessage('Original question.', isUser: true);
    final changing = repo.newConversation();
    final delayed = repo.appendMessage(
      'Delayed answer for the original chat.',
      isUser: false,
      conversationId: original,
    );
    final second = await changing;
    await delayed;
    expect(repo.data.activeConversationId, second);
    expect(repo.data.conversation, isEmpty);
    expect(messageJson(repo.data, original).map((m) => m['text']), [
      'Original question.',
      'Delayed answer for the original chat.',
    ]);
    final reopened = await LifeRepository.open(storage);
    try {
      expect(reopened.data.activeConversationId, second);
      expect(reopened.data.conversation, isEmpty);
      expect(
        messageJson(reopened.data, original).last['text'],
        'Delayed answer for the original chat.',
      );
    } finally {
      reopened.dispose();
    }
  });

  test('the serialized proposal guard rejects an asynchronous write after a conversation switch', () async {
    final original = repo.data.activeConversationId;
    await repo.appendMessage(
      'Request with an outstanding response.',
      isUser: true,
    );
    final changing = repo.newConversation();
    final rejected = expectLater(
      repo.proposeTools(registry, [
        projectCall('Late proposal'),
      ], conversationId: original),
      throwsA(permissionFailure()),
    );
    final second = await changing;
    await rejected;
    expect(repo.data.activeConversationId, second);
    expect(repo.data.actionProposals, isEmpty);
    expect(repo.data.life.projects, isEmpty);
    expect(repo.data.conversation, isEmpty);
  });

  test('20-chat capacity refuses another chat without dropping history or changing selection', () async {
    for (var i = 0; i < 20; i++) {
      await repo.appendMessage(
        'Conversation $i preserved message.',
        isUser: true,
      );
      if (i < 19) await repo.newConversation();
    }
    expect(repo.data.conversations.length, 20);
    final before = repo.data.toJson();
    await expectLater(repo.newConversation(), throwsStateError);
    expect(repo.data.toJson(), before);
    final reopened = await LifeRepository.open(storage);
    try {
      expect(reopened.data.toJson(), before);
      expect(
        reopened.data.conversations.map((c) => c.messages.single.text),
        List.generate(20, (i) => 'Conversation $i preserved message.'),
      );
    } finally {
      reopened.dispose();
    }
  });

  test('pending-session edits cannot target or transplant a proposal from another conversation', () async {
    Map<String, dynamic> eventCall(String title) => {
      'name': 'create_calendar_event',
      'arguments': {
        'title': title,
        'date': '2027-01-11',
        'startTime': '18:00',
        'endTime': '19:00',
      },
    };
    await repo.proposeTools(registry, [eventCall('Old unsaved session')]);
    final old = repo.data.currentProposals.single;
    await repo.newConversation();
    await repo.proposeTools(registry, [eventCall('New unsaved session')]);
    final current = repo.data.currentProposals.single;
    expect(
      () => PlanningTools.calculate(repo.data, 'modify_pending_session', {
        'actionId': old.id,
        'targetDate': '2027-01-14',
      }),
      throwsA(
        isA<PlanningError>().having(
          (error) => error.code,
          'code',
          'missing_record',
        ),
      ),
    );
    final revised = PlanningTools.calculate(
      repo.data,
      'modify_pending_session',
      {'actionId': current.id, 'targetDate': '2027-01-14'},
    );
    expect(revised.length, 1);
    expect(
      (revised.single['arguments'] as Map)['title'],
      'New unsaved session',
    );
    expect((revised.single['arguments'] as Map)['date'], '2027-01-14');
    expect(repo.data.actionProposals.first.toJson(), old.toJson());
  });

  test('the Agent sends only the active conversation history and active pending proposals', () async {
    await repo.appendMessage('Private old chat text.', isUser: true);
    await repo.proposeTools(registry, [projectCall('Old chat pending title')]);
    final oldAction = repo.data.currentProposals.single.id;
    await repo.newConversation();
    await repo.appendMessage('New chat earlier question.', isUser: true);
    await repo.appendMessage('New chat earlier reply.', isUser: false);
    await repo.proposeTools(registry, [
      projectCall('Current chat pending title'),
    ]);
    final currentAction = repo.data.currentProposals.single.id;
    final service = RemoteOrtaAgentService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['conversation'], [
          {'role': 'user', 'content': 'New chat earlier question.'},
          {'role': 'assistant', 'content': 'New chat earlier reply.'},
        ]);
        final pending = body['pendingActions'] as List;
        expect(pending.length, 1);
        expect((pending.single as Map)['actionId'], currentAction);
        expect(request.body, isNot(contains(oldAction)));
        expect(request.body, isNot(contains('Private old chat text.')));
        return http.Response(
          jsonEncode({'message': 'Hello again.', 'toolCalls': []}),
          200,
        );
      }),
    );
    final response = await ActionAgent(repo, service, registry).respond(
      'Hello again.',
      () => AgentContextBuilder.build(repo.data, screen: 'home'),
    );
    expect(response, 'Hello again.');
  });
}
