import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/models/scheduling_preferences.dart';
import 'package:orta/models/language.dart';
import 'package:orta/services/ai_actions.dart';
import 'package:orta/services/action_agent.dart';
import 'package:orta/services/agent_context_builder.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/storage_service.dart';
import 'package:orta/services/remote_orta_agent_service.dart';

class MemoryStorage implements LifeDataStorage {
  LifeData data = LifeData.empty();
  bool fail = false;
  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(data.toJson());
  @override
  Future<void> saveLifeData(LifeData value) async {
    if (fail) throw StateError('Disk unavailable');
    data = LifeData.fromJson(value.toJson());
  }
}

Map<String, dynamic> call(String name, Map<String, dynamic> arguments) => {
  'name': name,
  'arguments': arguments,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolRegistry registry;
  late LifeRepository repo;
  late MemoryStorage storage;
  setUp(() async {
    registry = await ToolRegistry.load();
    storage = MemoryStorage();
    repo = await LifeRepository.open(storage);
  });
  tearDown(() => repo.dispose());
  test('B C K L: unknown tools, unexpected fields, invalid dates and missing essentials are rejected', () {
    for (final input in [
      call('arbitrary_code', {}),
      call('create_exam', {'name': 'IELTS'}),
      call('create_exam', {'name': 'IELTS', 'date': '2027-02-30'}),
      call('create_exam', {
        'name': 'IELTS',
        'date': '2027-06-12',
        'secret': 'x',
      }),
    ]) {
      expect(
        () => registry.validate(
          input['name'] as String,
          input['arguments'] as Map<String, dynamic>,
        ),
        throwsA(isA<ToolFailure>()),
      );
    }
  });
  test('D E F: proposal persists without a mutation; rejection remains unchanged after restart', () async {
    await repo.proposeTools(registry, [
      call('create_exam', {'name': 'IELTS', 'date': '2027-06-12'}),
    ]);
    expect(repo.data.life.exams, isEmpty);
    expect(repo.data.actionProposals.single.status, 'pending');
    final id = repo.data.actionProposals.single.id;
    await repo.resolveAction(registry, id, approve: false);
    final reopened = await LifeRepository.open(storage);
    expect(reopened.data.life.exams, isEmpty);
    expect(reopened.data.actionProposals.single.status, 'rejected');
    reopened.dispose();
  });
  test('G H I J N O: approved exam/task, completion, context and receipts survive native file restart; duplicate approvals are safe', () async {
    final folder = await Directory.systemTemp.createTemp('orta-actions-');
    SharedPreferences.setMockInitialValues({});
    final native = StorageService(directory: folder);
    final local = await LifeRepository.open(native);
    try {
      await local.proposeTools(registry, [
        call('create_exam', {'name': 'IELTS', 'date': '2027-06-12'}),
        call('create_task', {'title': 'Essay'}),
      ]);
      final proposals = local.data.actionProposals.toList();
      await Future.wait([
        local.resolveAction(registry, proposals[0].id, approve: true),
        local.resolveAction(registry, proposals[0].id, approve: true),
      ]);
      await local.resolveAction(registry, proposals[1].id, approve: true);
      expect(local.data.life.exams.length, 1);
      expect(local.data.tasks.length, 1);
      await local.proposeTools(registry, [
        call('complete_task', {'id': local.data.tasks.single.id}),
      ]);
      await local.resolveAction(
        registry,
        local.data.actionProposals.last.id,
        approve: true,
      );
      expect(local.data.completedTasks.length, 1);
      expect(
        AgentContextBuilder.plan(local.data).single.id,
        local.data.life.exams.single.id,
      );
      expect(
        jsonEncode(
          AgentContextBuilder.build(local.data, screen: 'life').toJson(),
        ),
        contains('IELTS'),
      );
      final reopened = await LifeRepository.open(native);
      expect(reopened.data.completedTasks.length, 1);
      expect(
        reopened.data.actionProposals.every((p) => p.status == 'executed'),
        true,
      );
      expect(
        (await reopened.resolveAction(
          registry,
          proposals[0].id,
          approve: true,
        ))['ok'],
        true,
      );
      expect(reopened.data.life.exams.length, 1);
      reopened.dispose();
    } finally {
      local.dispose();
      await folder.delete(recursive: true);
    }
  });
  test('M: invalid multi-action group creates nothing; later conflicts are reported per action', () async {
    await expectLater(
      repo.proposeTools(registry, [
        call('create_project', {'name': 'GreenCity'}),
        call('create_exam', {'name': 'Missing date'}),
      ]),
      throwsA(isA<ToolFailure>()),
    );
    expect(repo.data.actionProposals, isEmpty);
    expect(repo.data.life.projects, isEmpty);
    await repo.proposeTools(registry, [
      call('create_project', {'name': 'GreenCity'}),
      call('create_task', {'title': 'Essay'}),
    ]);
    final group = repo.data.actionProposals.toList();
    await repo.saveProject(
      const ProjectContext(id: 'manual', name: 'GreenCity'),
    );
    expect(
      (await repo.resolveAction(registry, group[0].id, approve: true))['ok'],
      false,
    );
    expect(
      (await repo.resolveAction(registry, group[1].id, approve: true))['ok'],
      true,
    );
    expect(repo.data.actionProposals.map((p) => p.status), [
      'failed',
      'executed',
    ]);
  });
  test('P: disk failure leaves proposal pending and data unchanged; retry commits once', () async {
    await repo.proposeTools(registry, [
      call('create_task', {'title': 'Retry'}),
    ]);
    final id = repo.data.actionProposals.single.id;
    storage.fail = true;
    await expectLater(
      repo.resolveAction(registry, id, approve: true),
      throwsStateError,
    );
    expect(repo.data.tasks, isEmpty);
    expect(repo.data.actionProposals.single.status, 'pending');
    storage.fail = false;
    await repo.resolveAction(registry, id, approve: true);
    expect(repo.data.tasks.length, 1);
  });
  test('stale update and expired approval fail safely; unspecified fields preserved', () async {
    await repo.saveProject(
      const ProjectContext(
        id: 'p',
        name: 'GreenCity',
        description: 'Keep this',
      ),
    );
    await repo.proposeTools(registry, [
      call('update_project', {'id': 'p', 'stage': 'Active'}),
    ]);
    final id = repo.data.actionProposals.single.id;
    await repo.saveProject(
      const ProjectContext(id: 'p', name: 'Changed', description: 'Keep this'),
      create: false,
    );
    expect(
      (await repo.resolveAction(registry, id, approve: true))['code'],
      'conflict',
    );
    await repo.proposeTools(registry, [
      call('update_project', {'id': 'p', 'stage': 'Active'}),
    ]);
    await repo.resolveAction(
      registry,
      repo.data.actionProposals.last.id,
      approve: true,
    );
    expect(repo.data.life.projects.single.description, 'Keep this');
    final expired = registry.propose(
      repo.data,
      'create_task',
      {'title': 'Expired'},
      'expired',
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(
      () => registry.apply(repo.data, expired, DateTime.now()),
      throwsA(isA<ToolFailure>()),
    );
  });
  test('all entity create/update handlers and read tools execute with validated relationships', () async {
    for (final entry in [
      call('create_goal', {'titleKey': 'Study'}),
      call('create_exam', {'name': 'Exam', 'date': '2027-01-01'}),
      call('create_project', {'name': 'Project'}),
      call('create_task', {'title': 'Task'}),
      call('create_calendar_event', {
        'title': 'Session',
        'date': '2027-01-01',
        'startTime': '09:00',
        'endTime': '10:00',
      }),
    ]) {
      await repo.proposeTools(registry, [entry]);
      await repo.resolveAction(
        registry,
        repo.data.actionProposals.last.id,
        approve: true,
      );
    }
    for (final kind in ['goal', 'exam', 'project', 'task', 'calendar_event']) {
      final record = registry.records(repo.data, kind).single;
      final field = kind == 'goal'
          ? 'titleKey'
          : kind == 'exam' || kind == 'project'
          ? 'name'
          : 'title';
      await repo.proposeTools(registry, [
        call('update_$kind', {'id': record['id'], field: 'Updated $kind'}),
      ]);
      expect(
        (await repo.resolveAction(
          registry,
          repo.data.actionProposals.last.id,
          approve: true,
        ))['ok'],
        true,
      );
      expect(registry.records(repo.data, kind).single[field], 'Updated $kind');
    }
    await repo.saveSchedulingPreferences(
      SchedulingPreferences(
        timezone: 'Asia/Aqtau',
        studyStart: '18:00',
        studyEnd: '21:00',
        weekdays: [1, 2, 3, 4, 5],
      ),
    );
    for (final tool in registry.definitions.keys.where(
      (t) => registry.permission(t) == 'read',
    )) {
      expect(
        registry.read(
          repo.data,
          tool,
          tool == 'get_free_time' ? {'date': '2027-01-01'} : {},
        )['ok'],
        true,
      );
    }
    expect(
      (registry.read(repo.data, 'get_free_time', {'date': '2027-01-02'})['data']
          as Map)['availability'],
      'confirmed',
    );
  });
  test('conversational approval must reference the single pending review; unrelated yes is denied', () async {
    await repo.proposeTools(registry, [
      call('create_task', {'title': 'Confirm me'}),
    ]);
    final id = repo.data.actionProposals.single.id;
    final service = RemoteOrtaAgentService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'message': '',
            'toolCalls': [
              {
                'id': 'call1',
                'name': 'approve_action',
                'arguments': {'actionId': id},
              },
            ],
            'rawCalls': [
              {
                'id': 'call1',
                'type': 'function',
                'function': {
                  'name': 'approve_action',
                  'arguments': jsonEncode({'actionId': id}),
                },
              },
            ],
          }),
          200,
        ),
      ),
    );
    final agent = ActionAgent(repo, service, registry);
    await repo.appendMessage('Are you ready?', isUser: false);
    await agent.respond(
      'yes',
      () => AgentContextBuilder.build(repo.data, screen: 'home'),
    );
    expect(repo.data.tasks, isEmpty);
    await repo.appendMessage(
      actionText(Language.english, 'review'),
      isUser: false,
    );
    await agent.respond(
      'yes',
      () => AgentContextBuilder.build(repo.data, screen: 'home'),
    );
    expect(repo.data.tasks.length, 1);
    await agent.respond(
      'yes',
      () => AgentContextBuilder.build(repo.data, screen: 'home'),
    );
    expect(repo.data.tasks.length, 1);
    expect(explicitDecision('yes please destroy everything', true), false);
  });
  test('read loop returns actual client data to inference and refreshes context after a write', () async {
    await repo.saveExam(
      const ExamContext(id: 'e', name: 'Stored exam', date: '2027-06-12'),
    );
    var requests = 0;
    final service = RemoteOrtaAgentService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        requests++;
        if (requests == 1) {
          return http.Response(
            jsonEncode({
              'message': '',
              'toolCalls': [
                {'id': 'read1', 'name': 'get_exams', 'arguments': {}},
              ],
              'rawCalls': [
                {
                  'id': 'read1',
                  'type': 'function',
                  'function': {'name': 'get_exams', 'arguments': '{}'},
                },
              ],
            }),
            200,
          );
        }
        expect(jsonEncode(body['toolTurns']), contains('Stored exam'));
        return http.Response(
          jsonEncode({'message': 'Stored exam', 'toolCalls': []}),
          200,
        );
      }),
    );
    expect(
      await ActionAgent(repo, service, registry).respond(
        'What exams?',
        () => AgentContextBuilder.build(repo.data, screen: 'home'),
      ),
      'Stored exam',
    );
    expect(requests, 2);
  });
  test('schema 1 data migrates to schema 2 with no invented approvals', () {
    final old = LifeData.empty().toJson()
      ..['schemaVersion'] = 1
      ..remove('actionProposals');
    final restored = LifeData.fromJson(old);
    expect(restored.actionProposals, isEmpty);
    expect(restored.toJson()['schemaVersion'], 4);
  });
}
