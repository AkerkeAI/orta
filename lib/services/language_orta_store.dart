import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/language_definition.dart';
import '../models/language_orta_models.dart';
import 'language_orta_access.dart';

abstract class LanguageOrtaStore {
  Future<List<LanguageProfile>> profiles();
  Future<LanguageProfile> addLanguage(String languageCode);
  Future<LanguageProfile> saveProfile(LanguageProfile profile);
  Future<List<LanguagePracticeSession>> sessions({String? profileId});
  Future<LanguagePracticeSession> saveSession(LanguagePracticeSession session);
  Future<LanguageSessionResult> saveResult(LanguageSessionResult result);
  Future<LanguageSessionResult?> resultFor(String sessionId);
}

String newLanguageId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class MemoryLanguageSnapshotStore {
  LanguageOrtaSnapshot snapshot;
  MemoryLanguageSnapshotStore([this.snapshot = const LanguageOrtaSnapshot()]);
}

class StudentLanguageOrtaStore implements LanguageOrtaStore {
  final String studentId;
  final String role;
  final MemoryLanguageSnapshotStore memory;
  final SharedPreferences? prefs;
  final String? prefsKey;

  StudentLanguageOrtaStore({
    required this.studentId,
    required this.role,
    MemoryLanguageSnapshotStore? memory,
    this.prefs,
    this.prefsKey,
  }) : memory = memory ?? MemoryLanguageSnapshotStore() {
    LanguageOrtaAccess.assertStudent(role: role, studentId: studentId);
  }

  LanguageOrtaSnapshot get _data {
    LanguageOrtaAccess.assertStudent(role: role, studentId: studentId);
    return memory.snapshot;
  }

  Future<void> _commit(LanguageOrtaSnapshot next) async {
    LanguageOrtaAccess.assertStudent(role: role, studentId: studentId);
    for (final profile in next.profiles) {
      if (profile.studentId != studentId) {
        throw const LanguageOrtaDenied(
          'Students can only save their own language data.',
        );
      }
    }
    for (final session in next.sessions) {
      if (session.studentId != studentId) {
        throw const LanguageOrtaDenied(
          'Students can only save their own language data.',
        );
      }
    }
    for (final result in next.results) {
      if (result.studentId != studentId) {
        throw const LanguageOrtaDenied(
          'Students can only save their own language data.',
        );
      }
    }
    memory.snapshot = next;
    final key = prefsKey;
    if (prefs != null && key != null) {
      await prefs!.setString(key, jsonEncode(next.toJson()));
    }
  }

