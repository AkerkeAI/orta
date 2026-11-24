import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/orta_app.dart';
import 'app/theme/app_theme.dart';
import 'models/language.dart';
import 'models/language_orta_models.dart';
import 'screens/language_orta/language_orta_workspace.dart';
import 'services/language_orta_access.dart';
import 'services/language_orta_store.dart';
import 'services/language_practice_ai.dart';
import 'services/localization_service.dart';
import 'services/admissions_strings.dart';
import 'services/interface_language.dart';
import 'services/storage_service.dart';

bool _supabaseConfigured = false;
const _ortaViolet = Color(0xFF403B9D);
const _ortaVioletDeep = Color(0xFF292660);
const _ortaSandInk = Color(0xFF965C31);
const _ortaInk = Color(0xFF24233A);
const _ortaMuted = Color(0xFF77758D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    _supabaseConfigured = true;
  }
  runApp(const OrtaAppWrapper());
}

class OrtaAppWrapper extends StatelessWidget {
  const OrtaAppWrapper({super.key, this.storage});

  final LifeDataStorage? storage;

  @override
  Widget build(BuildContext context) => _AppLocaleHost(storage: storage);
}

Locale? _activeAppLocale;

class _AppLocaleHost extends StatefulWidget {
  const _AppLocaleHost({this.storage});
  final LifeDataStorage? storage;

  @override
  State<_AppLocaleHost> createState() => _AppLocaleHostState();
}

class _AppLocaleHostState extends State<_AppLocaleHost> {
  void _setLocale(Locale? locale) => setState(() => _activeAppLocale = locale);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ORTA Admissions',
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: [
      const AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ru'), Locale('kk')],
    locale: _activeAppLocale,
    home: widget.storage != null
        ? OrtaApp(storage: widget.storage!)
        : _AdmissionsEntry(onLocaleChanged: _setLocale),
  );
}

class _AdmissionsEntry extends StatefulWidget {
  const _AdmissionsEntry({required this.onLocaleChanged});
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<_AdmissionsEntry> createState() => _AdmissionsEntryState();
}

class _AdmissionsEntryState extends State<_AdmissionsEntry> {
  String? _loadedUserId;
  Map<String, dynamic>? _loadedProfile;
  int _profileLoadAttempt = 0;

  void _syncLocale(Locale? locale) {
    if (locale == null) return;
    final profile = _loadedProfile;
    if (profile != null) {
      _loadedProfile = {...profile, 'interface_language': locale.languageCode};
    }
    widget.onLocaleChanged(locale);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supabaseConfigured) return const _ConfigurationRequired();
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          _loadedUserId = null;
          _loadedProfile = null;
          _activeAppLocale = null;
          return _SignInPage(onLocaleChanged: widget.onLocaleChanged);
        }
        if (_loadedUserId == userId &&
            _loadedProfile != null &&
            _activeAppLocale != null) {
          return _RoleWorkspace(
            key: ValueKey(
              'workspace-$userId-${_activeAppLocale!.languageCode}',
            ),
            profile: _loadedProfile!,
            onLocaleChanged: _syncLocale,
          );
        }
        return FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('profile-$userId-$_profileLoadAttempt'),
          future: Supabase.instance.client
              .from('profiles')
              .select('role, full_name, interface_language')
              .eq('id', userId)
              .single(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AdmissionsStrings(
                            AppLocaleExtension.fromLanguageCode(
                              _activeAppLocale?.languageCode ?? 'en',
                            ),
                          ).text('profileError'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _profileLoadAttempt++),
                          child: Text(
                            AdmissionsStrings(
                              AppLocaleExtension.fromLanguageCode(
                                _activeAppLocale?.languageCode ?? 'en',
                              ),
                            ).text('retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final profile = profileSnapshot.data!;
            if (profile['app_mode'] == null && profile['role'] == 'student') {
              return _ModeChooser(
                onChoose: (mode) async {
                  await Supabase.instance.client.rpc('select_orta_mode', params: {'p_mode': mode});
                  if (mounted) setState(() { _loadedUserId = null; _loadedProfile = null; _profileLoadAttempt++; });
                },
              );
            }
            final locale = interfaceLocaleFromProfile(profile);
            final language = LanguageExtension.fromCode(locale.languageCode);
            _loadedUserId = userId;
            _loadedProfile = profile;
            _activeAppLocale = locale;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncLocale(_activeAppLocale);
            });
            return _RoleWorkspace(
              key: ValueKey('workspace-$userId-${language.code}'),
              profile: profile,
              onLocaleChanged: _syncLocale,
            );
          },
        );
      },
    );
  }
}

