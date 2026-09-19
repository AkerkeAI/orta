import '../models/user_profile.dart';
import 'localization_service.dart';

class TimelineEvent {
  final String time;
  final String title;
  final String description;
  final bool completed;

  TimelineEvent({
    required this.time,
    required this.title,
    required this.description,
    this.completed = false,
  });
}

class TimelineService {
  static List<TimelineEvent> generateTodayTimeline(
    UserProfile userProfile,
    AppLocale locale,
  ) {
    final now = DateTime.now();
    final wakeUpHour = int.parse(userProfile.wakeUpTime.split(':')[0]);
    final sleepHour = int.parse(userProfile.sleepTime.split(':')[0]);
    
    final events = <TimelineEvent>[];
    
    // Morning check-in (2 hours after wake-up)
    final morningCheckin = DateTime(now.year, now.month, now.day, wakeUpHour + 2);
    if (morningCheckin.hour < sleepHour) {
      events.add(TimelineEvent(
        time: _formatTime(morningCheckin),
        title: _getLocalizedString(locale, 'home_morning_checkin'),
        description: _getLocalizedString(locale, 'home_how_did_you_sleep'),
        completed: now.isAfter(morningCheckin),
      ));
    }
    
    // Mini interaction (mid-day)
    final miniInteraction = DateTime(now.year, now.month, now.day, (wakeUpHour + sleepHour) ~/ 2);
    if (miniInteraction.hour < sleepHour && miniInteraction.hour > wakeUpHour) {
      events.add(TimelineEvent(
        time: _formatTime(miniInteraction),
        title: _getLocalizedString(locale, 'home_mini_interaction'),
        description: _getLocalizedString(locale, 'home_describe_around'),
        completed: false,
      ));
    }
    
    // Quick moment (evening)
    final quickMoment = DateTime(now.year, now.month, now.day, sleepHour - 2);
    if (quickMoment.hour > wakeUpHour) {
      events.add(TimelineEvent(
        time: _formatTime(quickMoment),
        title: _getLocalizedString(locale, 'home_quick_moment'),
        description: _getLocalizedString(locale, 'home_tell_orta'),
        completed: false,
      ));
    }
    
    return events;
  }

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String _getLocalizedString(AppLocale locale, String key) {
    // This is a simplified version - in production we'd use the actual localization service
    final localizations = AppLocalizations(locale);
    switch (key) {
      case 'home_morning_checkin':
        return localizations.homeMorningCheckin;
      case 'home_how_did_you_sleep':
        return localizations.homeHowDidYouSleep;
      case 'home_mini_interaction':
        return localizations.homeMiniInteraction;
      case 'home_describe_around':
        return localizations.homeDescribeAround;
      case 'home_quick_moment':
        return localizations.homeQuickMoment;
      case 'home_tell_orta':
        return localizations.homeTellOrta;
      default:
        return key;
    }
  }
}
