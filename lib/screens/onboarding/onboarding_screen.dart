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
  final _nameController = TextEditingController();
  final _otherController = TextEditingController();
  final _interpreter = MockLifeContextInterpreter();
  int _step = 0;
  Language _interfaceLanguage = Language.english;
  final Set<LifeArea> _areas = {};
  List<String> _interpretation = [];
  List<GoalContext> _suggestions = [];
  final Set<String> _selectedGoals = {};

  String get _languageLabel {
    switch (_interfaceLanguage) {
      case Language.russian:
        return 'Русский';
      case Language.kazakh:
        return 'Қазақша';
      case Language.english:
        return 'English';
    }
  }

  String t(String key) {
    const en = {
      'welcome': 'Tell ORTA where you are now and where you want to go.',
      'name': 'What should ORTA call you?',
      'language': 'Choose your interface language',
      'life': 'What does your life look like right now?',
      'lifeHint': 'Choose all that apply.',
      'other': 'Describe your situation',
      'interpret': 'ORTA thinks these may describe your situation:',
      'goals': 'What would you like to move forward?',
      'summary': 'This is how ORTA understands your life.',
      'build': 'Build my ORTA',
      'continue': 'Continue',
      'back': 'Back',
      'skip': 'Skip for now',
      'otherGoal': 'Other goal',
    };
    const ru = {
      'welcome': 'Расскажите ORTA, где вы сейчас и куда хотите прийти.',
      'name': 'Как ORTA может к вам обращаться?',
      'language': 'Выберите язык интерфейса',
      'life': 'Как сейчас выглядит ваша жизнь?',
      'lifeHint': 'Выберите все подходящие варианты.',
      'other': 'Опишите вашу ситуацию',
      'interpret': 'ORTA думает, что вас могут описывать:',
      'goals': 'К чему вы хотите продвинуться?',
      'summary': 'Так ORTA понимает вашу жизнь.',
      'build': 'Создать мой ORTA',
      'continue': 'Продолжить',
      'back': 'Назад',
      'skip': 'Пропустить пока',
      'otherGoal': 'Другая цель',
    };
    const kk = {
      'welcome': 'ORTA-ға қазір қайда екеніңізді және қайда барғыңыз келетінін айтыңыз.',
      'name': 'ORTA сізге қалай айтуы керек?',
      'language': 'Интерфейс тілін таңдаңыз',
      'life': 'Қазір өміріңіз қалай көрінеді?',
      'lifeHint': 'Сәйкес келетіннің бәрін таңдаңыз.',
      'other': 'Жағдайыңызды сипаттаңыз',
      'interpret': 'ORTA сіздің жағдайыңызды былай түсінуі мүмкін:',
      'goals': 'Нені алға жылжытқыңыз келеді?',
      'summary': 'ORTA сіздің өміріңізді осылай түсінеді.',
      'build': 'Менің ORTA-ымды құру',
      'continue': 'Жалғастыру',
      'back': 'Артқа',
      'skip': 'Әзірге өткізу',
      'otherGoal': 'Басқа мақсат',
    };
    final map = _interfaceLanguage == Language.russian
        ? ru
        : _interfaceLanguage == Language.kazakh
        ? kk
        : en;
    return map[key] ?? key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _setLanguage(Language language) {
    setState(() => _interfaceLanguage = language);
    widget.onLocaleChange(language);
  }

  void _next() {
    if (_step == 1 && _nameController.text.trim().isEmpty) return;
    if (_step == 3 && _areas.isEmpty) return;
    if (_step == 3 &&
        _areas.contains(LifeArea.other) &&
        _otherController.text.trim().isNotEmpty) {
      _interpretation = _interpreter.interpret(_otherController.text);
    }
    if (_step == 4) {
      final draft = LifeContext(
        name: _nameController.text.trim(),
        interfaceLanguage: _interfaceLanguage,
        currentLifeAreas: _areas,
        otherDescription: _otherController.text.trim(),
        interpretedSuggestions: _interpretation,
      );
      _suggestions = GoalSuggestionService.suggestionsFor(draft);
      _selectedGoals.addAll(_suggestions.take(3).map((goal) => goal.id));
    }
    if (_step < 6) setState(() => _step++);
  }

  void _finish() {
    final draft = LifeContext(
      name: _nameController.text.trim(),
      interfaceLanguage: _interfaceLanguage,
      currentLifeAreas: _areas,
      otherDescription: _otherController.text.trim(),
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
                      Text(
                        _languageLabel,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(child: SingleChildScrollView(child: _body())),
                  const SizedBox(height: 16),
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
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
      decoration: const InputDecoration(hintText: 'Your name or nickname'),
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
            for (final entry in const [
              (Language.english, 'English'),
              (Language.russian, 'Русский'),
              (Language.kazakh, 'Қазақша'),
            ])
              Card(
                child: RadioListTile<Language>(
                  value: entry.$1,
                  title: Text(entry.$2),
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
      const SizedBox(height: 16),
      for (final area in LifeArea.values)
        CheckboxListTile(
          value: _areas.contains(area),
          title: Text(ortaLocalizations(context).lifeArea(area)),
          contentPadding: EdgeInsets.zero,
          onChanged: (value) =>
              setState(() => value! ? _areas.add(area) : _areas.remove(area)),
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
                .map(
                  (item) => Chip(
                    label: Text(
                      ortaLocalizations(context).interpretation(item),
                    ),
                  ),
                )
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
      const SizedBox(height: 16),
      for (final goal in _suggestions)
        CheckboxListTile(
          value: _selectedGoals.contains(goal.id),
          title: Text(ortaLocalizations(context).goal(goal.titleKey)),
          subtitle: Text(ortaLocalizations(context).lifeDomain(goal.areaKey)),
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
          'LIFE',
          _areas
              .map((area) => ortaLocalizations(context).lifeArea(area))
              .join(' · '),
        ),
      if (_selectedGoals.isNotEmpty)
        _summarySection(
          'GOALS',
          _suggestions
              .where((goal) => _selectedGoals.contains(goal.id))
              .map((goal) => ortaLocalizations(context).goal(goal.titleKey))
              .join(' · '),
        ),
      if (_interpretation.isNotEmpty)
        _summarySection(
          'NOTES',
          _interpretation
              .map((item) => ortaLocalizations(context).interpretation(item))
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
