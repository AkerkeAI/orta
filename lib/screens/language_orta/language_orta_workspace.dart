import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/language_definition.dart';
import '../../models/language_orta_models.dart';
import '../../services/language_orta_access.dart';
import '../../services/language_orta_store.dart';
import '../../services/language_orta_strings.dart';
import '../../services/language_practice_ai.dart';
import '../../services/language_practice_service.dart';
import '../../services/localization_service.dart';

const _ink = Color(0xFF172B4D);
const _muted = Color(0xFF6B7890);
const _line = Color(0xFFE8EDF4);
const _teal = Color(0xFF403B9D);
const _wash = Color(0xFFF8F7FC);
const _focusSkills = [
  PracticeSkill.listening,
  PracticeSkill.reading,
  PracticeSkill.writing,
  PracticeSkill.speaking,
];

enum _LanguagePage { home, profile, studio, results, progress }

class LanguageOrtaWorkspace extends StatefulWidget {
  final String role;
  final String studentId;
  final String studentName;
  final LanguageOrtaStore? store;
  final LanguagePracticeAi? coach;
  final ApprovedLanguageContext approvedContext;
  final AppLocale locale;
  final bool embedded;

  const LanguageOrtaWorkspace({
    super.key,
    required this.role,
    required this.studentId,
    this.studentName = '',
    this.store,
    this.coach,
    this.approvedContext = const ApprovedLanguageContext(),
    this.locale = AppLocale.english,
    this.embedded = true,
  });

  @override
  State<LanguageOrtaWorkspace> createState() => _LanguageOrtaWorkspaceState();
}

class _LanguageOrtaWorkspaceState extends State<LanguageOrtaWorkspace> {
  late LanguageOrtaStore _store;
  _LanguagePage _page = _LanguagePage.home;
  List<LanguageProfile> _profiles = [];
  List<LanguagePracticeSession> _sessions = [];
  LanguageProfile? _selected;
  LanguagePracticeSession? _active;
  LanguageSessionResult? _result;
  bool _loading = true;
  String? _error;
  PracticeSkill _skill = PracticeSkill.writing;
  PracticeScenario _scenario = PracticeScenario.everyday;
  final _response = TextEditingController();
  final _tts = FlutterTts();
  final _speech = stt.SpeechToText();
  final _chatQuestion = TextEditingController();
  final List<({bool fromStudent, String text})> _chatMessages = [];
  bool _chatBusy = false;
  String? _chatError;
  bool _busy = false;
  bool _recording = false;
  bool _speechReady = false;
  bool _playingAudio = false;
  String? _speechError;

  LanguageOrtaStrings get _t => LanguageOrtaStrings(widget.locale);

  @override
  void initState() {
    super.initState();
    _store =
        widget.store ??
        (LanguageOrtaAccess.canOpenRole(widget.role)
            ? StudentLanguageOrtaStore(
                studentId: widget.studentId,
                role: widget.role,
              )
            : const DeniedLanguageOrtaStore());
    _scenario = LanguagePracticeService.recommendedScenario(
      widget.approvedContext,
    );
    _load();
  }

