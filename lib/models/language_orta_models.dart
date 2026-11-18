import 'language_definition.dart';

const languageOrtaLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

enum PracticeSkill {
  speaking,
  writing,
  listening,
  reading,
  vocabulary,
  scenario,
  conversation,
}

enum PracticeScenario {
  everyday,
  universityInterview,
  intendedMajor,
  scholarshipInterview,
  personalProject,
  professionalIntro,
}

class ApprovedLanguageContext {
  final String? intendedMajor;
  final bool preparingUniversity;
  final bool hasProject;
  const ApprovedLanguageContext({
    this.intendedMajor,
    this.preparingUniversity = false,
    this.hasProject = false,
  });

  Map<String, dynamic> toSafeJson() => {
    if (intendedMajor != null && intendedMajor!.trim().isNotEmpty)
      'intendedMajor': intendedMajor!.trim(),
    'preparingUniversity': preparingUniversity,
    'hasProject': hasProject,
  };
}

class LanguageProfile {
  final String id;
  final String studentId;
  final String languageCode;
  final String languageName;
  final String currentLevel;
  final String targetLevel;
  final String goals;
  final List<String> preferredAreas;
  final Map<String, int> skillProgress;
  final DateTime updatedAt;

  const LanguageProfile({
    required this.id,
    required this.studentId,
    required this.languageCode,
    required this.languageName,
    this.currentLevel = 'A1',
    this.targetLevel = 'B2',
    this.goals = '',
    this.preferredAreas = const [],
    this.skillProgress = const {},
    required this.updatedAt,
  });

  String get displayName {
    final definition = LanguageDefinition.byCode(languageCode);
    return definition.code == languageCode
        ? definition.englishName
        : languageName;
  }

  int get completedCount =>
      skillProgress.values.fold<int>(0, (sum, value) => sum + value);

