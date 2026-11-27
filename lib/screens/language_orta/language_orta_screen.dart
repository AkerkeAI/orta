import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../models/life_context.dart';
import '../../models/life_data.dart';
import '../../models/language_orta_models.dart';
import '../../models/orta_models.dart' hide LanguageProfile;
import '../../models/user_profile.dart';
import '../../services/language_orta_strings.dart';
import '../../services/language_practice_service.dart';
import '../../services/language_practice_ai.dart';
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
  final VoidCallback? onOpenAgent;
  final LanguagePracticeAi? coach;

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
    this.onOpenAgent,
    this.coach,
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
      floatingActionButton: onOpenAgent == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'orta_agent_language',
              onPressed: onOpenAgent,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ORTA AI'),
            ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            TabBar(
              tabs: [
                for (final key in [
                  'studio',
                  'stories',
                  'today',
                  'history',
                  'moments',
                ])
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
                  _SkillPracticeTab(
                    key: ValueKey('skills_$targetCode'),
                    targetName: targetName,
                    languageCode: targetCode,
                    promptLanguageName: AppLocalizations(AppLocale.english)
                        .languageName(targetCode),
                    level: level,
                    strings: strings,
                    lifeContext: lifeContext,
                    coach: coach,
                    onSave: onSavePractice == null
                        ? null
                        : (skill, scenario, response) => onSavePractice!(
                            targetCode,
                            'skill_${skill.name}_${scenario.name}',
                            response,
                          ),
                  ),
                  _InteractiveStoriesTab(
                    targetName: targetName,
                    level: level,
                    strings: strings,
                    onSave: onSavePractice == null
                        ? null
                        : (response) =>
                              onSavePractice!(targetCode, 'story', response),
                  ),
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

class _SkillPracticeTab extends StatefulWidget {
  final String targetName, promptLanguageName, level, languageCode;
  final LanguageOrtaStrings strings;
  final LifeContext? lifeContext;
  final LanguagePracticeAi? coach;
  final Future<void> Function(PracticeSkill, PracticeScenario, String)? onSave;
  const _SkillPracticeTab({
    super.key,
    required this.targetName,
    required this.promptLanguageName,
    required this.level,
    required this.languageCode,
    required this.strings,
    required this.lifeContext,
    required this.coach,
    required this.onSave,
  });
  @override
  State<_SkillPracticeTab> createState() => _SkillPracticeTabState();
}

class _SkillPracticeTabState extends State<_SkillPracticeTab> {
  final _answer = TextEditingController();
  final _tts = FlutterTts();
  final _speech = stt.SpeechToText();
  PracticeSkill _skill = PracticeSkill.speaking;
  PracticeScenario _scenario = PracticeScenario.everyday;
  late PracticePrompt _prompt;
  bool _saving = false;
  bool _promptLoading = false;
  bool _recording = false;
  bool _audioPlaying = false;
  bool _speechReady = false;
  bool _showAudioTranscript = false;
  int _exerciseNumber = 0;
  String? _notice;
  LanguageCoachFeedback? _feedback;

  String get _level => widget.level.isEmpty ? 'A1' : widget.level;
  LanguagePracticeAi get _coach => widget.coach ?? LanguagePracticeAi();
  ApprovedLanguageContext get _approvedContext =>
      LanguagePracticeService.approvedFromLife(widget.lifeContext);
  LanguageProfile get _profile => LanguageProfile(
    id: 'personal_${widget.languageCode}',
    studentId: 'personal',
    languageCode: widget.languageCode,
    languageName: widget.promptLanguageName,
    currentLevel: _level,
    updatedAt: DateTime.now().toUtc(),
  );

  @override
  void initState() {
    super.initState();
    _prompt = _localPrompt(0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _audioPlaying = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _audioPlaying = false);
    });
    _generatePrompt(previousPrompt: '');
  }

  PracticePrompt _localPrompt(int variation) =>
      LanguagePracticeService.localPrompt(
        languageName: widget.promptLanguageName,
        level: _level,
        skill: _skill,
        scenario: _scenario,
        context: _approvedContext,
        variation: variation,
      );

  Future<void> _generatePrompt({String? previousPrompt}) async {
    final variation = _exerciseNumber;
    setState(() {
      _promptLoading = true;
      _prompt = _localPrompt(variation);
      _showAudioTranscript = false;
    });
    try {
      final generated = await _coach.start(
        profile: _profile,
        skill: _skill,
        scenario: _scenario,
        context: _approvedContext,
        previousPrompt: previousPrompt ?? '',
        variation: variation,
      );
      if (mounted) setState(() => _prompt = generated);
    } catch (_) {
      // The local exercise is already visible and remains usable offline.
    } finally {
      if (mounted) setState(() => _promptLoading = false);
    }
  }

  Future<void> _save() async {
    final answer = _answer.text.trim();
    if (_saving || widget.onSave == null || answer.isEmpty) return;
    setState(() {
      _saving = true;
      _notice = null;
    });
    final previous = '${_prompt.prompt}\n${_prompt.stimulus}';
    try {
      await widget.onSave!(_skill, _scenario, answer);
      final practice = LanguagePracticeSession(
        id: 'practice_${DateTime.now().microsecondsSinceEpoch}',
        studentId: 'personal',
        profileId: _profile.id,
        skill: _skill,
        scenario: _scenario,
        prompt: _prompt.prompt,
        stimulus: _prompt.stimulus,
        studentResponse: answer,
        transcript: _skill == PracticeSkill.speaking ? answer : '',
        status: 'completed',
        createdAt: DateTime.now().toUtc(),
        completedAt: DateTime.now().toUtc(),
      );
      late final LanguageCoachFeedback feedback;
      try {
        feedback = await _coach.evaluate(
          profile: _profile,
          session: practice,
          response: answer,
          context: _approvedContext,
        );
      } catch (_) {
        feedback = LanguageCoachFeedback.unavailable(
          widget.strings.text('coachUnavailable'),
        );
      }
      if (!mounted) return;
      setState(() {
        _answer.clear();
        _feedback = feedback;
        _notice = widget.strings.text('practiceSavedNotice');
        _exerciseNumber++;
      });
      await _generatePrompt(previousPrompt: previous);
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = widget.strings.text('practiceSaveErrorNotice'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_saving || _promptLoading) return;
    try {
      if (_speech.isListening) {
        await _speech.stop();
        if (mounted) setState(() => _recording = false);
        return;
      }
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onStatus: (status) {
            if (mounted) {
              setState(() => _recording = status == 'listening');
            }
          },
          onError: (_) {
            if (mounted) {
              setState(() {
                _recording = false;
                _notice = widget.strings.text('speechUnavailable');
              });
            }
          },
        );
      }
      if (!_speechReady) {
        setState(() => _notice = widget.strings.text('speechUnavailable'));
        return;
      }
      final locales = await _speech.locales();
      final supported = locales.where(
        (locale) => locale.localeId.toLowerCase().startsWith(
          '${widget.languageCode.toLowerCase()}-',
        ),
      );
      final localeId = supported.firstOrNull?.localeId ?? widget.languageCode;
      await _speech.listen(
        onResult: _onSpeechResult,
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 50),
          pauseFor: const Duration(seconds: 4),
          listenMode: stt.ListenMode.dictation,
        ),
      );
      if (mounted) setState(() => _recording = _speech.isListening);
    } catch (_) {
      if (mounted) {
        setState(() {
          _recording = false;
          _notice = widget.strings.text('speechUnavailable');
        });
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || result.recognizedWords.isEmpty) return;
    setState(() {
      _answer.value = TextEditingValue(
        text: result.recognizedWords,
        selection: TextSelection.collapsed(
          offset: result.recognizedWords.length,
        ),
      );
      _notice = null;
    });
  }

  Future<void> _playListeningAudio() async {
    if (_audioPlaying) {
      await _tts.stop();
      if (mounted) setState(() => _audioPlaying = false);
      return;
    }
    try {
      final languageCodes = [
        _voiceLocale(widget.languageCode),
        widget.languageCode,
      ];
      for (final language in languageCodes) {
        try {
          if (await _tts.isLanguageAvailable(language) == true) {
            await _tts.setLanguage(language);
            break;
          }
        } catch (_) {
          // Use the system default voice if the requested locale is not installed.
        }
      }
      await _tts.setSpeechRate(0.44);
      setState(() => _audioPlaying = true);
      await _tts.speak(_prompt.stimulus);
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioPlaying = false;
          _notice = widget.strings.text('audioUnavailable');
        });
      }
    }
  }

  String _voiceLocale(String code) =>
      const {
        'en': 'en-US',
        'ru': 'ru-RU',
        'kk': 'kk-KZ',
        'de': 'de-DE',
        'fr': 'fr-FR',
        'es': 'es-ES',
        'zh': 'zh-CN',
        'ja': 'ja-JP',
      }[code] ??
      code;

  Widget _feedbackCard() {
    final feedback = _feedback;
    if (feedback == null) return const SizedBox.shrink();
    final lines = [
      if (feedback.feedback.isNotEmpty) feedback.feedback,
      if (feedback.corrections.isNotEmpty)
        '${widget.strings.text('corrections')}: ${feedback.corrections}',
      if (feedback.explanation.isNotEmpty)
        '${widget.strings.text('explanation')}: ${feedback.explanation}',
      if (feedback.alternativePhrasing.isNotEmpty)
        '${widget.strings.text('alternativePhrasing')}: ${feedback.alternativePhrasing}',
      if (feedback.vocabulary.isNotEmpty)
        '${widget.strings.text('vocabulary')}: ${feedback.vocabulary.map((item) => '${item.term} — ${item.meaning}').join(', ')}',
    ];
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.strings.text('feedback'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              lines.isEmpty
                  ? widget.strings.text('coachUnavailable')
                  : lines.join('\n\n'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.strings.text('fourSkillsTitle'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(widget.strings.text('fourSkillsIntro')),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final skill in [
              PracticeSkill.listening,
              PracticeSkill.reading,
              PracticeSkill.writing,
              PracticeSkill.speaking,
            ])
              ChoiceChip(
                label: Text(widget.strings.text(skill.name)),
                selected: _skill == skill,
                onSelected: _saving || _promptLoading
                    ? null
                    : (_) {
                        setState(() {
                          _skill = skill;
                          _notice = null;
                          _feedback = null;
                          _exerciseNumber++;
                        });
                        _generatePrompt();
                      },
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PracticeScenario>(
          initialValue: _scenario,
          decoration: InputDecoration(
            labelText: widget.strings.text('chooseScenario'),
          ),
          items: PracticeScenario.values
              .map(
                (scenario) => DropdownMenuItem(
                  value: scenario,
                  child: Text(widget.strings.text(scenario.name)),
                ),
              )
              .toList(),
          onChanged: _saving || _promptLoading
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _scenario = value;
                    _notice = null;
                    _feedback = null;
                    _exerciseNumber++;
                  });
                  _generatePrompt();
                },
        ),
        if (_promptLoading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(minHeight: 2),
        ],
        if (_skill == PracticeSkill.listening && _prompt.stimulus.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _playListeningAudio,
                    icon: Icon(_audioPlaying ? Icons.stop : Icons.volume_up),
                    label: Text(
                      widget.strings.text(
                        _audioPlaying ? 'stopAudio' : 'listenAudio',
                      ),
                    ),
                  ),
                  if (_showAudioTranscript && _feedback != null) ...[
                    const SizedBox(height: 10),
                    Text(_prompt.stimulus),
                  ],
                ],
              ),
            ),
          ),
        if (_skill == PracticeSkill.reading && _prompt.stimulus.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_prompt.stimulus),
            ),
          ),
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_prompt.prompt),
          ),
        ),
        if (_skill == PracticeSkill.listening && _feedback != null)
          TextButton(
            onPressed: () =>
                setState(() => _showAudioTranscript = !_showAudioTranscript),
            child: Text(
              widget.strings.text(
                _showAudioTranscript ? 'hideTranscript' : 'showTranscript',
              ),
            ),
          ),
        if (_skill == PracticeSkill.speaking) ...[
          const SizedBox(height: 8),
          Text(widget.strings.text('speechPermissionInfo')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving || _promptLoading ? null : _toggleMicrophone,
            icon: Icon(
              _recording ? Icons.stop_circle_outlined : Icons.mic_none,
            ),
            label: Text(
              widget.strings.text(
                _recording ? 'stopRecording' : 'startRecording',
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _answer,
          minLines: 3,
          maxLines: 7,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: widget.strings.text('responseLanguage', {
              'language': widget.targetName,
            }),
            border: const OutlineInputBorder(),
          ),
        ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_notice!),
          ),
        FilledButton.icon(
          onPressed: _saving || _promptLoading || widget.onSave == null
              ? null
              : _save,
          icon: _saving || _promptLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            widget.strings.text(
              _saving || _promptLoading ? 'saving' : 'savePractice',
            ),
          ),
        ),
        _feedbackCard(),
      ],
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _answer.dispose();
    super.dispose();
  }
}

