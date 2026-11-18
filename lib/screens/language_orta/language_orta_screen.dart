import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../models/life_context.dart';
import '../../models/life_data.dart';
import '../../models/orta_models.dart';
import '../../models/user_profile.dart';
import '../../services/language_orta_strings.dart';
import '../../services/language_practice_service.dart';
import '../../services/localization_service.dart';

class LanguageOrtaScreen extends StatelessWidget {
  final UserProfile userProfile;
  final String? languageCode;
  final String? languageLevel;
  final LifeContext? lifeContext;
  final VoidCallback onBack;
  final AppLocale currentLocale;
  final List<LifeMapCategory> lifeMap;
  final List<LanguageMemory> memories;
  final List<LanguagePracticeEntry> practiceHistory;
  final int completedSessions;
  final Future<void> Function(String code, String topicKey, String response)?
  onSavePractice;
  final Future<void> Function(String)? onAddMemory;

  const LanguageOrtaScreen({
    super.key,
    required this.userProfile,
    this.languageCode,
    this.languageLevel,
    this.lifeContext,
    required this.onBack,
    this.currentLocale = AppLocale.english,
    this.lifeMap = const [],
    this.memories = const [],
    this.practiceHistory = const [],
    this.completedSessions = 0,
    this.onSavePractice,
    this.onAddMemory,
  });

