import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../models/life_context.dart';
import '../../models/orta_models.dart';
import '../../models/user_profile.dart';
import '../../services/localization_service.dart';
import '../../services/orta_agent_service.dart';
import '../../services/agent_config.dart';
import '../../services/remote_orta_agent_service.dart';
import '../../services/orta_localization.dart';
import '../../services/voice_input_service.dart';
import '../../services/orta_realtime_voice_service.dart';
import '../../widgets/language_selector.dart';
import '../language_orta/language_orta_screen.dart';

class OrtaShell extends StatefulWidget {
  final LifeContext lifeContext;
  final ValueChanged<LifeContext> onContextChanged;
  final VoidCallback onResetOnboarding;
  final AppLocale currentLocale;

  const OrtaShell({
    super.key,
    required this.lifeContext,
    required this.onContextChanged,
    required this.onResetOnboarding,
    required this.currentLocale,
  });

  @override
  State<OrtaShell> createState() => _OrtaShellState();
}

class _OrtaShellState extends State<OrtaShell> {
  int _index = 0;
  bool _languageMode = false;
  String? _selectedLanguageCode;
  late LifeContext _context;
  final List<CalendarItem> _plan = [];
  final List<String> _progress = [];
  final Map<String, List<LifeMapCategory>> _languageMaps = {};
  final Map<String, List<LanguageMemory>> _languageMemories = {};

  @override
  void initState() {
    super.initState();
    _context = widget.lifeContext;
  }

  String _label(String key) {
    const values = {
      'home': ['HOME', 'ГЛАВНАЯ', 'БАСТЫ БЕТ'],
      'plan': ['PLAN', 'ПЛАН', 'ЖОСПАР'],
      'life': ['LIFE', 'ЖИЗНЬ', 'ӨМІР'],
      'progress': ['PROGRESS', 'ПРОГРЕСС', 'ПРОГРЕСС'],
    };
    final index = widget.currentLocale == AppLocale.russian
        ? 1
        : widget.currentLocale == AppLocale.kazakh
        ? 2
        : 0;
    return values[key]![index];
  }

  AgentContext get _agentContext => AgentContext(
    currentScreen: _label(['home', 'plan', 'life', 'progress'][_index]),
    visibleSection: _index == 0 ? 'What matters now' : null,
    relevantLifeContext: _context,
  );

  void _applyAgentAction(AgentAction action) {
    final name = action.arguments['name'] as String? ?? 'Exam';
    final date = action.arguments['date'] as String? ?? 'Date to be confirmed';
    final isPlan = action.type == 'proposeStudyPlan';
    final exam = ExamContext(
      id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      date: date,
      importance: 'low',
      preparationWanted: isPlan,
    );
    setState(() {
      _context = _context.copyWith(exams: [..._context.exams, exam]);
      _plan.add(CalendarItem(title: name, date: date, category: 'Exam'));
      if (isPlan) {
        _plan.add(
          CalendarItem(
            title: '$name preparation',
            date: date,
            category: 'Preparation',
          ),
        );
      }
      _progress.insert(0, '$name added to your ORTA');
    });
    widget.onContextChanged(_context);
  }

