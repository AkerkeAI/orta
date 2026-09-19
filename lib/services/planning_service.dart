import '../models/orta_models.dart';

class PlanningService {
  static List<CalendarEvent> buildTodayPlan() {
    return [
      CalendarEvent(
        id: 'school',
        title: 'School',
        date: 'Today',
        startTime: '09:00',
        endTime: '12:00',
        category: 'Fixed',
        isFixed: true,
      ),
      CalendarEvent(
        id: 'project',
        title: 'Project work',
        date: 'Today',
        startTime: '15:30',
        endTime: '17:00',
        category: 'Flexible',
      ),
      CalendarEvent(
        id: 'english',
        title: 'English',
        date: 'Today',
        startTime: '17:00',
        endTime: '17:45',
        category: 'Language',
        isLanguageSession: true,
      ),
      CalendarEvent(
        id: 'free_window',
        title: 'Free window',
        date: 'Today',
        startTime: '18:00',
        endTime: '18:45',
        category: 'Free',
      ),
      CalendarEvent(
        id: 'university',
        title: 'University research',
        date: 'Today',
        startTime: '19:00',
        endTime: '19:30',
        category: 'Flexible',
      ),
    ];
  }

  static List<CalendarEvent> addItalianPlan() {
    return [
      CalendarEvent(
        id: 'italian_1',
        title: 'Italian',
        date: 'Tuesday',
        startTime: '18:00',
        endTime: '18:45',
        category: 'Language',
      ),
      CalendarEvent(
        id: 'italian_2',
        title: 'Italian',
        date: 'Saturday',
        startTime: '11:00',
        endTime: '11:45',
        category: 'Language',
      ),
    ];
  }
}