  @override
  Widget build(BuildContext context) {
    final targetCode = languageCode ?? userProfile.learningLanguage.code;
    final strings = LanguageOrtaStrings(currentLocale);
    final targetName = AppLocalizations(currentLocale).languageName(targetCode);
    final level =
        languageLevel ??
        lifeContext?.languages
            .where((language) => language.languageCode == targetCode)
            .firstOrNull
            ?.level ??
        (targetCode == userProfile.learningLanguage.code
            ? userProfile.level.shortName
            : '');
    return Scaffold(
      appBar: AppBar(
        title: Text('LANGUAGE ORTA · $targetName'),
        leading: IconButton(
          tooltip: strings.text('back'),
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
                for (final key in ['today', 'history', 'moments'])
                  Tab(
                    height: 64,
                    child: Text(
                      strings.text(key),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TodayTab(
                    key: ValueKey('practice_$targetCode'),
                    targetName: targetName,
                    level: level,
                    strings: strings,
                    topics: LanguagePracticeService.topicsFor(lifeContext),
                    onSave: onSavePractice == null
                        ? null
                        : (topic, response) =>
                              onSavePractice!(targetCode, topic, response),
                  ),
                  _HistoryTab(
                    history: practiceHistory,
                    completedSessions: completedSessions,
                    targetName: targetName,
                    lifeMap: lifeMap,
                    strings: strings,
                  ),
                  _MomentsTab(
                    memories: memories
                        .where((memory) => memory.language == targetCode)
                        .toList(),
                    onAddMemory: onAddMemory,
                    strings: strings,
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
  final String targetName;
  final String level;
  final LanguageOrtaStrings strings;
  final List<String> topics;
  final Future<void> Function(String, String)? onSave;
  const _TodayTab({
    super.key,
    required this.targetName,
    required this.level,
    required this.strings,
    required this.topics,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$targetName · ${level.isEmpty ? strings.text('levelUnset') : level}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          strings.text('selfGuided'),
          style: const TextStyle(color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        _SessionCard(
          targetName: targetName,
          strings: strings,
          topics: topics,
          onSave: onSave,
        ),
      ],
    ),
  );
}

class _SessionCard extends StatefulWidget {
  final String targetName;
  final LanguageOrtaStrings strings;
  final List<String> topics;
  final Future<void> Function(String, String)? onSave;
  const _SessionCard({
    required this.targetName,
    required this.strings,
    required this.topics,
    required this.onSave,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  final _controller = TextEditingController();
  String _topic = 'daily';
  bool _completed = false;
  bool _saving = false;
  String? _error;

  @override
  void didUpdateWidget(covariant _SessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.topics.contains(_topic)) _topic = widget.topics.first;
  }

  Future<void> _save() async {
    if (_saving || _completed || widget.onSave == null) return;
    final response = _controller.text.trim();
    if (response.isEmpty) {
      setState(() => _error = 'responseRequired');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave!(_topic, response);
      if (mounted) setState(() => _completed = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'saveError');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text('sessionTitle'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(strings.text('sessionAbout')),
            const SizedBox(height: 8),
            Text(
              strings.text('safeContext'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_topic),
              initialValue: _topic,
              isExpanded: true,
              decoration: InputDecoration(labelText: strings.text('topic')),
              items: widget.topics
                  .map(
                    (topic) => DropdownMenuItem(
                      value: topic,
                      child: Text(strings.text(topic)),
                    ),
                  )
                  .toList(),
              onChanged: _saving || _completed
                  ? null
                  : (value) => setState(() {
                      _topic = value!;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 16),
            Text(
              strings.text('${_topic}Prompt', {'language': widget.targetName}),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('languagePracticeResponse'),
              controller: _controller,
              readOnly: _saving || _completed,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: strings.text('response', {
                  'language': widget.targetName,
                }),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  strings.text(_error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (widget.onSave == null) Text(strings.text('saveUnavailable')),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('saveLanguagePractice'),
                onPressed: _saving || _completed || widget.onSave == null
                    ? null
                    : _save,
                child: Text(
                  strings.text(
                    _saving
                        ? 'saving'
                        : _completed
                        ? 'savedPractice'
                        : 'savePractice',
                  ),
                ),
              ),
            ),
            if (_completed)
              TextButton(
                onPressed: () => setState(() {
                  _controller.clear();
                  _completed = false;
                  _error = null;
                }),
                child: Text(strings.text('anotherPractice')),
              ),
          ],
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

class _HistoryTab extends StatelessWidget {
  final List<LanguagePracticeEntry> history;
  final int completedSessions;
  final String targetName;
  final List<LifeMapCategory> lifeMap;
  final LanguageOrtaStrings strings;
  const _HistoryTab({
    required this.history,
    required this.completedSessions,
    required this.targetName,
    required this.lifeMap,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          strings.text('completed', {'count': '$completedSessions'}),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(strings.text('historyAbout', {'language': targetName})),
        if (completedSessions > history.length && history.length < 50) ...[
          const SizedBox(height: 8),
          Text(strings.text('legacyHistory')),
        ],
        const SizedBox(height: 16),
        if (history.isEmpty) Text(strings.text('noHistory')),
        if (history.length == 50) Text(strings.text('recentHistory')),
        ...history.reversed.map((entry) {
          final date = entry.createdAt.toLocal();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text(
                      LanguagePracticeService.supportedTopics.contains(
                            entry.topicKey,
                          )
                          ? entry.topicKey
                          : 'daily',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dates.formatMediumDate(date)} · ${dates.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(entry.response),
                ],
              ),
            ),
          );
        }),
        if (lifeMap.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            strings.text('savedMap'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(strings.text('mapAbout')),
          ...lifeMap.map(
            (category) => ListTile(
              title: Text(category.name),
              subtitle: category.description.isEmpty
                  ? null
                  : Text(category.description),
              trailing: Text('${category.value}%'),
            ),
          ),
        ],
      ],
    );
  }
}

class _MomentsTab extends StatelessWidget {
  final List<LanguageMemory> memories;
  final Future<void> Function(String)? onAddMemory;
  final LanguageOrtaStrings strings;
  const _MomentsTab({
    required this.memories,
    required this.onAddMemory,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (memories.isEmpty) Text(strings.text('noMoments')),
      ...memories.map(
        (memory) => _MemoryCard(memory: memory, strings: strings),
      ),
      OutlinedButton.icon(
        onPressed: onAddMemory == null
            ? null
            : () async {
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      _MomentDialog(onSave: onAddMemory!, strings: strings),
                );
                if (saved == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.text('momentSaved'))),
                  );
                }
              },
        icon: const Icon(Icons.note_add),
        label: Text(strings.text('addMoment')),
      ),
    ],
  );
}

class _MemoryCard extends StatelessWidget {
  final LanguageMemory memory;
  final LanguageOrtaStrings strings;
  const _MemoryCard({required this.memory, required this.strings});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            memory.title == 'Moment' || memory.title.isEmpty
                ? strings.text('moment')
                : memory.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          SelectableText(memory.phrase),
          if (memory.meaning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              strings.text('meaning', {'meaning': memory.meaning}),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MomentDialog extends StatefulWidget {
  final Future<void> Function(String) onSave;
  final LanguageOrtaStrings strings;
  const _MomentDialog({required this.onSave, required this.strings});
  @override
  State<_MomentDialog> createState() => _MomentDialogState();
}

class _MomentDialogState extends State<_MomentDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || _controller.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_controller.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.strings.text('saveError');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(strings.text('moment')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.text('momentAbout')),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(hintText: strings.text('momentHint')),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(strings.text('cancel')),
        ),
        ElevatedButton(
          onPressed: _saving || _controller.text.trim().isEmpty ? null : _save,
          child: Text(strings.text(_saving ? 'saving' : 'save')),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