class _ConfigurationRequired extends StatelessWidget {
  const _ConfigurationRequired();

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleExtension.fromLanguageCode(
      Localizations.localeOf(context).languageCode,
    );
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AdmissionsStrings(locale).text('setup')),
        ),
      ),
    );
  }
}

class _SignInPage extends StatefulWidget {
  const _SignInPage({required this.onLocaleChanged});
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _invite = TextEditingController();
  bool _register = false;
  Language _interfaceLanguage = Language.english;
  bool _busy = false;
  String? _message;

  AdmissionsStrings get _strings =>
      AdmissionsStrings(AppLocaleExtension.fromLanguage(_interfaceLanguage));

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo:
              Uri.base.scheme == 'http' || Uri.base.scheme == 'https'
              ? Uri.base.origin
              : null,
          data: {
            'full_name': _name.text.trim(),
            'invite_code': _invite.text.trim(),
            'interface_language': _interfaceLanguage.code,
          },
        );
        if (mounted) {
          setState(() => _message = _strings.text('checkEmail'));
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (_) {
      if (mounted) setState(() => _message = _strings.text('signInFailed'));
    } catch (_) {
      if (mounted) {
        setState(() => _message = _strings.text('connectionError'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _invite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F5FC),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_rounded, size: 42, color: _ortaViolet),
                    const SizedBox(height: 10),
                    const Text(
                      'ORTA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _ortaInk,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _register
                          ? _strings.text('join')
                          : _strings.text('welcome'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: _ortaMuted),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<Language>(
                      initialValue: _interfaceLanguage,
                      decoration: InputDecoration(
                        labelText: _strings.text('language'),
                      ),
                      items: [
                        for (final language in Language.values)
                          DropdownMenuItem(
                            value: language,
                            child: Text(language.displayName),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _interfaceLanguage = value);
                        widget.onLocaleChanged(Locale(value.code));
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_register) ...[
                      TextField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: _strings.text('name'),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _invite,
                        decoration: InputDecoration(
                          labelText: _strings.text('invite'),
                          helperText: _strings.text('inviteHelp'),
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _strings.text('email'),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _strings.text('password'),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: const TextStyle(color: _ortaMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? _strings.text('wait')
                            : _register
                            ? _strings.text('create')
                            : _strings.text('signIn'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _register = !_register;
                              _message = null;
                            }),
                      child: Text(
                        _register
                            ? _strings.text('switchToSignIn')
                            : _strings.text('switchToCreate'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoleWorkspace extends StatelessWidget {
  const _RoleWorkspace({
    super.key,
    required this.profile,
    required this.onLocaleChanged,
  });
  final Map<String, dynamic> profile;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final role = profile['role'] as String;
    final name = profile['full_name'] as String? ?? '';
    final language = LanguageExtension.fromCode(
      profile['interface_language'] as String? ?? 'en',
    );
    if (profile['app_mode'] == 'personal') {
      return _PersonalEntry(profile: profile, onLocaleChanged: onLocaleChanged);
    }
    return _LiveRoleDashboard(
      key: ValueKey(language.code),
      role: role,
      name: name,
      interfaceLanguage: language,
      onLocaleChanged: onLocaleChanged,
    );
  }
}

class _ModeChooser extends StatelessWidget {
  const _ModeChooser({required this.onChoose});
  final Future<void> Function(String mode) onChoose;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520), child: Padding(padding: const EdgeInsets.all(28), child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Choose your ORTA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: () => _choose(context, 'personal'), icon: const Icon(Icons.person_outline), label: const Text('Personal ORTA')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => _choose(context, 'academy'), icon: const Icon(Icons.school_outlined), label: const Text('ORTA Academy')),
      ],
    )),
  )));
  Future<void> _choose(BuildContext context, String mode) async {
    try { await onChoose(mode); }
    catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save your choice: $error'))); }
  }
}

class _PersonalEntry extends StatefulWidget {
  const _PersonalEntry({required this.profile, required this.onLocaleChanged});
  final Map<String, dynamic> profile;
  final ValueChanged<Locale> onLocaleChanged;
  @override State<_PersonalEntry> createState() => _PersonalEntryState();
}
class _PersonalEntryState extends State<_PersonalEntry> {
  final _code = TextEditingController(); String? _error; bool _busy = false;
  @override void dispose() { _code.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Stack(children: [
    OrtaApp(),
    Positioned(right: 16, top: 16, child: SafeArea(child: TextButton.icon(
      onPressed: _busy ? null : () async {
        final code = await showDialog<String>(context: context, builder: (context) => AlertDialog(
          title: const Text('Activate ORTA Academy'), content: TextField(controller: _code, decoration: InputDecoration(labelText: 'Founder code', errorText: _error)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, _code.text), child: const Text('Activate'))],
        ));
        if (code == null || !mounted) return;
        setState(() { _busy = true; _error = null; });
        try {
          final ok = await Supabase.instance.client.rpc('activate_orta_academy', params: {'p_code': code});
          if (ok == true && mounted) { setState(() {}); } else if (mounted) { setState(() => _error = 'Code is invalid, expired, or already used.'); }
        } catch (_) { if (mounted) setState(() => _error = 'Could not validate code. Please try again.'); }
        if (mounted) setState(() => _busy = false);
      }, icon: const Icon(Icons.school_outlined), label: Text(_busy ? 'Checking…' : 'Activate Academy'),
    ))),
  ]);
}

