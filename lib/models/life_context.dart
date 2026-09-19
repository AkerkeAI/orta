import 'language.dart';
import 'language_definition.dart';

/// The life areas ORTA may know about. Users can add or remove them later.
enum LifeArea { school, university, work, freelance, project, gapYear, other }

enum CurrentLifeStatus {
  schoolStudent,
  universityStudent,
  working,
  freelancer,
  buildingProject,
  gapYear,
  other,
}

enum LifeDomain {
  education,
  university,
  career,
  work,
  projects,
  business,
  languages,
  exams,
  personalGoals,
}

extension LifeAreaExtension on LifeArea {
  String get key => name;
  String get label => name;

  static LifeArea fromKey(String value) {
    return LifeArea.values.firstWhere(
      (area) => area.name == value,
      orElse: () => LifeArea.other,
    );
  }
}

class GoalContext {
  final String id;
  final String titleKey;
  final String areaKey;
  final Map<String, String> details;

  const GoalContext({
    required this.id,
    required this.titleKey,
    required this.areaKey,
    this.details = const {},
  });

  String get title => titleKey;
  String get area => areaKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleKey': titleKey,
    'areaKey': areaKey,
    'details': details,
  };

  factory GoalContext.fromJson(Map<String, dynamic> json) => GoalContext(
    id: json['id'] as String? ?? 'goal',
    titleKey: json['titleKey'] as String? ?? json['title'] as String? ?? '',
    areaKey:
        json['areaKey'] as String? ?? json['area'] as String? ?? 'personal',
    details: Map<String, String>.from(json['details'] as Map? ?? {}),
  );
}

class EducationContext {
  final String? institution;
  final String? major;
  final String? year;
  final String? graduationYear;

  const EducationContext({
    this.institution,
    this.major,
    this.year,
    this.graduationYear,
  });

  Map<String, dynamic> toJson() => {
    'institution': institution,
    'major': major,
    'year': year,
    'graduationYear': graduationYear,
  };

  factory EducationContext.fromJson(Map<String, dynamic> json) =>
      EducationContext(
        institution: json['institution'] as String?,
        major: json['major'] as String?,
        year: json['year'] as String?,
        graduationYear: json['graduationYear'] as String?,
      );
}

class UniversityPlan {
  final String id;
  final String name;
  final String country;
  final String program;
  final String category;
  final String notes;

