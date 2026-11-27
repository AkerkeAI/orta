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
    int variation = 0,
  }) {
    final version = variation % 3;
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
      PracticeSkill.speaking => [
        'In $languageName, describe one place where you like to learn and explain why. Speak as if you are in $setting. $levelHint',
        'In $languageName, explain a small problem you solved and what you learned. Speak as if you are in $setting. $levelHint',
        'In $languageName, describe a goal you care about and one step you will take next. Speak as if you are in $setting. $levelHint',
      ][version],
      PracticeSkill.writing => [
        'In $languageName, write a short message inviting someone to join an activity. Include when, where and why. $levelHint',
        'In $languageName, compare two ways to learn something new and explain which you prefer. $levelHint',
        'In $languageName, write a short note describing a challenge and asking for one helpful suggestion. $levelHint',
      ][version],
      PracticeSkill.listening => [
        'Listen to the short audio and answer: What is the speaker planning to do, and why? Answer in $languageName. $levelHint',
        'Listen to the short audio and answer: What changed in the plan? Answer in $languageName. $levelHint',
        'Listen to the short audio and answer: Which detail helped solve the problem? Answer in $languageName. $levelHint',
      ][version],
      PracticeSkill.reading => [
        'Read the passage and answer: Why did the student change their plan? Answer in $languageName. $levelHint',
        'Read the passage and answer: Which detail helped the group make a decision? Answer in $languageName. $levelHint',
        'Read the passage and answer: What would the main character most likely do next? Use a clue from the text. Answer in $languageName. $levelHint',
      ][version],
      PracticeSkill.vocabulary =>
        'In $languageName, write 5 useful phrases you could use in $setting and use each in a short sentence. $levelHint',
      PracticeSkill.scenario =>
        'In $languageName, role-play $setting. Write both what you would say and one question you would ask. $levelHint',
      PracticeSkill.conversation =>
        'Have a natural $languageName conversation for $setting. Reply to the tutor in complete sentences. $levelHint',
    };
    final stimulus = switch (skill) {
      PracticeSkill.listening => _listeningStimulus(version),
      PracticeSkill.reading => _readingStimulus(version),
      PracticeSkill.conversation => 'Tutor: Hello. Thank you for joining me today. Could you briefly introduce yourself and say why this conversation matters to you?',
      _ => '',
    };
    return PracticePrompt(prompt: prompt, stimulus: stimulus);
  }

  static String _listeningStimulus(int version) => [
    'Hello, I am planning a small study group for Friday. We will meet in the library after class because it is quieter than the café. Please bring one question from the chapter.',
    'Our class visit was going to be on Tuesday, but the science room is being repaired. The teacher moved it to Thursday and asked everyone to bring a notebook instead of a lunch.',
    'Mira could not find the project map, so she checked the last page of her notebook. There she saw a note with the room number. The team arrived just before the presentation began.',
  ][version];

  static String _readingStimulus(int version) => [
    'Nora planned to study at the park, but a sudden rainstorm changed her mind. She went to the community library instead. A classmate was already there and offered to review the science notes together. They finished one chapter and agreed to meet again next week.',
    'The school garden team could not agree on what to plant. One group wanted flowers, while another wanted vegetables. They checked how much sunlight each bed received and chose herbs for the shaded corner. Everyone helped label the new plants.',
    'When Amir arrived at the club, the room was locked. He noticed a message on the noticeboard saying the meeting had moved to the art studio. He followed the signs and arrived in time to help his friends prepare their display.',
  ][version];

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
