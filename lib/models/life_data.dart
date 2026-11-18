import 'dart:convert';

import 'scheduling_preferences.dart';

import '../services/ai_actions.dart';

import 'language.dart';
import 'life_context.dart';
import 'orta_models.dart';

bool isLifeDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
}

class LanguagePracticeEntry {
  final String id, topicKey, response;
  final DateTime createdAt;
  const LanguagePracticeEntry({
    required this.id,
    required this.createdAt,
    required this.topicKey,
    required this.response,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'topicKey': topicKey,
    'response': response,
  };
  factory LanguagePracticeEntry.fromJson(Map<String, dynamic> json) =>
      LanguagePracticeEntry(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        topicKey: json['topicKey'] as String,
        response: json['response'] as String,
      );
}

class ConversationRecord {
  static const legacyId = 'conversation_main';
  final String id;
  final List<AgentMessage> messages;
  ConversationRecord({required this.id, List<AgentMessage> messages = const []})
    : messages = List.unmodifiable(messages);
  String get title {
    final first =
        messages
            .where((m) => m.isUser)
            .firstOrNull
            ?.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
    return first.length > 70 ? '${first.substring(0, 70)}…' : first;
  }

  DateTime? get updatedAt => messages.lastOrNull?.createdAt;
  ConversationRecord withMessages(List<AgentMessage> values) =>
      ConversationRecord(id: id, messages: values);
  Map<String, dynamic> toJson() => {
    'id': id,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
  factory ConversationRecord.fromJson(Map<String, dynamic> json) =>
      ConversationRecord(
        id: json['id'] as String,
        messages: (json['messages'] as List)
            .map(
              (m) => AgentMessage.fromJson(Map<String, dynamic>.from(m as Map)),
            )
            .toList(),
      );
}

class LanguageProgress {
  final String languageCode;
  final String level;
  final int completedSessions;
  final List<LifeMapCategory> lifeMap;
  final List<LanguageMemory> memories;
  final List<LanguagePracticeEntry> practiceHistory;
  LanguageProgress({
    required this.languageCode,
    this.level = '',
    this.completedSessions = 0,
    List<LifeMapCategory> lifeMap = const [],
    List<LanguageMemory> memories = const [],
    List<LanguagePracticeEntry> practiceHistory = const [],
  }) : lifeMap = List.unmodifiable(lifeMap),
       memories = List.unmodifiable(memories),
       practiceHistory = List.unmodifiable(practiceHistory);
  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'level': level,
    'completedSessions': completedSessions,
    'practiceHistory': practiceHistory.map((e) => e.toJson()).toList(),
    'lifeMap': lifeMap
        .map(
          (item) => {
            'name': item.name,
            'value': item.value,
            'description': item.description,
          },
        )
        .toList(),
    'memories': memories
        .map(
          (item) => {
            'id': item.id,
            'title': item.title,
            'context': item.context,
            'phrase': item.phrase,
            'meaning': item.meaning,
            'language': item.language,
          },
        )
        .toList(),
  };
  factory LanguageProgress.fromJson(Map<String, dynamic> json) =>
      LanguageProgress(
        languageCode: json['languageCode'] as String,
        level: json['level'] as String,
        completedSessions: json['completedSessions'] as int,
        practiceHistory: (json['practiceHistory'] as List? ?? [])
            .map(
              (e) => LanguagePracticeEntry.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        lifeMap: (json['lifeMap'] as List)
            .map(
              (row) => LifeMapCategory(
                name: row['name'] as String,
                value: row['value'] as int,
                description: row['description'] as String,
              ),
            )
            .toList(),
        memories: (json['memories'] as List)
            .map(
              (row) => LanguageMemory(
                id: row['id'] as String,
                title: row['title'] as String,
                context: row['context'] as String,
                phrase: row['phrase'] as String,
                meaning: row['meaning'] as String,
                language: row['language'] as String,
              ),
            )
            .toList(),
      );
}

LifeContext _freezeLife(LifeContext source) {
  final life = LifeContext.fromJson(source.toJson());
  return life.copyWith(
    currentLifeAreas: Set.unmodifiable(life.currentLifeAreas),
    interpretedSuggestions: List.unmodifiable(life.interpretedSuggestions),
    goals: List.unmodifiable(
      life.goals.map(
        (g) => GoalContext(
          id: g.id,
          titleKey: g.titleKey,
          areaKey: g.areaKey,
          details: Map.unmodifiable(g.details),
        ),
      ),
    ),
    universityPlans: List.unmodifiable(life.universityPlans),
    projects: List.unmodifiable(life.projects),
    languages: List.unmodifiable(life.languages),
    exams: List.unmodifiable(life.exams),
    commitments: List.unmodifiable(life.commitments),
    preferences: Map.unmodifiable(life.preferences),
  );
}

/// One persisted snapshot; Plan and Progress are projections, never separate stores.
class LifeData {
  static const schemaVersion = 4;
  final LifeContext life;
  final SchedulingPreferences scheduling;
  final bool onboardingCompleted;
  final List<Task> tasks;
  final List<CalendarEvent> events;
  final Map<String, LanguageProgress> languages;
  final List<ConversationRecord> conversations;
  final String activeConversationId;
  List<AgentMessage> get conversation =>
      conversations.firstWhere((c) => c.id == activeConversationId).messages;
  List<ToolProposal> get currentProposals => actionProposals
      .where((p) => p.conversationId == activeConversationId)
      .toList();
  final List<ToolProposal> actionProposals;