class _InteractiveStoriesTab extends StatefulWidget {
  final String targetName, level;
  final LanguageOrtaStrings strings;
  final Future<void> Function(String)? onSave;
  const _InteractiveStoriesTab({
    required this.targetName,
    required this.level,
    required this.strings,
    required this.onSave,
  });
  @override
  State<_InteractiveStoriesTab> createState() => _InteractiveStoriesTabState();
}

class _InteractiveStoriesTabState extends State<_InteractiveStoriesTab> {
  int? _story, _chapter, _branch;
  final List<String> _choices = [];
  final _replyController = TextEditingController();
  bool _saving = false;
  String? _noticeKey;
  static const _stories = [
    (
      'The Last Train',
      'Mina finds a sketchbook on the nearly empty train. Its owner is still on board.',
      [
        'Ask Mina to check the cover for a name.',
        'Look for a clue on the final page.',
      ],
    ),
    (
      'The Observatory Key',
      'At the school observatory, Leo discovers a small brass key beside the telescope.',
      [
        'Help Leo ask the caretaker about it.',
        'Search the star charts for a matching symbol.',
      ],
    ),
    (
      'Map of the Floating Market',
      'A hand-drawn map leads Hana to a quiet canal where lanterns are beginning to glow.',
      [
        'Follow the blue bridge marked on the map.',
        'Ask a boat maker what the symbol means.',
      ],
    ),
  ];
  String get _characterName => switch (_story) {
    0 => 'Mina',
    1 => 'Leo',
    _ => 'Hana',
  };

