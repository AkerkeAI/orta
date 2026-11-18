import 'dart:convert';

import 'scheduling_engine.dart';
import '../models/scheduling_preferences.dart';

import '../models/life_context.dart';
import '../models/life_data.dart';

/// Bounded snapshot of stored facts, refreshed from the repository for each send.
class AgentContextBuilder {
  static AgentContext build(
    LifeData data, {
    required String screen,
    String? entityType,
    String? entityId,
    DateTime? now,
  }) {
    final today = SchedulingEngine(data, nowOverride: now).today;
    final projectView = entityType == 'project' && entityId != null;
    final universityView = entityType == 'university' && entityId != null;
    String clip(String value, [int limit = 160]) =>
        value.length <= limit ? value : value.substring(0, limit);
    int selectedFirst(String a, String b) =>
        (a == entityId ? 0 : 1).compareTo(b == entityId ? 0 : 1);
    final orderedGoals = data.life.goals.toList()
      ..sort((a, b) => selectedFirst(a.id, b.id));
    final goals = orderedGoals
        .take(12)
        .map(
          (g) => GoalContext(
            id: g.id,
            titleKey: clip(g.titleKey),
            areaKey: g.areaKey,
            details: Map.fromEntries(
              (entityType == 'goal' && g.id == entityId
                      ? g.details
                      : <String, String>{})
                  .entries
                  .take(4)
                  .map((e) => MapEntry(clip(e.key, 40), clip(e.value))),
            ),
          ),
        )
        .toList();
    final projects = data.life.projects.toList()
      ..sort((a, b) => selectedFirst(a.id, b.id));
    final exams =
        data.life.exams
            .where(
              (e) =>
                  e.id == entityId ||
                  e.date == null ||
                  !isLifeDate(e.date!) ||
                  e.date!.compareTo(today) >= 0,
            )
            .toList()
          ..sort((a, b) {
            final selected = selectedFirst(a.id, b.id);
            return selected != 0
                ? selected
                : (a.date ?? '9999').compareTo(b.date ?? '9999');
          });
    final life = LifeContext(
      name: clip(data.life.name, 80),
      interfaceLanguage: data.life.interfaceLanguage,
      currentLifeAreas: data.life.currentLifeAreas,
      goals: goals,
      projects: projects
          .take(8)
          .map(
            (p) => ProjectContext(
              id: p.id,
              name: clip(p.name),
              description: entityType == 'project' && p.id == entityId
                  ? clip(p.description, 600)
                  : '',
              stage: entityType == 'project' && p.id == entityId
                  ? clip(p.stage)
                  : '',
              needs: entityType == 'project' && p.id == entityId
                  ? clip(p.needs, 400)
                  : '',
            ),
          )
          .toList(),
      exams: (projectView ? <ExamContext>[] : exams)
          .take(12)
          .map(
            (e) => ExamContext(
              id: e.id,
              name: clip(e.name),
              date: e.date,
              importance: e.importance,
              preparationWanted: e.preparationWanted,
            ),
          )
          .toList(),
      languages: data.life.languages
          .take(8)
          .map(
            (language) => LanguageContext(
              languageCode: language.languageCode,
              reason:
                  entityType == 'language' && entityId == language.languageCode
                  ? clip(language.reason)
                  : '',
              level:
                  data.languages[language.languageCode]?.level ??
                  language.level,
            ),
          )
          .toList(),
      commitments: data.life.commitments.take(6).map(clip).toList(),
      preferences: Map.fromEntries(
        data.life.preferences.entries.where(
          (e) => ['timezone', 'wakeUpTime', 'sleepTime'].contains(e.key),
        ),
      ),
    );
    final orderedTasks =
        data.tasks
            .where(
              (t) =>
                  (t.id == entityId || !t.completed) &&
                  (!projectView || t.projectId == entityId) &&
                  !universityView,
            )
            .toList()
          ..sort((a, b) {
            final selected = selectedFirst(a.id, b.id);
            return selected != 0
                ? selected
                : (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
          });
    final tasks = orderedTasks
        .take(12)
        .map(
          (t) => {
            'id': t.id,
            'title': clip(t.title),
            'dueDate': t.dueDate,
            'completed': t.completed,
            'goalId': t.goalId,
            'examId': t.examId,
            'projectId': t.projectId,
            'domain': t.domain?.name,
            'priority': t.priority,
            'estimatedMinutes': t.estimatedMinutes,
          },
        )
        .toList();
    final schedule =
        data.events
            .where(
              (e) =>
                  (e.id == entityId || e.date.compareTo(today) >= 0) &&
                  (!projectView || e.projectId == entityId) &&
                  !universityView,
            )
            .toList()
          ..sort((a, b) {
            final selected = selectedFirst(a.id, b.id);
            return selected != 0
                ? selected
                : '${a.date} ${a.startTime}'.compareTo(
                    '${b.date} ${b.startTime}',
                  );
          });
    Map<String, dynamic>? selected;
    if (entityId != null) {
      final record = switch (entityType) {
        'goal' =>
          data.life.goals.where((e) => e.id == entityId).firstOrNull?.toJson(),
        'project' =>
          data.life.projects
              .where((e) => e.id == entityId)
              .firstOrNull
              ?.toJson(),
        'exam' =>
          data.life.exams.where((e) => e.id == entityId).firstOrNull?.toJson(),
        'university' =>
          data.life.universityPlans
              .where((e) => e.id == entityId)
              .firstOrNull
              ?.toJson(),
        'task' =>
          data.tasks.where((e) => e.id == entityId).firstOrNull?.toJson(),
        'event' || 'calendar_event' =>
          data.events.where((e) => e.id == entityId).firstOrNull?.toJson(),
        _ => null,
      };
      if (record != null) {
        selected = {
          'type': entityType,
          ...record.map(
            (key, value) =>
                MapEntry(key, value is String ? clip(value, 600) : value),
          ),
        };
        if (selected['details'] is Map) {
          selected['details'] = Map.fromEntries(
            (selected['details'] as Map).entries
                .take(8)
                .map(
                  (e) => MapEntry(
                    clip(e.key.toString(), 40),
                    clip(e.value.toString(), 400),
                  ),
                ),
          );
        }
      }
    }
    // Exact user statements, never an invented memory or another chat's history.
    final older = data.conversation.take(
      data.conversation.length > 12 ? data.conversation.length - 12 : 0,
    );
    final earlierStatements = older
        .where((m) => m.isUser)
        .toList()
        .reversed
        .take(3)
        .map((m) => clip(m.text, 240))
        .toList()
        .reversed
        .toList();
    final visible = <String, dynamic>{
      'date': today,
      'selectedEntity': ?selected,
      if (selected != null)
        'selectedEntityTitle':
            selected['name'] ?? selected['title'] ?? selected['titleKey'],
      if (earlierStatements.isNotEmpty)
        'earlierUserStatements': earlierStatements,
      if (earlierStatements.isNotEmpty) 'memoryNote': 'Exact earlier user statements from this chat; requests may have been changed or rejected. Current stored facts and recent messages take precedence.',
      if (!projectView && !universityView)
        'planning': SchedulingEngine(data, nowOverride: now).snapshot(),
      'tasks': tasks,
      'schedule': schedule
          .take(12)
          .expand(
            (event) =>
                SchedulingEngine.dates(
                      SchedulingEngine.shift(event.date, -2),
                      SchedulingEngine.shift(event.date, 2),
                    )
                    .expand(SchedulingEngine(data, nowOverride: now).onDay)
                    .where((o) => o.event.id == event.id),
          )
          .take(12)
          .map(
            (o) => {
              'id': o.event.id,
              'title': clip(o.event.title),
              'date': o.date,
              'startTime': o.event.isAllDay ? null : minuteClock(o.start),
              'endTime': o.event.isAllDay ? null : minuteClock(o.end),
              'isAllDay': o.event.isAllDay,
              'timezone': SchedulingEngine(data).zone,
              'taskId': o.event.taskId,
              'examId': o.event.examId,
              'goalId': o.event.goalId,
              'projectId': o.event.projectId,
              'planningKind': o.event.planningKind,
            },
          )
          .toList(),
      'completedTasks': data.completedTasks
          .where(
            (t) => (!projectView || t.projectId == entityId) && !universityView,
          )
          .toList()
          .reversed
          .take(6)
          .map(
            (t) => {
              'id': t.id,
              'title': clip(t.title),
              'completedAt': t.completedAt?.toIso8601String(),
            },
          )
          .toList(),
      'scheduleCoverage': 'Only saved events are known; empty time is not confirmed availability.',
      'contextIsBounded': true,
    };
    final result = AgentContext(
      currentScreen: screen,
      currentEntityType: entityType,
      currentEntityId: entityId,
      visibleSection: screen == 'home' ? 'What matters now' : screen,
      relevantLifeContext: life,
      visibleData: visible,
    );
    // Avoid an unbounded payload even with unusually large imported fields.
    if (utf8.encode(jsonEncode(result.toJson())).length > 18000) {
      final compactSelected = selected == null
          ? null
          : <String, dynamic>{
              'type': selected['type'],
              for (final key in [
                'id',
                'name',
                'title',
                'titleKey',
                'date',
                'country',
                'program',
              ])
                if (selected[key] is String &&
                    (key != 'id' || (selected[key] as String).length <= 160))
                  key: clip(selected[key] as String, 120),
            };
      return AgentContext(
        currentScreen: clip(screen, 80),
        currentEntityType: entityType == null ? null : clip(entityType, 80),
        currentEntityId: entityId != null && entityId.length <= 160
            ? entityId
            : null,
        relevantLifeContext: LifeContext(
          name: life.name,
          interfaceLanguage: life.interfaceLanguage,
          goals: goals
              .where((g) => g.id.length <= 160)
              .take(3)
              .map(
                (g) => GoalContext(
                  id: g.id,
                  titleKey: clip(g.titleKey, 80),
                  areaKey: clip(g.areaKey, 80),
                ),
              )
              .toList(),
        ),
        visibleData: {
          'contextIsBounded': true,
          'contextTruncated': true,
          'selectedEntity': ?compactSelected,
          if (compactSelected != null)
            'selectedEntityTitle':
                compactSelected['name'] ??
                compactSelected['title'] ??
                compactSelected['titleKey'],
        },
      );
    }
    return result;
  }

  /// Exams are projected into Plan directly; linked preparation events stay distinct.
  static List<PlanRecord> plan(LifeData data) {
    final records = [
      for (final exam in data.life.exams)
        PlanRecord(
          id: exam.id,
          kind: 'exam',
          title: exam.name,
          date: exam.date,
          category: 'Exam',
        ),
      for (final event in data.events)
        PlanRecord(
          id: event.id,
          kind: 'event',
          title: event.title,
          date: event.date,
          startTime: event.startTime,
          endTime: event.endTime,
          category: event.category,
        ),
    ];
    records.sort(
      (a, b) => '${a.date ?? '9999'} ${a.startTime ?? ''}'.compareTo(
        '${b.date ?? '9999'} ${b.startTime ?? ''}',
      ),
    );
    return records;
  }
}

class PlanRecord {
  final String id, kind, title, category;
  final String? date, startTime, endTime;
  const PlanRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    required this.category,
    this.startTime,
    this.endTime,
  });
}
