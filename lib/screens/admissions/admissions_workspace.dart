import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/admissions_models.dart';
import '../../models/language_orta_models.dart';
import '../../screens/language_orta/language_orta_workspace.dart';
import '../../services/language_orta_access.dart';
import '../../services/language_orta_store.dart';

const _ink = Color(0xFF172B4D);
const _muted = Color(0xFF6B7890);
const _line = Color(0xFFE8EDF4);
const _wash = Color(0xFFF5F7FB);
const _blue = Color(0xFF4568F5);
const _teal = Color(0xFF25A98E);

class AdmissionsWorkspace extends StatefulWidget {
  const AdmissionsWorkspace({super.key});

  @override
  State<AdmissionsWorkspace> createState() => _AdmissionsWorkspaceState();
}

class _AdmissionsWorkspaceState extends State<AdmissionsWorkspace> {
  final OrtaRole _role = OrtaRole.founder;
  String _section = 'Overview';
  int _selectedNav = 0;
  final List<_DemoStudent> _students = [
    _DemoStudent(
      'Aruzhan K.',
      'Grade 11',
      'Intensive',
      'United States · China',
      68,
      'Essay draft due in 3 days',
    ),
    _DemoStudent(
      'Daniyar S.',
      'Grade 10',
      'Standard',
      'United States',
      42,
      'Book IELTS diagnostic',
    ),
    _DemoStudent(
      'Mira A.',
      'Grade 9',
      'Standard',
      'China · Singapore',
      27,
      'Review shortlist together',
    ),
    _DemoStudent(
      'Alikhan T.',
      'Grade 11',
      'Intensive',
      'United Kingdom · United States',
      81,
      'Submit transcript request',
    ),
  ];

  LanguageOrtaStore? _languageStore;

  @override
  void initState() {
    super.initState();
    _openPreviewLanguageStore();
  }

