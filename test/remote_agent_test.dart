import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/services/remote_orta_agent_service.dart';
import 'package:orta/services/orta_agent_service.dart';

class _FakeClient extends http.BaseClient {
  Map<String, dynamic>? requestBody;
  int statusCode = 200;
  String? customBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestBody = jsonDecode(
      await request.finalize().bytesToString(),
    ) as Map<String, dynamic>;
    final body =
        customBody ??
        (statusCode == 200
            ? jsonEncode({'message': 'Привет из ORTA', 'requestId': 'test'})
            : jsonEncode({'error': 'failed'}));
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test(
    'remote service serializes locale, context, and bounded history',
    () async {
      final client = _FakeClient();
      final service = RemoteOrtaAgentService(
        client: client,
        baseUrl: 'http://test',
      );
      final context = AgentContext(
        currentScreen: 'life',
        relevantLifeContext: const LifeContext(
          name: 'Test',
          interfaceLanguage: Language.russian,
        ),
      );
      final messages = List.generate(
        20,
        (index) => AgentMessage(text: '$index', isUser: index.isEven),
      );

      final result = await service.respond(
        'new',
        context,
        const AgentDraft(),
        conversation: messages,
      );

      expect(result.response, 'Привет из ORTA');
      expect(client.requestBody!['locale'], 'ru');
      expect((client.requestBody!['conversation'] as List).length, 12);
      expect(client.requestBody!['agentContext']['currentScreen'], 'life');
    },
  );

  test('remote service maps network/provider failures to safe error', () async {
    final client = _FakeClient()..statusCode = 503;
    final service = RemoteOrtaAgentService(
      client: client,
      baseUrl: 'http://test',
    );
    final context = AgentContext(
      currentScreen: 'home',
      relevantLifeContext: const LifeContext(
        name: 'Test',
        interfaceLanguage: Language.english,
      ),
    );

    await expectLater(
      service.respond('hello', context, const AgentDraft()),
      throwsA(isA<RemoteAgentException>()),
    );
  });

  test(
    'provider errors are safe and localized for every interface language',
    () async {
      for (final language in Language.values) {
        final client = _FakeClient()
          ..statusCode = 429
          ..customBody = jsonEncode({
            'code': 'rate_limit',
            'error': 'private upstream text',
          });
        final service = RemoteOrtaAgentService(
          client: client,
          baseUrl: 'http://test',
        );
        final context = AgentContext(
          currentScreen: 'PLAN',
          relevantLifeContext: LifeContext(
            name: 'Test',
            interfaceLanguage: language,
          ),
        );
        try {
          await service.respond('hello', context, const AgentDraft());
          fail('Expected rate limit error');
        } on RemoteAgentException catch (error) {
          expect(error.message, isNot(contains('private upstream text')));
          expect(
            error.message,
            contains(
              language == Language.english
                  ? 'limit'
                  : language == Language.russian
                  ? 'лимит'
                  : 'шегіне',
            ),
          );
        }
      }
    },
  );

  test('malformed and empty successful responses fail safely', () async {
    for (final body in ['not json', '{}', '{"message":""}']) {
      final client = _FakeClient()..customBody = body;
      final service = RemoteOrtaAgentService(
        client: client,
        baseUrl: 'http://test',
      );
      final context = AgentContext(
        currentScreen: 'HOME',
        relevantLifeContext: const LifeContext(
          name: 'Test',
          interfaceLanguage: Language.english,
        ),
      );
      await expectLater(
        service.respond('hello', context, const AgentDraft()),
        throwsA(isA<RemoteAgentException>()),
      );
    }
  });
}