  const UniversityPlan({
    required this.id,
    required this.name,
    this.country = '',
    this.program = '',
    this.category = 'Possible',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'program': program,
    'category': category,
    'notes': notes,
  };

  factory UniversityPlan.fromJson(Map<String, dynamic> json) => UniversityPlan(
    id:
        json['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    name: json['name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    program: json['program'] as String? ?? '',
    category: json['category'] as String? ?? 'Possible',
    notes: json['notes'] as String? ?? '',
  );
}

class CareerContext {
  final String? role;
  final String? industry;
  final String? desiredDirection;
  final String? currentGoal;

  const CareerContext({
    this.role,
    this.industry,
    this.desiredDirection,
    this.currentGoal,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'industry': industry,
    'desiredDirection': desiredDirection,
    'currentGoal': currentGoal,
  };

  factory CareerContext.fromJson(Map<String, dynamic> json) => CareerContext(
    role: json['role'] as String?,
    industry: json['industry'] as String?,
    desiredDirection: json['desiredDirection'] as String?,
    currentGoal: json['currentGoal'] as String?,
  );
}

class ProjectContext {
  final String id;
  final String name;
  final String description;
  final String stage;
  final String needs;

  const ProjectContext({
    required this.id,
    required this.name,
    this.description = '',
    this.stage = '',
    this.needs = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'stage': stage,
    'needs': needs,
  };

  factory ProjectContext.fromJson(Map<String, dynamic> json) => ProjectContext(
    id:
        json['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    stage: json['stage'] as String? ?? '',
    needs: json['needs'] as String? ?? '',
  );
}

class LanguageContext {
  final String languageCode;
  final String level;
  final String reason;

  const LanguageContext({
    required this.languageCode,
    this.level = '',
    this.reason = '',
  });

  LanguageDefinition get definition => LanguageDefinition.byCode(languageCode);

  Map<String, dynamic> toJson() => {
    'language': languageCode,
    'level': level,
    'reason': reason,
  };

  factory LanguageContext.fromJson(Map<String, dynamic> json) =>
      LanguageContext(
        languageCode: json['language'] as String? ?? 'en',
        level: json['level'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
      );
}

class ExamContext {
  final String id;
  final String name;
  final String? date;
  final String importance;
  final bool preparationWanted;

  const ExamContext({
    required this.id,
    required this.name,
    this.date,
    this.importance = 'normal',
    this.preparationWanted = false,
  });

  ExamContext copyWith({String? date, bool? preparationWanted}) => ExamContext(
    id: id,
    name: name,
    date: date ?? this.date,
    importance: importance,
    preparationWanted: preparationWanted ?? this.preparationWanted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date,
    'importance': importance,
    'preparationWanted': preparationWanted,
  };

  factory ExamContext.fromJson(Map<String, dynamic> json) => ExamContext(
    id:
        json['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    name: json['name'] as String? ?? '',
    date: json['date'] as String?,
    importance: json['importance'] as String? ?? 'normal',
    preparationWanted: json['preparationWanted'] as bool? ?? false,
  );
}

class LifeContext {
  final String name;
  final Language interfaceLanguage;
  final Set<LifeArea> currentLifeAreas;
  final String otherDescription;
  final List<String> interpretedSuggestions;
  final List<GoalContext> goals;
  final EducationContext? education;
  final List<UniversityPlan> universityPlans;
  final CareerContext? career;
  final List<ProjectContext> projects;
  final List<LanguageContext> languages;
  final List<ExamContext> exams;
  final List<String> commitments;
  final Map<String, String> preferences;

  const LifeContext({
    required this.name,
    required this.interfaceLanguage,
    this.currentLifeAreas = const {},
    this.otherDescription = '',
    this.interpretedSuggestions = const [],
    this.goals = const [],
    this.education,
    this.universityPlans = const [],
    this.career,
    this.projects = const [],
    this.languages = const [],
    this.exams = const [],
    this.commitments = const [],
    this.preferences = const {},
  });

  LifeContext copyWith({
    String? name,
    Language? interfaceLanguage,
    Set<LifeArea>? currentLifeAreas,
    String? otherDescription,
    List<String>? interpretedSuggestions,
    List<GoalContext>? goals,
    EducationContext? education,
    List<UniversityPlan>? universityPlans,
    CareerContext? career,
    List<ProjectContext>? projects,
    List<LanguageContext>? languages,
    List<ExamContext>? exams,
    List<String>? commitments,
    Map<String, String>? preferences,
  }) => LifeContext(
    name: name ?? this.name,
    interfaceLanguage: interfaceLanguage ?? this.interfaceLanguage,
    currentLifeAreas: currentLifeAreas ?? this.currentLifeAreas,
    otherDescription: otherDescription ?? this.otherDescription,
    interpretedSuggestions:
        interpretedSuggestions ?? this.interpretedSuggestions,
    goals: goals ?? this.goals,
    education: education ?? this.education,
    universityPlans: universityPlans ?? this.universityPlans,
    career: career ?? this.career,
    projects: projects ?? this.projects,
    languages: languages ?? this.languages,
    exams: exams ?? this.exams,
    commitments: commitments ?? this.commitments,
    preferences: preferences ?? this.preferences,
  );

  bool hasArea(LifeArea area) => currentLifeAreas.contains(area);
  bool hasGoal(String id) => goals.any((goal) => goal.id == id);

  Map<String, dynamic> toJson() => {
    'name': name,
    'interfaceLanguage': interfaceLanguage.code,
    'currentLifeAreas': currentLifeAreas.map((area) => area.key).toList(),
    'otherDescription': otherDescription,
    'interpretedSuggestions': interpretedSuggestions,
    'goals': goals.map((goal) => goal.toJson()).toList(),
    'education': education?.toJson(),
    'universityPlans': universityPlans.map((item) => item.toJson()).toList(),
    'career': career?.toJson(),
    'projects': projects.map((item) => item.toJson()).toList(),
    'languages': languages.map((item) => item.toJson()).toList(),
    'exams': exams.map((item) => item.toJson()).toList(),
    'commitments': commitments,
    'preferences': preferences,
  };

  factory LifeContext.fromJson(Map<String, dynamic> json) => LifeContext(
    name: json['name'] as String? ?? '',
    interfaceLanguage: LanguageExtension.fromCode(
      json['interfaceLanguage'] as String? ?? 'en',
    ),
    currentLifeAreas: ((json['currentLifeAreas'] as List?) ?? [])
        .map((value) => LifeAreaExtension.fromKey(value as String))
        .toSet(),
    otherDescription: json['otherDescription'] as String? ?? '',
    interpretedSuggestions: List<String>.from(
      json['interpretedSuggestions'] as List? ?? const [],
    ),
    goals: ((json['goals'] as List?) ?? [])
        .map(
          (item) =>
              GoalContext.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    education: json['education'] == null
        ? null
        : EducationContext.fromJson(
            Map<String, dynamic>.from(json['education'] as Map),
          ),
    universityPlans: ((json['universityPlans'] as List?) ?? [])
        .map(
          (item) =>
              UniversityPlan.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    career: json['career'] == null
        ? null
        : CareerContext.fromJson(
            Map<String, dynamic>.from(json['career'] as Map),
          ),
    projects: ((json['projects'] as List?) ?? [])
        .map(
          (item) =>
              ProjectContext.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    languages: ((json['languages'] as List?) ?? [])
        .map(
          (item) =>
              LanguageContext.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    exams: ((json['exams'] as List?) ?? [])
        .map(
          (item) =>
              ExamContext.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    commitments: List<String>.from(json['commitments'] as List? ?? const []),
    preferences: Map<String, String>.from(json['preferences'] as Map? ?? {}),
  );
}

class AgentContext {
  final String currentScreen;
  final String? currentEntityType;
  final String? currentEntityId;
  final String? visibleSection;
  final String mode;
  final LifeContext relevantLifeContext;

  const AgentContext({
    required this.currentScreen,
    this.currentEntityType,
    this.currentEntityId,
    this.visibleSection,
    this.mode = 'core',
    required this.relevantLifeContext,
  });

  Map<String, dynamic> toJson() => {
    'currentScreen': currentScreen,
    'currentEntityType': currentEntityType,
    'currentEntityId': currentEntityId,
    'visibleSection': visibleSection,
    'mode': mode,
    'relevantLifeContext': relevantLifeContext.toJson(),
  };
}

enum ActionStatus {
  draft,
  needsInformation,
  awaitingApproval,
  approved,
  completed,
  cancelled,
}

class AgentAction {
  final String type;
  final Map<String, dynamic> arguments;
  final ActionStatus status;

  const AgentAction({
    required this.type,
    required this.arguments,
    this.status = ActionStatus.draft,
  });

  AgentAction withStatus(ActionStatus next) =>
      AgentAction(type: type, arguments: arguments, status: next);
}

class ActionProposal {
  final String title;
  final String description;
  final AgentAction action;

  const ActionProposal({
    required this.title,
    required this.description,
    required this.action,
  });
}

class AgentMessage {
  final String text;
  final bool isUser;
  final ActionProposal? proposal;

  const AgentMessage({required this.text, required this.isUser, this.proposal});
}
