import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/language.dart';
import '../../app/theme/app_theme.dart';
import '../../services/localization_service.dart';
import '../../services/timeline_service.dart';

class HomeScreen extends StatelessWidget {
  final UserProfile userProfile;
  final AppLocale currentLocale;
  final Function(String) onNavigateToAi;

  const HomeScreen({
    super.key,
    required this.userProfile,
    required this.currentLocale,
    required this.onNavigateToAi,
  });

  String _getGreeting(AppLocalizations localizations) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return localizations.homeGoodMorning;
    } else if (hour < 17) {
      return localizations.homeGoodAfternoon;
    } else {
      return localizations.homeGoodEvening;
    }
  }

  String _getNextLevel(LanguageLevel currentLevel) {
    switch (currentLevel) {
      case LanguageLevel.a0:
        return 'A1';
      case LanguageLevel.a1:
        return 'A2';
      case LanguageLevel.a2:
        return 'B1';
      case LanguageLevel.b1:
        return 'B2';
      case LanguageLevel.b2:
        return 'C1';
      case LanguageLevel.c1:
        return 'C2';
      case LanguageLevel.c2:
        return ''; // No next level for C2
      case LanguageLevel.unknown:
        return 'A1';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(currentLocale);
    final nextLevel = _getNextLevel(userProfile.level);
    final timelineEvents = TimelineService.generateTodayTimeline(userProfile, currentLocale);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              '${_getGreeting(localizations)}, ${userProfile.name}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            // Current language
            Text(
              '${_getLanguageDisplayName(userProfile.learningLanguage, localizations)} · ${userProfile.level.shortName}',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // ORTA Today section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.homeOrtaToday,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...timelineEvents.map((event) => _TimelineEventItem(event: event)),
                    const SizedBox(height: 16),
                    // Weekly conversation
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            localizations.homeThisWeek,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              localizations.homeConversationWithOrta,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${userProfile.weeklyConversationsCompleted}${localizations.homeWeeklyConversationProgress}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Today's task card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            localizations.homeTodayTask,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Describe what you can see around you in ${_getLanguageDisplayName(userProfile.learningLanguage, localizations)}.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onNavigateToAi('Describe what you can see around you');
                        },
                        icon: const Icon(Icons.chat),
                        label: Text(localizations.homeDoWithAi),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Progress section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.homeProgress,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (userProfile.level == LanguageLevel.c2)
                      Text(
                        localizations.levelMastery,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                userProfile.level.shortName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${(userProfile.progressToNextLevel * 100).toInt()}% ${localizations.homeToNextLevel} $nextLevel',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: userProfile.progressToNextLevel,
                              backgroundColor: AppTheme.dividerColor,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Activity section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.homeActivity,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActivityItem(
                            icon: Icons.local_fire_department,
                            label: localizations.homeDayStreak,
                            value: '${userProfile.dayStreak}',
                          ),
                        ),
                        Expanded(
                          child: _ActivityItem(
                            icon: Icons.menu_book,
                            label: localizations.homeWords,
                            value: '${userProfile.wordsPracticed}',
                          ),
                        ),
                        Expanded(
                          child: _ActivityItem(
                            icon: Icons.chat,
                            label: localizations.homeConversations,
                            value: '${userProfile.conversations}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // AI message card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: const Text(
                            'O',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            localizations.appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${localizations.homeHowDidYouSleep} ${userProfile.name}?',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Handle response
                            },
                            child: Text(localizations.responseWell),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Handle response
                            },
                            child: Text(localizations.responseNotGreat),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageDisplayName(Language language, AppLocalizations localizations) {
    switch (language) {
      case Language.english:
        return localizations.langEnglish;
      case Language.russian:
        return localizations.langRussian;
      case Language.kazakh:
        return localizations.langKazakh;
    }
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ActivityItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TimelineEventItem extends StatelessWidget {
  final TimelineEvent event;

  const _TimelineEventItem({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            event.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: event.completed ? AppTheme.primaryColor : AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
