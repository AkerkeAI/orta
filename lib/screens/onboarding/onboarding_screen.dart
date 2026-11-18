import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../models/life_context.dart';
import '../../services/goal_suggestion_service.dart';
import '../../services/life_context_interpreter.dart';
import '../../services/localization_service.dart';
import '../../services/orta_localization.dart';

class OnboardingScreen extends StatefulWidget {
  final ValueChanged<LifeContext> onComplete;
  final ValueChanged<Language> onLocaleChange;
  final AppLocale currentLocale;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    required this.onLocaleChange,
    this.currentLocale = AppLocale.english,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _otherController = TextEditingController();
  final _interpreter = MockLifeContextInterpreter();
  int _step = 0;
  Language _interfaceLanguage = Language.english;
  final Set<LifeArea> _areas = {};
  List<String> _interpretation = [];
  List<GoalContext> _suggestions = [];
  final Set<String> _selectedGoals = {};

  bool _nameInvalid = false;
  bool _lifeInvalid = false;
  bool _goalsGenerated = false;

  AppLocalizations get _strings =>
      AppLocalizations(AppLocaleExtension.fromLanguage(_interfaceLanguage));

  String t(String key) => _strings.get('life_onboarding_$key');

  @override
  void initState() {
    super.initState();
    _interfaceLanguage = LanguageExtension.fromCode(
      widget.currentLocale.languageCode,
    );
  }

  @override
  void didUpdateWidget(OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocale != widget.currentLocale) {
      _interfaceLanguage = LanguageExtension.fromCode(
        widget.currentLocale.languageCode,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _setLanguage(Language language) {
    setState(() => _interfaceLanguage = language);
    widget.onLocaleChange(language);
  }

  void _goToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _step = step);
  }

  void _next() {
    if (_step == 1 && _nameController.text.trim().isEmpty) {
      setState(() => _nameInvalid = true);
      return;
    }
    if (_step == 3 && _areas.isEmpty) {
      setState(() => _lifeInvalid = true);
      return;
    }
    if (_step == 3) {
      _interpretation =
          _areas.contains(LifeArea.other) &&
              _otherController.text.trim().isNotEmpty
          ? _interpreter.interpret(_otherController.text)
          : [];
      final draft = LifeContext(
        name: _nameController.text.trim(),
        interfaceLanguage: _interfaceLanguage,
        currentLifeAreas: Set.of(_areas),
        otherDescription: _areas.contains(LifeArea.other)
            ? _otherController.text.trim()
            : '',
        interpretedSuggestions: _interpretation,
      );
      _suggestions = GoalSuggestionService.suggestionsFor(draft);
      // Revisiting Life keeps deliberate goal choices, and removes stale goals.
      _selectedGoals.retainAll(_suggestions.map((goal) => goal.id));
      if (!_goalsGenerated) {
        _selectedGoals.addAll(_suggestions.take(3).map((goal) => goal.id));
        _goalsGenerated = true;
      }
    }
    if (_step < 5) _goToStep(_step + 1);
  }