  LanguageProfile copyWith({
    String? currentLevel,
    String? targetLevel,
    String? goals,
    List<String>? preferredAreas,
    Map<String, int>? skillProgress,
    DateTime? updatedAt,
  }) => LanguageProfile(
    id: id,
    studentId: studentId,
    languageCode: languageCode,
    languageName: languageName,
    currentLevel: currentLevel ?? this.currentLevel,
    targetLevel: targetLevel ?? this.targetLevel,
    goals: goals ?? this.goals,
    preferredAreas: preferredAreas ?? this.preferredAreas,
    skillProgress: skillProgress ?? this.skillProgress,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'languageCode': languageCode,
    'languageName': languageName,
    'currentLevel': currentLevel,
    'targetLevel': targetLevel,
    'goals': goals,
    'preferredAreas': preferredAreas,
    'skillProgress': skillProgress,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory LanguageProfile.fromJson(Map<String, dynamic> json) =>
      LanguageProfile(
        id: json['id'] as String,
        studentId: json['studentId'] as String? ?? json['student_id'] as String,
        languageCode:
            json['languageCode'] as String? ?? json['language_code'] as String,
        languageName:
            json['languageName'] as String? ?? json['language_name'] as String,
        currentLevel:
            json['currentLevel'] as String? ??
            json['current_level'] as String? ??
            'A1',
        targetLevel:
            json['targetLevel'] as String? ??
            json['target_level'] as String? ??
            'B2',
        goals: json['goals'] as String? ?? '',
        preferredAreas: [
          for (final item in json['preferredAreas'] as List? ??
              json['preferred_areas'] as List? ??
              const [])
            item.toString(),
        ],
        skillProgress: {
          for (final entry
              in ((json['skillProgress'] ?? json['skill_progress'] ?? const {})
                      as Map)
                  .entries)
            entry.key.toString(): (entry.value as num).toInt(),
        },
        updatedAt: DateTime.parse(
          (json['updatedAt'] ?? json['updated_at']).toString(),
        ),
      );

  Map<String, dynamic> toSupabaseRow() => {
    'id': id,
    'student_id': studentId,
    'language_code': languageCode,
    'language_name': languageName,
    'current_level': currentLevel,
    'target_level': targetLevel,
    'goals': goals,
    'preferred_areas': preferredAreas,
    'skill_progress': skillProgress,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class LanguagePracticeSession {
  final String id;
  final String studentId;
  final String profileId;
  final PracticeSkill skill;
  final PracticeScenario scenario;
  final String prompt;
  final String stimulus;
  final String studentResponse;
  final String transcript;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;

  const LanguagePracticeSession({
    required this.id,
    required this.studentId,
    required this.profileId,
    required this.skill,
    required this.scenario,
    required this.prompt,
    this.stimulus = '',
    this.studentResponse = '',
    this.transcript = '',
    this.status = 'in_progress',
    required this.createdAt,
    this.completedAt,
  });

  bool get completed => status == 'completed';

  LanguagePracticeSession copyWith({
    String? prompt,
    String? stimulus,
    String? studentResponse,
    String? transcript,
    String? status,
    DateTime? completedAt,
  }) => LanguagePracticeSession(
    id: id,
    studentId: studentId,
    profileId: profileId,
    skill: skill,
    scenario: scenario,
    prompt: prompt ?? this.prompt,
    stimulus: stimulus ?? this.stimulus,
    studentResponse: studentResponse ?? this.studentResponse,
    transcript: transcript ?? this.transcript,
    status: status ?? this.status,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'profileId': profileId,
    'skill': skill.name,
    'scenario': scenario.name,
    'prompt': prompt,
    'stimulus': stimulus,
    'studentResponse': studentResponse,
    'transcript': transcript,
    'status': status,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };

  factory LanguagePracticeSession.fromJson(Map<String, dynamic> json) =>
      LanguagePracticeSession(
        id: json['id'] as String,
        studentId: json['studentId'] as String? ?? json['student_id'] as String,
        profileId: json['profileId'] as String? ?? json['profile_id'] as String,
        skill: PracticeSkill.values.byName(
          json['skill'] as String? ?? 'writing',
        ),
        scenario: PracticeScenario.values.firstWhere(
          (item) =>
              item.name ==
              (json['scenario'] as String? ?? json['scenario_key'] as String?),
          orElse: () => PracticeScenario.everyday,
        ),
        prompt: json['prompt'] as String? ?? '',
        stimulus: json['stimulus'] as String? ?? '',
        studentResponse:
            json['studentResponse'] as String? ??
            json['student_response'] as String? ??
            '',
        transcript: json['transcript'] as String? ?? '',
        status: json['status'] as String? ?? 'in_progress',
        createdAt: DateTime.parse(
          (json['createdAt'] ?? json['created_at']).toString(),
        ),
        completedAt: json['completedAt'] == null && json['completed_at'] == null
            ? null
            : DateTime.parse(
                (json['completedAt'] ?? json['completed_at']).toString(),
              ),
      );

  Map<String, dynamic> toSupabaseRow() => {
    'id': id,
    'student_id': studentId,
    'profile_id': profileId,
    'skill': skill.name,
    'scenario_key': scenario.name,
    'prompt': prompt,
    'stimulus': stimulus,
    'student_response': studentResponse,
    'transcript': transcript,
    'status': status,
    'created_at': createdAt.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
  };
}

class VocabularyItem {
  final String term;
  final String meaning;
  const VocabularyItem({required this.term, required this.meaning});
  Map<String, dynamic> toJson() => {'term': term, 'meaning': meaning};
  factory VocabularyItem.fromJson(Map<String, dynamic> json) => VocabularyItem(
    term: json['term'] as String? ?? '',
    meaning: json['meaning'] as String? ?? '',
  );
}

class LanguageSessionResult {
  final String id;
  final String sessionId;
  final String studentId;
  final String originalResponse;
  final String corrections;
  final String explanation;
  final String alternativePhrasing;
  final List<VocabularyItem> vocabulary;
  final String feedback;
  final bool aiAvailable;
  final DateTime createdAt;

  const LanguageSessionResult({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.originalResponse,
    this.corrections = '',
    this.explanation = '',
    this.alternativePhrasing = '',
    this.vocabulary = const [],
    this.feedback = '',
    this.aiAvailable = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'studentId': studentId,
    'originalResponse': originalResponse,
    'corrections': corrections,
    'explanation': explanation,
    'alternativePhrasing': alternativePhrasing,
    'vocabulary': vocabulary.map((item) => item.toJson()).toList(),
    'feedback': feedback,
    'aiAvailable': aiAvailable,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory LanguageSessionResult.fromJson(Map<String, dynamic> json) =>
      LanguageSessionResult(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String? ?? json['session_id'] as String,
        studentId: json['studentId'] as String? ?? json['student_id'] as String,
        originalResponse:
            json['originalResponse'] as String? ??
            json['original_response'] as String? ??
            '',
        corrections: json['corrections'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        alternativePhrasing:
            json['alternativePhrasing'] as String? ??
            json['alternative_phrasing'] as String? ??
            '',
        vocabulary: [
          for (final item in json['vocabulary'] as List? ?? const [])
            VocabularyItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        feedback: json['feedback'] as String? ?? '',
        aiAvailable:
            json['aiAvailable'] as bool? ?? json['ai_available'] as bool? ?? false,
        createdAt: DateTime.parse(
          (json['createdAt'] ?? json['created_at']).toString(),
        ),
      );

  Map<String, dynamic> toSupabaseRow() => {
    'id': id,
    'session_id': sessionId,
    'student_id': studentId,
    'original_response': originalResponse,
    'corrections': corrections,
    'explanation': explanation,
    'alternative_phrasing': alternativePhrasing,
    'vocabulary': vocabulary.map((item) => item.toJson()).toList(),
    'feedback': feedback,
    'ai_available': aiAvailable,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

class LanguageOrtaSnapshot {
  final List<LanguageProfile> profiles;
  final List<LanguagePracticeSession> sessions;
  final List<LanguageSessionResult> results;
  const LanguageOrtaSnapshot({
    this.profiles = const [],
    this.sessions = const [],
    this.results = const [],
  });

  Map<String, dynamic> toJson() => {
    'profiles': profiles.map((item) => item.toJson()).toList(),
    'sessions': sessions.map((item) => item.toJson()).toList(),
    'results': results.map((item) => item.toJson()).toList(),
  };

  factory LanguageOrtaSnapshot.fromJson(Map<String, dynamic> json) =>
      LanguageOrtaSnapshot(
        profiles: [
          for (final item in json['profiles'] as List? ?? const [])
            LanguageProfile.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        sessions: [
          for (final item in json['sessions'] as List? ?? const [])
            LanguagePracticeSession.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
        ],
        results: [
          for (final item in json['results'] as List? ?? const [])
            LanguageSessionResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
        ],
      );
}

class LanguageOrtaDenied implements Exception {
  final String message;
  const LanguageOrtaDenied([
    this.message = 'Language ORTA is available only to students.',
  ]);
  @override
  String toString() => message;
}
