import 'language.dart';

enum LanguageLevel {
  a0,
  a1,
  a2,
  b1,
  b2,
  c1,
  c2,
  unknown,
}

extension LanguageLevelExtension on LanguageLevel {
  String get displayName {
    switch (this) {
      case LanguageLevel.a0:
        return 'A0 — Beginner';
      case LanguageLevel.a1:
        return 'A1';
      case LanguageLevel.a2:
        return 'A2';
      case LanguageLevel.b1:
        return 'B1';
      case LanguageLevel.b2:
        return 'B2';
      case LanguageLevel.c1:
        return 'C1';
      case LanguageLevel.c2:
        return 'C2';
      case LanguageLevel.unknown:
        return 'I don\'t know my level';
    }
  }

  String get shortName {
    switch (this) {
      case LanguageLevel.a0:
        return 'A0';
      case LanguageLevel.a1:
        return 'A1';
      case LanguageLevel.a2:
        return 'A2';
      case LanguageLevel.b1:
        return 'B1';
      case LanguageLevel.b2:
        return 'B2';
      case LanguageLevel.c1:
        return 'C1';
      case LanguageLevel.c2:
        return 'C2';
      case LanguageLevel.unknown:
        return '?';
    }
  }

  static LanguageLevel fromString(String value) {
    switch (value) {
      case 'A0':
        return LanguageLevel.a0;
      case 'A1':
        return LanguageLevel.a1;
      case 'A2':
        return LanguageLevel.a2;
      case 'B1':
        return LanguageLevel.b1;
      case 'B2':
        return LanguageLevel.b2;
      case 'C1':
        return LanguageLevel.c1;
      case 'C2':
        return LanguageLevel.c2;
      default:
        return LanguageLevel.unknown;
    }
  }
}

class UserProfile {
  final String name;
  final Language nativeLanguage;
  final Language learningLanguage;
  final LanguageLevel level;
  final String wakeUpTime;
  final String sleepTime;
  final bool notificationsEnabled;
  final int dayStreak;
  final int wordsPracticed;
  final int conversations;
  final double progressToNextLevel; // 0.0 to 1.0
  final int weeklyConversationsCompleted; // 0 or 1 for weekly goal

  UserProfile({
    required this.name,
    required this.nativeLanguage,
    required this.learningLanguage,
    required this.level,
    required this.wakeUpTime,
    required this.sleepTime,
    this.notificationsEnabled = true,
    this.dayStreak = 0,
    this.wordsPracticed = 0,
    this.conversations = 0,
    this.progressToNextLevel = 0.0,
    this.weeklyConversationsCompleted = 0,
  });

  UserProfile copyWith({
    String? name,
    Language? nativeLanguage,
    Language? learningLanguage,
    LanguageLevel? level,
    String? wakeUpTime,
    String? sleepTime,
    bool? notificationsEnabled,
    int? dayStreak,
    int? wordsPracticed,
    int? conversations,
    double? progressToNextLevel,
    int? weeklyConversationsCompleted,
  }) {
    return UserProfile(
      name: name ?? this.name,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      learningLanguage: learningLanguage ?? this.learningLanguage,
      level: level ?? this.level,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      sleepTime: sleepTime ?? this.sleepTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dayStreak: dayStreak ?? this.dayStreak,
      wordsPracticed: wordsPracticed ?? this.wordsPracticed,
      conversations: conversations ?? this.conversations,
      progressToNextLevel: progressToNextLevel ?? this.progressToNextLevel,
      weeklyConversationsCompleted: weeklyConversationsCompleted ?? this.weeklyConversationsCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'nativeLanguage': nativeLanguage.code,
      'learningLanguage': learningLanguage.code,
      'level': level.shortName,
      'wakeUpTime': wakeUpTime,
      'sleepTime': sleepTime,
      'notificationsEnabled': notificationsEnabled,
      'dayStreak': dayStreak,
      'wordsPracticed': wordsPracticed,
      'conversations': conversations,
      'progressToNextLevel': progressToNextLevel,
      'weeklyConversationsCompleted': weeklyConversationsCompleted,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      nativeLanguage: LanguageExtension.fromCode(json['nativeLanguage'] ?? 'en'),
      learningLanguage: LanguageExtension.fromCode(json['learningLanguage'] ?? 'en'),
      level: LanguageLevelExtension.fromString(json['level'] ?? 'A0'),
      wakeUpTime: json['wakeUpTime'] ?? '08:00',
      sleepTime: json['sleepTime'] ?? '22:00',
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      dayStreak: json['dayStreak'] ?? 0,
      wordsPracticed: json['wordsPracticed'] ?? 0,
      conversations: json['conversations'] ?? 0,
      progressToNextLevel: (json['progressToNextLevel'] as num?)?.toDouble() ?? 0.0,
      weeklyConversationsCompleted: json['weeklyConversationsCompleted'] ?? 0,
    );
  }
}