  void _finish() {
    final draft = LifeContext(
      name: _nameController.text.trim(),
      interfaceLanguage: _interfaceLanguage,
      currentLifeAreas: Set.of(_areas),
      otherDescription: _areas.contains(LifeArea.other)
          ? _otherController.text.trim()
          : '',
      interpretedSuggestions: _interpretation,
      goals: _suggestions
          .where((goal) => _selectedGoals.contains(goal.id))
          .toList(),
    );
    widget.onComplete(draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                      PopupMenuButton<Language>(
                        tooltip: _strings.get('interface_language'),
                        initialValue: _interfaceLanguage,
                        onSelected: _setLanguage,
                        itemBuilder: (_) => [
                          for (final language in Language.values)
                            PopupMenuItem(
                              value: language,
                              child: Text(language.displayName),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _interfaceLanguage.displayName,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _body(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_step > 0)
                    TextButton(
                      onPressed: () => _goToStep(_step - 1),
                      child: Text(t('back')),
                    ),
                  if (_step < 5)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: Text(t('continue')),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finish,
                        child: Text(t('build')),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return _intro();
      case 1:
        return _name();
      case 2:
        return _language();
      case 3:
        return _life();
      case 4:
        return _goals();
      case 5:
        return _summary();
      default:
        return const SizedBox();
    }
  }

  Widget _intro() => _stepLayout(
    'ORTA',
    t('welcome'),
    const Icon(Icons.auto_awesome, size: 48),
  );

  Widget _name() => _stepLayout(
    t('name'),
    '',
    TextField(
      controller: _nameController,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _next(),
      onChanged: (_) {
        if (_nameInvalid) setState(() => _nameInvalid = false);
      },
      decoration: InputDecoration(
        hintText: t('nameHint'),
        errorText: _nameInvalid ? _strings.onboardingNameError : null,
      ),
    ),
  );

  Widget _language() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t('language'),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      RadioGroup<Language>(
        groupValue: _interfaceLanguage,
        onChanged: (value) {
          if (value != null) _setLanguage(value);
        },
        child: Column(
          children: [
            for (final language in Language.values)
              Card(
                child: RadioListTile<Language>(
                  value: language,
                  title: Text(language.displayName),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _life() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t('life'),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        t('lifeHint'),
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      if (_lifeInvalid)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            t('lifeError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 16),
      for (final area in LifeArea.values)
        CheckboxListTile(
          value: _areas.contains(area),
          title: Text(_strings.lifeArea(area)),
          contentPadding: EdgeInsets.zero,
          onChanged: (value) => setState(() {
            if (value == true) {
              _areas.add(area);
            } else {
              _areas.remove(area);
              if (area == LifeArea.other) _interpretation = [];
            }
            _lifeInvalid = false;
          }),
        ),
      if (_areas.contains(LifeArea.other)) ...[
        const SizedBox(height: 8),
        TextField(
          controller: _otherController,
          maxLines: 3,
          decoration: InputDecoration(labelText: t('other')),
        ),
        if (_interpretation.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            t('interpret'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: _interpretation
                .map((item) => Chip(label: Text(_strings.interpretation(item))))
                .toList(),
          ),
        ],
      ],
    ],
  );

  Widget _goals() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t('goals'),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(t('goalsHint')),
      const SizedBox(height: 16),
      for (final goal in _suggestions)
        CheckboxListTile(
          value: _selectedGoals.contains(goal.id),
          title: Text(_strings.goal(goal.titleKey)),
          subtitle: Text(_strings.lifeDomain(goal.areaKey)),
          contentPadding: EdgeInsets.zero,
          onChanged: (value) => setState(
            () => value!
                ? _selectedGoals.add(goal.id)
                : _selectedGoals.remove(goal.id),
          ),
        ),
    ],
  );

  Widget _summary() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t('summary'),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      Text(
        _nameController.text.trim(),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      if (_areas.isNotEmpty)
        _summarySection(
          t('summaryLife'),
          _areas.map((area) => _strings.lifeArea(area)).join(' · '),
        ),
      if (_selectedGoals.isNotEmpty)
        _summarySection(
          t('summaryGoals'),
          _suggestions
              .where((goal) => _selectedGoals.contains(goal.id))
              .map((goal) => _strings.goal(goal.titleKey))
              .join(' · '),
        ),
      if (_selectedGoals.isEmpty) Text(t('noGoals')),
      if (_areas.contains(LifeArea.other) &&
          _otherController.text.trim().isNotEmpty)
        _summarySection(t('summaryNotes'), _otherController.text.trim()),
      if (_interpretation.isNotEmpty)
        _summarySection(
          t('interpret'),
          _interpretation
              .map((item) => _strings.interpretation(item))
              .join(' · '),
        ),
    ],
  );

  Widget _summarySection(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );

  Widget _stepLayout(String title, String subtitle, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      ),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary),
        ),
      ],
      const SizedBox(height: 32),
      child,
    ],
  );
}
