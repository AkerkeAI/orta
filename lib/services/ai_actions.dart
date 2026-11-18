import 'scheduling_engine.dart';
import 'planning_strings.dart';
import '../models/scheduling_preferences.dart';

import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/life_context.dart';
import '../models/language.dart';
import '../models/life_data.dart';
import '../models/orta_models.dart';

class ToolFailure implements Exception {
  final String code;
  final String detail;
  const ToolFailure(this.code, this.detail);
  @override
  String toString() => '$code: $detail';
}

class ToolProposal {
  final String id, tool, summary, status;
  final String conversationId;
  final Map<String, dynamic> arguments;
  final DateTime createdAt;
  final String? baseRecord;
  final String? baseConstraints;
  final Map<String, dynamic>? result;
  ToolProposal({
    required this.id,
    required this.tool,
    required Map<String, dynamic> arguments,
    required this.summary,
    this.status = 'pending',
    this.conversationId = ConversationRecord.legacyId,
    required this.createdAt,
    this.baseRecord,
    this.baseConstraints,
    this.result,
  }) : arguments = Map.unmodifiable(
         jsonDecode(jsonEncode(arguments)) as Map<String, dynamic>,
       );
  ToolProposal withStatus(String value, {Map<String, dynamic>? result}) =>
      ToolProposal(
        id: id,
        conversationId: conversationId,
        tool: tool,
        arguments: arguments,
        summary: summary,
        status: value,
        createdAt: createdAt,
        baseRecord: baseRecord,
        baseConstraints: baseConstraints,
        result: result,
      );
  Map<String, dynamic> toJson() => {
    'actionId': id,
    'conversationId': conversationId,
    'tool': tool,
    'arguments': arguments,
    'summary': summary,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'baseRecord': baseRecord,
    'baseConstraints': baseConstraints,
    'result': result,
  };
  factory ToolProposal.fromJson(Map<String, dynamic> j) {
    if (![
      'pending',
      'approved',
      'rejected',
      'executed',
      'failed',
    ].contains(j['status'])) {
      throw const FormatException('Invalid action status');
    }
    return ToolProposal(
      id: j['actionId'] as String,
      conversationId:
          j['conversationId'] as String? ?? ConversationRecord.legacyId,
      tool: j['tool'] as String,
      arguments: Map<String, dynamic>.from(j['arguments'] as Map),
      summary: j['summary'] as String,
      status: j['status'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      baseRecord: j['baseRecord'] as String?,
      baseConstraints: j['baseConstraints'] as String?,
      result: j['result'] == null
          ? null
          : Map<String, dynamic>.from(j['result'] as Map),
    );
  }
  bool expired(DateTime now) =>
      now.difference(createdAt) > const Duration(minutes: 15);
}

/// Only narrow, explicit confirmation phrases are eligible for model-selected approval.
/// General intent recognition and tool selection remain Groq's responsibility.
bool explicitDecision(String message, bool approve) {
  final text = message
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.!]+$'), '')
      .trim();
  return (approve
          ? [
              'yes',
              'go ahead',
              'add it',
              'confirm',
              'approve',
              'do it',
              'yes, add it',
              'да',
              'добавь',
              'подтверждаю',
              'иә',
              'қос',
            ]
          : [
              'forget that plan',
              'forget this plan',
              'cancel that plan',
              'забудь этот план',
              'отмени этот план',
              'бұл жоспардан бас тарт',
              'no',
              'cancel',
              'cancel that',
              'actually, cancel that',
              'no, don\'t add it',
              'нет',
              'отмена',
              'не добавляй',
              'жоқ',
              'бас тарту',
            ])
      .contains(text);
}

bool groupDecision(String message, bool approve) {
  final text = message
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.!]+$'), '')
      .trim();
  return (approve
          ? [
              'save this plan',
              'save the plan',
              'yes, save the plan',
              'go ahead with that plan',
              'сохрани этот план',
              'подтверждаю этот план',
              'осы жоспарды сақта',
              'жоспарды сақта',
              'approve all',
              'confirm all',
              'yes, approve all',
              'подтвердить всё',
              'подтвердить все',
              'растау бәрін',
              'барлығын растау',
            ]
          : [
              'forget that plan',
              'forget this plan',
              'cancel that plan',
              'cancel this plan',
              'забудь этот план',
              'отмени этот план',
              'бұл жоспардан бас тарт',
              'осы жоспардан бас тарт',
              'reject all',
              'cancel all',
              'отменить всё',
              'отменить все',
              'барлығынан бас тарту',
            ])
      .contains(text);
}