  Future<void> _openPreviewLanguageStore() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'language_orta_preview_student';
    if (!mounted) return;
    setState(() {
      _languageStore = StudentLanguageOrtaStore(
        studentId: 'preview-student',
        role: 'student',
        memory: MemoryLanguageSnapshotStore(
          StudentLanguageOrtaStore.loadFromPrefs(prefs, key),
        ),
        prefs: prefs,
        prefsKey: key,
      );
    });
  }

  List<String> get _sections => switch (_role) {
    OrtaRole.founder => [
      'Overview',
      'Students',
      'Mentors',
      'Finance',
      'Opportunities',
    ],
    OrtaRole.student => LanguageOrtaAccess.studentSections([
      'Dashboard',
      'Universities',
      'Applications',
      'Progress',
      'Lessons',
      'Opportunities',
    ]),
    OrtaRole.mentor => [
      'Dashboard',
      'My students',
      'My lessons',
      'My earnings',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (!sections.contains(_section)) {
      _section = sections.first;
      _selectedNav = 0;
    }
    return Scaffold(
      backgroundColor: _wash,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            return Row(
              children: [
                if (wide) _sidebar(sections),
                Expanded(
                  child: Column(
                    children: [
                      _topbar(wide),
                      if (!wide) _mobileNav(sections),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 34 : 20,
                            24,
                            wide ? 34 : 20,
                            34,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1160),
                              child: _content(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sidebar(List<String> sections) => Container(
    width: 248,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: _line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 25, 20, 26),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORTA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'ADMISSIONS',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.4,
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 16, 11),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var i = 0; i < sections.length; i++) _navItem(sections[i], i),
        const Spacer(),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _blue, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Small steps today make big opportunities possible.',
                  style: TextStyle(fontSize: 12, height: 1.45, color: _ink),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _navItem(String title, int index) {
    final active = _selectedNav == index;
    final icon = _iconFor(title);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() {
          _selectedNav = index;
          _section = title;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEEF2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: active ? _blue : _muted),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: active ? _blue : _ink,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topbar(bool wide) => Container(
    height: 72,
    padding: EdgeInsets.symmetric(horizontal: wide ? 30 : 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        if (!wide)
          const Text(
            'ORTA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: 1,
            ),
          ),
        if (wide)
          Text(
            _section,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _ink,
              fontSize: 15,
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5DB),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'PREVIEW',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9A6A00),
              letterSpacing: .7,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFEAF0FF),
              child: Icon(
                _role == OrtaRole.founder
                    ? Icons.person
                    : _role == OrtaRole.student
                    ? Icons.school_outlined
                    : Icons.cast_for_education_outlined,
                color: _blue,
                size: 17,
              ),
            ),
            const SizedBox(width: 9),
            if (MediaQuery.sizeOf(context).width > 520)
              Text(
                _roleLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _muted,
              size: 19,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _mobileNav(List<String> sections) => Container(
    height: 54,
    color: Colors.white,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        for (var i = 0; i < sections.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(sections[i]),
              selected: _selectedNav == i,
              onSelected: (_) => setState(() {
                _selectedNav = i;
                _section = sections[i];
              }),
              selectedColor: const Color(0xFFE9EEFF),
              labelStyle: TextStyle(
                color: _selectedNav == i ? _blue : _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
      ],
    ),
  );

  String get _roleLabel => switch (_role) {
    OrtaRole.founder => 'Founder',
    OrtaRole.student => 'Student',
    OrtaRole.mentor => 'Mentor',
  };

  Widget _content() {
    final workspace = _role == OrtaRole.founder
        ? _founderContent()
        : _role == OrtaRole.student
        ? _studentContent()
        : _mentorContent();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1E2B9)),
          ),
          child: const Text(
            'Preview workspace · Names, figures and opportunities are sample data. Changes are not saved.',
            style: TextStyle(color: Color(0xFF785C1D), fontSize: 11),
          ),
        ),
        const SizedBox(height: 18),
        workspace,
      ],
    );
  }

  Widget _founderContent() => switch (_section) {
    'Students' => _studentsPage(),
    'Mentors' => _mentorsPage(),
    'Finance' => _financePage(),
    'Opportunities' => _opportunitiesPage(),
    _ => _founderDashboard(),
  };

  Widget _founderDashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Good morning, Aigerim',
        'Here’s what needs your attention today.',
        action: _actionButton(
          'Add student',
          Icons.add,
          () => _notice('Student invitation flow is ready to connect.'),
        ),
      ),
      const SizedBox(height: 22),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _metric(
            'Active students',
            '24',
            '+3 this month',
            Icons.groups_2_outlined,
            const Color(0xFFEEF2FF),
            _blue,
          ),
          _metric(
            'Active programs',
            '18',
            '12 Standard · 6 Intensive',
            Icons.auto_awesome_mosaic_outlined,
            const Color(0xFFE8F8F3),
            _teal,
          ),
          _metric(
            'Upcoming deadlines',
            '07',
            'Next 14 days',
            Icons.event_outlined,
            const Color(0xFFFFF4E5),
            const Color(0xFFD88924),
          ),
          _metric(
            'Pending confirmations',
            '03',
            'Lessons to review',
            Icons.fact_check_outlined,
            const Color(0xFFFFEBEE),
            const Color(0xFFD55D6A),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _responsivePair(
        _panel('Student progress', _studentRows(compact: true)),
        _deadlinesPanel(),
      ),
      const SizedBox(height: 18),
      _responsivePair(
        _panel('Today’s consultations', _consultationRows()),
        _attentionPanel(),
      ),
    ],
  );

  Widget _studentsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Students',
        'Manage profiles, programs, mentors and admissions progress.',
        action: _actionButton(
          'Invite student',
          Icons.person_add_alt_1,
          () => _notice('Student invitation flow is ready to connect.'),
        ),
      ),
      const SizedBox(height: 18),
      _panel(
        'All students · 24',
        Column(
          children: [
            _studentRows(),
            const Divider(height: 1),
            _studentLine(
              'Samat B.',
              'Grade 10 · ORTA Standard',
              'China · Japan',
              36,
              'On track',
            ),
            _studentLine(
              'Madina R.',
              'Grade 9 · ORTA Standard',
              'United States',
              19,
              'New registration',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _mentorsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Mentors',
        'Assignments, lesson confirmations and compensation.',
        action: _actionButton(
          'Add mentor',
          Icons.add,
          () => _notice('Mentor invitation flow is ready to connect.'),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _mentorCard(
            'Aruzhan N.',
            'USA admissions',
            '8 assigned students',
            '12 lessons · 60,000 ₸',
            Icons.flight_takeoff_rounded,
          ),
          _mentorCard(
            'Daulet K.',
            'China admissions',
            '7 assigned students',
            '10 lessons · 50,000 ₸',
            Icons.language_rounded,
          ),
          _mentorCard(
            'Aigerim S.',
            'Founder mentorship',
            '24 assigned students',
            '6 sessions this week',
            Icons.workspace_premium_outlined,
          ),
        ],
      ),
    ],
  );

  Widget _financePage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Financial overview',
        'Package payments, service delivery and operating costs.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _metric(
            'Received this month',
            '₸1.24M',
            'Payments recorded',
            Icons.south_west,
            const Color(0xFFE8F8F3),
            _teal,
          ),
          _metric(
            'Outstanding',
            '₸540K',
            '3 unconditional offers verified',
            Icons.pending_actions,
            const Color(0xFFFFF4E5),
            const Color(0xFFD88924),
          ),
          _metric(
            'Mentor compensation',
            '₸110K',
            'Confirmed lessons only',
            Icons.payments_outlined,
            const Color(0xFFEEF2FF),
            _blue,
          ),
          _metric(
            'Refund requests',
            '01',
            'Awaiting review',
            Icons.currency_exchange,
            const Color(0xFFFFEBEE),
            const Color(0xFFD55D6A),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _panel(
        'Recent financial records',
        Column(
          children: [
            _financialRow(
              'Initial payment · Aruzhan K.',
              '₸20,000',
              'Received · 28 Oct',
            ),
            _financialRow(
              'Mentor lesson · USA · Daniyar S.',
              '₸5,000',
              'Confirmed · 27 Oct',
            ),
            _financialRow(
              'Unconditional offer · Alikhan T.',
              '₸180,000',
              'Verification needed · 26 Oct',
            ),
            _financialRow(
              'Refund request · Mira A.',
              '₸15,000',
              'Review service delivery',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _studentContent() => switch (_section) {
    'Universities' => _universitiesPage(),
    'Applications' => _applicationsPage(),
    'Progress' => _progressPage(),
    'Lessons' => _studentLessonsPage(),
    'Opportunities' => _opportunitiesPage(),
    'Language ORTA' => LanguageOrtaWorkspace(
      role: 'student',
      studentId: 'preview-student',
      studentName: 'Aruzhan',
      store: _languageStore,
      approvedContext: const ApprovedLanguageContext(
        intendedMajor: 'Computer Science',
        preparingUniversity: true,
      ),
    ),
    _ => _studentDashboard(),
  };

  Widget _studentDashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Your admissions journey',
        'You’re making steady progress, Aruzhan.',
      ),
      const SizedBox(height: 18),
      _panel(
        'ORTA Intensive · Your roadmap',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Overall progress',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                Text(
                  '68%',
                  style: TextStyle(color: _blue, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(
                value: .68,
                minHeight: 9,
                color: _blue,
                backgroundColor: Color(0xFFE9EDF5),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag('Profile complete', _teal),
                _tag('University shortlist', _blue),
                _tag('Applications in progress', const Color(0xFFD88924)),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Your next step: finish the first Common App essay draft by Friday.',
              style: TextStyle(color: _ink, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _responsivePair(
        _panel('Next up', _consultationRows()),
        _deadlinesPanel(),
      ),
      const SizedBox(height: 18),
      _panel('Recommended for you', _opportunityRows(student: true)),
      const SizedBox(height: 18),
      _panel(
        'Language ORTA',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Practice interviews, everyday conversation and study language without changing your applications.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('openLanguageOrta'),
              onPressed: () => setState(() {
                _section = LanguageOrtaAccess.moduleName;
                _selectedNav = _sections.indexOf(LanguageOrtaAccess.moduleName);
              }),
              icon: const Icon(Icons.translate_rounded, size: 18),
              label: const Text('Open Language ORTA'),
              style: FilledButton.styleFrom(backgroundColor: _teal),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _universitiesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'University shortlist',
        'Compare programs, deadlines and verified admission sources.',
        action: _actionButton(
          'Add university',
          Icons.add,
          () => _notice(
            'University search can be connected to verified sources.',
          ),
        ),
      ),
      const SizedBox(height: 18),
      _panel(
        'Your shortlist · 4',
        Column(
          children: [
            _universityRow(
              'University of Toronto',
              'Canada · Computer Science',
              'Early deadline · 7 Nov',
              'IELTS 6.5 · SAT optional',
            ),
            _universityRow(
              'University of Hong Kong',
              'Hong Kong · Data Science',
              'Deadline · 1 Dec',
              'IELTS 6.5 · Transcript',
            ),
            _universityRow(
              'Arizona State University',
              'United States · Informatics',
              'Rolling admission',
              'IELTS 6.0 · Common App',
            ),
            _universityRow(
              'Xi’an Jiaotong-Liverpool',
              'China · Computer Science',
              'Deadline · 15 Jan',
              'IELTS 6.0 · Personal statement',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _applicationsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Applications',
        'Track every university application and its required documents.',
        action: _actionButton(
          'Add application',
          Icons.add,
          () => _notice('Application creation form is ready to connect.'),
        ),
      ),
      const SizedBox(height: 18),
      _panel(
        'Application tracker',
        Column(
          children: [
            _applicationRow(
              'University of Toronto',
              'In preparation',
              'Essay · Transcript · IELTS',
            ),
            _applicationRow(
              'Arizona State University',
              'Submitted',
              'Submitted 24 Oct · Awaiting review',
            ),
            _applicationRow(
              'University of Hong Kong',
              'In preparation',
              'Recommendation letter missing',
            ),
            _applicationRow(
              'Xi’an Jiaotong-Liverpool',
              'Not started',
              'Deadline 15 Jan',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _progressPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Your progress',
        'Academic milestones and achievements in one place.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _metric(
            'IELTS practice',
            '6.5',
            'Target 7.0 · updated 29 Oct',
            Icons.translate_rounded,
            const Color(0xFFE8F8F3),
            _teal,
          ),
          _metric(
            'SAT practice',
            '1380',
            'Target 1450 · updated 26 Oct',
            Icons.school_outlined,
            const Color(0xFFEEF2FF),
            _blue,
          ),
          _metric(
            'Milestones done',
            '12 / 18',
            '6 more on your roadmap',
            Icons.flag_outlined,
            const Color(0xFFFFF4E5),
            const Color(0xFFD88924),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _panel(
        'Recent achievements',
        Column(
          children: [
            _financialRow(
              'Volunteer tutor · Aktau Youth Center',
              'Completed',
              'Oct 2026',
            ),
            _financialRow('Regional robotics finalist', 'Award', 'Sep 2026'),
            _financialRow('School science fair project', 'Project', 'Aug 2026'),
          ],
        ),
      ),
    ],
  );

  Widget _studentLessonsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Lessons',
        'Your consultation schedule and confirmation history.',
      ),
      const SizedBox(height: 18),
      _panel('Upcoming consultations', _consultationRows()),
      const SizedBox(height: 18),
      _panel(
        'Awaiting your confirmation',
        Column(
          children: [
            _confirmLessonRow(
              'USA admissions · Aruzhan N.',
              '28 Oct · 16:00',
              confirmable: true,
            ),
            _confirmLessonRow(
              'Founder strategy · Aigerim S.',
              '25 Oct · 15:00',
              confirmable: true,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _mentorContent() => switch (_section) {
    'My students' => _mentorStudentsPage(),
    'My lessons' => _mentorLessonsPage(),
    'My earnings' => _earningsPage(),
    _ => _mentorDashboard(),
  };

  Widget _mentorDashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Welcome back, Aruzhan',
        'Here are your students and upcoming sessions.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _metric(
            'My students',
            '08',
            'USA admissions',
            Icons.groups_2_outlined,
            const Color(0xFFEEF2FF),
            _blue,
          ),
          _metric(
            'This week',
            '05',
            'Upcoming sessions',
            Icons.event_outlined,
            const Color(0xFFE8F8F3),
            _teal,
          ),
          _metric(
            'Awaiting confirmation',
            '02',
            'Student response needed',
            Icons.fact_check_outlined,
            const Color(0xFFFFF4E5),
            const Color(0xFFD88924),
          ),
          _metric(
            'Confirmed earnings',
            '₸60K',
            '12 completed lessons',
            Icons.payments_outlined,
            const Color(0xFFF2EDFF),
            const Color(0xFF7956D8),
          ),
        ],
      ),
      const SizedBox(height: 22),
      _responsivePair(
        _panel('Upcoming consultations', _consultationRows()),
        _panel(
          'Follow up',
          Column(
            children: [
              _followup('Aruzhan K.', 'Review Common App essay before Friday'),
              _followup('Daniyar S.', 'Share US admissions checklist'),
              _followup('Alikhan T.', 'Discuss unconditional offer status'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      _panel('My students', _studentRows(compact: true)),
    ],
  );

  Widget _mentorStudentsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'My students',
        'Only students assigned to your admissions specialization.',
      ),
      const SizedBox(height: 18),
      _panel('Assigned · 8', _studentRows()),
    ],
  );
  Widget _mentorLessonsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'My lessons',
        'Mark a session as delivered, then the student confirms it.',
      ),
      const SizedBox(height: 18),
      _panel(
        'Scheduled and awaiting confirmation',
        Column(
          children: [
            _confirmLessonRow(
              'Aruzhan K. · Common App strategy',
              'Today · 16:00',
              confirmable: false,
            ),
            _confirmLessonRow(
              'Daniyar S. · US university shortlist',
              'Tomorrow · 17:30',
              confirmable: false,
            ),
            _confirmLessonRow(
              'Alikhan T. · Decision review',
              '28 Oct · 14:00',
              confirmable: false,
            ),
          ],
        ),
      ),
    ],
  );
  Widget _earningsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'My earnings',
        'Compensation is counted after the student confirms a delivered consultation.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _metric(
            'Confirmed',
            '₸60,000',
            '12 lessons × ₸5,000',
            Icons.verified_outlined,
            const Color(0xFFE8F8F3),
            _teal,
          ),
          _metric(
            'Pending confirmation',
            '₸10,000',
            '2 lessons awaiting students',
            Icons.pending_outlined,
            const Color(0xFFFFF4E5),
            const Color(0xFFD88924),
          ),
          _metric(
            'Paid to date',
            '₸45,000',
            '9 lessons paid',
            Icons.account_balance_wallet_outlined,
            const Color(0xFFEEF2FF),
            _blue,
          ),
        ],
      ),
      const SizedBox(height: 18),
      _panel(
        'Payment history',
        Column(
          children: [
            _financialRow('October payout', '₸30,000', 'Paid · 20 Oct'),
            _financialRow('September payout', '₸15,000', 'Paid · 30 Sep'),
          ],
        ),
      ),
    ],
  );

  Widget _opportunitiesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Opportunities',
        'Scholarships, competitions and programs with source links.',
      ),
      const SizedBox(height: 18),
      _panel(
        'Matched opportunities',
        _opportunityRows(student: _role == OrtaRole.student),
      ),
    ],
  );

  Widget _heading(String title, String subtitle, {Widget? action}) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 12,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 25,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
      ?action,
    ],
  );

  Widget _metric(
    String title,
    String value,
    String note,
    IconData icon,
    Color tint,
    Color color,
  ) => SizedBox(
    width: 220,
    child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: _muted, size: 19),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(note, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    ),
  );

  Widget _responsivePair(Widget left, Widget right) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 700
        ? Column(children: [left, const SizedBox(height: 16), right])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          ),
  );
  Widget _panel(String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _studentRows({bool compact = false}) => Column(
    children: [
      for (final student in _students.take(compact ? 3 : 4))
        _studentLine(
          student.name,
          '${student.grade} · ORTA ${student.program}',
          student.targets,
          student.progress,
          student.next,
        ),
    ],
  );
  Widget _studentLine(
    String name,
    String program,
    String targets,
    int progress,
    String next,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFFEEF2FF),
          child: Text(
            name.characters.first,
            style: const TextStyle(color: _blue, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$program · $targets',
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
              if (next.isNotEmpty)
                Text(next, style: const TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$progress%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: progress / 100,
                minHeight: 5,
                color: _blue,
                backgroundColor: const Color(0xFFE9EDF5),
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _deadlinesPanel() => _panel(
    'Upcoming deadlines',
    Column(
      children: [
        _deadline(
          'NOV',
          '07',
          'University of Toronto',
          'Aruzhan K. · Early application',
          const Color(0xFFFFF2E4),
        ),
        _deadline(
          'NOV',
          '12',
          'SAT registration',
          'Daniyar S. · Test deadline',
          const Color(0xFFEAF8F4),
        ),
        _deadline(
          'DEC',
          '01',
          'University of Hong Kong',
          'Aruzhan K. · Application',
          const Color(0xFFEEF2FF),
        ),
      ],
    ),
  );
  Widget _deadline(
    String month,
    String day,
    String title,
    String note,
    Color tint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      children: [
        Container(
          width: 42,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Text(
                month,
                style: const TextStyle(
                  fontSize: 8,
                  color: _muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                day,
                style: const TextStyle(
                  fontSize: 15,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(note, style: const TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _consultationRows() => Column(
    children: [
      _consultation(
        '16:00',
        'Aruzhan K. · Common App strategy',
        'USA mentor · Online',
        'Today',
      ),
      _consultation(
        '17:30',
        'Daniyar S. · University shortlist',
        'China mentor · Online',
        'Today',
      ),
      _consultation(
        '14:00',
        'Alikhan T. · Admissions decision review',
        'Founder · Offline, Aktau',
        'Tomorrow',
      ),
    ],
  );
  Widget _consultation(String time, String title, String detail, String date) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: const TextStyle(
                color: _blue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$detail · $date',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _attentionPanel() => _panel(
    'Needs your attention',
    Column(
      children: [
        _attention(
          Icons.error_outline,
          '1 student is behind schedule',
          'Daniyar · IELTS diagnostic overdue',
          const Color(0xFFD55D6A),
        ),
        _attention(
          Icons.verified_user_outlined,
          'Offer needs verification',
          'Alikhan · Unconditional offer submitted',
          _blue,
        ),
        _attention(
          Icons.currency_exchange,
          'Refund request received',
          'Mira · Review delivered services',
          const Color(0xFFD88924),
        ),
      ],
    ),
  );
  Widget _attention(IconData icon, String title, String detail, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _mentorCard(
    String name,
    String area,
    String students,
    String workload,
    IconData icon,
  ) => SizedBox(
    width: 280,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEEF2FF),
            child: Icon(icon, color: _blue),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          Text(area, style: const TextStyle(fontSize: 11, color: _muted)),
          const Divider(height: 22),
          Text(students, style: const TextStyle(fontSize: 11, color: _ink)),
          const SizedBox(height: 5),
          Text(workload, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    ),
  );

  Widget _financialRow(String title, String value, String status) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              Text(status, style: const TextStyle(color: _muted, fontSize: 10)),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _universityRow(
    String name,
    String detail,
    String deadline,
    String requirements,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.account_balance_outlined,
            color: _blue,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(detail, style: const TextStyle(color: _muted, fontSize: 10)),
              Text(
                '$deadline · $requirements',
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _notice(
            'Preview only: verified university source links are not connected yet.',
          ),
          icon: const Icon(Icons.open_in_new, size: 17, color: _muted),
        ),
      ],
    ),
  );

  Widget _applicationRow(String university, String status, String detail) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: _blue, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    university,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            _statusChip(status),
          ],
        ),
      );

  Widget _statusChip(String status) {
    final color = status == 'Submitted' || status == 'Confirmed'
        ? _teal
        : status == 'In preparation'
        ? _blue
        : const Color(0xFFD88924);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _opportunityRows({required bool student}) => Column(
    children: [
      _opportunity(
        'Lester B. Pearson Scholarship',
        'University of Toronto · Canada',
        'Deadline 7 Nov · Fully funded',
        'Strong match: academic record and leadership',
        student,
      ),
      _opportunity(
        'Huawei Seeds for the Future',
        'Huawei · Kazakhstan',
        'Deadline 18 Nov · No fee',
        'Suggested based on your technology interests',
        student,
      ),
      _opportunity(
        'Asia-Pacific Youth Innovation Challenge',
        'Youth program · Online',
        'Deadline 2 Dec · No fee',
        'Eligibility needs review · source linked',
        student,
      ),
    ],
  );
  Widget _opportunity(
    String title,
    String org,
    String deadline,
    String match,
    bool student,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8F3),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.stars_outlined, color: _teal, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(org, style: const TextStyle(color: _muted, fontSize: 10)),
              Text(
                deadline,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Text(match, style: const TextStyle(color: _teal, fontSize: 10)),
              Text(
                'Sample listing · source not verified',
                style: TextStyle(
                  color: _blue.withValues(alpha: .9),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        if (!student)
          IconButton(
            onPressed: () =>
                _notice('Opportunity assignment form is ready to connect.'),
            icon: const Icon(Icons.person_add_alt, color: _blue, size: 18),
          ),
      ],
    ),
  );

  Widget _confirmLessonRow(
    String title,
    String date, {
    required bool confirmable,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.video_call_outlined, color: _blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(date, style: const TextStyle(color: _muted, fontSize: 10)),
            ],
          ),
        ),
        if (confirmable)
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => _notice(
                  'Preview only: confirmation and earnings are not saved.',
                ),
                child: const Text('Confirm', style: TextStyle(fontSize: 10)),
              ),
              TextButton(
                onPressed: () => _notice(
                  'Preview only: dispute review is not connected to saved records.',
                ),
                child: const Text(
                  'Dispute',
                  style: TextStyle(fontSize: 10, color: Colors.redAccent),
                ),
              ),
            ],
          )
        else
          TextButton(
            onPressed: () =>
                _notice('Preview only: completion status is not saved.'),
            child: const Text('Mark complete', style: TextStyle(fontSize: 10)),
          ),
      ],
    ),
  );

  Widget _followup(String name, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      children: [
        const Icon(Icons.arrow_right_alt, color: _blue, size: 18),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(text, style: const TextStyle(color: _muted, fontSize: 10)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
    ),
  );
  Widget _actionButton(String text, IconData icon, VoidCallback onPressed) =>
      FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(text),
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      );
  void _notice(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );

  IconData _iconFor(String title) => switch (title) {
    'Overview' || 'Dashboard' => Icons.grid_view_rounded,
    'Students' || 'My students' => Icons.groups_2_outlined,
    'Mentors' => Icons.school_outlined,
    'Finance' || 'My earnings' => Icons.account_balance_wallet_outlined,
    'Opportunities' => Icons.auto_awesome_outlined,
    'Universities' => Icons.account_balance_outlined,
    'Applications' => Icons.description_outlined,
    'Progress' => Icons.trending_up_rounded,
    'Lessons' || 'My lessons' => Icons.event_note_outlined,
    'Language ORTA' => Icons.translate_rounded,
    _ => Icons.circle_outlined,
  };
}

class _DemoStudent {
  const _DemoStudent(
    this.name,
    this.grade,
    this.program,
    this.targets,
    this.progress,
    this.next,
  );
  final String name, grade, program, targets, next;
  final int progress;
}