  LifeData({
    required LifeContext life,
    SchedulingPreferences? scheduling,
    this.onboardingCompleted = false,
    List<Task> tasks = const [],
    List<CalendarEvent> events = const [],
    Map<String, LanguageProgress> languages = const {},
    List<AgentMessage> conversation = const [],
    List<ConversationRecord>? conversations,
    String? activeConversationId,
    List<ToolProposal> actionProposals = const [],
  }) : scheduling = scheduling ?? SchedulingPreferences(),
       life = _freezeLife(life),
       tasks = List.unmodifiable(tasks),
       events = List.unmodifiable(events),
       languages = Map.unmodifiable(languages),
       conversations = List.unmodifiable(
         conversations ??
             [
               ConversationRecord(
                 id: ConversationRecord.legacyId,
                 messages: conversation,
               ),
             ],
       ),
       activeConversationId =
           activeConversationId ??
           conversations?.firstOrNull?.id ??
           ConversationRecord.legacyId,
       actionProposals = List.unmodifiable(actionProposals);

  factory LifeData.empty() => LifeData(
    life: const LifeContext(name: '', interfaceLanguage: Language.english),
  );

  LifeData copyWith({
    LifeContext? life,
    SchedulingPreferences? scheduling,
    bool? onboardingCompleted,
    List<Task>? tasks,
    List<CalendarEvent>? events,
    Map<String, LanguageProgress>? languages,
    List<AgentMessage>? conversation,
    List<ConversationRecord>? conversations,
    String? activeConversationId,
    List<ToolProposal>? actionProposals,
  }) => LifeData(
    life: life ?? this.life,
    scheduling: scheduling ?? this.scheduling,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    tasks: tasks ?? this.tasks,
    events: events ?? this.events,
    languages: languages ?? this.languages,
    conversations: conversation == null
        ? conversations ?? this.conversations
        : (conversations ?? this.conversations)
              .map(
                (c) =>
                    c.id == (activeConversationId ?? this.activeConversationId)
                    ? c.withMessages(conversation)
                    : c,
              )
              .toList(),
    activeConversationId: activeConversationId ?? this.activeConversationId,
    actionProposals: actionProposals ?? this.actionProposals,
  );

  List<Task> get completedTasks =>
      tasks.where((task) => task.completed).toList();

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'scheduling': scheduling.toJson(),
    'actionProposals': actionProposals.map((p) => p.toJson()).toList(),
    'lifeContext': life.toJson(),
    'onboardingCompleted': onboardingCompleted,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'languageProgress': languages.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'conversations': conversations.map((c) => c.toJson()).toList(),
    'activeConversationId': activeConversationId,
  };