class _LiveRoleDashboard extends StatefulWidget {
  const _LiveRoleDashboard({
    super.key,
    required this.role,
    required this.name,
    required this.interfaceLanguage,
    required this.onLocaleChanged,
  });
  final String role;
  final String name;
  final Language interfaceLanguage;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<_LiveRoleDashboard> createState() => _LiveRoleDashboardState();
}

class _LiveRoleDashboardState extends State<_LiveRoleDashboard> {
  String? _section;
  bool _busy = false;
  late Language _interfaceLanguage = widget.interfaceLanguage;
  AdmissionsStrings get _strings =>
      AdmissionsStrings(AppLocaleExtension.fromLanguage(_interfaceLanguage));
  String _label(String value) => _strings.text(value);

  List<String> get _sections => switch (widget.role) {
    'founder' => [
      'Students',
      'Applications',
      'Consultations',
      'Enrollments',
      'Universities',
      'Finance',
      'Opportunities',
      'Invitations',
    ],
    'student' => LanguageOrtaAccess.studentSections([
      'My applications',
      'Consultations',
      'Tasks',
      'Achievements',
      'Opportunities',
      'Payments',
    ]),
    'mentor' => ['My students', 'Consultations', 'My earnings'],
    'parent' => ['Refund requests', 'Payments'],
    _ => ['My profile'],
  };

  String get _activeSection => _section ?? _sections.first;

