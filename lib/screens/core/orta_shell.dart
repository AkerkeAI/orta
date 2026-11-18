import '../../models/life_data.dart';
import '../../services/scheduling_engine.dart';
import '../../services/planning_strings.dart';
import '../../widgets/planning_views.dart';
import '../../widgets/scheduling_preferences_dialog.dart';
import '../../services/ai_actions.dart';
import '../../services/action_agent.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../services/product_strings.dart';

import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../models/life_context.dart';
import '../../services/life_repository.dart';
import '../../services/agent_context_builder.dart';
import '../../services/life_data_strings.dart';
import '../../widgets/life_record_dialog.dart';
import '../../models/orta_models.dart';
import '../../models/user_profile.dart';
import '../../services/localization_service.dart';
import '../../services/orta_agent_service.dart';
import '../../services/agent_config.dart';
import '../../services/remote_orta_agent_service.dart';
import '../../services/orta_localization.dart';
import '../../widgets/language_selector.dart';
import '../language_orta/language_orta_screen.dart';

class OrtaShell extends StatefulWidget {
  final LifeRepository repository;
  final VoidCallback onResetOnboarding;
  final AppLocale currentLocale;

  const OrtaShell({
    super.key,
    required this.repository,
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
  LifeContext get _context => widget.repository.lifeView;
  List<CalendarItem> get _plan =>
      AgentContextBuilder.plan(widget.repository.data)
          .map(
            (item) => CalendarItem(
              id: item.id,
              kind: item.kind,
              title: item.title,
              date:
                  item.date ??
                  lifeDataText(_context.interfaceLanguage, 'unknownDate'),
              category: item.category,
              startTime: item.startTime ?? '',
              endTime: item.endTime,
            ),
          )
          .toList();
  List<String> get _progress => [
    ...widget.repository.data.completedTasks.map(
      (t) =>
          '${t.title} · ${planningDate(_context.interfaceLanguage, SchedulingEngine(widget.repository.data, nowOverride: t.completedAt).today)}',
    ),
    ...widget.repository.data.events
        .where((e) => e.completedAt != null)
        .map(
          (e) =>
              '${e.title} · ${planningDate(_context.interfaceLanguage, SchedulingEngine(widget.repository.data, nowOverride: e.completedAt).today)}',
        ),
  ];

  Future<void> _save(Future<void> Function() change) async {
    try {
      await change();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lifeDataText(_context.interfaceLanguage, 'error')),
          ),
        );
      }
    }
  }

  Future<void> _addRecord([String type = 'exam']) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          LifeRecordDialog(repository: widget.repository, initialType: type),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lifeDataText(_context.interfaceLanguage, 'saved')),
        ),
      );
    }
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

  AgentContext _agentContext({String? type, String? id}) =>
      AgentContextBuilder.build(
        widget.repository.data,
        screen: ['home', 'plan', 'life', 'progress'][_index],
        entityType: type,
        entityId: id,
      );

  void _openAgent({String? type, String? id}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentSheet(
        repository: widget.repository,
        contextBuilder: () => _agentContext(type: type, id: id),
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
                onTap: () async {
                  await _save(
                    () => widget.repository.updateLife(
                      (life) => life.copyWith(
                        currentLifeAreas: {...life.currentLifeAreas, area},
                      ),
                    ),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
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
        lifeMap: widget.repository
            .languageProgress(
              _selectedLanguageCode ?? _context.languages.first.languageCode,
            )
            .lifeMap,
        memories: widget.repository
            .languageProgress(
              _selectedLanguageCode ?? _context.languages.first.languageCode,
            )
            .memories,
        completedSessions: widget.repository
            .languageProgress(
              _selectedLanguageCode ?? _context.languages.first.languageCode,
            )
            .completedSessions,
        languageLevel: widget.repository
            .languageProgress(
              _selectedLanguageCode ?? _context.languages.first.languageCode,
            )
            .level,
        lifeContext: _context,
        practiceHistory: widget.repository
            .languageProgress(
              _selectedLanguageCode ?? _context.languages.first.languageCode,
            )
            .practiceHistory,
        onSavePractice: (code, topicKey, response) => widget.repository
            .recordPractice(code, topicKey: topicKey, response: response),
        onAddMemory: (phrase) => widget.repository.addLanguageMoment(
          _selectedLanguageCode ?? _context.languages.first.languageCode,
          phrase,
        ),
        onBack: () => setState(() => _languageMode = false),
        currentLocale: widget.currentLocale,
      );
    }
    final screens = [
      HomeView(
        lifeContext: _context,
        plan: _plan,
        data: widget.repository.data,
        onSelectEntity: (type, id) => _openAgent(type: type, id: id),
      ),
      PlanView(
        data: widget.repository.data,
        onPreferences: () => showDialog<void>(
          context: context,
          builder: (_) =>
              SchedulingPreferencesDialog(repository: widget.repository),
        ),
        onCompleteSession: (id, completed) =>
            _save(() => widget.repository.completeSession(id, completed)),
        items: _plan,
        tasks: widget.repository.data.tasks,
        language: _context.interfaceLanguage,
        onCompleteTask: (id, completed) =>
            _save(() => widget.repository.completeTask(id, completed)),
        onAddTask: () => _addRecord('task'),
        onSelectEntity: (type, id) => _openAgent(type: type, id: id),
      ),
      LifeView(
        lifeContext: _context,
        onAddArea: _addLifeArea,
        onAddRecord: () => _addRecord(),
        onSelectEntity: (type, id) => _openAgent(type: type, id: id),
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
      ProgressView(items: _progress, language: _context.interfaceLanguage),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 40,
        actions: [
          IconButton(
            tooltip: productText(_context.interfaceLanguage, 'settings'),
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
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

  Future<void> _openSettings() async {
    final language = _context.interfaceLanguage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(productText(language, 'settings')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(productText(language, 'interfaceLanguage')),
              for (final choice in Language.values)
                ListTile(
                  title: Text(choice.displayName),
                  trailing: choice == _context.interfaceLanguage
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    await _save(
                      () => widget.repository.updateLife(
                        (life) => life.copyWith(interfaceLanguage: choice),
                      ),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              Text(productText(language, 'privacy')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(productText(language, 'close')),
          ),
        ],
      ),
    );
  }

  UserProfile _languageProfile(String code) => UserProfile(
    name: _context.name,
    nativeLanguage: _context.interfaceLanguage,
    learningLanguage: LanguageExtension.fromCode(code),
    level: LanguageLevelExtension.fromString(
      widget.repository.languageProgress(code).level,
    ),
    wakeUpTime: _context.preferences['wakeUpTime'] ?? '',
    sleepTime: _context.preferences['sleepTime'] ?? '',
  );

  void _addLanguage() {
    showDialog<String>(
      context: context,
      builder: (_) => LanguageSelectorDialog(locale: widget.currentLocale),
    ).then((code) {
      if (!mounted ||
          code == null ||
          _context.languages.any((item) => item.languageCode == code)) {
        return;
      }
      _save(
        () => widget.repository.updateLife(
          (life) => life.copyWith(
            languages: [
              ...life.languages,
              LanguageContext(languageCode: code),
            ],
          ),
        ),
      );
    });
  }
}

class CalendarItem {
  final String? id;
  final String kind;
  final String title;
  final String date;
  final String category;
  final String startTime;
  final String? endTime;
  final bool isFreeWindow;
  const CalendarItem({
    this.id,
    this.kind = 'event',
    required this.title,
    required this.date,
    required this.category,
    this.startTime = '',
    this.endTime,
    this.isFreeWindow = false,
  });
}

class HomeView extends StatelessWidget {
  final LifeContext lifeContext;
  final List<CalendarItem> plan;
  final LifeData? data;
  final void Function(String, String)? onSelectEntity;
  const HomeView({
    super.key,
    required this.lifeContext,
    required this.plan,
    this.data,
    this.onSelectEntity,
  });

  @override
  Widget build(BuildContext context) {
    if (data != null) {
      return DailyOverview(data: data!, onSelect: onSelectEntity);
    }
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
              title: productText(lifeContext.interfaceLanguage, 'projects'),
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
  final List<Task> tasks;
  final LifeData? data;
  final VoidCallback? onPreferences;
  final Future<void> Function(String, bool)? onCompleteSession;
  final Language language;
  final Future<void> Function(String, bool)? onCompleteTask;
  final VoidCallback? onAddTask;
  final void Function(String, String)? onSelectEntity;
  const PlanView({
    super.key,
    required this.items,
    this.data,
    this.onPreferences,
    this.onCompleteSession,
    this.tasks = const [],
    this.language = Language.english,
    this.onCompleteTask,
    this.onAddTask,
    this.onSelectEntity,
  });
  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  @override
  Widget build(BuildContext context) => PlanningCalendar(
    data:
        widget.data ??
        LifeData(
          life: LifeContext(name: '', interfaceLanguage: widget.language),
          tasks: widget.tasks,
        ),
    onCompleteTask: widget.onCompleteTask,
    onCompleteSession: widget.onCompleteSession,
    onAddTask: widget.onAddTask,
    onPreferences: widget.onPreferences,
    onSelect: widget.onSelectEntity,
  );
}

class LifeView extends StatelessWidget {
  final LifeContext lifeContext;
  final VoidCallback onAddArea;
  final VoidCallback? onAddRecord;
  final void Function(String, String)? onSelectEntity;
  final VoidCallback onAddLanguage;
  final VoidCallback? onOpenLanguage;
  final ValueChanged<String> onSelectLanguage;
  final VoidCallback onReset;
  const LifeView({
    super.key,
    required this.lifeContext,
    required this.onAddArea,
    this.onAddRecord,
    this.onSelectEntity,
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
        Text(
          productText(lifeContext.interfaceLanguage, 'life'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          productText(lifeContext.interfaceLanguage, 'lifeIntro'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: productText(lifeContext.interfaceLanguage, 'currentLife'),
          child: Text(
            lifeContext.currentLifeAreas.isEmpty
                ? productText(lifeContext.interfaceLanguage, 'noAreas')
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
            title: productText(lifeContext.interfaceLanguage, 'goals'),
            child: Column(
              children: [
                for (final goal in lifeContext.goals)
                  ListTile(
                    title: Text(ortaLocalizations(context).goal(goal.titleKey)),
                    onTap: () => onSelectEntity?.call('goal', goal.id),
                  ),
              ],
            ),
          ),
        if (lifeContext.universityPlans.isNotEmpty)
          _SectionCard(
            title: productText(lifeContext.interfaceLanguage, 'universities'),
            child: Column(
              children: [
                for (final university in lifeContext.universityPlans)
                  ListTile(
                    title: Text(university.name),
                    subtitle: Text(
                      [
                        university.country,
                        university.program,
                      ].where((v) => v.isNotEmpty).join(' · '),
                    ),
                    onTap: () =>
                        onSelectEntity?.call('university', university.id),
                  ),
              ],
            ),
          ),
        if (lifeContext.career != null)
          _SectionCard(
            title: productText(lifeContext.interfaceLanguage, 'career'),
            child: Text(
              [lifeContext.career!.role, lifeContext.career!.desiredDirection]
                  .whereType<String>()
                  .where((item) => item.isNotEmpty)
                  .join(' -> '),
            ),
          ),
        if (lifeContext.projects.isNotEmpty)
          _SectionCard(
            title: productText(lifeContext.interfaceLanguage, 'projects'),
            child: Column(
              children: [
                for (final project in lifeContext.projects)
                  ListTile(
                    title: Text(project.name),
                    onTap: () => onSelectEntity?.call('project', project.id),
                  ),
              ],
            ),
          ),
        if (lifeContext.exams.isNotEmpty)
          _SectionCard(
            title: productText(lifeContext.interfaceLanguage, 'exams'),
            child: Column(
              children: [
                for (final exam in lifeContext.exams)
                  ListTile(
                    title: Text(exam.name),
                    subtitle: Text(
                      exam.date ??
                          lifeDataText(
                            lifeContext.interfaceLanguage,
                            'unknownDate',
                          ),
                    ),
                    onTap: () => onSelectEntity?.call('exam', exam.id),
                  ),
              ],
            ),
          ),
        if (lifeContext.languages.isNotEmpty)
          _SectionCard(
            title: productText(lifeContext.interfaceLanguage, 'languages'),
            child: Column(
              children: lifeContext.languages
                  .map(
                    (language) => ListTile(
                      title: Text(
                        ortaLocalizations(context)
                            .languageName(language.languageCode),
                      ),
                      subtitle: Text(
                        language.level.isEmpty
                            ? productText(
                                lifeContext.interfaceLanguage,
                                'unknownLevel',
                              )
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
        if (onAddRecord != null)
          OutlinedButton.icon(
            onPressed: onAddRecord,
            icon: const Icon(Icons.add),
            label: Text(lifeDataText(lifeContext.interfaceLanguage, 'add')),
          ),
        OutlinedButton.icon(
          onPressed: onAddArea,
          icon: const Icon(Icons.add),
          label: Text(productText(lifeContext.interfaceLanguage, 'addArea')),
        ),
        OutlinedButton.icon(
          onPressed: onAddLanguage,
          icon: const Icon(Icons.language),
          label: Text(
            productText(lifeContext.interfaceLanguage, 'addLanguage'),
          ),
        ),
        if (onOpenLanguage != null)
          OutlinedButton.icon(
            onPressed: onOpenLanguage,
            icon: const Icon(Icons.language),
            label: Text(
              productText(lifeContext.interfaceLanguage, 'openLanguage'),
            ),
          ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                  productText(lifeContext.interfaceLanguage, 'resetTitle'),
                ),
                content: Text(
                  productText(lifeContext.interfaceLanguage, 'resetBody'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      productText(lifeContext.interfaceLanguage, 'cancel'),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(
                      productText(lifeContext.interfaceLanguage, 'reset'),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true) onReset();
          },
          icon: const Icon(Icons.restart_alt),
          label: Text(productText(lifeContext.interfaceLanguage, 'reset')),
        ),
      ],
    ),
  );
}

class ProgressView extends StatelessWidget {
  final List<String> items;
  final Language language;
  const ProgressView({
    super.key,
    required this.items,
    this.language = Language.english,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        Text(
          planningText(language, 'progress'),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          _EmptyState(text: planningText(language, 'unknownProgress')),
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
  final AgentContext Function() contextBuilder;
  final LifeRepository repository;
  final OrtaAgentService agentService;
  const AgentSheet({
    super.key,
    required this.contextBuilder,
    required this.repository,
    required this.agentService,
  });
  @override
  State<AgentSheet> createState() => _AgentSheetState();
}

class _AgentSheetState extends State<AgentSheet> {
  final _controller = TextEditingController();
  late final OrtaAgentService _service = widget.agentService;
  ToolRegistry? _registry;
  List<AgentMessage> get _messages => widget.repository.data.conversation;
  List<ToolProposal> get _pending => widget.repository.data.currentProposals
      .where((p) => p.status == 'pending')
      .toList();
  Language get _language => widget.repository.data.life.interfaceLanguage;
  bool _sending = false, _expanded = false;
  String? _error, _failedText;
  AgentDraft _draft = const AgentDraft();

  @override
  void initState() {
    super.initState();
    _expanded = _pending.isNotEmpty;
    widget.repository.addListener(_refresh);
    ToolRegistry.load()
        .then((registry) {
          if (mounted) setState(() => _registry = registry);
        })
        .catchError((Object _) {
          /* A send retries loading and reports an error safely. */
        });
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        if (_pending.isNotEmpty) _expanded = true;
      });
    }
  }

  String _summary(ToolProposal p) =>
      _registry?.humanSummary(widget.repository.data, p.tool, p.arguments) ??
      p.summary;

  Future<void> _newConversation() async {
    if (_sending) return;
    try {
      await widget.repository.newConversation();
      _controller.clear();
      if (mounted) {
        setState(() {
          _draft = const AgentDraft();
          _error = null;
          _failedText = null;
          _expanded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = productText(_language, 'newChatError'));
      }
    }
  }

  Future<void> _history() async {
    if (_sending) return;
    final language = _language;
    final conversations = widget.repository.data.conversations.reversed
        .toList();
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(productText(language, 'history')),
        content: SizedBox(
          width: 420,
          height: 380,
          child: Column(
            children: [
              Text(productText(language, 'retention')),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (_, index) {
                    final conversation = conversations[index];
                    return ListTile(
                      title: Text(
                        conversation.title.isEmpty
                            ? productText(language, 'untitled')
                            : conversation.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: conversation.updatedAt == null
                          ? null
                          : Text(
                              planningDate(
                                language,
                                SchedulingEngine(
                                  widget.repository.data,
                                  nowOverride: conversation.updatedAt,
                                ).today,
                              ),
                            ),
                      trailing:
                          conversation.id ==
                              widget.repository.data.activeConversationId
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () =>
                          Navigator.pop(dialogContext, conversation.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(productText(language, 'close')),
          ),
        ],
      ),
    );
    if (id == null || !mounted) return;
    try {
      await widget.repository.resumeConversation(id);
      _controller.clear();
      if (mounted) {
        setState(() {
          _draft = const AgentDraft();
          _error = null;
          _failedText = null;
          _expanded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = productText(_language, 'newChatError'));
      }
    }
  }

  Future<void> _send({String? text, bool retry = false}) async {
    final message = (text ?? _controller.text).trim();
    if (message.isEmpty || _sending) return;
    if (message.length > 8000) {
      setState(() => _error = productText(_language, 'tooLong'));
      return;
    }
    final conversationId = widget.repository.data.activeConversationId;
    setState(() {
      _sending = true;
      _error = null;
      _failedText = null;
    });
    try {
      final last = _messages.lastOrNull;
      if (!retry || last?.isUser != true || last?.text != message) {
        await widget.repository.appendMessage(
          message,
          isUser: true,
          conversationId: conversationId,
        );
      }
      _controller.clear();
      if (widget.repository.data.activeConversationId != conversationId) return;
      final String response;
      if (_service is RemoteOrtaAgentService) {
        final registry = _registry ?? await ToolRegistry.load();
        _registry = registry;
        response = await ActionAgent(
          widget.repository,
          _service,
          registry,
        ).respond(message, widget.contextBuilder);
      } else {
        final result = await _service.respond(
          message,
          widget.contextBuilder(),
          _draft,
          conversation: _messages,
        );
        response = result.response;
        _draft = result.draft;
      }
      await widget.repository.appendMessage(
        response,
        isUser: false,
        conversationId: conversationId,
      );
    } on RemoteAgentException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _failedText = message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = lifeDataText(_language, 'chatSaveError');
          _failedText = message;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resolve(ToolProposal proposal, bool approve) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _failedText = null;
    });
    final conversationId = widget.repository.data.activeConversationId;
    Map<String, dynamic>? committed;
    try {
      final registry = _registry ?? await ToolRegistry.load();
      committed = await widget.repository.resolveAction(
        registry,
        proposal.id,
        approve: approve,
      );
      await widget.repository.appendMessage(
        ActionAgent.resultMessage(_language, committed),
        isUser: false,
        conversationId: conversationId,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = committed == null
              ? actionText(_language, 'retry')
              : ActionAgent.resultMessage(_language, committed),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resolveGroup(bool approve) async {
    if (_sending || _pending.isEmpty) return;
    final ids = _pending.map((p) => p.id).toList();
    final conversationId = widget.repository.data.activeConversationId;
    setState(() {
      _sending = true;
      _error = null;
      _failedText = null;
    });
    Map<String, dynamic>? committed;
    try {
      final registry = _registry ?? await ToolRegistry.load();
      committed = await widget.repository.resolveActions(
        registry,
        ids,
        approve: approve,
      );
      await widget.repository.appendMessage(
        ActionAgent.resultMessage(_language, committed),
        isUser: false,
        conversationId: conversationId,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = committed == null
              ? actionText(_language, 'retry')
              : ActionAgent.resultMessage(_language, committed),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _message(AgentMessage message) => Align(
    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      key: ValueKey(message.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isUser ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: message.isUser
          ? Text(message.text, style: const TextStyle(color: Colors.white))
          : MarkdownBody(
              data: message.text,
              selectable: true,
              fitContent: false,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: const TextStyle(
                      color: AppTheme.textPrimary,
                      height: 1.45,
                    ),
                  ),
              // Model-provided images never trigger network or local-file reads.
              imageBuilder: (_, _, alt) =>
                  Text(alt ?? productText(_language, 'imageOmitted')),
              onTapLink: (_, href, _) async {
                final uri = Uri.tryParse(href ?? '');
                final valid =
                    uri != null &&
                    ['https', 'http'].contains(uri.scheme) &&
                    uri.host.isNotEmpty &&
                    uri.userInfo.isEmpty;
                if (valid) {
                  await Clipboard.setData(ClipboardData(text: uri.toString()));
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        productText(
                          _language,
                          valid ? 'linkCopied' : 'linkUnavailable',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
    ),
  );
  Widget _proposal(ToolProposal proposal) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_summary(proposal)),
          if (proposal.expired(DateTime.now()))
            Text(planningText(_language, 'expired')),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _sending || proposal.expired(DateTime.now())
                    ? null
                    : () => _resolve(proposal, true),
                child: Text(actionText(_language, 'confirm')),
              ),
              TextButton(
                onPressed: _sending ? null : () => _resolve(proposal, false),
                child: Text(actionText(_language, 'cancel')),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _content(Object entry) {
    if (entry is AgentMessage) return _message(entry);
    if (entry is ToolProposal) return _proposal(entry);
    if (entry == 'loading') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(productText(_language, 'thinking')),
          ],
        ),
      );
    }
    if (entry == 'error') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_failedText != null)
              TextButton(
                onPressed: _sending
                    ? null
                    : () => _send(text: _failedText, retry: true),
                child: Text(productText(_language, 'retry')),
              ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      children: [
        ElevatedButton(
          onPressed: _sending ? null : () => _resolveGroup(true),
          child: Text(planningText(_language, 'approveAll')),
        ),
        TextButton(
          onPressed: _sending ? null : () => _resolveGroup(false),
          child: Text(planningText(_language, 'rejectAll')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final entries = <Object>[
      ..._messages,
      if (_sending) 'loading',
      if (_error != null) 'error',
      ..._pending,
      if (_pending.length > 1) 'group',
    ];
    final agentContext = widget.contextBuilder();
    final rawSelectedTitle =
        agentContext.visibleData['selectedEntityTitle'] as String?;
    final selectedTitle =
        rawSelectedTitle != null && agentContext.currentEntityType == 'goal'
        ? AppLocalizations(AppLocaleExtension.fromLanguage(_language))
              .goal(rawSelectedTitle)
        : rawSelectedTitle;
    final screen =
        [
          'home',
          'life',
          'plan',
          'progress',
        ].contains(agentContext.currentScreen)
        ? agentContext.currentScreen
        : 'home';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            height:
                MediaQuery.sizeOf(context).height *
                (_expanded || keyboard ? .94 : .52),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ORTA',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: productText(_language, 'newChat'),
                        onPressed: _sending ? null : _newConversation,
                        icon: const Icon(Icons.add_comment_outlined),
                      ),
                      IconButton(
                        tooltip: productText(_language, 'history'),
                        onPressed: _sending ? null : _history,
                        icon: const Icon(Icons.history),
                      ),
                      IconButton(
                        tooltip: productText(
                          _language,
                          _expanded ? 'collapse' : 'expand',
                        ),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded ? Icons.unfold_less : Icons.open_in_full,
                        ),
                      ),
                      IconButton(
                        tooltip: productText(_language, 'close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    productText(
                      _language,
                      'viewing',
                      name: selectedTitle ?? productText(_language, screen),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(child: Text(productText(_language, 'welcome')))
                        : ListView.builder(
                            reverse: true,
                            itemCount: entries.length,
                            itemBuilder: (_, index) =>
                                _content(entries[entries.length - 1 - index]),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: keyboard ? 1 : 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) => _send(text: text),
                          decoration: InputDecoration(
                            hintText: productText(_language, 'message'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: productText(_language, 'send'),
                        onPressed: _sending ? null : () => _send(),
                        icon: const Icon(Icons.send),
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
    widget.repository.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }
}