  static LanguageOrtaSnapshot loadFromPrefs(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const LanguageOrtaSnapshot();
    return LanguageOrtaSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  @override
  Future<List<LanguageProfile>> profiles() async => List.unmodifiable(
    _data.profiles.where((item) => item.studentId == studentId),
  );

  @override
  Future<LanguageProfile> addLanguage(String languageCode) async {
    final existing = _data.profiles.where(
      (item) =>
          item.studentId == studentId && item.languageCode == languageCode,
    );
    if (existing.isNotEmpty) return existing.first;
    final definition = LanguageDefinition.byCode(languageCode);
    final profile = LanguageProfile(
      id: newLanguageId(),
      studentId: studentId,
      languageCode: languageCode,
      languageName: definition.englishName,
      updatedAt: DateTime.now().toUtc(),
    );
    await _commit(
      LanguageOrtaSnapshot(
        profiles: [..._data.profiles, profile],
        sessions: _data.sessions,
        results: _data.results,
      ),
    );
    return profile;
  }

  @override
  Future<LanguageProfile> saveProfile(LanguageProfile profile) async {
    if (profile.studentId != studentId) {
      throw const LanguageOrtaDenied(
        'Students can only save their own language data.',
      );
    }
    final next = [
      for (final item in _data.profiles)
        if (item.id == profile.id)
          profile.copyWith(updatedAt: DateTime.now().toUtc())
        else
          item,
    ];
    if (!next.any((item) => item.id == profile.id)) {
      next.add(profile.copyWith(updatedAt: DateTime.now().toUtc()));
    }
    await _commit(
      LanguageOrtaSnapshot(
        profiles: next,
        sessions: _data.sessions,
        results: _data.results,
      ),
    );
    return (await profiles()).firstWhere((item) => item.id == profile.id);
  }

  @override
  Future<List<LanguagePracticeSession>> sessions({String? profileId}) async {
    return List.unmodifiable(
      _data.sessions.where(
        (item) =>
            item.studentId == studentId &&
            (profileId == null || item.profileId == profileId),
      ),
    );
  }

  @override
  Future<LanguagePracticeSession> saveSession(
    LanguagePracticeSession session,
  ) async {
    if (session.studentId != studentId) {
      throw const LanguageOrtaDenied(
        'Students can only save their own language data.',
      );
    }
    final next = [
      for (final item in _data.sessions)
        if (item.id == session.id) session else item,
    ];
    if (!next.any((item) => item.id == session.id)) next.add(session);
    final previous = _data.sessions.where((item) => item.id == session.id);
    final newlyCompleted =
        session.completed && (previous.isEmpty || !previous.first.completed);
    var profiles = _data.profiles;
    if (newlyCompleted) {
      profiles = [
        for (final profile in profiles)
          if (profile.id == session.profileId)
            profile.copyWith(
              skillProgress: {
                ...profile.skillProgress,
                session.skill.name:
                    (profile.skillProgress[session.skill.name] ?? 0) + 1,
              },
              updatedAt: DateTime.now().toUtc(),
            )
          else
            profile,
      ];
    }
    await _commit(
      LanguageOrtaSnapshot(
        profiles: profiles,
        sessions: next,
        results: _data.results,
      ),
    );
    return session;
  }

  @override
  Future<LanguageSessionResult> saveResult(LanguageSessionResult result) async {
    if (result.studentId != studentId) {
      throw const LanguageOrtaDenied(
        'Students can only save their own language data.',
      );
    }
    final next = [
      for (final item in _data.results)
        if (item.sessionId == result.sessionId) result else item,
    ];
    if (!next.any((item) => item.sessionId == result.sessionId)) {
      next.add(result);
    }
    await _commit(
      LanguageOrtaSnapshot(
        profiles: _data.profiles,
        sessions: _data.sessions,
        results: next,
      ),
    );
    return result;
  }

  @override
  Future<LanguageSessionResult?> resultFor(String sessionId) async {
    return _data.results
        .where(
          (item) => item.studentId == studentId && item.sessionId == sessionId,
        )
        .firstOrNull;
  }
}

class DeniedLanguageOrtaStore implements LanguageOrtaStore {
  const DeniedLanguageOrtaStore();
  Never _deny() => throw const LanguageOrtaDenied(
    'Language ORTA is available only to authenticated students.',
  );

  @override
  Future<LanguageProfile> addLanguage(String languageCode) async => _deny();
  @override
  Future<List<LanguageProfile>> profiles() async => _deny();
  @override
  Future<LanguageSessionResult?> resultFor(String sessionId) async => _deny();
  @override
  Future<LanguageSessionResult> saveResult(
    LanguageSessionResult result,
  ) async => _deny();
  @override
  Future<LanguageProfile> saveProfile(LanguageProfile profile) async => _deny();
  @override
  Future<LanguagePracticeSession> saveSession(
    LanguagePracticeSession session,
  ) async => _deny();
  @override
  Future<List<LanguagePracticeSession>> sessions({String? profileId}) async =>
      _deny();
}

class SupabaseLanguageOrtaStore implements LanguageOrtaStore {
  final SupabaseClient client;
  final String studentId;
  final String role;

  SupabaseLanguageOrtaStore({
    required this.client,
    required this.studentId,
    required this.role,
  }) {
    LanguageOrtaAccess.assertStudent(role: role, studentId: studentId);
    final uid = client.auth.currentUser?.id;
    if (uid == null || uid != studentId) {
      throw const LanguageOrtaDenied(
        'Language ORTA is available only to the signed-in student.',
      );
    }
  }

