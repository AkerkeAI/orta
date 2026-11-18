import '../models/language_orta_models.dart';
import '../models/life_context.dart';

class PracticePrompt {
  final String prompt;
  final String stimulus;
  const PracticePrompt({required this.prompt, this.stimulus = ''});
}

/// Local, self-guided exercises. Only broad context categories determine topics;
/// free-text names, notes, dates, commitments and other personal fields are unused.
class LanguagePracticeService {
  static const supportedTopics = {
    'daily',
    'education',
    'exam',
    'career',
    'project',
    'goal',
  };

  static const skills = PracticeSkill.values;
  static const scenarios = PracticeScenario.values;

  static ApprovedLanguageContext approvedFromLife(LifeContext? life) {
    if (life == null) return const ApprovedLanguageContext();
    return ApprovedLanguageContext(
      preparingUniversity:
          life.currentLifeAreas.contains(LifeArea.university) ||
          life.currentLifeAreas.contains(LifeArea.school) ||
          life.education != null,
      hasProject:
          life.currentLifeAreas.contains(LifeArea.project) ||
          life.projects.isNotEmpty,
    );
  }

  static PracticePrompt localPrompt({
    required String languageName,
    required String level,
    required PracticeSkill skill,
    required PracticeScenario scenario,
    ApprovedLanguageContext context = const ApprovedLanguageContext(),
  }) {
    final setting = switch (scenario) {
      PracticeScenario.everyday => 'an everyday conversation',
      PracticeScenario.universityInterview => 'a university interview',
      PracticeScenario.intendedMajor =>
        context.intendedMajor == null || context.intendedMajor!.isEmpty
            ? 'explaining an intended field of study'
            : 'explaining an interest in ${context.intendedMajor}',
      PracticeScenario.scholarshipInterview => 'a scholarship interview',
      PracticeScenario.personalProject =>
        context.hasProject
            ? 'presenting a personal project in general terms'
            : 'presenting a fictional personal project',
      PracticeScenario.professionalIntro => 'a professional self-introduction',
    };
    final levelHint =
        'Keep the language around $level. Do not invent application facts.';
    final prompt = switch (skill) {
      PracticeSkill.speaking =>
        'In $languageName, speak as if you are in $setting. Type the words you would say. $levelHint',
      PracticeSkill.writing =>
        'In $languageName, write 6–10 sentences for $setting. $levelHint',
      PracticeSkill.listening =>
        'Read this $languageName listening rehearsal (audio is not available), then answer in $languageName. $levelHint',
      PracticeSkill.reading =>
        'Read the $languageName passage, then answer the question in $languageName. $levelHint',
      PracticeSkill.vocabulary =>
        'In $languageName, write 5 useful phrases you could use in $setting and use each in a short sentence. $levelHint',
      PracticeSkill.scenario =>
        'In $languageName, role-play $setting. Write both what you would say and one question you would ask. $levelHint',
      PracticeSkill.conversation =>
        'Have a natural $languageName conversation for $setting. Reply to the tutor in complete sentences. $levelHint',
    };
    final stimulus = switch (skill) {
      PracticeSkill.listening || PracticeSkill.reading =>
        _stimulus(languageName, level, scenario, context),
      PracticeSkill.conversation =>
        'Tutor: Hello. Thank you for joining me today. Could you briefly introduce yourself and say why this conversation matters to you?',
      _ => '',
    };
    return PracticePrompt(prompt: prompt, stimulus: stimulus);
  }

  static String _stimulus(
    String languageName,
    String level,
    PracticeScenario scenario,
    ApprovedLanguageContext context,
  ) {
    final major = context.intendedMajor?.trim();
    final subject = (major != null && major.isNotEmpty)
        ? major
        : 'your intended field of study';
    return switch (scenario) {
      PracticeScenario.universityInterview =>
        'A short $languageName rehearsal ($level): “We would like to understand your motivation. Please tell us about $subject and one challenge you hope to work on. You do not need to quote any real application essay.”',
      PracticeScenario.scholarshipInterview =>
        'A short $languageName rehearsal ($level): “Scholarships support students who can explain their goals clearly. Describe one academic goal and one way you would contribute to a community.”',
      PracticeScenario.personalProject =>
        'A short $languageName rehearsal ($level): “Imagine presenting a project. Explain the problem, what you built, and the next step. Use a fictional example if you prefer.”',
      PracticeScenario.professionalIntro =>
        'A short $languageName rehearsal ($level): “In professional settings, a clear introduction includes your name role, one strength, and what you are looking for.”',
      PracticeScenario.intendedMajor =>
        'A short $languageName rehearsal ($level): “Many students change their minds. Explain what draws you to $subject and one question you still have.”',
      PracticeScenario.everyday =>
        'A short $languageName rehearsal ($level): “You meet a classmate after school. They ask about your day, a class you enjoyed, and plans for the weekend.”',
    };
  }

  static PracticeScenario recommendedScenario(ApprovedLanguageContext context) {
    if (context.preparingUniversity) {
      return PracticeScenario.universityInterview;
    }
    if (context.hasProject) return PracticeScenario.personalProject;
    return PracticeScenario.everyday;
  }

  static List<String> topicsFor(LifeContext? life) {
    final topics = <String>['daily'];
    if (life == null) return topics;
    if (life.currentLifeAreas.any(
          (area) => area == LifeArea.school || area == LifeArea.university,
        ) ||
        life.education != null) {
      topics.add('education');
    }
    if (life.exams.isNotEmpty) topics.add('exam');
    if (life.currentLifeAreas.any(
          (area) => area == LifeArea.work || area == LifeArea.freelance,
        ) ||
        life.career != null) {
      topics.add('career');
    }
    if (life.currentLifeAreas.contains(LifeArea.project) ||
        life.projects.isNotEmpty) {
      topics.add('project');
    }
    if (life.goals.isNotEmpty) topics.add('goal');
    return List.unmodifiable(topics);
  }
}
