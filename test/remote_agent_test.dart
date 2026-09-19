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

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestBody = jsonDecode(
      await request.finalize().bytesToString(),
    ) as Map<String, dynamic>;
    final body = statusCode == 200
        ? jsonEncode({'message': 'Привет из ORTA', 'requestId': 'test'})
        : jsonEncode({'error': 'failed'});
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
}
