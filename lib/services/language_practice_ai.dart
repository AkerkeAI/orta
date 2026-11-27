import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/language_orta_models.dart';
import 'agent_config.dart';
import 'language_practice_service.dart';

class LanguagePracticeAi {
  final http.Client client;
  final String baseUrl;
  final String? accessToken;
  final Duration timeout;

  LanguagePracticeAi({
    http.Client? client,
    this.baseUrl = ortaBackendBaseUrl,
    this.accessToken,
    this.timeout = const Duration(seconds: 30),
  }) : client = client ?? http.Client();

  Future<PracticePrompt> start({
    required LanguageProfile profile,
    required PracticeSkill skill,
    required PracticeScenario scenario,
    ApprovedLanguageContext context = const ApprovedLanguageContext(),
    String previousPrompt = '',
    int variation = 0,
  }) async {
    final local = LanguagePracticeService.localPrompt(
      languageName: profile.displayName,
      level: profile.currentLevel,
      skill: skill,
      scenario: scenario,
      context: context,
      variation: variation,
    );
    try {
      final body = await _post({
        'action': 'start',
        'languageName': profile.displayName,
        'level': profile.currentLevel,
        'skill': skill.name,
        'scenario': scenario.name,
        'prompt': previousPrompt,
        'approvedContext': context.toSafeJson(),
      });
      final prompt = body['prompt'] as String? ?? '';
      if (prompt.trim().isEmpty) return local;
      return PracticePrompt(
        prompt: prompt.trim(),
        stimulus: (body['stimulus'] as String? ?? local.stimulus).trim(),
      );
    } on LanguagePracticeAiUnavailable {
      return local;
    }
  }

  Future<String> chat({
    required LanguageProfile profile,
    required PracticeSkill skill,
    required PracticeScenario scenario,
    required String message,
    required String interfaceLanguage,
    List<Map<String, String>> history = const [],
    ApprovedLanguageContext context = const ApprovedLanguageContext(),
  }) async {
    final body = await _post({
      'action': 'chat',
      'languageName': profile.displayName,
      'level': profile.currentLevel,
      'skill': skill.name,
      'scenario': scenario.name,
      'message': message,
      'interfaceLanguage': interfaceLanguage,
      'chatHistory': history,
      'approvedContext': context.toSafeJson(),
    });
    final reply = (body['tutorReply'] as String? ?? '').trim();
    if (reply.isEmpty) {
      throw const LanguagePracticeAiUnavailable(
        'The AI tutor returned an empty reply.',
      );
    }
    return reply;
  }

  Future<LanguageCoachFeedback> evaluate({
    required LanguageProfile profile,
    required LanguagePracticeSession session,
    required String response,
    ApprovedLanguageContext context = const ApprovedLanguageContext(),
  }) async {
    try {
      final body = await _post({
        'action': 'evaluate',
        'languageName': profile.displayName,
        'level': profile.currentLevel,
        'skill': session.skill.name,
        'scenario': session.scenario.name,
        'prompt': session.prompt,
        'stimulus': session.stimulus,
        'response': response,
        'transcript': session.transcript,
        'approvedContext': context.toSafeJson(),
      });
      return LanguageCoachFeedback(
        corrections: (body['corrections'] as String? ?? '').trim(),
        explanation: (body['explanation'] as String? ?? '').trim(),
        alternativePhrasing: (body['alternativePhrasing'] as String? ?? '')
            .trim(),
        vocabulary: [
          for (final item in body['vocabulary'] as List? ?? const [])
            VocabularyItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        feedback: (body['feedback'] as String? ?? '').trim(),
        tutorReply: (body['tutorReply'] as String? ?? '').trim(),
        available: true,
      );
    } on LanguagePracticeAiUnavailable catch (error) {
      return LanguageCoachFeedback.unavailable(error.message);
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/api/language/practice'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode == 403) {
        throw const LanguagePracticeAiUnavailable(
          'Language coaching is limited to signed-in students.',
        );
      }
      if (response.statusCode >= 400) {
        String message =
            'Language coaching is unavailable. Your practice can still be saved.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['error'] is String) {
            message = decoded['error'] as String;
          }
        } catch (_) {}
        throw LanguagePracticeAiUnavailable(message);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const LanguagePracticeAiUnavailable(
          'Language coaching returned an incomplete response.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on LanguagePracticeAiUnavailable {
      rethrow;
    } catch (_) {
      throw const LanguagePracticeAiUnavailable(
        'Language coaching is unavailable. Your practice can still be saved.',
      );
    }
  }
}

class LanguageCoachFeedback {
  final String corrections;
  final String explanation;
  final String alternativePhrasing;
  final List<VocabularyItem> vocabulary;
  final String feedback;
  final String tutorReply;
  final bool available;
  const LanguageCoachFeedback({
    this.corrections = '',
    this.explanation = '',
    this.alternativePhrasing = '',
    this.vocabulary = const [],
    this.feedback = '',
    this.tutorReply = '',
    required this.available,
  });

  factory LanguageCoachFeedback.unavailable(String message) =>
      LanguageCoachFeedback(feedback: message, available: false);
}

class LanguagePracticeAiUnavailable implements Exception {
  final String message;
  const LanguagePracticeAiUnavailable(this.message);
  @override
  String toString() => message;
}