  void _openAgent() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentSheet(
        contextData: _agentContext,
        onAction: _applyAgentAction,
        agentService: useRemoteOrtaAgent
            ? RemoteOrtaAgentService()
            : MockOrtaAgentService(),
      ),
    );
  }

  void _addLifeArea() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            for (final area in LifeArea.values)
              ListTile(
                title: Text(ortaLocalizations(context).lifeDomain(area.name)),
                trailing: _context.hasArea(area)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  setState(() {
                    final areas = {..._context.currentLifeAreas, area};
                    _context = _context.copyWith(currentLifeAreas: areas);
                  });
                  widget.onContextChanged(_context);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_languageMode) {
      return LanguageOrtaScreen(
        userProfile: _languageProfile(
          _selectedLanguageCode ?? _context.languages.first.languageCode,
        ),
        languageCode:
            _selectedLanguageCode ?? _context.languages.first.languageCode,
        lifeMap:
            _languageMaps[_selectedLanguageCode ??
                _context.languages.first.languageCode] ??
            const [],
        memories:
            _languageMemories[_selectedLanguageCode ??
                _context.languages.first.languageCode] ??
            const [],
        onAddMemory: (phrase) {
          final code =
              _selectedLanguageCode ?? _context.languages.first.languageCode;
          setState(
            () => _languageMemories[code] = [
              ...(_languageMemories[code] ?? []),
              LanguageMemory(
                title: 'Moment',
                context: 'Real life',
                phrase: phrase,
                meaning: 'Saved in this language space.',
                language: code,
              ),
            ],
          );
        },
        onBack: () => setState(() => _languageMode = false),
        currentLocale: widget.currentLocale,
      );
    }
    final screens = [
      HomeView(lifeContext: _context, plan: _plan),
      PlanView(items: _plan),
      LifeView(
        lifeContext: _context,
        onAddArea: _addLifeArea,
        onAddLanguage: _addLanguage,
        onOpenLanguage: _context.languages.isEmpty
            ? null
            : () => setState(() {
                _selectedLanguageCode = _context.languages.first.languageCode;
                _languageMode = true;
              }),
        onSelectLanguage: (code) => setState(() {
          _selectedLanguageCode = code;
          _languageMode = true;
        }),
        onReset: widget.onResetOnboarding,
      ),
      ProgressView(items: _progress),
    ];
    return Scaffold(
      body: Stack(
        children: [
          screens[_index],
          Positioned(
            right: 18,
            bottom: 18,
            child: AgentButton(onPressed: _openAgent),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: _label('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: _label('plan'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_tree_outlined),
            selectedIcon: const Icon(Icons.account_tree),
            label: _label('life'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: _label('progress'),
          ),
        ],
      ),
    );
  }

  UserProfile _languageProfile(String code) => UserProfile(
    name: _context.name,
    nativeLanguage: _context.interfaceLanguage,
    learningLanguage: LanguageExtension.fromCode(code),
    level: LanguageLevelExtension.fromString(_context.languages.first.level),
    wakeUpTime: '08:00',
    sleepTime: '22:00',
  );

  void _addLanguage() {
    showDialog<String>(
      context: context,
      builder: (_) => const LanguageSelectorDialog(),
    ).then((code) {
      if (!mounted ||
          code == null ||
          _context.languages.any((item) => item.languageCode == code)) {
        return;
      }
      final next = _context.copyWith(
        languages: [
          ..._context.languages,
          LanguageContext(languageCode: code, reason: 'Personal goal'),
        ],
      );
      setState(() => _context = next);
      widget.onContextChanged(next);
    });
  }
}

class CalendarItem {
  final String title;
  final String date;
  final String category;
  final String startTime;
  final String? endTime;
  final bool isFreeWindow;
  const CalendarItem({
    required this.title,
    required this.date,
    required this.category,
    this.startTime = '09:00',
    this.endTime,
    this.isFreeWindow = false,
  });
}

class HomeView extends StatelessWidget {
  final LifeContext lifeContext;
  final List<CalendarItem> plan;
  const HomeView({super.key, required this.lifeContext, required this.plan});

  @override
  Widget build(BuildContext context) {
    final nextGoal = lifeContext.goals.isEmpty ? null : lifeContext.goals.first;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          Text(
            'Good to see you, ${lifeContext.name}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'ORTA is shaping today around what matters to you.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'What matters now',
            child: nextGoal == null
                ? const Text(
                    'Add a goal in LIFE and ORTA will suggest a next step.',
                  )
                : Text(
                    ortaLocalizations(context).goal(nextGoal.titleKey),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (lifeContext.exams.isNotEmpty)
            _SectionCard(
              title: 'Upcoming exams',
              child: Text(
                lifeContext.exams
                    .map(
                      (exam) => '${exam.name} · ${exam.date ?? 'date unknown'}',
                    )
                    .join('\n'),
              ),
            ),
          if (lifeContext.projects.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Projects',
              child: Text(
                lifeContext.projects.map((project) => project.name).join('\n'),
              ),
            ),
          ],
          if (lifeContext.languages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Language practice',
              child: Text(
                lifeContext.languages
                    .map(
                      (language) =>
                          '${language.definition.englishName} · ${language.level.isEmpty ? 'level unknown' : language.level}',
                    )
                    .join('\n'),
              ),
            ),
          ],
          if (plan.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Next on your plan',
              child: Text(plan.first.title),
            ),
          ],
        ],
      ),
    );
  }
}