  dynamic _query() {
    final client = Supabase.instance.client;
    final id = client.auth.currentUser!.id;
    return switch (_activeSection) {
      'Students' =>
        client
            .from('students')
            .select(
              'id, grade, countries, profile_complete, profile:profiles!students_id_fkey(full_name)',
            ),
      'My applications' =>
        client
            .from('applications')
            .select('id, status, deadline, university_id')
            .eq('student_id', id),
      'Applications' =>
        client
            .from('applications')
            .select(
              'id, student_id, status, deadline, unconditional_offer_verified, university:universities!applications_university_id_fkey(name)',
            ),
      'Consultations' when widget.role == 'mentor' =>
        client
            .from('lessons')
            .select('id, student_id, scheduled_at, status')
            .eq('mentor_id', id),
      'Consultations' when widget.role == 'student' =>
        client
            .from('lessons')
            .select('id, scheduled_at, status, service_kind')
            .eq('student_id', id),
      'Consultations' =>
        client
            .from('lessons')
            .select('id, student_id, scheduled_at, status, service_kind'),
      'Enrollments' =>
        client
            .from('enrollments')
            .select(
              'id, student_id, program, start_date, planned_expert_consultations',
            ),
      'Universities' =>
        client
            .from('universities')
            .select('id, name, country, official_url, source_verified_at'),
      'Finance' =>
        client
            .from('payments')
            .select(
              'id, student_id, payment_kind, amount_kzt, status, recorded_at',
            ),
      'Payments' when widget.role == 'parent' =>
        client
            .from('payments')
            .select(
              'id, student_id, payment_kind, amount_kzt, status, recorded_at',
            )
            .eq('guardian_id', id),
      'Payments' =>
        client
            .from('payments')
            .select('id, payment_kind, amount_kzt, status, recorded_at')
            .eq('student_id', id),
      'Opportunities' =>
        client
            .from('opportunities')
            .select(
              'id, title, organization, deadline, official_url, source_verified_at',
            ),
      'Invitations' =>
        client
            .from('registration_invites')
            .select('id, code, email, role, expires_at, used_at'),
      'My students' =>
        client
            .from('student_mentors')
            .select('student_id, specialization, assigned_at')
            .eq('mentor_id', id),
      'My earnings' =>
        client
            .from('mentor_earnings')
            .select('id, lesson_id, amount_kzt, earned_at, paid_out_at')
            .eq('mentor_id', id),
      'Refund requests' =>
        client
            .from('refund_requests')
            .select(
              'id, student_id, status, requested_at, calculated_refund_kzt',
            )
            .eq('guardian_id', id),
      'Tasks' =>
        client
            .from('tasks')
            .select('id, title, due_date, completed_at')
            .eq('student_id', id),
      'Achievements' =>
        client
            .from('achievements')
            .select('id, title, category, achieved_on')
            .eq('student_id', id),
      _ =>
        client
            .from('students')
            .select('id, grade, countries, intended_majors, english_level')
            .eq('id', id),
    };
  }

