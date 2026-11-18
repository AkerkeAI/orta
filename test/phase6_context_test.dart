import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/models/orta_models.dart';
import 'package:orta/services/agent_context_builder.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/storage_service.dart';

const _life = LifeContext(
  name: 'Context test',
  interfaceLanguage: Language.english,
  goals: [
    GoalContext(
      id: 'goal-1',
      titleKey: 'Finish application',
      areaKey: 'education',
      details: {'next': 'Prepare the application essay'},
    ),
    GoalContext(
      id: 'goal-2',
      titleKey: 'Another goal',
      areaKey: 'personal',
      details: {'private': 'UNSELECTED_GOAL_DETAIL'},
    ),
  ],
  projects: [
    ProjectContext(
      id: 'project-1',
      name: 'Portfolio',
      description: 'A photography portfolio',
      stage: 'First draft',
      needs: 'Choose three examples',
    ),
    ProjectContext(
      id: 'project-2',
      name: 'Another project',
      description: 'UNSELECTED_PROJECT_DESCRIPTION',
      stage: 'UNSELECTED_PROJECT_STAGE',
      needs: 'UNSELECTED_PROJECT_NEEDS',
    ),
  ],
  universityPlans: [
    UniversityPlan(
      id: 'university-1',
      name: 'Example University',
      country: 'Canada',
      program: 'Design',
      category: 'Target',
      notes: 'The essay is still needed',
    ),
    UniversityPlan(
      id: 'university-2',
      name: 'Another University',
      notes: 'UNSELECTED_UNIVERSITY_NOTES',
    ),
  ],
  preferences: {'timezone': 'Asia/Aqtau', 'unrelated': 'UNRELATED_PREFERENCE'},
);

AgentContext _build(LifeData data, {String? type, String? id}) =>
    AgentContextBuilder.build(
      data,
      screen: 'life',
      entityType: type,
      entityId: id,
      now: DateTime.utc(2026, 10, 12, 8),
    );

class _Storage implements LifeDataStorage {
  LifeData value = LifeData(life: _life, onboardingCompleted: true);
  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(value.toJson());
  @override
  Future<void> saveLifeData(LifeData data) async {
    value = LifeData.fromJson(data.toJson());
  }
}

