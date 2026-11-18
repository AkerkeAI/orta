import 'language.dart';
import 'life_context.dart';

class Goal {
  final String id;
  final String title;
  final String category;
  final bool selected;
  final Map<String, dynamic> details;

  Goal({
    required this.id,
    required this.title,
    required this.category,
    this.selected = false,
    this.details = const {},
  });
}

class Task {
  final String id;
  final String title;
  final String category;
  final String time;
  final bool completed;
  final String? description;
  final String? goalId;
  final String? projectId;
  final String? examId;
  final String? dueDate;
  final DateTime? completedAt;
  final String priority;
  final int? estimatedMinutes;
  final LifeDomain? domain;

  Task({
    required this.id,
    required this.title,
    required this.category,
    this.time = '',
    this.completed = false,
    this.description,
    this.goalId,
    this.projectId,
    this.examId,
    this.dueDate,
    this.completedAt,
    this.priority = '',
    this.estimatedMinutes,
    this.domain,
  });
  Task withCompletion(bool value, DateTime now) => Task(
    id: id,
    title: title,
    category: category,
    time: time,
    description: description,
    goalId: goalId,
    projectId: projectId,
    examId: examId,
    dueDate: dueDate,
    domain: domain,
    completed: value,
    completedAt: value ? now : null,
    priority: priority,
    estimatedMinutes: estimatedMinutes,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'time': time,
    'completed': completed,
    'description': description,
    'goalId': goalId,
    'projectId': projectId,
    'examId': examId,
    'dueDate': dueDate,
    'completedAt': completedAt?.toIso8601String(),
    'priority': priority,
    'estimatedMinutes': estimatedMinutes,
    'domain': domain?.name,
  };
  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    time: json['time'] as String,
    completed: json['completed'] as bool,
    description: json['description'] as String?,
    priority: json['priority'] as String? ?? '',
    estimatedMinutes: json['estimatedMinutes'] as int?,
    goalId: json['goalId'] as String?,
    projectId: json['projectId'] as String?,
    examId: json['examId'] as String?,
    dueDate: json['dueDate'] as String?,
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    domain: json['domain'] == null
        ? null
        : LifeDomain.values.byName(json['domain'] as String),
  );
}

class CalendarEvent {
  final String id;
  final String title;
  final String date;
  final String startTime;
  final String endTime;
  final String category;
  final bool isFixed;
  final bool isLanguageSession;
  final bool isAllDay;
  final String timezone, planningKind;
  final String? latestEnd, planningDeadline;
  final DateTime? completedAt;
  final String? goalId;
  final String? projectId;
  final String? examId;
  final String? taskId;
  final String? languageCode;
  final LifeDomain? domain;
  // Local wall-clock time. User timezone is retained in LifeContext.preferences.
  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.category,
    this.isAllDay = false,
    this.timezone = '',
    this.planningKind = '',
    this.latestEnd,
    this.planningDeadline,
    this.completedAt,
    this.isFixed = false,
    this.isLanguageSession = false,
    this.goalId,
    this.projectId,
    this.examId,
    this.taskId,
    this.languageCode,
    this.domain,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'category': category,
    'isAllDay': isAllDay,
    'timezone': timezone,
    'planningKind': planningKind,
    'latestEnd': latestEnd,
    'planningDeadline': planningDeadline,
    'completedAt': completedAt?.toIso8601String(),
    'isFixed': isFixed,
    'isLanguageSession': isLanguageSession,
    'goalId': goalId,
    'projectId': projectId,
    'examId': examId,
    'taskId': taskId,
    'languageCode': languageCode,
    'domain': domain?.name,
  };
  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    date: json['date'] as String,
    startTime: json['startTime'] as String,
    endTime: json['endTime'] as String,
    category: json['category'] as String,
    isAllDay: json['isAllDay'] as bool? ?? false,
    timezone: json['timezone'] as String? ?? '',
    planningKind: json['planningKind'] as String? ?? '',
    latestEnd: json['latestEnd'] as String?,
    planningDeadline: json['planningDeadline'] as String?,
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    isFixed: json['isFixed'] as bool,
    isLanguageSession: json['isLanguageSession'] as bool,
    goalId: json['goalId'] as String?,
    projectId: json['projectId'] as String?,
    examId: json['examId'] as String?,
    taskId: json['taskId'] as String?,
    languageCode: json['languageCode'] as String?,
    domain: json['domain'] == null
        ? null
        : LifeDomain.values.byName(json['domain'] as String),
  );
}

class Opportunity {
  final String id;
  final String title;
  final String category;
  final String deadline;
  final String whyItMatches;
  final String relevantGoal;
  final String status;
  final String realLanguage;

  Opportunity({
    required this.id,
    required this.title,
    required this.category,
    required this.deadline,
    required this.whyItMatches,
    required this.relevantGoal,
    required this.status,
    this.realLanguage = 'Russian',
  });
}

class ApplicationDraft {
  final String title;
  final String projectName;
  final String problem;
  final String solution;
  final String impact;
  final String team;
  final String realSubmissionLanguage;
  final bool draftPrepared;

  ApplicationDraft({
    required this.title,
    required this.projectName,
    required this.problem,
    required this.solution,
    required this.impact,
    required this.team,
    this.realSubmissionLanguage = 'Russian',
    this.draftPrepared = false,
  });
}

class University {
  final String id;
  final String name;
  final String country;
  final String program;
  final String deadline;
  final String requirementsStatus;
  final String requiredLanguage;
  final List<String> requirements;
  final String insight;

  University({
    required this.id,
    required this.name,
    required this.country,
    required this.program,
    required this.deadline,
    required this.requirementsStatus,
    required this.requiredLanguage,
    required this.requirements,
    required this.insight,
  });
}

class Project {
  final String id;
  final String name;
  final String description;
  final String stage;
  final List<String> goals;
  final List<String> upcomingDeadlines;
  final int opportunitiesCount;
  final String nextAction;
  final List<String> progress;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.stage,
    required this.goals,
    required this.upcomingDeadlines,
    required this.opportunitiesCount,
    required this.nextAction,
    required this.progress,
  });
}

class LanguageProfile {
  final Language learningLanguage;
  final String levelLabel;
  final double languageIndependence;
  final List<LifeMapCategory> lifeMap;

  LanguageProfile({
    required this.learningLanguage,
    required this.levelLabel,
    required this.languageIndependence,
    required this.lifeMap,
  });
}

class LifeMapCategory {
  final String name;
  final int value;
  final String description;

  LifeMapCategory({
    required this.name,
    required this.value,
    required this.description,
  });
}

class LanguageMemory {
  final String title;
  final String context;
  final String phrase;
  final String meaning;
  final String language;
  final String? id;

  LanguageMemory({
    this.id,
    required this.title,
    required this.context,
    required this.phrase,
    required this.meaning,
    required this.language,
  });
}

class DailyBrief {
  final String title;
  final List<String> completed;
  final List<String> findings;
  final List<String> tomorrow;
  final String suggestedFocus;

  DailyBrief({
    required this.title,
    required this.completed,
    required this.findings,
    required this.tomorrow,
    required this.suggestedFocus,
  });
}
