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
import 'services/storage_service.dart';

bool _supabaseConfigured = false;

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
    home: storage != null
        ? OrtaApp(storage: storage)
        : const _AdmissionsEntry(),
  );
}

class _AdmissionsEntry extends StatelessWidget {
  const _AdmissionsEntry();

  @override
  Widget build(BuildContext context) {
    if (!_supabaseConfigured) return const _ConfigurationRequired();
    return const _SupabaseAuthGate();
  }
}

class _ConfigurationRequired extends StatelessWidget {
  const _ConfigurationRequired();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('ORTA requires Supabase configuration to sign in.'),
      ),
    ),
  );
}

class _SupabaseAuthGate extends StatelessWidget {
  const _SupabaseAuthGate();

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return const _SignInPage();
      return _RoleWorkspace(userId: session.user.id);
    },
  );
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

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
          setState(() => _message = 'Check your email to verify your account.');
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _message = 'Could not connect. Check your details and try again.',
        );
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
    backgroundColor: const Color(0xFFF5F7FB),
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
                    const Icon(
                      Icons.hub_rounded,
                      size: 42,
                      color: Color(0xFF4568F5),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ORTA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Color(0xFF172B4D),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _register
                          ? 'Join your admissions workspace'
                          : 'Your admissions journey, together',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7890),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_register) ...[
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _invite,
                        decoration: const InputDecoration(
                          labelText: 'ORTA invitation code',
                          helperText:
                              'Enter the code sent by your ORTA Founder.',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Language>(
                        initialValue: _interfaceLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Interface language',
                        ),
                        items: [
                          for (final language in Language.values)
                            DropdownMenuItem(
                              value: language,
                              child: Text(language.displayName),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _interfaceLanguage = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xFF6B7890),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : _register
                            ? 'Create account'
                            : 'Sign in',
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
                            ? 'Already have an account? Sign in'
                            : 'Have an invitation code? Create account',
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
  const _RoleWorkspace({required this.userId});
  final String userId;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'We could not load your ORTA profile. Contact your Founder or try again.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final profile = snapshot.data!.first;
      final role = profile['role'] as String;
      final name = profile['full_name'] as String? ?? '';
      final language = LanguageExtension.fromCode(
        profile['interface_language'] as String? ?? 'en',
      );
      return _LiveRoleDashboard(
        key: ValueKey(language.code),
        role: role,
        name: name,
        interfaceLanguage: language,
      );
    },
  );
}

class _LiveRoleDashboard extends StatefulWidget {
  const _LiveRoleDashboard({
    super.key,
    required this.role,
    required this.name,
    required this.interfaceLanguage,
  });
  final String role;
  final String name;
  final Language interfaceLanguage;

  @override
  State<_LiveRoleDashboard> createState() => _LiveRoleDashboardState();
}

class _LiveRoleDashboardState extends State<_LiveRoleDashboard> {
  String? _section;
  bool _busy = false;

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
          title: const Text('Invite to ORTA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: inviteRole,
                decoration: const InputDecoration(labelText: 'Workspace role'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'mentor', child: Text('Mentor')),
                  DropdownMenuItem(
                    value: 'parent',
                    child: Text('Parent / guardian'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => inviteRole = value ?? 'student'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'role': inviteRole,
                'email': emailController.text.trim(),
              }),
              child: const Text('Create invite'),
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
          title: const Text('Invitation created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share this one-time code with the invited person:'),
              const SizedBox(height: 12),
              SelectableText(
                row['code'].toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Expires ${row['expires_at']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) setState(() => _section = 'Invitations');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite could not be created: $error')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lesson update failed: $error')));
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
          title: const Text('Dispute consultation'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What should the Founder review?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, reasonController.text.trim()),
              child: const Text('Send for review'),
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
            SnackBar(content: Text('Could not submit dispute: $error')),
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
            SnackBar(content: Text('Could not confirm consultation: $error')),
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
              PopupMenuItem(value: section, child: Text(section)),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(title), const Icon(Icons.arrow_drop_down)],
          ),
        ),
        actions: [
          if (widget.role == 'founder')
            IconButton(
              tooltip: 'Invite user',
              onPressed: _busy ? null : _createInvite,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          PopupMenuButton<Language>(
            tooltip: 'Interface language',
            initialValue: widget.interfaceLanguage,
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
            tooltip: 'Sign out',
            onPressed: () => client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _activeSection == LanguageOrtaAccess.moduleName
          ? _languageOrta()
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _query(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Could not load $title.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      widget.name.isEmpty
                          ? 'Welcome to ORTA'
                          : 'Welcome, ${widget.name}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$title · ${rows.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (rows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Your ORTA workspace is ready. Records will appear here when they are added.',
                          ),
                        ),
                      ),
                    if (_busy) const LinearProgressIndicator(),
                    for (final row in rows) ...[
                      Card(
                        child: ListTile(
                          leading: Icon(
                            widget.role == 'founder'
                                ? Icons.school_outlined
                                : widget.role == 'mentor'
                                ? Icons.event_note_outlined
                                : Icons.description_outlined,
                            color: const Color(0xFF4568F5),
                          ),
                          title: Text(_rowTitle(row, title)),
                          subtitle: Text(
                            row.entries
                                .where((e) => e.key != 'id')
                                .map((e) => '${e.key}: ${e.value}')
                                .join(' · '),
                          ),
                          trailing:
                              widget.role == 'mentor' &&
                                  title == 'Consultations' &&
                                  row['status'] == 'scheduled'
                              ? TextButton(
                                  onPressed: () =>
                                      _completeLesson(row['id'] as String),
                                  child: const Text('Mark conducted'),
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
                                      child: const Text('Confirm'),
                                    ),
                                    TextButton(
                                      onPressed: () => _confirmLesson(
                                        row['id'] as String,
                                        confirmed: false,
                                      ),
                                      child: const Text('Dispute'),
                                    ),
                                  ],
                                )
                              : widget.role == 'founder' &&
                                    title == 'Applications' &&
                                    row['status'] == 'unconditional_offer' &&
                                    row['unconditional_offer_verified'] != true
                              ? TextButton(
                                  onPressed: () async {
                                    await client.rpc(
                                      'verify_unconditional_offer',
                                      params: {'p_application_id': row['id']},
                                    );
                                    if (mounted) setState(() {});
                                  },
                                  child: const Text('Verify offer'),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Future<void> _saveInterfaceLanguage(Language language) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'interface_language': language.code})
          .eq('id', Supabase.instance.client.auth.currentUser!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interface language saved.')),
        );
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save interface language.')),
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
