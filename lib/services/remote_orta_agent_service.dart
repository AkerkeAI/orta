import 'dart:async';
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
    this.timeout = const Duration(seconds: 75),
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
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        throw RemoteAgentException(_error('invalid_response', context));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RemoteAgentException(
          _error(
            body is Map
                ? body['code'] as String? ?? 'provider_error'
                : 'provider_error',
            context,
          ),
        );
      }
      if (body is! Map ||
          body['message'] is! String ||
          (body['message'] as String).trim().isEmpty) {
        throw RemoteAgentException(_error('invalid_response', context));
      }
      return MockAgentResult(response: body['message'] as String, draft: draft);
    } on RemoteAgentException {
      rethrow;
    } on TimeoutException {
      throw RemoteAgentException(_error('network', context));
    } catch (_) {
      throw RemoteAgentException(_error('network', context));
    }
  }

  Future<Map<String, dynamic>> toolTurn(
    String message,
    AgentContext context,
    List<AgentMessage> conversation,
    List<Map<String, dynamic>> turns,
    List<Map<String, dynamic>> pending,
  ) async {
    final history =
        conversation.isNotEmpty &&
            conversation.last.isUser &&
            conversation.last.text == message
        ? conversation.sublist(0, conversation.length - 1)
        : conversation;
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/api/agent/message'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'locale': context.relevantLifeContext.interfaceLanguage.code,
              'lifeContext': context.relevantLifeContext.toJson(),
              'agentContext': context.toJson(),
              'conversation': history
                  .skip(history.length > 12 ? history.length - 12 : 0)
                  .map(
                    (m) => {
                      'role': m.isUser ? 'user' : 'assistant',
                      'content': m.text,
                    },
                  )
                  .toList(),
              'toolsEnabled': true,
              'toolTurns': turns,
              'pendingActions': pending,
            }),
          )
          .timeout(timeout);
      final dynamic body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw RemoteAgentException(
          _error(
            body is Map
                ? body['code'] as String? ?? 'provider_error'
                : 'provider_error',
            context,
          ),
        );
      }
      if (body is! Map ||
          body['message'] is! String ||
          body['toolCalls'] is! List ||
          (body['toolCalls'] as List).length > 8 ||
          ((body['toolCalls'] as List).isEmpty &&
              (body['message'] as String).trim().isEmpty)) {
        throw RemoteAgentException(_error('invalid_response', context));
      }
      final ids = <String>{};
      for (final call in body['toolCalls'] as List) {
        if (call is! Map ||
            call['id'] is! String ||
            !ids.add(call['id'] as String) ||
            call['name'] is! String ||
            call['arguments'] is! Map) {
          throw RemoteAgentException(_error('invalid_response', context));
        }
      }
      return Map<String, dynamic>.from(body);
    } on RemoteAgentException {
      rethrow;
    } on FormatException {
      throw RemoteAgentException(_error('invalid_response', context));
    } catch (_) {
      throw RemoteAgentException(_error('network', context));
    }
  }

  String _error(String code, AgentContext context) {
    const messages = {
      'request_too_large': [
        'This conversation exceeds the current AI request limit. No changes were made.',
        'Этот разговор превышает текущий лимит запроса ИИ. Данные не изменены.',
        'Бұл әңгіме ЖИ сұрауының ағымдағы шегінен асады. Деректер өзгерген жоқ.',
      ],
      'access_denied': [
        'ORTA could not access the AI service. Check the connection settings.',
        'ORTA не получил доступ к сервису ИИ. Проверьте настройки подключения.',
        'ORTA ЖИ қызметіне кіре алмады. Қосылым баптауларын тексеріңіз.',
      ],
      'invalid_request': [
        'ORTA could not process this message. Please shorten it and try again.',
        'ORTA не смог обработать сообщение. Сократите его и попробуйте снова.',
        'ORTA хабарламаны өңдей алмады. Қысқартып, қайта көріңіз.',
      ],
      'not_configured': [
        'ORTA AI is not configured. Check the backend settings.',
        'ИИ ORTA не настроен. Проверьте настройки сервера.',
        'ORTA жасанды интеллекті бапталмаған. Сервер баптауларын тексеріңіз.',
      ],
      'authentication': [
        'The AI key was rejected. Check backend/.env.',
        'Ключ ИИ отклонён. Проверьте backend/.env.',
        'Жасанды интеллект кілті қабылданбады. backend/.env файлын тексеріңіз.',
      ],
      'model_unavailable': [
        'The configured AI model is unavailable. Check the backend model setting.',
        'Выбранная модель ИИ недоступна. Проверьте настройки модели на сервере.',
        'Таңдалған модель қолжетімсіз. Сервердегі модель баптауын тексеріңіз.',
      ],
      'rate_limit': [
        'AI usage limit reached. Please wait and try again.',
        'Достигнут лимит запросов ИИ. Подождите и попробуйте снова.',
        'Жасанды интеллект сұрауларының шегіне жеттіңіз. Күтіп, қайта көріңіз.',
      ],
      'network': [
        'ORTA could not connect right now. Check your connection and try again.',
        'ORTA не удалось подключиться. Проверьте соединение и повторите попытку.',
        'ORTA қосыла алмады. Байланысты тексеріп, қайта көріңіз.',
      ],
      'invalid_response': [
        'ORTA received an invalid AI response. Please try again.',
        'ORTA получил некорректный ответ ИИ. Попробуйте снова.',
        'ORTA жарамсыз жауап алды. Қайта көріңіз.',
      ],
      'provider_error': [
        'The AI service could not complete your request. Please try again.',
        'Сервис ИИ не смог обработать запрос. Попробуйте снова.',
        'Жасанды интеллект қызметі сұрауды орындай алмады. Қайта көріңіз.',
      ],
    };
    final language = context.relevantLifeContext.interfaceLanguage;
    final index = language == Language.russian
        ? 1
        : language == Language.kazakh
        ? 2
        : 0;
    return (messages[code] ?? messages['provider_error']!)[index];
  }
}