  Future<void> _load() async {
    if (!LanguageOrtaAccess.canOpenRole(widget.role)) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await _store.profiles();
      final sessions = await _store.sessions();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _sessions = sessions;
        _selected ??= profiles.firstOrNull;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _response.dispose();
    _chatQuestion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!LanguageOrtaAccess.canOpenRole(widget.role)) {
      return _denied();
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!, style: const TextStyle(color: _ink)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFBF7F1), Color(0xFFF3F2FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 600 ? 18 : 32,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tabs(),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.025),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_page),
                      child: switch (_page) {
                        _LanguagePage.home => _home(),
                        _LanguagePage.profile => _profile(),
                        _LanguagePage.studio => _studio(),
                        _LanguagePage.results => _results(),
                        _LanguagePage.progress => _progress(),
                      },
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

  Widget _denied() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t.text('deniedTitle'),
          key: const ValueKey('languageOrtaDenied'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(_t.text('studentOnly'), style: const TextStyle(color: _muted)),
      ],
    ),
  );

  Widget _tabs() {
    final items = [
      (_LanguagePage.home, 'home'),
      (_LanguagePage.studio, 'studio'),
      (_LanguagePage.progress, 'progress'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            key: ValueKey('languageTab_${item.$2}'),
            label: Text(_t.text(item.$2)),
            selected: _page == item.$1,
            selectedColor: const Color(0xFFF1DECA),
            labelStyle: TextStyle(
              color: _page == item.$1 ? _teal : _muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            side: BorderSide.none,
            onSelected: (_) => setState(() => _page = item.$1),
          ),
      ],
    );
  }

  Widget _home() {
    final name = widget.studentName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t.text('welcome', {'name': name.isEmpty ? '' : ', $name'}),
          style: const TextStyle(
            color: _ink,
            fontSize: 25,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t.text('boundary'),
          style: const TextStyle(color: _teal, height: 1.45),
        ),
        const SizedBox(height: 18),
        _sectionTitle(_t.text('yourLanguages'), action: _addLanguageButton()),
        const SizedBox(height: 12),
        if (_profiles.isEmpty)
          _card(
            child: Text(
              _t.text('noLanguages'),
              style: const TextStyle(color: _muted),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final profile in _profiles) _languageCard(profile)],
          ),
        const SizedBox(height: 18),
        if (_selected != null) ...[
          _sectionTitle(_t.text('skillProgress')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final skill in _focusSkills)
                _skillChip(skill, _selected!.skillProgress[skill.name] ?? 0),
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle(_t.text('recommended')),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_t.text(_scenario.name)} · ${_selected!.displayName} · ${_selected!.currentLevel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguagePracticeService.localPrompt(
                    languageName: _selected!.displayName,
                    level: _selected!.currentLevel,
                    skill: PracticeSkill.writing,
                    scenario: _scenario,
                    context: widget.approvedContext,
                  ).prompt,
                  style: const TextStyle(color: _muted, height: 1.45),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('recommendedPractice'),
                  onPressed: () {
                    _skill = PracticeSkill.writing;
                    _openStudio();
                  },
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  child: Text(_t.text('startPractice')),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _sectionTitle(_t.text('recentSessions')),
        const SizedBox(height: 12),
        if (_recent.isEmpty)
          Text(_t.text('noRecent'), style: const TextStyle(color: _muted))
        else
          for (final session in _recent.take(5)) _sessionTile(session),
      ],
    );
  }

  List<LanguagePracticeSession> get _recent {
    final items = [..._sessions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Widget _languageCard(LanguageProfile profile) {
    final selected = _selected?.id == profile.id;
    return SizedBox(
      width: 260,
      child: Material(
        color: selected ? const Color(0xFFF1DECA) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('languageCard_${profile.languageCode}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selected = profile),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? _teal : _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${profile.currentLevel} → ${profile.targetLevel}',
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_t.text('sessionsCompleted')}: ${profile.completedCount}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selected = profile;
                        _page = _LanguagePage.profile;
                      }),
                      child: Text(_t.text('editProfile')),
                    ),
                    TextButton(
                      onPressed: () {
                        _selected = profile;
                        _openStudio();
                      },
                      child: Text(_t.text('openStudio')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profile() {
    final profile = _selected;
    if (profile == null) return Text(_t.text('noLanguages'));
    return _ProfileForm(
      key: ValueKey(profile.id),
      profile: profile,
      strings: _t,
      onSave: (next) async {
        final saved = await _store.saveProfile(next);
        await _load();
        if (mounted) {
          setState(() {
            _selected = saved;
            _page = _LanguagePage.home;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_t.text('profileSaved'))));
        }
      },
    );
  }

  Widget _studio() {
    final profile = _selected;
    if (profile == null) return Text(_t.text('noLanguages'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t.text('studio')} · ${profile.displayName}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _t.text('chooseSkill'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final skill in _focusSkills)
              ChoiceChip(
                key: ValueKey('skill_${skill.name}'),
                label: Text(_t.text(skill.name)),
                selected: _skill == skill,
                selectedColor: _tintFor(skill),
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                        _skill = skill;
                        _active = null;
                        _response.clear();
                      }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<PracticeScenario>(
          key: ValueKey(_scenario),
          initialValue: _scenario,
          decoration: InputDecoration(labelText: _t.text('chooseScenario')),
          items: [
            for (final scenario in PracticeScenario.values)
              DropdownMenuItem(
                value: scenario,
                child: Text(_t.text(scenario.name)),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _scenario = value!;
                  _active = null;
                }),
        ),
        if (_skill == PracticeSkill.speaking) ...[
          const SizedBox(height: 12),
          Text(
            _t.text('speechPermissionInfo'),
            style: const TextStyle(color: _muted),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          _t.text('focusSkillsHint'),
          style: const TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_active == null)
          FilledButton(
            key: const ValueKey('startLanguagePractice'),
            onPressed: _busy ? null : _start,
            style: FilledButton.styleFrom(backgroundColor: _teal),
            child: Text(_t.text(_busy ? 'saving' : 'start')),
          )
        else ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _active!.prompt,
                  style: const TextStyle(color: _ink, height: 1.45),
                ),
                if (_skill == PracticeSkill.listening &&
                    _active!.stimulus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _playExerciseAudio,
                    icon: Icon(_playingAudio ? Icons.stop : Icons.volume_up),
                    label: Text(
                      _t.text(_playingAudio ? 'stopAudio' : 'listenAudio'),
                    ),
                  ),
                ],
                if (_active!.stimulus.isNotEmpty &&
                    _skill != PracticeSkill.listening) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _wash,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _active!.stimulus,
                      style: const TextStyle(color: _ink, height: 1.45),
                    ),
                  ),
                ],
                if (_active!.transcript.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _active!.transcript,
                    style: const TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          if (_skill == PracticeSkill.speaking) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _toggleSpeakingInput,
              icon: Icon(
                _recording ? Icons.stop_circle_outlined : Icons.mic_none,
              ),
              label: Text(
                _t.text(_recording ? 'stopRecording' : 'startRecording'),
              ),
            ),
            if (_speechError != null)
              Text(
                _speechError!,
                style: const TextStyle(color: Color(0xFF9B5835)),
              ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('languageStudioResponse'),
            controller: _response,
            minLines: 4,
            maxLines: 10,
            maxLength: 4000,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: _t.text('response', {'language': profile.displayName}),
              alignLabelWithHint: true,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('finishLanguagePractice'),
                onPressed: _busy ? null : _finish,
                style: FilledButton.styleFrom(backgroundColor: _teal),
                child: Text(_t.text(_busy ? 'saving' : 'finish')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _chatPanel(profile),
      ],
    );
  }

  Future<void> _playExerciseAudio() async {
    final session = _active;
    final profile = _selected;
    if (session == null || profile == null || session.stimulus.isEmpty) return;
    try {
      if (_playingAudio) {
        await _tts.stop();
        if (mounted) setState(() => _playingAudio = false);
        return;
      }
      final locales = [
        _voiceLocale(profile.languageCode),
        profile.languageCode,
      ];
      for (final locale in locales) {
        try {
          if (await _tts.isLanguageAvailable(locale) == true) {
            await _tts.setLanguage(locale);
            break;
          }
        } catch (_) {
          // Use the system default voice if the requested locale is not installed.
        }
      }
      await _tts.setSpeechRate(0.44);
      setState(() => _playingAudio = true);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _playingAudio = false);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _playingAudio = false);
      });
      await _tts.speak(session.stimulus);
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingAudio = false;
          _speechError = _t.text('audioUnavailable');
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

  Future<void> _toggleSpeakingInput() async {
    final profile = _selected;
    if (profile == null || _busy || _active == null) return;
    try {
      if (_speech.isListening) {
        await _speech.stop();
        if (mounted) setState(() => _recording = false);
        return;
      }
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onStatus: (status) {
            if (mounted) setState(() => _recording = status == 'listening');
          },
          onError: (_) {
            if (mounted) {
              setState(() {
                _recording = false;
                _speechError = _t.text('speechUnavailable');
              });
            }
          },
        );
      }
      if (!_speechReady) {
        setState(() => _speechError = _t.text('speechUnavailable'));
        return;
      }
      final locales = await _speech.locales();
      final supported = locales.where(
        (locale) => locale.localeId.toLowerCase().startsWith(
          '${profile.languageCode.toLowerCase()}-',
        ),
      );
      await _speech.listen(
        onResult: _onSpeakingResult,
        listenOptions: stt.SpeechListenOptions(
          localeId: supported.firstOrNull?.localeId ?? profile.languageCode,
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
          _speechError = _t.text('speechUnavailable');
        });
      }
    }
  }

  void _onSpeakingResult(SpeechRecognitionResult result) {
    if (!mounted || result.recognizedWords.isEmpty) return;
    setState(() {
      _response.value = TextEditingValue(
        text: result.recognizedWords,
        selection: TextSelection.collapsed(
          offset: result.recognizedWords.length,
        ),
      );
      _speechError = null;
    });
  }

  Widget _chatPanel(LanguageProfile profile) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEEECFF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: _teal),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t.text('askOrta'),
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _t.text('chatHelper'),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_chatMessages.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final turn in _chatMessages.take(12))
            Align(
              alignment: turn.fromStudent
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: turn.fromStudent ? _teal : const Color(0xFFFFF1E2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  turn.text,
                  style: TextStyle(
                    height: 1.4,
                    color: turn.fromStudent ? Colors.white : _ink,
                  ),
                ),
              ),
            ),
        ],
        if (_chatError != null) ...[
          const SizedBox(height: 9),
          Text(
            _chatError!,
            style: const TextStyle(color: Color(0xFF9B5835), fontSize: 13),
          ),
        ],
        if (_chatBusy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 3),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('languageOrtaChatQuestion'),
                controller: _chatQuestion,
                minLines: 1,
                maxLines: 3,
                maxLength: 2000,
                enabled: !_chatBusy,
                onSubmitted: (_) => _askOrta(profile),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: _t.text('questionHint'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: IconButton.filled(
                tooltip: _t.text('send'),
                onPressed: _chatBusy ? null : () => _askOrta(profile),
                style: IconButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _askOrta(LanguageProfile profile) async {
    final question = _chatQuestion.text.trim();
    if (question.isEmpty || _chatBusy) return;
    FocusScope.of(context).unfocus();
    final history = [
      for (final turn in _chatMessages.take(10))
        {'role': turn.fromStudent ? 'user' : 'assistant', 'content': turn.text},
    ];
    setState(() {
      _chatBusy = true;
      _chatError = null;
    });
    try {
      final reply = await (widget.coach ?? LanguagePracticeAi()).chat(
        profile: profile,
        skill: _skill,
        scenario: _scenario,
        message: question,
        interfaceLanguage: widget.locale.languageCode,
        history: history,
        context: widget.approvedContext,
      );
      if (!mounted) return;
      setState(() {
        _chatMessages
          ..add((fromStudent: true, text: question))
          ..add((fromStudent: false, text: reply));
        if (_chatMessages.length > 12) {
          _chatMessages.removeRange(0, _chatMessages.length - 12);
        }
        _chatQuestion.clear();
        _chatBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chatBusy = false;
        _chatError = _t.text('chatUnavailable');
      });
    }
  }

  Widget _results() {
    final result = _result;
    final session = _active;
    if (result == null || session == null) {
      return Text(_t.text('noRecent'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t.text('results'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        _resultBlock(_t.text('original'), result.originalResponse),
        _resultBlock(
          _t.text('corrections'),
          result.aiAvailable
              ? (result.corrections.isEmpty ? '—' : result.corrections)
              : _t.text('aiUnavailable'),
        ),
        if (result.aiAvailable) ...[
          _resultBlock(_t.text('explanation'), result.explanation),
          _resultBlock(_t.text('alternative'), result.alternativePhrasing),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t.text('usefulVocabulary'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (result.vocabulary.isEmpty)
                  const Text('—', style: TextStyle(color: _muted))
                else
                  for (final item in result.vocabulary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${item.term} — ${item.meaning}',
                        style: const TextStyle(color: _ink),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _resultBlock(_t.text('actionable'), result.feedback),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              key: const ValueKey('retryLanguagePractice'),
              onPressed: () {
                _response.clear();
                _active = null;
                _result = null;
                _page = _LanguagePage.studio;
                setState(() {});
                _start();
              },
              child: Text(_t.text('retry')),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _response.clear();
                  _active = null;
                  _result = null;
                  _page = _LanguagePage.studio;
                });
                _start();
              },
              style: FilledButton.styleFrom(backgroundColor: _teal),
              child: Text(_t.text('another')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _progress() {
    final profile = _selected;
    final sessions =
        _sessions
            .where((item) => profile == null || item.profileId == profile.id)
            .where((item) => item.completed)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final vocab = <String>{};
    return FutureBuilder<List<LanguageSessionResult>>(
      future:
          Future.wait(
            sessions.map((session) async {
              final result = await _store.resultFor(session.id);
              return result;
            }),
          ).then(
            (items) => [
              for (final item in items)
                if (item != null) item,
            ],
          ),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const <LanguageSessionResult>[];
        for (final result in results) {
          for (final item in result.vocabulary) {
            if (item.term.trim().isNotEmpty) vocab.add(item.term.trim());
          }
        }
        final strongest = profile == null
            ? null
            : (profile.skillProgress.entries
                      .where(
                        (entry) => _focusSkills.any(
                          (skill) => skill.name == entry.key,
                        ),
                      )
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .firstOrNull;
        final weakest = profile == null
            ? null
            : (_focusSkills
                      .map(
                        (skill) => MapEntry(
                          skill.name,
                          profile.skillProgress[skill.name] ?? 0,
                        ),
                      )
                      .toList()
                    ..sort((a, b) => a.value.compareTo(b.value)))
                  .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t.text('progress'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 14),
            if (profile == null || sessions.isEmpty)
              Text(
                _t.text('emptyProgress'),
                style: const TextStyle(color: _muted),
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric(_t.text('sessionsCompleted'), '${sessions.length}'),
                  _metric(_t.text('vocabularyLearned'), '${vocab.length}'),
                  if (strongest != null)
                    _metric(_t.text('strengths'), _t.text(strongest.key)),
                  if (weakest != null)
                    _metric(_t.text('improve'), _t.text(weakest.key)),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle(_t.text('skillProgress')),
              const SizedBox(height: 10),
              for (final skill in _focusSkills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          _t.text(skill.name),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value:
                                ((profile.skillProgress[skill.name] ?? 0) / 8)
                                    .clamp(0, 1),
                            minHeight: 8,
                            color: _teal,
                            backgroundColor: const Color(0xFFF1DECA),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${profile.skillProgress[skill.name] ?? 0}'),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _sectionTitle(_t.text('historyTitle')),
              const SizedBox(height: 8),
              for (final session in sessions.take(20)) _sessionTile(session),
            ],
          ],
        );
      },
    );
  }

  Widget _metric(String title, String value) => SizedBox(
    width: 180,
    child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _sessionTile(LanguagePracticeSession session) {
    final profile = _profiles
        .where((item) => item.id == session.profileId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _card(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${_t.text(session.skill.name)} · ${_t.text(session.scenario.name)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          subtitle: Text(
            '${profile?.displayName ?? ''} · ${session.status}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _resultBlock(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(
            body.isEmpty ? '—' : body,
            style: const TextStyle(height: 1.45, color: _ink),
          ),
        ],
      ),
    ),
  );

  Widget _skillChip(PracticeSkill skill, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _tintFor(skill),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      '${_t.text(skill.name)} · $count',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    ),
  );

  Color _tintFor(PracticeSkill skill) => switch (skill) {
    PracticeSkill.speaking => const Color(0xFFFFF1E2),
    PracticeSkill.writing => const Color(0xFFEEECFF),
    PracticeSkill.listening => const Color(0xFFE7F3FB),
    PracticeSkill.reading => const Color(0xFFEEF8E8),
    PracticeSkill.vocabulary => const Color(0xFFFFF6E8),
    PracticeSkill.scenario => const Color(0xFFF3EEFF),
    PracticeSkill.conversation => const Color(0xFFE9F8F4),
  };

  Widget _addLanguageButton() => OutlinedButton.icon(
    key: const ValueKey('addLanguageOrta'),
    onPressed: _addLanguage,
    icon: const Icon(Icons.add, size: 16),
    label: Text(_t.text('addLanguage')),
  );

  Widget _sectionTitle(String title, {Widget? action}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (action != null) action,
    ],
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A172B4D),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );

  Future<void> _addLanguage() async {
    final used = _profiles.map((item) => item.languageCode).toSet();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_t.text('addLanguage')),
        children: [
          for (final language in LanguageDefinition.all)
            if (!used.contains(language.code))
              SimpleDialogOption(
                key: ValueKey('addLang_${language.code}'),
                onPressed: () => Navigator.pop(context, language.code),
                child: Text('${language.englishName} · ${language.nativeName}'),
              ),
        ],
      ),
    );
    if (code == null) return;
    final profile = await _store.addLanguage(code);
    await _load();
    if (mounted) setState(() => _selected = profile);
  }

  void _openStudio() => setState(() {
    _page = _LanguagePage.studio;
    _active = null;
    _result = null;
    _response.clear();
  });

  Future<void> _start() async {
    final profile = _selected;
    if (profile == null || _busy) return;
    setState(() => _busy = true);
    try {
      final previous =
          _sessions
              .where(
                (item) => item.profileId == profile.id && item.skill == _skill,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final generated = await (widget.coach ?? LanguagePracticeAi()).start(
        profile: profile,
        skill: _skill,
        scenario: _scenario,
        context: widget.approvedContext,
        previousPrompt: previous.isEmpty
            ? ''
            : '${previous.first.prompt}\n${previous.first.stimulus}',
        variation: previous.length,
      );
      final prompt = generated.prompt;
      final stimulus = generated.stimulus;
      final session = LanguagePracticeSession(
        id: newLanguageId(),
        studentId: widget.studentId,
        profileId: profile.id,
        skill: _skill,
        scenario: _scenario,
        prompt: prompt,
        stimulus: stimulus,
        createdAt: DateTime.now().toUtc(),
      );
      await _store.saveSession(session);
      if (!mounted) return;
      setState(() {
        _active = session;
        _busy = false;
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_t.text('startFailed'))));
    }
  }

  Future<void> _finish() async {
    final profile = _selected;
    final session = _active;
    final text = _response.text.trim();
    if (profile == null || session == null || _busy) return;
    if (text.isEmpty && session.studentResponse.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_t.text('responseRequired'))));
      return;
    }
    setState(() => _busy = true);
    final response = text.isEmpty ? session.studentResponse : text;
    try {
      final feedback = await (widget.coach ?? LanguagePracticeAi()).evaluate(
        profile: profile,
        session: session,
        response: response,
        context: widget.approvedContext,
      );
      final completed = session.copyWith(
        studentResponse: response,
        status: 'completed',
        completedAt: DateTime.now().toUtc(),
        transcript: [
          if (session.transcript.isNotEmpty) session.transcript,
          if (text.isNotEmpty) 'Student: $text',
        ].join('\n'),
      );
      await _store.saveSession(completed);
      final result = LanguageSessionResult(
        id: newLanguageId(),
        sessionId: completed.id,
        studentId: widget.studentId,
        originalResponse: response,
        corrections: feedback.corrections,
        explanation: feedback.explanation,
        alternativePhrasing: feedback.alternativePhrasing,
        vocabulary: feedback.vocabulary,
        feedback: feedback.available
            ? feedback.feedback
            : _t.text('aiUnavailable'),
        aiAvailable: feedback.available,
        createdAt: DateTime.now().toUtc(),
      );
      await _store.saveResult(result);
      if (!mounted) return;
      setState(() {
        _active = completed;
        _result = result;
        _busy = false;
        _page = _LanguagePage.results;
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_t.text('finishFailed'))));
    }
  }
}

