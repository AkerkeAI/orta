import '../models/language.dart';
import '../models/orta_models.dart';
import '../models/user_profile.dart';

class OrtaDemoState {
  final UserProfile userProfile;
  final List<Opportunity> opportunities;
  final List<University> universities;
  final Project project;
  final ApplicationDraft applicationDraft;
  final LanguageProfile languageProfile;
  final List<LanguageMemory> languageMemories;
  final List<CalendarEvent> calendar;
  final DailyBrief dailyBrief;
  final List<String> progressTimeline;
  final List<Task> tasks;
  final List<Goal> goals;

  OrtaDemoState({
    required this.userProfile,
    required this.opportunities,
    required this.universities,
    required this.project,
    required this.applicationDraft,
    required this.languageProfile,
    required this.languageMemories,
    required this.calendar,
    required this.dailyBrief,
    required this.progressTimeline,
    required this.tasks,
    required this.goals,
  });
}

class DemoDataService {
  static OrtaDemoState buildDemoState(UserProfile userProfile) {
    final demoGoals = [
      Goal(
        id: 'university',
        title: 'University',
        category: 'Education',
        selected: true,
        details: {
          'field': 'Computer Science',
          'countries': ['Germany', 'Netherlands'],
        },
      ),
      Goal(
        id: 'project',
        title: 'My Project / Startup',
        category: 'Project',
        selected: true,
        details: {
          'projectName': 'AIqyn',
          'description': 'AI workflow tools for early-stage founders.',
        },
      ),
      Goal(
        id: 'language',
        title: 'Learn a Language',
        category: 'Language',
        selected: true,
        details: {'targetLanguage': 'English', 'level': 'B2'},
      ),
      Goal(
        id: 'other',
        title: 'Personal Development',
        category: 'Growth',
        selected: true,
      ),
    ];

    final demoProject = Project(
      id: 'project_aiqyn',
      name: 'AIqyn',
      description: 'AI workflow tools for early-stage founders.',
      stage: 'Pilot',
      goals: [
        'Prepare competition application',
        'Improve pitch deck',
        'Validate pilot',
      ],
      upcomingDeadlines: [
        'Competition deadline in 6 days',
        'Pitch review Friday',
      ],
      opportunitiesCount: 3,
      nextAction: 'Complete competition application',
      progress: ['MVP ✓', 'Pitch ✓', 'Pilot ○'],
    );

    final opportunities = [
      Opportunity(
        id: 'opportunity_1',
        title: 'Startup Catalyst 2026',
        category: 'Programs',
        deadline: 'In 6 days',
        whyItMatches: 'This program matches your AI startup project and supports founders building early traction.',
        relevantGoal: 'My Project / Startup',
        status: 'New',
      ),
      Opportunity(
        id: 'opportunity_2',
        title: 'Ecosystem Ventures Grant',
        category: 'Grants',
        deadline: 'In 12 days',
        whyItMatches: 'Your project addresses a clear user problem and fits the grant focus on digital innovation.',
        relevantGoal: 'AIqyn',
        status: 'Reviewing',
      ),
    ];

    final universities = [
      University(
        id: 'uni_1',
        name: 'University of Twente',
        country: 'Netherlands',
        program: 'MSc Computer Science',
        deadline: '2026-10-18',
        requirementsStatus: 'Requires action',
        requiredLanguage: 'English B2',
        requirements: [
          'English proficiency',
          'Transcript',
          'Motivation letter',
          'Portfolio',
        ],
        insight: 'This program requires English B2. Your current plan does not include English preparation.',
      ),
      University(
        id: 'uni_2',
        name: 'University of Bologna',
        country: 'Italy',
        program: 'MSc Digital Innovation',
        deadline: '2026-10-10',
        requirementsStatus: 'Italian required',
        requiredLanguage: 'Italian B2',
        requirements: ['Italian B2', 'Academic CV', 'Statement of purpose'],
        insight: 'This program requires Italian B2. ORTA detected a gap in your plan.',
      ),
    ];

    final appDraft = ApplicationDraft(
      title: 'DRAFT — NOT SUBMITTED',
      projectName: 'AIqyn',
      problem: 'Founders spend too much time repeating manual research and documentation tasks before product validation.',
      solution: 'AIqyn helps founders organize early customer discovery, synthesize research, and turn insights into actionable workstreams.',
      impact: 'Teams can move faster from idea to pilot while maintaining clarity on priorities and risks.',
      team: 'Akerke, product and research lead; support from advisors and design collaborators.',
      realSubmissionLanguage: 'Russian',
      draftPrepared: true,
    );

    final lifeMap = [
      LifeMapCategory(
        name: 'Everyday conversation',
        value: 78,
        description: 'Daily life and practical communication',
      ),
      LifeMapCategory(
        name: 'Academic language',
        value: 55,
        description: 'Research and academic writing',
      ),
      LifeMapCategory(
        name: 'Projects & pitching',
        value: 64,
        description: 'Explaining ideas clearly and confidently',
      ),
      LifeMapCategory(
        name: 'Writing',
        value: 58,
        description: 'Structured writing and summaries',
      ),
      LifeMapCategory(
        name: 'Speaking',
        value: 49,
        description: 'Fluent, natural spoken communication',
      ),
    ];

    final languageProfile = LanguageProfile(
      learningLanguage: Language.english,
      levelLabel: 'English · B2',
      languageIndependence: 42,
      lifeMap: lifeMap,
    );

    final memories = [
      LanguageMemory(
        title: 'Monday · Project work',
        context: 'Project work',
        phrase: 'I need to clarify our target audience.',
        meaning: 'I need to explain exactly who the product is for.',
        language: 'English',
      ),
      LanguageMemory(
        title: 'Tuesday · University research',
        context: 'University research',
        phrase: 'I am considering studying archaeology abroad.',
        meaning: 'I am thinking about studying archaeology in another country.',
        language: 'English',
      ),
    ];

    final calendar = [
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
        id: 'project_work',
        title: 'Project work',
        date: 'Today',
        startTime: '15:30',
        endTime: '17:00',
        category: 'Flexible',
        isFixed: false,
      ),
      CalendarEvent(
        id: 'english',
        title: 'English',
        date: 'Today',
        startTime: '17:00',
        endTime: '17:45',
        category: 'Language',
        isFixed: false,
        isLanguageSession: true,
      ),
      CalendarEvent(
        id: 'free_window',
        title: 'Free window',
        date: 'Today',
        startTime: '18:00',
        endTime: '18:45',
        category: 'Flexible',
        isFixed: false,
      ),
      CalendarEvent(
        id: 'uni_research',
        title: 'University research',
        date: 'Today',
        startTime: '19:00',
        endTime: '19:30',
        category: 'Flexible',
        isFixed: false,
      ),
    ];