void main() {
  test('selected university retains real details without unrelated notes', () {
    final context = _build(
      LifeData(life: _life),
      type: 'university',
      id: 'university-1',
    );
    final selected = context.visibleData['selectedEntity'] as Map;
    expect(context.currentEntityType, 'university');
    expect(context.currentEntityId, 'university-1');
    expect(selected['id'], 'university-1');
    expect(selected['country'], 'Canada');
    expect(selected['program'], 'Design');
    expect(selected['category'], 'Target');
    expect(selected['notes'], 'The essay is still needed');
    expect(context.visibleData['selectedEntityTitle'], 'Example University');
    final serialized = jsonEncode(context.toJson());
    expect(serialized, isNot(contains('UNSELECTED_UNIVERSITY_NOTES')));
    expect(serialized, isNot(contains('UNRELATED_PREFERENCE')));
    expect(serialized, isNot(contains('UNSELECTED_PROJECT_DESCRIPTION')));
    expect(serialized, isNot(contains('UNSELECTED_GOAL_DETAIL')));
  });

  test('selected project preserves its description, stage and actual need', () {
    final context = _build(
      LifeData(life: _life),
      type: 'project',
      id: 'project-1',
    );
    final selected = context.visibleData['selectedEntity'] as Map;
    expect(selected['description'], 'A photography portfolio');
    expect(selected['stage'], 'First draft');
    expect(selected['needs'], 'Choose three examples');
    expect(context.visibleData['selectedEntityTitle'], 'Portfolio');
    expect(context.relevantLifeContext.projects.first.id, 'project-1');
    expect(context.relevantLifeContext.projects.first.needs, selected['needs']);
    final serialized = jsonEncode(context.toJson());
    expect(serialized, isNot(contains('UNSELECTED_PROJECT_DESCRIPTION')));
    expect(serialized, isNot(contains('UNSELECTED_PROJECT_STAGE')));
    expect(serialized, isNot(contains('UNSELECTED_PROJECT_NEEDS')));
  });

  test(
    'equal IDs in different record types do not expose unrelated details',
    () {
      final data = LifeData(
        life: _life.copyWith(
          goals: [
            const GoalContext(
              id: 'shared-id',
              titleKey: 'A goal',
              areaKey: 'personal',
              details: {'private': 'UNRELATED_COLLIDING_GOAL_DETAIL'},
            ),
          ],
          projects: [
            const ProjectContext(
              id: 'shared-id',
              name: 'Selected project',
              description: 'The selected project details',
            ),
          ],
        ),
      );
      data.validate();
      final context = _build(data, type: 'project', id: 'shared-id');
      expect(context.visibleData['selectedEntityTitle'], 'Selected project');
      final serialized = jsonEncode(context.toJson());
      expect(serialized, contains('The selected project details'));
      expect(serialized, isNot(contains('UNRELATED_COLLIDING_GOAL_DETAIL')));
    },
  );

  test('actual calendar_event UI type retains selected event title and complete saved metadata', () {
    final completed = DateTime.utc(2026, 10, 10, 14);
    final data = LifeData(
      life: _life,
      events: [
        CalendarEvent(
          id: 'selected-event',
          title: 'Completed preparation',
          category: 'Study',
          date: '2026-10-10',
          startTime: '18:00',
          endTime: '19:00',
          timezone: 'Asia/Aqtau',
          latestEnd: '20:00',
          planningDeadline: '2026-10-20',
          completedAt: completed,
          goalId: 'goal-1',
          projectId: 'project-1',
        ),
      ],
    );
    data.validate();
    for (final type in ['calendar_event', 'event']) {
      final context = _build(data, type: type, id: 'selected-event');
      final selected = context.visibleData['selectedEntity'] as Map;
      expect(context.currentEntityType, type);
      expect(context.currentEntityId, 'selected-event');
      expect(
        context.visibleData['selectedEntityTitle'],
        'Completed preparation',
      );
      expect(selected['type'], type);
      expect(selected['id'], 'selected-event');
      expect(selected['timezone'], 'Asia/Aqtau');
      expect(selected['latestEnd'], '20:00');
      expect(selected['planningDeadline'], '2026-10-20');
      expect(selected['completedAt'], completed.toIso8601String());
      expect(selected['goalId'], 'goal-1');
      expect(selected['projectId'], 'project-1');
    }
  });

  test('selected task includes saved priority and effort', () {
    final data = LifeData(
      life: _life,
      tasks: [
        Task(
          id: 'task-1',
          title: 'Draft essay',
          category: 'Study',
          priority: 'high',
          estimatedMinutes: 45,
          goalId: 'goal-1',
          dueDate: '2026-10-20',
        ),
      ],
    );
    final context = _build(data, type: 'task', id: 'task-1');
    final selected = context.visibleData['selectedEntity'] as Map;
    expect(selected['priority'], 'high');
    expect(selected['estimatedMinutes'], 45);
    expect(selected['goalId'], 'goal-1');
    final task = (context.visibleData['tasks'] as List).single as Map;
    expect(task['priority'], 'high');
    expect(task['estimatedMinutes'], 45);
    expect(context.visibleData['selectedEntityTitle'], 'Draft essay');
  });

  test(
    'context is rebuilt from the committed record after a mutation',
    () async {
      final storage = _Storage();
      final repository = await LifeRepository.open(storage);
      addTearDown(repository.dispose);
      final before = _build(repository.data, type: 'project', id: 'project-1');
      await repository.saveProject(
        const ProjectContext(
          id: 'project-1',
          name: 'Revised portfolio',
          description: 'A finished photography collection',
          stage: 'Ready for review',
          needs: 'Ask for feedback',
        ),
        create: false,
      );
      final after = _build(repository.data, type: 'project', id: 'project-1');
      expect(before.visibleData['selectedEntityTitle'], 'Portfolio');
      expect(after.visibleData['selectedEntityTitle'], 'Revised portfolio');
      expect(
        (after.visibleData['selectedEntity'] as Map)['needs'],
        'Ask for feedback',
      );
      expect(
        after.relevantLifeContext.projects.first.stage,
        'Ready for review',
      );
      expect(storage.value.life.projects.first.name, 'Revised portfolio');
    },
  );

  test(
    'earlier memory uses exact bounded user text from only the active chat',
    () {
      final messages = List.generate(
        20,
        (index) => AgentMessage(
          id: 'active-$index',
          createdAt: DateTime.utc(2026, 10, 12, 8, index),
          isUser: index.isEven,
          text: index.isEven
              ? 'User statement $index ${'қ' * 400}'
              : 'ASSISTANT_INVENTION_$index',
        ),
      );
      final data = LifeData(
        life: _life,
        activeConversationId: 'active',
        conversations: [
          ConversationRecord(id: 'active', messages: messages),
          ConversationRecord(
            id: 'other',
            messages: [
              AgentMessage(
                id: 'other-message',
                createdAt: DateTime.utc(2026, 10, 12),
                isUser: true,
                text: 'OTHER_CHAT_PRIVATE_TEXT',
              ),
            ],
          ),
        ],
      );
      final context = _build(data);
      expect(
        context.visibleData['earlierUserStatements'],
        [
          2,
          4,
          6,
        ].map((index) => messages[index].text.substring(0, 240)).toList(),
      );
      final serialized = jsonEncode(context.toJson());
      expect(serialized, isNot(contains('OTHER_CHAT_PRIVATE_TEXT')));
      expect(serialized, isNot(contains('ASSISTANT_INVENTION')));
      expect(
        context.visibleData['memoryNote'],
        contains('Current stored facts and recent messages take precedence'),
      );
      final newChat = _build(
        data.copyWith(
          conversations: [
            ...data.conversations,
            ConversationRecord(id: 'new'),
          ],
          activeConversationId: 'new',
        ),
      );
      expect(newChat.visibleData.containsKey('earlierUserStatements'), isFalse);
    },
  );

  test(
    'large multibyte fields remain bounded and preserve selected context',
    () {
      final large = 'қ' * 10000;
      final data = LifeData(
        life: _life.copyWith(
          name: large,
          goals: List.generate(
            24,
            (index) => GoalContext(
              id: 'large-goal-$index',
              titleKey: large,
              areaKey: 'education',
              details: {'note': large},
            ),
          ),
          projects: List.generate(
            16,
            (index) => ProjectContext(
              id: 'large-project-$index',
              name: large,
              description: large,
              stage: large,
              needs: large,
            ),
          ),
          universityPlans: [
            UniversityPlan(
              id: 'selected-university',
              name: 'Selected university',
              country: large,
              program: large,
              notes: large,
            ),
          ],
          commitments: List.filled(12, large),
        ),
        tasks: List.generate(
          24,
          (index) =>
              Task(id: 'large-task-$index', title: large, category: 'Study'),
        ),
      );
      final context = _build(
        data,
        type: 'university',
        id: 'selected-university',
      );
      expect(
        utf8.encode(jsonEncode(context.toJson())).length,
        lessThanOrEqualTo(18000),
      );
      expect(context.visibleData['contextIsBounded'], isTrue);
      expect(context.visibleData['selectedEntityTitle'], 'Selected university');
      expect(context.visibleData['tasks'], isEmpty);
      expect(context.visibleData.containsKey('planning'), isFalse);
      final selected = context.visibleData['selectedEntity'] as Map;
      expect(selected['id'], 'selected-university');
      expect((selected['country'] as String).length, lessThanOrEqualTo(600));
      if (context.visibleData['contextTruncated'] == true) {
        expect(selected.containsKey('notes'), isFalse);
      } else {
        expect((selected['notes'] as String).length, lessThanOrEqualTo(600));
      }
    },
  );

  test(
    'fallback still enforces the budget for a large saved goal area field',
    () {
      final data = LifeData(
        life: _life.copyWith(
          goals: [
            GoalContext(
              id: 'selected-goal',
              titleKey: 'Current goal',
              areaKey: 'қ' * 10000,
            ),
          ],
        ),
      );
      data.validate();
      final context = _build(data, type: 'goal', id: 'selected-goal');
      expect(
        utf8.encode(jsonEncode(context.toJson())).length,
        lessThanOrEqualTo(18000),
      );
      expect(context.visibleData['selectedEntityTitle'], 'Current goal');
    },
  );
  test('selected project excludes unrelated calendar and exam context', () {
    final data = LifeData(
      life: const LifeContext(
        name: 'QA',
        interfaceLanguage: Language.english,
        projects: [ProjectContext(id: 'p1', name: 'Green Lab')],
        exams: [ExamContext(id: 'e1', name: 'IELTS', date: '2026-11-20')],
      ),
      tasks: [Task(id: 't1', title: 'Essay', category: 'Task', examId: 'e1')],
      events: [
        CalendarEvent(
          id: 'c1',
          title: 'IELTS study',
          date: '2026-10-19',
          startTime: '18:00',
          endTime: '19:00',
          category: 'Study',
          examId: 'e1',
        ),
      ],
    );
    final context = AgentContextBuilder.build(
      data,
      screen: 'life',
      entityType: 'project',
      entityId: 'p1',
      now: DateTime.utc(2026, 10, 12),
    );
    expect(context.visibleData['selectedEntityTitle'], 'Green Lab');
    expect(context.visibleData.containsKey('planning'), isFalse);
    expect(context.visibleData['tasks'], isEmpty);
    expect(context.visibleData['schedule'], isEmpty);
    expect(context.relevantLifeContext.exams, isEmpty);
    final plan = AgentContextBuilder.build(
      data,
      screen: 'plan',
      now: DateTime.utc(2026, 10, 12),
    );
    expect(plan.visibleData.containsKey('planning'), isTrue);
    expect(plan.relevantLifeContext.exams.single.name, 'IELTS');
  });
}