class ToolRegistry {
  final Map<String, Map<String, dynamic>> definitions;
  ToolRegistry(List<dynamic> rows)
    : definitions = {
        for (final row in rows)
          row['name'] as String: Map<String, dynamic>.from(row as Map),
      };
  static Future<ToolRegistry> load() async => ToolRegistry(
    jsonDecode(await rootBundle.loadString('assets/orta_tools.json')) as List,
  );
  Map<String, dynamic> validate(String tool, Map<String, dynamic> args) {
    final def = definitions[tool];
    if (def == null) {
      throw const ToolFailure('unknown_tool', 'Tool is not registered.');
    }
    void check(dynamic value, Map rule) {
      switch (rule['type']) {
        case 'object':
          if (value is! Map) {
            throw const ToolFailure('invalid_arguments', 'Expected an object.');
          }
          final props = rule['properties'] as Map;
          if (value.keys.any((k) => !props.containsKey(k))) {
            throw const ToolFailure('invalid_arguments', 'Unexpected fields.');
          }
          for (final key in rule['required'] as List? ?? []) {
            if (!value.containsKey(key)) {
              throw ToolFailure('missing_information', 'Please provide $key.');
            }
          }
          for (final key in value.keys) {
            check(value[key], props[key] as Map);
          }
        case 'array':
          if (value is! List ||
              value.length > (rule['maxItems'] as int? ?? 60) ||
              rule['uniqueItems'] == true &&
                  value.map(jsonEncode).toSet().length != value.length) {
            throw const ToolFailure('invalid_arguments', 'Invalid list.');
          }
          for (final item in value) {
            check(item, rule['items'] as Map);
          }
        case 'integer':
          if (value is! int ||
              value < (rule['minimum'] as int? ?? 0) ||
              value > (rule['maximum'] as int? ?? 10080)) {
            throw const ToolFailure('invalid_arguments', 'Invalid number.');
          }
        case 'boolean':
          if (value is! bool) {
            throw const ToolFailure('invalid_arguments', 'Invalid boolean.');
          }
        case 'string':
          if (value is! String || value.trim().isEmpty || value.length > 500) {
            throw const ToolFailure('invalid_arguments', 'Invalid text.');
          }
          if (rule['enum'] != null && !(rule['enum'] as List).contains(value)) {
            throw const ToolFailure('invalid_arguments', 'Invalid value.');
          }
          if (rule['format'] == 'date' && !isLifeDate(value)) {
            throw const ToolFailure(
              'invalid_date',
              'Use an exact valid YYYY-MM-DD date.',
            );
          }
          if (rule['format'] == 'time' && !schedulingTime(value)) {
            throw const ToolFailure('invalid_time', 'Use HH:mm.');
          }
      }
    }

    check(args, def['parameters'] as Map);
    if (tool.startsWith('update_') &&
            tool != 'update_planning_preferences' &&
            args.length < 2 ||
        tool == 'update_planning_preferences' && args.isEmpty) {
      throw const ToolFailure(
        'missing_information',
        'Which fields should change?',
      );
    }
    if (tool == 'create_calendar_event' &&
        args['isAllDay'] != true &&
        (!args.containsKey('startTime') || !args.containsKey('endTime'))) {
      throw const ToolFailure(
        'missing_information',
        'Provide start and end times.',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(args)) as Map);
  }

  String permission(String tool) =>
      definitions[tool]?['permission'] as String? ?? 'unknown';
  String? recordFingerprint(
    LifeData data,
    String tool,
    Map<String, dynamic> a,
  ) {
    if (tool == 'update_planning_preferences') {
      return jsonEncode(data.scheduling.toJson());
    }
    if (!tool.startsWith('update_') && !tool.startsWith('complete_')) {
      return null;
    }
    final kind = tool.startsWith('complete_')
        ? tool.substring(9)
        : tool.substring(7);
    final row = records(
      data,
      kind,
    ).where((r) => r['id'] == a['id']).firstOrNull;
    if (row == null) {
      throw const ToolFailure(
        'missing_record',
        'The selected record no longer exists.',
      );
    }
    return jsonEncode(row);
  }

  List<Map<String, dynamic>> records(LifeData d, String kind) => switch (kind) {
    'goal' => d.life.goals.map((r) => r.toJson()).toList(),
    'exam' => d.life.exams.map((r) => r.toJson()).toList(),
    'project' => d.life.projects.map((r) => r.toJson()).toList(),
    'task' => d.tasks.map((r) => r.toJson()).toList(),
    'calendar_event' => d.events.map((r) => r.toJson()).toList(),
    _ => throw const ToolFailure('unknown_tool', 'Unknown entity.'),
  };