class PlanView extends StatefulWidget {
  final List<CalendarItem> items;
  const PlanView({super.key, required this.items});
  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  bool _week = false;
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        Text(
          AppLocalizations.of(context).ui('plan'),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your schedule grows from your real context.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(AppLocalizations.of(context).ui('day')),
            ),
            ButtonSegment(
              value: true,
              label: Text(AppLocalizations.of(context).ui('week')),
            ),
          ],
          selected: {_week},
          onSelectionChanged: (value) => setState(() => _week = value.first),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => ChoiceChip(
              label: Text(
                [
                  'Mon 14',
                  'Tue 15',
                  'Wed 16',
                  'Thu 17',
                  'Fri 18',
                  'Sat 19',
                  'Sun 20',
                ][index],
              ),
              selected: _selectedDay == index,
              onSelected: (_) => setState(() => _selectedDay = index),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _week
              ? AppLocalizations.of(context).ui('week')
              : AppLocalizations.of(context).ui('timeline'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.items.isEmpty)
          const _EmptyState(
            text: 'Your plan is clear for now. Ask ORTA to add an action.',
          ),
        ...widget.items.map(
          (item) => InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(item.title),
                content: Text(
                  '${item.startTime}${item.endTime == null ? '' : '–${item.endTime}'} · ${item.category}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    item.startTime,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: item.isFreeWindow ? Colors.teal.shade50 : null,
                    child: ListTile(
                      title: Text(item.title),
                      subtitle: Text('${item.date} · ${item.category}'),
                      leading: Icon(
                        item.isFreeWindow
                            ? Icons.free_breakfast
                            : Icons.event_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class LifeView extends StatelessWidget {
  final LifeContext lifeContext;
  final VoidCallback onAddArea;
  final VoidCallback onAddLanguage;
  final VoidCallback? onOpenLanguage;
  final ValueChanged<String> onSelectLanguage;
  final VoidCallback onReset;
  const LifeView({
    super.key,
    required this.lifeContext,
    required this.onAddArea,
    required this.onAddLanguage,
    required this.onOpenLanguage,
    required this.onSelectLanguage,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        const Text(
          'LIFE',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'This is what ORTA currently understands.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Current life',
          child: Text(
            lifeContext.currentLifeAreas.isEmpty
                ? 'No areas added yet.'
                : lifeContext.currentLifeAreas
                      .map(
                        (area) =>
                            ortaLocalizations(context).lifeDomain(area.name),
                      )
                      .join('\n'),
          ),
        ),
        if (lifeContext.goals.isNotEmpty)
          _SectionCard(
            title: 'Goals',
            child: Text(
              lifeContext.goals
                  .map((goal) => ortaLocalizations(context).goal(goal.titleKey))
                  .join('\n'),
            ),
          ),
        if (lifeContext.universityPlans.isNotEmpty)
          _SectionCard(
            title: 'Universities',
            child: Text(
              '${lifeContext.universityPlans.length} in your shortlist',
            ),
          ),
        if (lifeContext.career != null)
          _SectionCard(
            title: 'Career',
            child: Text(
              [lifeContext.career!.role, lifeContext.career!.desiredDirection]
                  .whereType<String>()
                  .where((item) => item.isNotEmpty)
                  .join(' -> '),
            ),
          ),
        if (lifeContext.exams.isNotEmpty)
          _SectionCard(
            title: 'Exams',
            child: Text(lifeContext.exams.map((exam) => exam.name).join('\n')),
          ),
        if (lifeContext.languages.isNotEmpty)
          _SectionCard(
            title: 'Languages',
            child: Column(
              children: lifeContext.languages
                  .map(
                    (language) => ListTile(
                      title: Text(language.definition.englishName),
                      subtitle: Text(
                        language.level.isEmpty
                            ? 'Level unknown'
                            : language.level,
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => onSelectLanguage(language.languageCode),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAddArea,
          icon: const Icon(Icons.add),
          label: const Text('Add life area'),
        ),
        OutlinedButton.icon(
          onPressed: onAddLanguage,
          icon: const Icon(Icons.language),
          label: const Text('Add language goal'),
        ),
        if (onOpenLanguage != null)
          OutlinedButton.icon(
            onPressed: onOpenLanguage,
            icon: const Icon(Icons.language),
            label: const Text('Open Language ORTA'),
          ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Reset ORTA?'),
                content: const Text(
                  'This clears the local LifeContext and returns to onboarding.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            );
            if (confirmed == true) onReset();
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset ORTA'),
        ),
      ],
    ),
  );
}

class ProgressView extends StatelessWidget {
  final List<String> items;
  const ProgressView({super.key, required this.items});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        const Text(
          'PROGRESS',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          const _EmptyState(text: 'Completed actions will appear here.'),
        ...items.map(
          (item) => ListTile(
            leading: const Icon(
              Icons.check_circle_outline,
              color: AppTheme.primaryColor,
            ),
            title: Text(item),
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    ),
  );
}

class AgentButton extends StatelessWidget {
  final VoidCallback onPressed;
  const AgentButton({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    onPressed: onPressed,
    heroTag: 'orta_agent',
    icon: const Icon(Icons.auto_awesome),
    label: const Text('ORTA'),
  );
}

class AgentSheet extends StatefulWidget {
  final AgentContext contextData;
  final ValueChanged<AgentAction> onAction;
  final OrtaAgentService agentService;
  const AgentSheet({
    super.key,
    required this.contextData,
    required this.onAction,
    required this.agentService,
  });
  @override
  State<AgentSheet> createState() => _AgentSheetState();
}

class _AgentSheetState extends State<AgentSheet> {
  final _controller = TextEditingController();
  late final OrtaAgentService _service = widget.agentService;
  final List<AgentMessage> _messages = const [
    AgentMessage(
      text:
          'I am here with the context of this screen. What should we work on?',
      isUser: false,
    ),
  ].toList();
  AgentDraft _draft = const AgentDraft();
  ActionProposal? _proposal;
  bool _sending = false;
  String? _error;
  bool _expanded = false;
  final VoiceInputService _voiceInput = PrototypeVoiceInputService();

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AgentMessage(text: text, isUser: true));
    });
    try {
      final result = await _service.respond(
        text,
        widget.contextData,
        _draft,
        conversation: _messages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          AgentMessage(
            text: result.response,
            isUser: false,
            proposal: result.proposal,
          ),
        );
        _draft = result.draft;
        _proposal = result.proposal;
        _sending = false;
      });
    } on RemoteAgentException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'ORTA could not connect right now. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * (_expanded ? .92 : .42),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ORTA Agent',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded ? Icons.unfold_less : Icons.open_in_full,
                        ),
                        tooltip: _expanded ? 'Collapse' : 'Expand',
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OrtaVoiceScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.call_outlined),
                        tooltip: 'Voice prototype',
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    widget.contextData.currentScreen,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: _messages
                          .map(
                            (message) => Align(
                              alignment: message.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: message.isUser
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  message.text,
                                  style: TextStyle(
                                    color: message.isUser
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (_sending)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_proposal != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _proposal!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_proposal!.description),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                widget.onAction(_proposal!.action);
                                setState(() => _proposal = null);
                              },
                              child: const Text('CONFIRM'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Ask ORTA',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send),
                      ),
                      IconButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final result = await _voiceInput.startListening();
                          if (!mounted) return;
                          if (result == null) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Voice input is not connected in this prototype.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.mic_none),
                        tooltip: 'Voice input',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class OrtaVoiceScreen extends StatelessWidget {
  const OrtaVoiceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final voiceService = PrototypeRealtimeVoiceService();
    return Scaffold(
      appBar: AppBar(title: const Text('ORTA')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.graphic_eq,
              size: 72,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ready',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Realtime voice is not connected in this prototype (${voiceService.state.name}).',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.call_end),
              label: const Text('End call'),
            ),
          ],
        ),
      ),
    );
  }
}
