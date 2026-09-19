import 'language.dart';

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

  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.time,
    this.completed = false,
    this.description,
  });
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

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.category,
    this.isFixed = false,
    this.isLanguageSession = false,
  });
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

  LanguageMemory({
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