    final tasks = [
      Task(
        id: 'task_1',
        title: 'Project description draft',
        category: 'Application',
        time: 'Tomorrow 10:00',
        description: 'Refine the problem and solution sections',
        completed: true,
      ),
      Task(
        id: 'task_2',
        title: 'English session',
        category: 'Language',
        time: 'Today 17:00',
        description: 'Practice explaining your project in English',
        completed: false,
      ),
      Task(
        id: 'task_3',
        title: 'University requirement review',
        category: 'Education',
        time: 'Today 19:00',
        description: 'Check required documents and deadlines',
        completed: false,
      ),
    ];

    final progressTimeline = [
      'Application draft prepared',
      'English session completed',
      'University requirement added',
      'Project milestone completed',
    ];

    final dailyBrief = DailyBrief(
      title: 'ORTA DAILY',
      completed: [
        '4 tasks completed',
        'English session completed',
        'Project draft prepared',
      ],
      findings: ['3 project opportunities', '1 university requirement'],
      tomorrow: ['5 planned tasks', '1h 20m free time'],
      suggestedFocus: 'University research',
    );

    return OrtaDemoState(
      userProfile: userProfile,
      opportunities: opportunities,
      universities: universities,
      project: demoProject,
      applicationDraft: appDraft,
      languageProfile: languageProfile,
      languageMemories: memories,
      calendar: calendar,
      dailyBrief: dailyBrief,
      progressTimeline: progressTimeline,
      tasks: tasks,
      goals: demoGoals,
    );
  }
}