  int _inferBranch(String reply) {
    final text = reply.toLowerCase();
    final clueWords = switch (_story) {
      0 => ['ticket', 'page', 'clue', 'conductor', 'carriage'],
      1 => ['chart', 'star', 'symbol', 'constellation'],
      _ => ['boat', 'maker', 'bridge', 'canal'],
    };
    return clueWords.any(text.contains) ? 1 : 0;
  }

  List<String> get _currentChoices {
    final chapter = _chapter ?? 0;
    if (chapter == 0) return _stories[_story!].$3;
    if (chapter == 1) {
      return switch (_story) {
        0 =>
          _branch == 1
              ? [
                  'Show the ticket to the conductor.',
                  'Check it for a carriage number.',
                ]
              : [
                  'Call out the name written inside.',
                  'Ask passengers if they recognize the sketchbook.',
                ],
        1 =>
          _branch == 1
              ? [
                  'Compare the symbol with the star map.',
                  'Trace the constellation in your notebook.',
                ]
              : [
                  'Ask the caretaker who last used the key.',
                  'Try it on the old map cabinet.',
                ],
        _ =>
          _branch == 1
              ? [
                  'Ask the boat maker where the mark leads.',
                  'Show the map to the nearby shopkeeper.',
                ]
              : [
                  'Follow the blue bridge.',
                  'Look for the lantern with the same mark.',
                ],
      };
    }
    return switch (_story) {
      0 =>
        _branch == 1
            ? [
                'Find the passenger from the carriage number.',
                'Leave a message with the conductor.',
              ]
            : [
                'Return the sketchbook to its owner.',
                'Ask Mina to add a friendly note.',
              ],
      1 =>
        _branch == 1
            ? [
                'Name the new constellation together.',
                'Record the discovery for the school.',
              ]
            : [
                'Return the key to the caretaker.',
                'Explore the first page of the notebook.',
              ],
      _ =>
        _branch == 1
            ? [
                'Visit the little bookshop.',
                'Follow the canal to the marked arch.',
              ]
            : [
                'Carry the map to the lantern stall.',
                'Invite Hana to explore the market.',
              ],
    };
  }