  Future<void> _createInvite() async {
    final emailController = TextEditingController();
    var inviteRole = 'student';
    final request = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_strings.text('inviteTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: inviteRole,
                decoration: InputDecoration(
                  labelText: _strings.text('workspaceRole'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'student',
                    child: Text(_strings.text('studentRole')),
                  ),
                  DropdownMenuItem(
                    value: 'mentor',
                    child: Text(_strings.text('mentorRole')),
                  ),
                  DropdownMenuItem(
                    value: 'parent',
                    child: Text(_strings.text('parentRole')),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => inviteRole = value ?? 'student'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _strings.text('emailOptional'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_strings.text('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'role': inviteRole,
                'email': emailController.text.trim(),
              }),
              child: Text(_strings.text('createInvite')),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
    if (request == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await Supabase.instance.client.rpc(
        'create_registration_invite',
        params: {'p_role': request['role'], 'p_email': request['email']},
      ) as List;
      final row = Map<String, dynamic>.from(result.first as Map);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_strings.text('inviteCreated')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_strings.text('shareCode')),
              const SizedBox(height: 12),
              SelectableText(
                row['code'].toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _strings.text('expires', {
                  'date': row['expires_at'].toString(),
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_strings.text('done')),
            ),
          ],
        ),
      );
      if (mounted) setState(() => _section = 'Invitations');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _strings.text('inviteFailed', {'error': error.toString()}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeLesson(String lessonId) async {
    try {
      await Supabase.instance.client
          .from('lessons')
          .update({
            'status': 'conducted',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', lessonId);
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _strings.text('lessonFailed', {'error': error.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmLesson(
    String lessonId, {
    required bool confirmed,
  }) async {
    final reasonController = TextEditingController();
    if (!confirmed) {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_strings.text('disputeTitle')),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _strings.text('reviewPrompt'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_strings.text('cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, reasonController.text.trim()),
              child: Text(_strings.text('sendReview')),
            ),
          ],
        ),
      );
      reasonController.dispose();
      if (reason == null || reason.isEmpty || !mounted) return;
      try {
        await Supabase.instance.client.from('lesson_confirmations').insert({
          'lesson_id': lessonId,
          'student_id': Supabase.instance.client.auth.currentUser!.id,
          'confirmed': false,
          'dispute_reason': reason,
        });
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _strings.text('disputeFailed', {'error': error.toString()}),
              ),
            ),
          );
        }
      }
    } else {
      try {
        await Supabase.instance.client.from('lesson_confirmations').insert({
          'lesson_id': lessonId,
          'student_id': Supabase.instance.client.auth.currentUser!.id,
          'confirmed': true,
        });
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _strings.text('confirmFailed', {'error': error.toString()}),
              ),
            ),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<ApprovedLanguageContext> _approvedLanguageContext() async {
    final client = Supabase.instance.client;
    final id = client.auth.currentUser?.id;
    if (id == null) return const ApprovedLanguageContext();
    try {
      final student = await client
          .from('students')
          .select('intended_majors')
          .eq('id', id)
          .maybeSingle();
      final applications = await client
          .from('applications')
          .select('id')
          .eq('student_id', id)
          .limit(1);
      String? major;
      final majors = student?['intended_majors'];
      if (majors is List && majors.isNotEmpty) {
        major = majors.first?.toString();
      } else if (majors is String && majors.trim().isNotEmpty) {
        major = majors.trim();
      }
      return ApprovedLanguageContext(
        intendedMajor: major,
        preparingUniversity: (applications as List).isNotEmpty,
      );
    } catch (_) {
      return const ApprovedLanguageContext();
    }
  }

  Widget _languageOrta() {
    final client = Supabase.instance.client;
    final studentId = client.auth.currentUser!.id;
    return FutureBuilder<ApprovedLanguageContext>(
      future: _approvedLanguageContext(),
      builder: (context, snapshot) => LanguageOrtaWorkspace(
        role: widget.role,
        studentId: studentId,
        studentName: widget.name,
        locale: AppLocaleExtension.fromLanguage(_interfaceLanguage),
        store: LanguageOrtaAccess.canOpenRole(widget.role)
            ? SupabaseLanguageOrtaStore(
                client: client,
                studentId: studentId,
                role: widget.role,
              )
            : const DeniedLanguageOrtaStore(),
        coach: LanguagePracticeAi(
          accessToken: client.auth.currentSession?.accessToken,
        ),
        approvedContext: snapshot.data ?? const ApprovedLanguageContext(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final title = _activeSection;
    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<String>(
          initialValue: _activeSection,
          onSelected: (value) => setState(() => _section = value),
          itemBuilder: (_) => [
            for (final section in _sections)
              PopupMenuItem(value: section, child: Text(_label(section))),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(_label(title)), const Icon(Icons.arrow_drop_down)],
          ),
        ),
        actions: [
          if (widget.role == 'founder')
            IconButton(
              tooltip: _strings.text('inviteUser'),
              onPressed: _busy ? null : _createInvite,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          PopupMenuButton<Language>(
            tooltip: _strings.text('language'),
            initialValue: _interfaceLanguage,
            onSelected: _saveInterfaceLanguage,
            itemBuilder: (_) => [
              for (final language in Language.values)
                PopupMenuItem(
                  value: language,
                  child: Text(language.displayName),
                ),
            ],
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: _strings.text('signOut'),
            onPressed: () => client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _activeSection == LanguageOrtaAccess.moduleName
            ? KeyedSubtree(
                key: const ValueKey('language-orta'),
                child: _languageOrta(),
              )
            : FutureBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(_activeSection),
                future: _query(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        _strings.text('couldNotLoad', {
                          'section': _label(title),
                        }),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snapshot.data!;
                  return ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(23),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6EB),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFFF1E3D1)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4A779)
                                  .withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _WarmRoadPainter(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.name.isEmpty
                                          ? _strings.text('welcomeNoName')
                                          : _strings.text('welcomeName', {
                                              'name': widget.name,
                                            }),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        height: 1.18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: _ortaVioletDeep,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      _label(title),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _ortaSandInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: _ortaViolet.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.route_rounded,
                                  color: _ortaViolet,
                                  size: 27,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _label(title),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: _ortaInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1DECA),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '${rows.length}',
                              style: const TextStyle(
                                color: _ortaSandInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (rows.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(_strings.text('workspaceReady')),
                          ),
                        ),
                      if (_busy) const LinearProgressIndicator(),
                      for (final row in rows) ...[
                        TweenAnimationBuilder<double>(
                          key: ValueKey('$_activeSection-${row['id']}'),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 11),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 7,
                              ),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1DECA),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  widget.role == 'founder'
                                      ? Icons.school_rounded
                                      : widget.role == 'mentor'
                                      ? Icons.event_note_rounded
                                      : Icons.description_rounded,
                                  color: _ortaSandInk,
                                ),
                              ),
                              title: Text(_rowTitle(row, title)),
                              subtitle: Text(
                                row.entries
                                    .where(
                                      (e) => e.key != 'id' && e.value != null,
                                    )
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing:
                                  widget.role == 'mentor' &&
                                      title == 'Consultations' &&
                                      row['status'] == 'scheduled'
                                  ? TextButton(
                                      onPressed: () =>
                                          _completeLesson(row['id'] as String),
                                      child: Text(
                                        _strings.text('markConducted'),
                                      ),
                                    )
                                  : widget.role == 'student' &&
                                        title == 'Consultations' &&
                                        row['status'] == 'conducted'
                                  ? Wrap(
                                      children: [
                                        TextButton(
                                          onPressed: () => _confirmLesson(
                                            row['id'] as String,
                                            confirmed: true,
                                          ),
                                          child: Text(_strings.text('confirm')),
                                        ),
                                        TextButton(
                                          onPressed: () => _confirmLesson(
                                            row['id'] as String,
                                            confirmed: false,
                                          ),
                                          child: Text(_strings.text('dispute')),
                                        ),
                                      ],
                                    )
                                  : widget.role == 'founder' &&
                                        title == 'Applications' &&
                                        row['status'] ==
                                            'unconditional_offer' &&
                                        row['unconditional_offer_verified'] !=
                                            true
                                  ? TextButton(
                                      onPressed: () async {
                                        await client.rpc(
                                          'verify_unconditional_offer',
                                          params: {
                                            'p_application_id': row['id'],
                                          },
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      child: Text(_strings.text('verifyOffer')),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<void> _saveInterfaceLanguage(Language language) async {
    try {
      final locale = await persistInterfaceLanguage(
        language,
        persist: (code) async {
          await Supabase.instance.client
              .from('profiles')
              .update({'interface_language': code})
              .eq('id', Supabase.instance.client.auth.currentUser!.id)
              .select('id')
              .single();
        },
      );
      if (mounted) {
        setState(() => _interfaceLanguage = language);
        widget.onLocaleChanged(locale);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AdmissionsStrings(AppLocaleExtension.fromLanguage(language))
                  .text('languageSaved'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_strings.text('languageFailed'))),
        );
      }
    }
  }

  String _rowTitle(Map<String, dynamic> row, String fallback) {
    if (widget.role == 'founder' && fallback == 'Students') {
      final profile = row['profile'];
      if (profile is Map &&
          profile['full_name'] is String &&
          (profile['full_name'] as String).isNotEmpty) {
        return profile['full_name'] as String;
      }
    }
    final university = row['university'];
    if (university is Map && university['name'] is String) {
      return university['name'] as String;
    }
    return (row['title'] ?? row['name'] ?? row['status'] ?? fallback)
        .toString();
  }
}

class _WarmRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(size.width * 0.78, size.height * 1.1)
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.72,
        size.width * 1.02,
        size.height * 0.46,
        size.width * 0.82,
        size.height * -0.1,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFD7A878).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFC98750).withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    final dotPaint = Paint()
      ..color = const Color(0xFFC98750).withValues(alpha: 0.65);
    for (final metric in route.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 11) {
        final point = metric.getTangentForOffset(distance)?.position;
        if (point != null) canvas.drawCircle(point, 1.7, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WarmRoadPainter oldDelegate) => false;
}
