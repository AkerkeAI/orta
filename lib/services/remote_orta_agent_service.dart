import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/life_context.dart';
import '../models/language.dart';
import 'agent_config.dart';
import 'orta_agent_service.dart';

class RemoteAgentException implements Exception {
  final String message;
  const RemoteAgentException(this.message);
  @override
  String toString() => message;
}

class RemoteOrtaAgentService implements OrtaAgentService {
  final http.Client client;
  final String baseUrl;
  final Duration timeout;

  RemoteOrtaAgentService({
    http.Client? client,
    this.baseUrl = ortaBackendBaseUrl,
    this.timeout = const Duration(seconds: 30),
  }) : client = client ?? http.Client();

  @override
  Future<MockAgentResult> respond(
    String message,
    AgentContext context,
    AgentDraft draft, {
    List<AgentMessage> conversation = const [],
  }) async {
    final history =
        conversation.isNotEmpty &&
            conversation.last.isUser &&
            conversation.last.text == message
        ? conversation.sublist(0, conversation.length - 1)
        : conversation;
    final bounded = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/api/agent/message'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'locale': context.relevantLifeContext.interfaceLanguage.code,
              'lifeContext': context.relevantLifeContext.toJson(),
              'agentContext': context.toJson(),
              'conversation': bounded
                  .map(
                    (item) => {
                      'role': item.isUser ? 'user' : 'assistant',
                      'content': item.text,
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw const RemoteAgentException(
          'ORTA could not connect right now. Try again.',
        );
      final body = jsonDecode(response.body);
      if (body is! Map ||
          body['message'] is! String ||
          (body['message'] as String).trim().isEmpty)
        throw const RemoteAgentException(
          'ORTA could not connect right now. Try again.',
        );
      return MockAgentResult(response: body['message'] as String, draft: draft);
    } on RemoteAgentException {
      rethrow;
    } catch (_) {
      throw const RemoteAgentException(
        'ORTA could not connect right now. Try again.',
      );
    }
  }
}
