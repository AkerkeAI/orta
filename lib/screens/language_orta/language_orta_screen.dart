import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../models/language_definition.dart';
import '../../models/orta_models.dart';
import '../../models/user_profile.dart';
import '../../services/localization_service.dart';
import '../../services/orta_localization.dart';

class LanguageOrtaScreen extends StatelessWidget {
  final UserProfile userProfile;
  final String? languageCode;
  final VoidCallback onBack;
  final AppLocale currentLocale;
  final List<LifeMapCategory> lifeMap;
  final List<LanguageMemory> memories;
  final ValueChanged<String>? onPracticeCompleted;
  final ValueChanged<String>? onAddMemory;

  const LanguageOrtaScreen({
    super.key,
    required this.userProfile,
    this.languageCode,
    required this.onBack,
    this.currentLocale = AppLocale.english,
    this.lifeMap = const [],
    this.memories = const [],
    this.onPracticeCompleted,
    this.onAddMemory,
  });

  @override
  Widget build(BuildContext context) {
    final definition = LanguageDefinition.byCode(
      languageCode ?? userProfile.learningLanguage.code,
    );
    final effectiveLifeMap = lifeMap.isNotEmpty
        ? lifeMap
        : [
            LifeMapCategory(
              name: 'Everyday conversation',
              value: 0,
              description: 'Practice from your own life',
            ),
          ];
    final effectiveMemories = memories.isNotEmpty
        ? memories
        : const <LanguageMemory>[];

    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('LANGUAGE ORTA · ${definition.englishName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: strings.ui('today')),
                Tab(text: strings.ui('life_map')),
                Tab(text: strings.ui('moments')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TodayTab(
                    userProfile: userProfile,
                    definition: definition,
                    lifeMap: effectiveLifeMap,
                    onPracticeCompleted: onPracticeCompleted,
                  ),
                  _LifeMapTab(lifeMap: effectiveLifeMap),
                  _MomentsTab(
                    memories: effectiveMemories,
                    onAddMemory: onAddMemory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  final UserProfile userProfile;
  final LanguageDefinition definition;
  final List<LifeMapCategory> lifeMap;
  final ValueChanged<String>? onPracticeCompleted;
  const _TodayTab({
    required this.userProfile,
    required this.definition,
    required this.lifeMap,
    required this.onPracticeCompleted,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${definition.englishName} · ${userProfile.level.shortName}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppLocalizations.of(context).ui('practice_environment'),
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SessionCard(
          onPracticeCompleted: () {
            onPracticeCompleted?.call(definition.code);
          },
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

class _LifeMapTab extends StatelessWidget {
  final List<LifeMapCategory> lifeMap;
  const _LifeMapTab({required this.lifeMap});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: _LifeMapCard(lifeMap: lifeMap),
  );
}

class _MomentsTab extends StatelessWidget {
  final List<LanguageMemory> memories;
  final ValueChanged<String>? onAddMemory;
  const _MomentsTab({required this.memories, required this.onAddMemory});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (memories.isEmpty) Text(strings.ui('no_moments')),
        ...memories.map((memory) => _MemoryCard(memory: memory)),
        OutlinedButton.icon(
          onPressed: () =>
              onAddMemory?.call('A new language moment from real life.'),
          icon: const Icon(Icons.note_add),
          label: Text(strings.ui('add_moment')),
        ),
      ],
    );
  }
}

class _SessionCard extends StatefulWidget {
  final VoidCallback onPracticeCompleted;

  const _SessionCard({required this.onPracticeCompleted});

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s session is a safe practice sandbox built from your context.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
              'MODULE 1 — REAL LIFE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a recent situation and explain it in your target language.',
            ),
            const SizedBox(height: 16),
            const Text(
              'MODULE 2 — YOUR GOAL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Practice the words and phrases that help you move forward.',
            ),
            const SizedBox(height: 16),
            const Text(
              'MODULE 3 — REFLECTION',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Tell ORTA what happened today and what you need next.'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _completed = true;
                  });
                  widget.onPracticeCompleted();
                },
                child: Text(
                  _completed ? 'Practice complete' : 'Complete mock practice',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifeMapCard extends StatelessWidget {
  final List<LifeMapCategory> lifeMap;

  const _LifeMapCard({required this.lifeMap});

  @override
  Widget build(BuildContext context) {
    final languageIndependence = lifeMap.isNotEmpty
        ? lifeMap.map((c) => c.value).reduce((a, b) => a + b) ~/ lifeMap.length
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Language Independence',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$languageIndependence%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...lifeMap.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (category.value / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                      color: AppTheme.primaryColor,
                      backgroundColor: const Color(0xFFE8F5F3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final LanguageMemory memory;

  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memory.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(memory.phrase, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              'Meaning: ${memory.meaning}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