  Map<String, dynamic> read(LifeData d, String tool, Map<String, dynamic> a) {
    validate(tool, a);
    if (permission(tool) != 'read') {
      throw const ToolFailure('permission', 'Read permission required.');
    }
    dynamic value;
    if (tool == 'get_planning_context') {
      value = SchedulingEngine(d).snapshot();
    } else if (tool == 'get_life_context') {
      value = d.life.toJson();
    } else if (tool == 'get_upcoming_deadlines') {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      value =
          [
            ...d.life.exams
                .where((e) => e.date != null && e.date!.compareTo(today) >= 0)
                .map((e) => {'kind': 'exam', ...e.toJson()}),
            ...d.tasks
                .where(
                  (t) =>
                      !t.completed &&
                      t.dueDate != null &&
                      t.dueDate!.compareTo(today) >= 0,
                )
                .map((t) => {'kind': 'task', ...t.toJson()}),
          ]..sort(
            (a, b) => ('${a['date'] ?? a['dueDate']}').compareTo(
              '${b['date'] ?? b['dueDate']}',
            ),
          );
    } else if (tool == 'get_free_time') {
      try {
        value = {
          'date': a['date'],
          'timezone': SchedulingEngine(d).zone,
          'availability': 'confirmed',
          'windows': SchedulingEngine(d)
              .freeWindows(a['date'] as String, a['kind'] as String? ?? 'study')
              .map((s) => s.toJson())
              .toList(),
        };
      } on PlanningError catch (error) {
        throw ToolFailure(
          error.code,
          planningErrorText(d.life.interfaceLanguage, error.code),
        );
      }
    } else {
      final kind = {
        'get_goals': 'goal',
        'get_exams': 'exam',
        'get_projects': 'project',
        'get_tasks': 'task',
        'get_calendar_events': 'calendar_event',
      }[tool]!;
      final all = records(d, kind);
      value = {
        'records': all.take(40).toList(),
        'total': all.length,
        'truncated': all.length > 40,
      };
    }
    final result = {'ok': true, 'tool': tool, 'data': value};
    if (utf8.encode(jsonEncode(result)).length > 18000) {
      throw const ToolFailure(
        'context_limit',
        'Result too large; narrow the request.',
      );
    }
    return result;
  }

  String humanSummary(LifeData data, String tool, Map<String, dynamic> args) {
    final language = data.life.interfaceLanguage;
    if (tool == 'update_planning_preferences') {
      return '${planningText(language, 'preferences')}\n${args.entries.map((e) => '${planningText(language, e.key)}: ${e.value}').join('\n')}';
    }
    final index = language == Language.russian
        ? 1
        : language == Language.kazakh
        ? 2
        : 0;
    const names = {
      'goal': ['goal', 'цель', 'мақсат'],
      'exam': ['exam', 'экзамен', 'емтихан'],
      'project': ['project', 'проект', 'жоба'],
      'task': ['task', 'задачу', 'тапсырма'],
      'calendar_event': ['calendar event', 'событие', 'күнтізбе оқиғасы'],
    };
    final kind = tool.startsWith('complete_')
        ? tool.substring(9)
        : tool.substring(7);
    final verb = tool.startsWith('complete_')
        ? ['Complete', 'Завершить', 'Аяқтау']
        : tool.startsWith('create_')
        ? ['Add', 'Добавить', 'Қосу']
        : ['Update', 'Изменить', 'Өзгерту'];
    const fields = {
      'titleKey': ['Title', 'Название', 'Атауы'],
      'name': ['Name', 'Название', 'Атауы'],
      'title': ['Title', 'Название', 'Атауы'],
      'date': ['Date', 'Дата', 'Күні'],
      'dueDate': ['Due date', 'Срок', 'Мерзімі'],
      'startTime': ['Start', 'Начало', 'Басталуы'],
      'endTime': ['End', 'Конец', 'Аяқталуы'],
      'description': ['Description', 'Описание', 'Сипаттамасы'],
      'stage': ['Stage', 'Этап', 'Кезең'],
      'needs': ['Needs', 'Потребности', 'Қажеттіліктер'],
      'category': ['Category', 'Категория', 'Санат'],
      'areaKey': ['Area', 'Сфера', 'Сала'],
      'importance': ['Priority', 'Приоритет', 'Басымдық'],
      'preparationWanted': ['Preparation', 'Подготовка', 'Дайындық'],
      'planningKind': ['Activity', 'Занятие', 'Сабақ'],
      'timezone': ['Time zone', 'Часовой пояс', 'Уақыт белдеуі'],
      'planningDeadline': ['Deadline', 'Срок', 'Мерзімі'],
      'latestEnd': ['Latest end', 'Позднейшее окончание', 'Ең кеш аяқталуы'],
      'isAllDay': ['All day', 'Весь день', 'Күні бойы'],
      'priority': ['Priority', 'Приоритет', 'Басымдық'],
      'estimatedMinutes': [
        'Effort (minutes)',
        'Время (минуты)',
        'Уақыт (минут)',
      ],
    };
    String recordName(String kind, String id) {
      final row = records(data, kind).where((r) => r['id'] == id).firstOrNull;
      return (row?['name'] ?? row?['title'] ?? row?['titleKey'] ?? id)
          .toString();
    }

    final lines = <String>['${verb[index]} ${names[kind]![index]}'];
    for (final entry in args.entries) {
      if (entry.key == 'id') {
        lines.add(recordName(kind, entry.value as String));
      } else if (entry.key.endsWith('Id')) {
        final linkedKind = entry.key.substring(0, entry.key.length - 2);
        lines.add(
          '${names[linkedKind]![index]}: ${recordName(linkedKind, entry.value as String)}',
        );
      } else {
        final value =
            ['date', 'dueDate', 'planningDeadline'].contains(entry.key)
            ? planningDate(language, entry.value as String)
            : entry.key == 'planningKind'
            ? (entry.value == 'study'
                  ? ['Study', 'Учёба', 'Оқу'][index]
                  : ['Work', 'Работа', 'Жұмыс'][index])
            : entry.value;
        lines.add('${fields[entry.key]![index]}: $value');
      }
    }
    return lines.join('\n');
  }