class _ProfileForm extends StatefulWidget {
  final LanguageProfile profile;
  final LanguageOrtaStrings strings;
  final Future<void> Function(LanguageProfile) onSave;
  const _ProfileForm({
    super.key,
    required this.profile,
    required this.strings,
    required this.onSave,
  });
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late String _current = widget.profile.currentLevel;
  late String _target = widget.profile.targetLevel;
  late final TextEditingController _goals = TextEditingController(
    text: widget.profile.goals,
  );
  late Set<String> _areas = {...widget.profile.preferredAreas};

  @override
  void dispose() {
    _goals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${strings.text('profile')} · ${widget.profile.displayName}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _current,
          decoration: InputDecoration(labelText: strings.text('currentLevel')),
          items: [
            for (final level in languageOrtaLevels)
              DropdownMenuItem(value: level, child: Text(level)),
          ],
          onChanged: (value) => setState(() => _current = value!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _target,
          decoration: InputDecoration(labelText: strings.text('targetLevel')),
          items: [
            for (final level in languageOrtaLevels)
              DropdownMenuItem(value: level, child: Text(level)),
          ],
          onChanged: (value) => setState(() => _target = value!),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('languageGoals'),
          controller: _goals,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: strings.text('goals'),
            hintText: strings.text('goalsHint'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          strings.text('preferredAreas'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final skill in _focusSkills)
              FilterChip(
                label: Text(strings.text(skill.name)),
                selected: _areas.contains(skill.name),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _areas.add(skill.name);
                  } else {
                    _areas.remove(skill.name);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('saveLanguageProfile'),
          onPressed: () => widget.onSave(
            widget.profile.copyWith(
              currentLevel: _current,
              targetLevel: _target,
              goals: _goals.text.trim(),
              preferredAreas: _areas.toList(),
            ),
          ),
          style: FilledButton.styleFrom(backgroundColor: _teal),
          child: Text(strings.text('saveProfile')),
        ),
      ],
    );
  }
}
