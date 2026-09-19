import '../models/life_context.dart';

class GoalSuggestionService {
  static List<GoalContext> suggestionsFor(LifeContext context) {
    final values = <String, GoalContext>{};

    void add(String id, String areaKey) {
      values[id] = GoalContext(id: id, titleKey: id, areaKey: areaKey);
    }

    for (final area in context.currentLifeAreas) {
      switch (area) {
        case LifeArea.school:
          add('school_university', 'education');
          add('school_grades', 'education');
          add('school_exams', 'education');
          add('school_language', 'language');
          add('school_time', 'personal');
        case LifeArea.university:
          add('university_performance', 'education');
          add('university_graduate', 'education');
          add('university_internship', 'career');
          add('university_research', 'education');
          add('university_job', 'career');
          add('university_language', 'language');
          add('university_time', 'personal');
        case LifeArea.work:
          add('career_advance', 'career');
          add('career_job', 'career');
          add('career_skills', 'career');
          add('career_certification', 'career');
          add('career_organization', 'personal');
        case LifeArea.freelance:
          add('freelance_clients', 'career');
          add('freelance_income', 'career');
          add('freelance_portfolio', 'career');
          add('freelance_workload', 'personal');
          add('freelance_business', 'project');
        case LifeArea.project:
          add('project_develop', 'project');
          add('project_funding', 'project');
          add('project_partners', 'project');
          add('project_users', 'project');
          add('project_mvp', 'project');
          add('project_pitch', 'project');
        case LifeArea.gapYear:
          add('gap_university', 'education');
          add('gap_portfolio', 'project');
          add('gap_work', 'career');
          add('gap_travel', 'personal');
          add('gap_language', 'language');
          add('gap_skills', 'personal');
          add('gap_project', 'project');
        case LifeArea.other:
          add('other_personal', 'personal');
      }
    }

    if (context.hasGoal('language_keep')) add('language_keep', 'language');
    add('other_goal', 'personal');
    return values.values.toList();
  }
}