  ToolProposal propose(
    LifeData data,
    String tool,
    Map<String, dynamic> input,
    String id,
    DateTime now,
  ) {
    final args = validate(tool, input);
    if (permission(tool) != 'approval') {
      throw const ToolFailure('permission', 'This is not a write tool.');
    }
    final base = recordFingerprint(data, tool, args);
    final proposal = ToolProposal(
      id: id,
      conversationId: data.activeConversationId,
      tool: tool,
      arguments: args,
      summary: humanSummary(data, tool, args),
      createdAt: now,
      baseRecord: base,
      baseConstraints:
          args.containsKey('planningKind') ||
              tool == 'update_calendar_event' &&
                  data.events
                          .where((e) => e.id == args['id'])
                          .firstOrNull
                          ?.planningKind
                          .isNotEmpty ==
                      true
          ? jsonEncode(data.scheduling.toJson())
          : null,
    );
    apply(
      data,
      proposal,
      now,
    ); // Validate against current repository without publishing changes.
    return proposal;
  }

  LifeData apply(LifeData data, ToolProposal proposal, DateTime now) {
    final tool = proposal.tool;
    final a = validate(tool, proposal.arguments);
    if (permission(tool) != 'approval') {
      throw const ToolFailure('permission', 'Write permission required.');
    }
    if (proposal.expired(now)) {
      throw const ToolFailure(
        'expired',
        'Proposal expired; ask ORTA for a new one.',
      );
    }
    if (recordFingerprint(data, tool, a) != proposal.baseRecord) {
      throw const ToolFailure(
        'conflict',
        'Record changed since this proposal. Request a fresh proposal.',
      );
    }
    if (proposal.baseConstraints != null &&
        proposal.baseConstraints != jsonEncode(data.scheduling.toJson())) {
      throw ToolFailure(
        'stale',
        planningText(data.life.interfaceLanguage, 'stale'),
      );
    }
    if (tool == 'update_planning_preferences') {
      final pref = SchedulingPreferences.fromJson({
        ...data.scheduling.toJson(),
        ...a,
      });
      pref.validate();
      return data.copyWith(scheduling: pref);
    }
    if (tool == 'complete_calendar_event') {
      final event = data.events.firstWhere((e) => e.id == a['id']);
      if (event.completedAt != null) {
        throw const ToolFailure('duplicate', 'Session is already completed.');
      }
      return data.copyWith(
        events: data.events
            .map(
              (e) => e.id == event.id
                  ? CalendarEvent.fromJson({
                      ...e.toJson(),
                      'completedAt': now.toUtc().toIso8601String(),
                    })
                  : e,
            )
            .toList(),
      );
    }
    if (tool == 'complete_task') {
      final task = data.tasks.firstWhere((t) => t.id == a['id']);
      if (task.completed) {
        throw const ToolFailure('duplicate', 'Task is already completed.');
      }
      return data.copyWith(
        tasks: data.tasks
            .map(
              (t) => t.id == task.id ? t.withCompletion(true, now.toUtc()) : t,
            )
            .toList(),
      );
    }
    final create = tool.startsWith('create_');
    final kind = tool.substring(7);
    final all = records(data, kind);
    final id = create ? 'ai_${proposal.id}' : a['id'] as String;
    final previous = create
        ? <String, dynamic>{}
        : all.firstWhere((r) => r['id'] == id);
    final defaults = switch (kind) {
      'goal' => {'areaKey': 'personal', 'details': <String, String>{}},
      'exam' => {'importance': 'normal', 'preparationWanted': false},
      'project' => {'description': '', 'stage': '', 'needs': ''},
      'task' => {
        'category': 'Task',
        'time': '',
        'completed': false,
        'completedAt': null,
      },
      'calendar_event' => {
        'category': 'Event',
        'isFixed': false,
        'isLanguageSession': false,
        'isAllDay': false,
        'timezone': data.scheduling.timezone,
      },
      _ => throw const ToolFailure('unknown_tool', 'Unknown write tool.'),
    };
    final row = <String, dynamic>{...defaults, ...previous, ...a, 'id': id};
    if (kind == 'calendar_event' && row['isAllDay'] == true) {
      row['startTime'] = '';
      row['endTime'] = '';
    }
    final titleField = kind == 'goal'
        ? 'titleKey'
        : (kind == 'exam' || kind == 'project')
        ? 'name'
        : 'title';
    if (create &&
        all.any(
          (r) =>
              r[titleField].toString().toLowerCase().trim() ==
                  row[titleField].toString().toLowerCase().trim() &&
              (kind != 'exam' || r['date'] == row['date']) &&
              (kind != 'calendar_event' ||
                  r['date'] == row['date'] &&
                      r['startTime'] == row['startTime'] &&
                      r['endTime'] == row['endTime']),
        )) {
      throw const ToolFailure('duplicate', 'A matching record already exists.');
    }
    List<T> put<T>(List<T> rows, T value, String Function(T) key) => create
        ? [...rows, value]
        : rows.map((r) => key(r) == id ? value : r).toList();
    final next = switch (kind) {
      'goal' => data.copyWith(
        life: data.life.copyWith(
          goals: put(data.life.goals, GoalContext.fromJson(row), (r) => r.id),
        ),
      ),
      'exam' => data.copyWith(
        life: data.life.copyWith(
          exams: put(data.life.exams, ExamContext.fromJson(row), (r) => r.id),
        ),
      ),
      'project' => data.copyWith(
        life: data.life.copyWith(
          projects: put(
            data.life.projects,
            ProjectContext.fromJson(row),
            (r) => r.id,
          ),
        ),
      ),
      'task' => data.copyWith(
        tasks: put(data.tasks, Task.fromJson(row), (r) => r.id),
      ),
      'calendar_event' => data.copyWith(
        events: put(data.events, CalendarEvent.fromJson(row), (r) => r.id),
      ),
      _ => throw const ToolFailure('unknown_tool', 'Unknown entity.'),
    };
    next.validate();
    if (kind == 'calendar_event') {
      final event = next.events.firstWhere((e) => e.id == id);
      final engine = SchedulingEngine(next, nowOverride: now);
      for (final day in SchedulingEngine.dates(
        SchedulingEngine.shift(event.date, -2),
        SchedulingEngine.shift(event.date, 2),
      )) {
        if (engine
            .conflicts(day)
            .any((pair) => pair.any((o) => o.event.id == id))) {
          throw ToolFailure(
            'conflict',
            planningText(data.life.interfaceLanguage, 'conflictError'),
          );
        }
      }
      try {
        if (!event.isAllDay &&
            !engine.stableClock(
              event.date,
              clockMinutes(event.startTime),
              clockMinutes(event.endTime),
              timezone: event.timezone.isEmpty ? engine.zone : event.timezone,
            )) {
          throw const PlanningError('timezone');
        }
        engine.checkPlanned(event);
      } on PlanningError catch (error) {
        throw ToolFailure(
          error.code,
          planningErrorText(data.life.interfaceLanguage, error.code),
        );
      }
    }
    return next;
  }
}