  Future<void> _sendReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty || _saving) return;
    final advanced = await _choose(
      'My reply in ${widget.targetName}: $reply',
      branch: (_chapter ?? 0) == 0 ? _inferBranch(reply) : null,
    );
    if (mounted && advanced) {
      _replyController.clear();
      setState(() {});
    }
  }

  Future<bool> _choose(String choice, {int? branch}) async {
    if (_saving) return false;
    setState(() {
      _saving = true;
      _noticeKey = null;
    });
    var saved = false;
    try {
      if (widget.onSave == null) throw StateError('saving unavailable');
      await widget.onSave!
          .call('Story: ${_stories[_story!].$1}. $choice')
          .timeout(const Duration(seconds: 5));
      saved = true;
    } catch (_) {
      // Keep the story moving even if history storage is temporarily offline.
    }
    if (mounted) {
      setState(() {
        _choices.add(choice);
        if ((_chapter ?? 0) == 0) _branch = branch ?? _inferBranch(choice);
        _saving = false;
        _chapter = (_chapter ?? 0) + 1;
        _noticeKey = saved
            ? 'savedPractice'
            : widget.onSave == null
            ? 'saveUnavailable'
            : 'saveError';
      });
    }
    return true;
  }

  String _sceneText(bool finished) {
    final chapter = _chapter ?? 0;
    if (chapter == 0) return _stories[_story!].$2;
    final secondChoice = _choices.length > 1 ? _choices[1].toLowerCase() : '';
    final finalChoice = _choices.length > 2 ? _choices[2].toLowerCase() : '';
    if (finished) {
      return switch ((_story, _branch)) {
        (0, 0) =>
          finalChoice.contains('passenger')
              ? 'A passenger recognizes the drawing and points to Ellis in the next carriage. Mina returns the sketchbook, and Ellis shows you the tiny city hidden in its pages.'
              : 'You call Ellis’s name, and a student from the next carriage hurries over. Mina returns the sketchbook; Ellis smiles and invites you to add one small detail to the drawing.',
        (0, _) =>
          finalChoice.contains('message')
              ? 'The conductor delivers your note at the next stop. Ellis returns for the sketchbook, grateful that you left a clear message.'
              : 'You follow the carriage number and find Ellis just before the doors open. The ticket clue has led the sketchbook safely home.',
        (1, 0) =>
          finalChoice.contains('notebook')
              ? 'The notebook reveals the observatory’s first student discovery. Leo adds your names to its new page before the caretaker locks the cabinet.'
              : 'The caretaker recognizes the key and opens the map cabinet. Inside is a star chart left by the first student astronomers.',
        (1, _) =>
          finalChoice.contains('record')
              ? 'You record the constellation for the school. By morning, Leo’s careful notes have everyone looking up at the same patch of sky.'
              : 'You name the new constellation together. Leo sketches it beside the telescope, preserving the pattern for the next clear night.',
        (_, 0) =>
          finalChoice.contains('hana')
              ? 'Hana joins you beneath the lanterns, and the stall keeper shares how the floating market began. The map becomes your guide for another visit.'
              : 'You carry the map to the lantern stall. Its maker recognizes the mark and shows you the hidden courtyard where the map was drawn.',
        _ =>
          finalChoice.contains('canal')
              ? 'You follow the canal to the marked arch. Behind it, the bookshop owner reveals the map’s story and lets Hana add its final page.'
              : 'The boat maker guides you to the little bookshop. Its owner recognizes the handwriting and explains who drew the map.',
      };
    }
    if (chapter == 1) {
      return switch ((_story, _branch)) {
        (0, 0) => 'Mina turns the cover toward you. Inside, someone has written “Ellis Park.” Mina asks, “Should we call out the name, or see if another passenger recognizes the sketchbook?”',
        (0, _) => 'On the final page, you find a train ticket tucked beside a drawing. Mina says, “The carriage number is smudged. Shall we show it to the conductor or look more closely?”',
        (1, 0) => 'The caretaker recognizes the key: it belongs to the old map cabinet. Leo asks whether you should find out who last used it or try the key.',
        (1, _) => 'The symbol matches a group of stars on the chart. Leo asks you to trace the pattern or compare it with the observatory map.',
        (_, 0) => 'The blue bridge ends at a lantern stall. Hana spots the map’s mark on one lantern and asks whether to follow the trail or inspect the mark.',
        _ => 'The boat maker recognizes the mark as a sign near the canal bookshop. Hana asks whether to ask for directions or show the map to a shopkeeper.',
      };
    }
    return switch ((_story, _branch)) {
      (0, 0) =>
        secondChoice.contains('passenger')
            ? 'A passenger recognizes the sketchbook’s cover and remembers Ellis drawing the river just a few seats away. Mina has found the owner; now you can choose how to return it.'
            : 'Mina calls Ellis’s name softly. A student from the next carriage answers, but the train is already nearing the station. You decide how to make sure the sketchbook gets back.',
      (0, _) =>
        secondChoice.contains('carriage')
            ? 'The number on the ticket matches the carriage behind you. Mina spots Ellis there, sketching the same station window. You decide how to approach.'
            : 'The conductor recognizes the ticket and remembers Ellis boarding one stop ago. Mina has a likely lead; you decide what to do before the train stops.',
      (1, 0) =>
        secondChoice.contains('cabinet')
            ? 'The key turns in the old cabinet. Inside, Leo finds a notebook and a chart rolled around a small brass telescope lens.'
            : 'The caretaker remembers the last astronomy club meeting and points you to a notebook left beside the telescope. Leo wonders what it might reveal.',
      (1, _) =>
        secondChoice.contains('notebook')
            ? 'Your tracing reveals a constellation that is missing from the observatory guide. Leo asks you to help preserve the discovery.'
            : 'The chart confirms the symbol is a new star pattern. Leo asks whether you should name it or record it for other students.',
      (_, 0) =>
        secondChoice.contains('lantern')
            ? 'The matching lantern bears a tiny map mark on its base. Hana follows it to a courtyard tucked behind the market stalls.'
            : 'The bridge leads to a lantern stall. Its maker recognizes Hana’s map and points toward a quiet courtyard.',
      _ =>
        secondChoice.contains('shopkeeper')
            ? 'The shopkeeper recognizes the map and marks a small bookshop beside the canal. Hana is ready to find its owner.'
            : 'The boat maker explains the symbol and offers to guide you toward the bookshop near the canal.',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_story == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.strings.text('chooseStory'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(widget.strings.text('storiesIntro')),
          for (var i = 0; i < _stories.length; i++)
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(_stories[i].$1),
                subtitle: Text(_stories[i].$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() {
                  _story = i;
                  _chapter = 0;
                  _branch = null;
                  _noticeKey = null;
                  _replyController.clear();
                  _choices.clear();
                }),
              ),
            ),
        ],
      );
    }
    final story = _stories[_story!];
    final finished = (_chapter ?? 0) >= 3;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextButton.icon(
          onPressed: () => setState(() {
            _story = null;
            _chapter = null;
            _branch = null;
            _noticeKey = null;
            _replyController.clear();
          }),
          icon: const Icon(Icons.arrow_back),
          label: Text(widget.strings.text('allStories')),
        ),
        Text(story.$1, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Practice in ${widget.targetName} · ${widget.level.isEmpty ? 'open level' : widget.level}',
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: finished ? 1 : ((_chapter ?? 0) + 1) / 3,
        ),
        if (_noticeKey != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.strings.text(_noticeKey!),
              style: TextStyle(
                color: _noticeKey == 'savedPractice'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_stories_outlined),
                const SizedBox(height: 12),
                Text(
                  _sceneText(finished),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_choices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Your last response: ${_choices.last}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (finished) ...[
          Text(widget.strings.text('storyComplete')),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() {
              _chapter = 0;
              _branch = null;
              _noticeKey = null;
              _replyController.clear();
              _choices.clear();
            }),
            child: const Text('Play again'),
          ),
        ] else ...[
          Text(
            widget.strings.text('storyReplyPrompt', {
              'language': widget.targetName,
            }),
          ),
          for (var i = 0; i < _currentChoices.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => _choose(
                        _currentChoices[i],
                        branch: (_chapter ?? 0) == 0 ? i : null,
                      ),
                child: Text(_currentChoices[i]),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _replyController,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: widget.strings.text('replyToCharacter', {
                'character': _characterName,
              }),
              border: const OutlineInputBorder(),
            ),
          ),
          FilledButton.icon(
            onPressed: _saving || _replyController.text.trim().isEmpty
                ? null
                : _sendReply,
            icon: const Icon(Icons.send_outlined),
            label: Text(widget.strings.text('sendStoryReply')),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
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
                    entry.topicKey == 'story'
                        ? strings.text('stories')
                        : entry.topicKey.startsWith('skill_')
                        ? '${strings.text(entry.topicKey.split('_')[1])} · ${entry.topicKey.split('_').last}'
                        : strings.text(
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
