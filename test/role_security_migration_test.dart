import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role protection migration requires invitation and denies client role updates', () {
    final sql = File(
      'supabase/migrations/20261115120000_lock_roles_and_profile_locale.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('revoke update on public.profiles'));
    expect(
      sql,
      contains('grant update (full_name, phone, interface_language)'),
    );
    expect(sql, contains('profiles_protect_role'));
    expect(sql, contains('new.role is distinct from old.role'));
    expect(sql, contains('valid orta invitation is required'));
    expect(sql, isNot(contains("new.raw_app_meta_data ->> 'role'")));
    expect(sql, contains("'interface_language'"));
  });

  test('auth registration remains email and password based', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('auth.signUp('));
    expect(source, contains('email: _email.text.trim()'));
    expect(source, contains('password: _password.text'));
    expect(source, contains('auth.signInWithPassword('));
    expect(source, isNot(contains('student-signup-preview')));
  });
}