  factory LifeData.fromJson(Map<String, dynamic> json) {
    if (![1, 2, 3, schemaVersion].contains(json['schemaVersion'])) {
      throw const FormatException('Unsupported data version');
    }
    final data = LifeData(
      scheduling: SchedulingPreferences.fromJson(
        Map<String, dynamic>.from(json['scheduling'] as Map? ?? {}),
      ),
      actionProposals: (json['actionProposals'] as List? ?? [])
          .map(
            (p) => ToolProposal.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList(),
      life: LifeContext.fromJson(
        Map<String, dynamic>.from(json['lifeContext'] as Map),
      ),
      onboardingCompleted: json['onboardingCompleted'] as bool,
      tasks: (json['tasks'] as List)
          .map((row) => Task.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
      events: (json['events'] as List)
          .map(
            (row) =>
                CalendarEvent.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      languages: (json['languageProgress'] as Map).map(
        (key, value) => MapEntry(
          key as String,
          LanguageProgress.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
      conversations: json['conversations'] == null
          ? null
          : (json['conversations'] as List)
                .map(
                  (c) => ConversationRecord.fromJson(
                    Map<String, dynamic>.from(c as Map),
                  ),
                )
                .toList(),
      activeConversationId: json['activeConversationId'] as String?,
      conversation: (json['conversation'] as List? ?? [])
          .map(
            (row) =>
                AgentMessage.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
    );
    data.validate();
    return data;
  }

  void validate() {
    scheduling.validate();
    void check(bool valid, String message) {
      if (!valid) throw FormatException(message);
    }

    void ids(Iterable<String> values) {
      final list = values.toList();
      check(
        list.every((id) => id.trim().isNotEmpty) &&
            list.toSet().length == list.length,
        'Invalid or duplicate identifiers',
      );
    }

    ids(actionProposals.map((p) => p.id));
    check(
      actionProposals.every(
        (p) => p.id.isNotEmpty && p.tool.isNotEmpty && p.summary.isNotEmpty,
      ),
      'Invalid proposal',
    );
    ids(life.goals.map((g) => g.id));
    ids(life.exams.map((e) => e.id));
    ids(life.projects.map((p) => p.id));
    ids(life.universityPlans.map((p) => p.id));
    ids(tasks.map((t) => t.id));
    ids(events.map((e) => e.id));
    ids(conversations.map((c) => c.id));
    check(
      conversations.isNotEmpty &&
          conversations.length <= 20 &&
          conversations.any((c) => c.id == activeConversationId),
      'Invalid conversation selection',
    );
    ids(conversations.expand((c) => c.messages).map((m) => m.id ?? ''));
    check(
      actionProposals.every(
        (p) => conversations.any((c) => c.id == p.conversationId),
      ),
      'Proposal conversation does not exist',
    );
    check(
      life.languages.map((l) => l.languageCode).toSet().length ==
          life.languages.length,
      'Duplicate target languages',
    );
    check(
      life.goals.every((g) => g.titleKey.trim().isNotEmpty) &&
          life.exams.every((e) => e.name.trim().isNotEmpty) &&
          life.projects.every((p) => p.name.trim().isNotEmpty),
      'Empty record title',
    );
    bool reference(String? id, Iterable<String> all) =>
        id == null || all.contains(id);
    void links(String? goal, String? project, String? exam) {
      check(
        reference(goal, life.goals.map((g) => g.id)) &&
            reference(project, life.projects.map((p) => p.id)) &&
            reference(exam, life.exams.map((e) => e.id)),
        'Record relationship does not exist',
      );
    }

    for (final task in tasks) {
      links(task.goalId, task.projectId, task.examId);
      check(
        task.title.trim().isNotEmpty &&
            (task.dueDate == null || isLifeDate(task.dueDate!)),
        'Invalid task',
      );
      check(
        task.completed == (task.completedAt != null),
        'Invalid task completion',
      );
    }
    check(
      tasks.every(
        (t) =>
            ['', 'low', 'normal', 'high'].contains(t.priority) &&
            (t.estimatedMinutes == null ||
                t.estimatedMinutes! > 0 && t.estimatedMinutes! <= 10080),
      ),
      'Invalid task effort or priority',
    );
    final clock = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
    for (final event in events) {
      links(event.goalId, event.projectId, event.examId);
      check(
        reference(event.taskId, tasks.map((t) => t.id)),
        'Event task does not exist',
      );
      check(
        event.title.trim().isNotEmpty &&
            isLifeDate(event.date) &&
            (event.isAllDay
                ? event.startTime.isEmpty && event.endTime.isEmpty
                : clock.hasMatch(event.startTime) &&
                      clock.hasMatch(event.endTime) &&
                      event.startTime.compareTo(event.endTime) < 0) &&
            (event.timezone.isEmpty || knownSchedulingZone(event.timezone)) &&
            ['', 'study', 'work'].contains(event.planningKind) &&
            (event.latestEnd == null || schedulingTime(event.latestEnd!)) &&
            (event.planningDeadline == null ||
                isLifeDate(event.planningDeadline!)),
        'Invalid calendar event',
      );
    }
    for (final entry in languages.entries) {
      check(
        entry.key == entry.value.languageCode &&
            RegExp(r'^[a-z]{2,3}(?:-[A-Za-z0-9]+)?$').hasMatch(entry.key) &&
            entry.value.completedSessions >= 0,
        'Invalid language progress',
      );
      ids(entry.value.practiceHistory.map((p) => p.id));
      check(
        entry.value.practiceHistory.length <= 50 &&
            entry.value.practiceHistory.every(
              (p) =>
                  p.topicKey.trim().isNotEmpty &&
                  p.topicKey.length <= 50 &&
                  p.response.trim().isNotEmpty &&
                  p.response.length <= 4000,
            ),
        'Invalid practice history',
      );
      ids(entry.value.memories.map((m) => m.id ?? ''));
      check(
        entry.value.memories.every((m) => m.language == entry.key),
        'Language histories must remain separate',
      );
      check(
        entry.value.lifeMap.every((m) => m.value >= 0 && m.value <= 100),
        'Invalid language map',
      );
    }
    check(
      conversations.every(
        (c) =>
            c.messages.length <= 50 &&
            c.messages.every(
              (m) => m.createdAt != null && m.text.trim().isNotEmpty,
            ),
      ),
      'Invalid conversation',
    );
    final encoded = jsonEncode(toJson());
    check(
      !RegExp(r'\b(?:gsk_[A-Za-z0-9]{20,}|sk-proj-[A-Za-z0-9_-]{20,})')
          .hasMatch(encoded),
      'Secrets must not be saved in Flutter',
    );
    check(
      !life.preferences.keys.any(
        (k) =>
            RegExp(r'api.?key|secret|token', caseSensitive: false).hasMatch(k),
      ),
      'Secrets must remain server-side',
    );
  }
}