  @override
  Future<List<LanguageProfile>> profiles() async {
    final rows = await client
        .from('language_profiles')
        .select()
        .eq('student_id', studentId)
        .order('updated_at', ascending: false);
    return [
      for (final row in rows as List)
        LanguageProfile.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<LanguageProfile> addLanguage(String languageCode) async {
    final current = await profiles();
    final existing = current.where((item) => item.languageCode == languageCode);
    if (existing.isNotEmpty) return existing.first;
    final definition = LanguageDefinition.byCode(languageCode);
    final row = await client
        .from('language_profiles')
        .insert({
          'student_id': studentId,
          'language_code': languageCode,
          'language_name': definition.englishName,
        })
        .select()
        .single();
    return LanguageProfile.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<LanguageProfile> saveProfile(LanguageProfile profile) async {
    if (profile.studentId != studentId) {
      throw const LanguageOrtaDenied(
        'Students can only save their own language data.',
      );
    }
    final row = await client
        .from('language_profiles')
        .update({
          'current_level': profile.currentLevel,
          'target_level': profile.targetLevel,
          'goals': profile.goals,
          'preferred_areas': profile.preferredAreas,
          'skill_progress': profile.skillProgress,
        })
        .eq('id', profile.id)
        .eq('student_id', studentId)
        .select()
        .single();
    return LanguageProfile.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<LanguagePracticeSession>> sessions({String? profileId}) async {
    var query = client
        .from('language_practice_sessions')
        .select()
        .eq('student_id', studentId);
    if (profileId != null) query = query.eq('profile_id', profileId);
    final rows = await query.order('created_at', ascending: false);
    return [
      for (final row in rows as List)
        LanguagePracticeSession.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<LanguagePracticeSession> saveSession(
    LanguagePracticeSession session,
  ) async {
    if (session.studentId != studentId) {
      throw const LanguageOrtaDenied(
        'Students can only save their own language data.',
      );
    }
    final row = await client
        .from('language_practice_sessions')
        .upsert(session.toSupabaseRow())
        .eq('student_id', studentId)
        .select()
        .single();
    final saved = LanguagePracticeSession.fromJson(
      Map<String, dynamic>.from(row),
    );
    if (saved.completed) {
      final profileRow = await client
          .from('language_profiles')
          .select()
          .eq('id', saved.profileId)
          .eq('student_id', studentId)
          .single();
      final profile = LanguageProfile.fromJson(
        Map<String, dynamic>.from(profileRow),
      );
      final counts = await client
          .from('language_practice_sessions')
          .select('skill')
          .eq('student_id', studentId)
          .eq('profile_id', saved.profileId)
          .eq('status', 'completed');
      final progress = <String, int>{};
      for (final item in counts as List) {
        final skill = (item as Map)['skill'] as String? ?? '';
        if (skill.isEmpty) continue;
        progress[skill] = (progress[skill] ?? 0) + 1;
      }
      await client
          .from('language_profiles')
          .update({'skill_progress': progress})
          .eq('id', profile.id)
          .eq('student_id', studentId);
    }
    return saved;
  }

  @override
  Future<LanguageSessionResult> saveResult(LanguageSessionResult result) async {
    if (result.studentId != studentId) {
      throw const LanguageOrtaDenied(
        'Students can only save their own language data.',
      );
    }
    final row = await client
        .from('language_session_results')
        .upsert(result.toSupabaseRow())
        .eq('student_id', studentId)
        .select()
        .single();
    return LanguageSessionResult.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<LanguageSessionResult?> resultFor(String sessionId) async {
    final rows = await client
        .from('language_session_results')
        .select()
        .eq('student_id', studentId)
        .eq('session_id', sessionId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return LanguageSessionResult.fromJson(
      Map<String, dynamic>.from(list.first as Map),
    );
  }
}
