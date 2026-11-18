import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language.dart';
import '../models/life_context.dart';
import '../models/life_data.dart';
import '../models/user_profile.dart';

abstract interface class LifeDataStorage {
  Future<LifeData> loadLifeData();
  Future<void> saveLifeData(LifeData data);
}

class StorageService implements LifeDataStorage {
  static const lifeDataKey = 'orta_life_data';
  static const backupKey = 'orta_life_data_backup';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _userProfileKey = 'user_profile';
  static const _lifeContextKey = 'life_context';
  final Directory? directory;
  StorageService({this.directory});

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/orta');
    await folder.create(recursive: true);
    return File('${folder.path}/life-data.json');
  }

  Future<void> _atomicWrite(File target, String encoded) async {
    final pending = File('${target.path}.pending');
    try {
      await pending.writeAsString(encoded, flush: true);
      // Same-directory rename replaces the snapshot atomically on iOS/Android.
      await pending.rename(target.path);
    } catch (_) {
      try {
        if (await pending.exists()) await pending.delete();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<LifeData> loadLifeData() async {
    final file = await _file();
    if (await file.exists()) {
      return LifeData.fromJson(
        Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map),
      );
    }
    // Legacy preferences remain untouched for recovery after migration.
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final previousSnapshot = prefs.getString(lifeDataKey);
    if (previousSnapshot != null) {
      final data = LifeData.fromJson(
        Map<String, dynamic>.from(jsonDecode(previousSnapshot) as Map),
      );
      await saveLifeData(data);
      return data;
    }
    final legacy = prefs.getString(_lifeContextKey);
    final profile = prefs.getString(_userProfileKey);
    final completed = prefs.getBool(_onboardingCompletedKey) ?? false;
    if (legacy == null && profile == null) {
      if (completed) {
        throw const FormatException('Saved onboarding context is missing');
      }
      return LifeData.empty();
    }
    LifeContext life;
    Map<String, LanguageProgress> progress = {};
    if (legacy != null) {
      final json = Map<String, dynamic>.from(jsonDecode(legacy) as Map);
      for (final field in ['goals', 'exams', 'projects', 'universityPlans']) {
        final rows = json[field] as List? ?? [];
        final reserved = rows
            .whereType<Map>()
            .map((row) => row['id'])
            .whereType<String>()
            .toSet();
        final used = <String>{};
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i] as Map;
          final id = row['id'] as String?;
          if (id == null || id.trim().isEmpty || !used.add(id)) {
            var repaired = 'legacy_${field}_$i';
            while (reserved.contains(repaired) || used.contains(repaired)) {
              repaired += '_';
            }
            row['id'] = repaired;
            used.add(repaired);
          }
        }
      }
      life = LifeContext.fromJson(json);
    } else {
      final user = UserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(profile!) as Map),
      );
      life = LifeContext(
        name: user.name,
        interfaceLanguage: user.nativeLanguage,
        languages: [
          LanguageContext(
            languageCode: user.learningLanguage.code,
            level: user.level.shortName,
          ),
        ],
        preferences: {
          'wakeUpTime': user.wakeUpTime,
          'sleepTime': user.sleepTime,
          'notificationsEnabled': user.notificationsEnabled.toString(),
        },
      );
      progress = {
        user.learningLanguage.code: LanguageProgress(
          languageCode: user.learningLanguage.code,
          level: user.level.shortName,
          completedSessions: user.conversations,
        ),
      };
    }
    final migrated = LifeData(
      life: life,
      onboardingCompleted: completed,
      languages: progress,
    );
    await saveLifeData(migrated);
    return migrated;
  }

  @override
  Future<void> saveLifeData(LifeData data) async {
    data.validate();
    final encoded = jsonEncode(data.toJson());
    if (utf8.encode(encoded).length > 2000000) {
      throw StateError('Local storage capacity reached');
    }
    final file = await _file();
    if (await file.exists()) {
      final previous = await file.readAsString();
      // Never overwrite externally corrupted or future-version data.
      LifeData.fromJson(Map<String, dynamic>.from(jsonDecode(previous) as Map));
      await _atomicWrite(File('${file.path}.backup'), previous);
    }
    await _atomicWrite(file, encoded);
  }

  // Compatibility APIs route to the unified snapshot once migration has occurred.
  Future<bool> isOnboardingCompleted() async {
    if (await (await _file()).exists()) {
      return (await loadLifeData()).onboardingCompleted;
    }
    return (await SharedPreferences.getInstance()).getBool(
          _onboardingCompletedKey,
        ) ??
        false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    if (await (await _file()).exists()) {
      await saveLifeData(
        (await loadLifeData()).copyWith(onboardingCompleted: completed),
      );
      return;
    }
    if (!await (await SharedPreferences.getInstance()).setBool(
      _onboardingCompletedKey,
      completed,
    )) {
      throw StateError('Could not save onboarding');
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _userProfileKey,
      jsonEncode(profile.toJson()),
    )) {
      throw StateError('Could not save profile');
    }
  }

  Future<UserProfile?> getUserProfile() async {
    final value = (await SharedPreferences.getInstance()).getString(
      _userProfileKey,
    );
    if (value == null) return null;
    return UserProfile.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  Future<void> saveLifeContext(LifeContext context) async {
    if (await (await _file()).exists()) {
      await saveLifeData((await loadLifeData()).copyWith(life: context));
      return;
    }
    if (!await (await SharedPreferences.getInstance()).setString(
      _lifeContextKey,
      jsonEncode(context.toJson()),
    )) {
      throw StateError('Could not save context');
    }
  }

  Future<LifeContext?> getLifeContext() async {
    if (await (await _file()).exists()) return (await loadLifeData()).life;
    final value = (await SharedPreferences.getInstance()).getString(
      _lifeContextKey,
    );
    if (value == null) return null;
    return LifeContext.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _onboardingCompletedKey,
      _userProfileKey,
      _lifeContextKey,
      lifeDataKey,
      backupKey,
    ]) {
      await prefs.remove(key);
    }
    final file = await _file();
    for (final path in [
      file.path,
      '${file.path}.backup',
      '${file.path}.pending',
    ]) {
      final existing = File(path);
      if (await existing.exists()) await existing.delete();
    }
  }
}
