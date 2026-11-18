import '../models/scheduling_preferences.dart';

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/life_context.dart';
import '../models/life_data.dart';
import '../models/orta_models.dart';
import 'storage_service.dart';
import 'ai_actions.dart';

String newLifeId(String kind) {
  final random = Random.secure();
  return '${kind}_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

class LifeRepository extends ChangeNotifier {
  final LifeDataStorage storage;
  LifeData _data;
  Future<void> _queue = Future.value();
  bool _closed = false;
  LifeRepository._(this.storage, this._data);
  static Future<LifeRepository> open(LifeDataStorage storage) async =>
      LifeRepository._(storage, await storage.loadLifeData());
  LifeData get data => _data;

  /// Safe language metadata is read through a projection; Core records stay untouched.
  LifeContext get lifeView => data.life.copyWith(
    languages: data.life.languages
        .map(
          (language) => LanguageContext(
            languageCode: language.languageCode,
            reason: language.reason,
            level:
                data.languages[language.languageCode]?.level ?? language.level,
          ),
        )
        .toList(),
  );

  Future<void> _commit(LifeData Function(LifeData) change) {
    final operation = _queue.then((_) async {
      if (_closed) throw StateError('Repository is closed');
      final next = change(_data);
      next.validate();
      await storage.saveLifeData(next);
      _data = next;
      if (!_closed) notifyListeners();
    });
    // Failed operations don't poison subsequent writes, and never publish unsaved state.
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> completeOnboarding(LifeContext life) =>
      _commit((data) => data.copyWith(life: life, onboardingCompleted: true));
  Future<void> updateLife(LifeContext Function(LifeContext) change) =>
      _commit((data) => data.copyWith(life: change(data.life)));

  List<T> _put<T>(
    List<T> all,
    T value,
    String Function(T) id, {
    required bool create,
  }) {
    final index = all.indexWhere((row) => id(row) == id(value));
    if (create && index >= 0) {
      throw StateError('A record with this ID already exists');
    }
    if (!create && index < 0) throw StateError('Record no longer exists');
    return index < 0
        ? [...all, value]
        : [...all.take(index), value, ...all.skip(index + 1)];
  }

  Future<void> saveGoal(GoalContext value, {bool create = true}) => updateLife(
    (life) => life.copyWith(
      goals: _put(life.goals, value, (g) => g.id, create: create),
    ),
  );
  Future<void> saveProject(ProjectContext value, {bool create = true}) =>
      updateLife(
        (life) => life.copyWith(
          projects: _put(life.projects, value, (p) => p.id, create: create),
        ),
      );
  Future<void> saveExam(ExamContext value, {bool create = true}) {
    if (value.date != null && !isLifeDate(value.date!)) {
      return Future.error(const FormatException('Use a full YYYY-MM-DD date'));
    }
    return updateLife(
      (life) => life.copyWith(
        exams: _put(life.exams, value, (e) => e.id, create: create),
      ),
    );
  }

  Future<void> saveTask(Task value, {bool create = true}) => _commit(
    (data) => data.copyWith(
      tasks: _put(data.tasks, value, (t) => t.id, create: create),
    ),
  );
  Future<void> saveEvent(CalendarEvent value, {bool create = true}) => _commit(
    (data) => data.copyWith(
      events: _put(data.events, value, (e) => e.id, create: create),
    ),
  );
  Future<void> completeTask(String id, bool completed) => _commit((data) {
    final task = data.tasks.firstWhere((t) => t.id == id);
    if (task.completed == completed) return data;
    return data.copyWith(
      tasks: _put(
        data.tasks,
        task.withCompletion(completed, DateTime.now().toUtc()),
        (t) => t.id,
        create: false,
      ),
    );
  });

  Future<void> deleteRecord(String kind, String id) => _commit((data) {
    // Validation restricts deletion of referenced records rather than silently cascading.
    switch (kind) {
      case 'goal':
        if (!data.life.goals.any((g) => g.id == id)) {
          throw StateError('Record not found');
        }
        return data.copyWith(
          life: data.life.copyWith(
            goals: data.life.goals.where((g) => g.id != id).toList(),
          ),
        );
      case 'exam':
        if (!data.life.exams.any((e) => e.id == id)) {
          throw StateError('Record not found');
        }
        return data.copyWith(
          life: data.life.copyWith(
            exams: data.life.exams.where((e) => e.id != id).toList(),
          ),
        );
      case 'project':
        if (!data.life.projects.any((p) => p.id == id)) {
          throw StateError('Record not found');
        }
        return data.copyWith(
          life: data.life.copyWith(
            projects: data.life.projects.where((p) => p.id != id).toList(),
          ),
        );
      case 'task':
        if (!data.tasks.any((t) => t.id == id)) {
          throw StateError('Record not found');
        }
        return data.copyWith(
          tasks: data.tasks.where((t) => t.id != id).toList(),
        );
      case 'event':
        if (!data.events.any((e) => e.id == id)) {
          throw StateError('Record not found');
        }
        return data.copyWith(
          events: data.events.where((e) => e.id != id).toList(),
        );
      default:
        throw ArgumentError('Unknown record type');
    }
  });

  Future<void> reset() => _commit((_) => LifeData.empty());
  Future<String> newConversation() async {
    var id = newLifeId('conversation');
    await _commit((data) {
      if (data.conversation.isEmpty &&
          !data.currentProposals.any((p) => p.status == 'pending')) {
        id = data.activeConversationId;
        return data;
      }
      if (data.conversations.length >= 20) {
        throw StateError('Conversation history is full');
      }
      return data.copyWith(
        conversations: [
          ...data.conversations,
          ConversationRecord(id: id),
        ],
        activeConversationId: id,
      );
    });
    return id;
  }

  Future<void> resumeConversation(String id) => _commit((data) {
    if (!data.conversations.any((c) => c.id == id)) {
      throw StateError('Conversation not found');
    }
    return data.copyWith(activeConversationId: id);
  });
  Future<void> appendMessage(
    String text, {
    required bool isUser,
    String? conversationId,
  }) => _commit((data) {
    final id = conversationId ?? data.activeConversationId;
    final record = data.conversations.firstWhere((c) => c.id == id);
    final all = [
      ...record.messages,
      AgentMessage(
        id: newLifeId('message'),
        text: text,
        isUser: isUser,
        createdAt: DateTime.now().toUtc(),
      ),
    ];
    return data.copyWith(
      conversations: data.conversations
          .map(
            (c) => c.id == id
                ? c.withMessages(all.skip(max(0, all.length - 50)).toList())
                : c,
          )
          .toList(),
    );
  });

  /// Only target-language metadata may change; callers cannot pass a Core mutation.
  Future<void> saveLanguageProgress(LanguageProgress progress) => _commit(
    (data) => data.copyWith(
      languages: {...data.languages, progress.languageCode: progress},
    ),
  );
  LanguageProgress languageProgress(String code) =>
      data.languages[code] ??
      LanguageProgress(
        languageCode: code,
        level:
            data.life.languages
                .where((l) => l.languageCode == code)
                .map((l) => l.level)
                .firstOrNull ??
            '',
      );
  Future<void> addLanguageMoment(String code, String phrase) => _commit((data) {
    final current =
        data.languages[code] ??
        LanguageProgress(
          languageCode: code,
          level:
              data.life.languages
                  .where((l) => l.languageCode == code)
                  .map((l) => l.level)
                  .firstOrNull ??
              '',
        );
    final next = LanguageProgress(
      languageCode: code,
      level: current.level,
      completedSessions: current.completedSessions,
      lifeMap: current.lifeMap,
      practiceHistory: current.practiceHistory,
      memories: [
        ...current.memories,
        LanguageMemory(
          id: newLifeId('moment'),
          title: 'Moment',
          context: 'Language practice',
          phrase: phrase,
          meaning: '',
          language: code,
        ),
      ],
    );
    return data.copyWith(languages: {...data.languages, code: next});
  });
  Future<void> recordPractice(
    String code, {
    String? response,
    String topicKey = 'daily',
  }) => _commit((data) {
    if (response != null &&
        (response.trim().isEmpty || response.length > 4000)) {
      throw const FormatException('Practice response is required');
    }
    final current =
        data.languages[code] ??
        LanguageProgress(
          languageCode: code,
          level:
              data.life.languages
                  .where((l) => l.languageCode == code)
                  .map((l) => l.level)
                  .firstOrNull ??
              '',
        );
    return data.copyWith(
      languages: {
        ...data.languages,
        code: LanguageProgress(
          languageCode: code,
          level: current.level,
          completedSessions: current.completedSessions + 1,
          practiceHistory: response == null
              ? current.practiceHistory
              : [
                      ...current.practiceHistory,
                      LanguagePracticeEntry(
                        id: newLifeId('practice'),
                        createdAt: DateTime.now().toUtc(),
                        topicKey: topicKey,
                        response: response.trim(),
                      ),
                    ]
                    .skip(max(0, current.practiceHistory.length + 1 - 50))
                    .toList(),
          lifeMap: current.lifeMap,
          memories: current.memories,
        ),
      },
    );
  });

  Future<void> saveSchedulingPreferences(SchedulingPreferences value) =>
      _commit((data) {
        value.validate();
        return data.copyWith(scheduling: value);
      });
  Future<void> completeSession(String id, bool completed) => _commit(
    (data) => data.copyWith(
      events: data.events
          .map(
            (e) => e.id == id
                ? CalendarEvent.fromJson({
                    ...e.toJson(),
                    'completedAt': completed
                        ? DateTime.now().toUtc().toIso8601String()
                        : null,
                  })
                : e,
          )
          .toList(),
    ),
  );

  Future<Map<String, dynamic>> resolveActions(
    ToolRegistry registry,
    List<String> ids, {
    required bool approve,
  }) async {
    Map<String, dynamic> result = {};
    await _commit((data) {
      if (ids.isEmpty || ids.length > 8 || ids.toSet().length != ids.length) {
        throw const ToolFailure('invalid_arguments', 'Invalid action group.');
      }
      final proposals = data.actionProposals
          .where((p) => ids.contains(p.id))
          .toList();
      if (proposals.length != ids.length) {
        throw const ToolFailure('missing_record', 'Proposal no longer exists.');
      }
      if (proposals.any((p) => p.conversationId != data.activeConversationId)) {
        throw const ToolFailure(
          'permission',
          'This proposal belongs to another conversation.',
        );
      }
      var next = data;
      final receipts = <String, ToolProposal>{};
      try {
        for (final p in proposals.whereType<ToolProposal>()) {
          if (p.status != 'pending') {
            if (approve && p.status != 'executed') {
              throw const ToolFailure('stale', 'Proposal no longer pending.');
            }
            continue;
          }
          if (approve) next = registry.apply(next, p, DateTime.now().toUtc());
          final receipt = approve
              ? {
                  'ok': true,
                  'tool': p.tool,
                  'summary': registry.humanSummary(data, p.tool, p.arguments),
                  'actionId': p.id,
                  'recordId': p.arguments['id'] ?? 'ai_${p.id}',
                }
              : {'ok': false, 'code': 'rejected', 'actionId': p.id};
          receipts[p.id] = p.withStatus(
            approve ? 'executed' : 'rejected',
            result: receipt,
          );
        }
        next.validate();
        result = approve
            ? {
                'ok': true,
                'summary': proposals
                    .whereType<ToolProposal>()
                    .map(
                      (p) => registry.humanSummary(data, p.tool, p.arguments),
                    )
                    .join('\n\n'),
                'actionIds': ids,
              }
            : {'ok': false, 'code': 'rejected', 'actionIds': ids};
        return next.copyWith(
          actionProposals: data.actionProposals
              .map((p) => receipts[p.id] ?? p)
              .toList(),
        );
      } catch (error) {
        // The group is atomic: publish neither a partial mutation nor a false success receipt.
        final code = error is ToolFailure ? error.code : 'invalid_arguments';
        result = {
          'ok': false,
          'code': 'batchFailed',
          'reason': code,
          'actionIds': ids,
        };
        return data.copyWith(
          actionProposals: data.actionProposals
              .map(
                (p) => ids.contains(p.id) && p.status == 'pending'
                    ? p.withStatus(
                        'failed',
                        result: {
                          'ok': false,
                          'code': 'batchFailed',
                          'reason': code,
                        },
                      )
                    : p,
              )
              .toList(),
        );
      }
    });
    return result;
  }

  Future<void> proposeTools(
    ToolRegistry registry,
    List<Map<String, dynamic>> calls, {
    String? conversationId,
  }) => _commit((data) {
    if (conversationId != null && conversationId != data.activeConversationId) {
      throw const ToolFailure(
        'permission',
        'Conversation changed before proposal creation.',
      );
    }
    if (calls.isEmpty || calls.length > 8) {
      throw const ToolFailure(
        'invalid_arguments',
        'At most eight actions per request.',
      );
    }
    final now = DateTime.now().toUtc();
    final pending = <ToolProposal>[];
    var preview = data;
    for (final call in calls) {
      final proposal = registry.propose(
        preview,
        call['name'] as String,
        Map<String, dynamic>.from(call['arguments'] as Map),
        newLifeId('action'),
        now,
      );
      preview = registry.apply(preview, proposal, now);
      pending.add(proposal);
    }
    // A revised request supersedes pending proposals; executing/rejected receipts remain durable.
    return data.copyWith(
      actionProposals: [
        ...data.actionProposals.map(
          (p) =>
              p.status == 'pending' &&
                  p.conversationId == data.activeConversationId
              ? p.withStatus(
                  'rejected',
                  result: {'ok': false, 'code': 'superseded'},
                )
              : p,
        ),
        ...pending,
      ],
    );
  });

  Future<Map<String, dynamic>> resolveAction(
    ToolRegistry registry,
    String id, {
    required bool approve,
  }) async {
    Map<String, dynamic> result = {};
    await _commit((data) {
      final proposal = data.actionProposals
          .where((p) => p.id == id)
          .firstOrNull;
      if (proposal == null) {
        throw const ToolFailure('missing_record', 'Proposal no longer exists.');
      }
      if (proposal.conversationId != data.activeConversationId) {
        throw const ToolFailure(
          'permission',
          'This proposal belongs to another conversation.',
        );
      }
      if (proposal.status != 'pending') {
        result = proposal.result ?? {'ok': false, 'code': proposal.status};
        return data; // Durable execution receipt makes repeated confirmation idempotent.
      }
      var next = data;
      var status = approve ? 'executed' : 'rejected';
      if (approve) {
        try {
          next = registry.apply(data, proposal, DateTime.now().toUtc());
          result = {
            'ok': true,
            'tool': proposal.tool,
            'summary': registry.humanSummary(
              data,
              proposal.tool,
              proposal.arguments,
            ),
            'actionId': id,
            'recordId': proposal.arguments['id'] ?? 'ai_$id',
          };
        } on ToolFailure catch (error) {
          status = 'failed';
          result = {'ok': false, 'code': error.code, 'detail': error.detail};
        } on FormatException {
          status = 'failed';
          result = {
            'ok': false,
            'code': 'invalid_arguments',
            'detail': 'Invalid record relationship or date.',
          };
        }
      } else {
        result = {'ok': false, 'code': 'rejected', 'actionId': id};
      }
      // Mutation and receipt are persisted atomically. Failed storage leaves both pending/unchanged.
      return next.copyWith(
        actionProposals: data.actionProposals
            .map((p) => p.id == id ? p.withStatus(status, result: result) : p)
            .toList(),
      );
    });
    return result;
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
