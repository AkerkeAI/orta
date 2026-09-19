import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_context.dart';
import '../models/user_profile.dart';

class StorageService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _userProfileKey = 'user_profile';
  static const String _lifeContextKey = 'life_context';

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, completed);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = jsonEncode(profile.toJson());
    await prefs.setString(_userProfileKey, profileJson);
  }

  Future<void> saveLifeContext(LifeContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lifeContextKey, jsonEncode(context.toJson()));
  }

  Future<LifeContext?> getLifeContext() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lifeContextKey);
    if (value == null) return null;
    try {
      return LifeContext.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_userProfileKey);

    if (profileJson == null) return null;

    try {
      final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
      return UserProfile.fromJson(profileMap);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompletedKey);
    await prefs.remove(_userProfileKey);
    await prefs.remove(_lifeContextKey);
  }
}
