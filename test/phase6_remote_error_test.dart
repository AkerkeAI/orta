import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/services/orta_agent_service.dart';
import 'package:orta/services/remote_orta_agent_service.dart';

const _expected = <String, Map<Language, String>>{
  'request_too_large': {
    Language.english: 'This conversation exceeds the current AI request limit. No changes were made.',
    Language.russian:
        'Этот разговор превышает текущий лимит запроса ИИ. Данные не изменены.',
    Language.kazakh: 'Бұл әңгіме ЖИ сұрауының ағымдағы шегінен асады. Деректер өзгерген жоқ.',
  },
  'access_denied': {
    Language.english:
        'ORTA could not access the AI service. Check the connection settings.',
    Language.russian:
        'ORTA не получил доступ к сервису ИИ. Проверьте настройки подключения.',
    Language.kazakh:
        'ORTA ЖИ қызметіне кіре алмады. Қосылым баптауларын тексеріңіз.',
  },
  'invalid_request': {
    Language.english:
        'ORTA could not process this message. Please shorten it and try again.',
    Language.russian:
        'ORTA не смог обработать сообщение. Сократите его и попробуйте снова.',
    Language.kazakh: 'ORTA хабарламаны өңдей алмады. Қысқартып, қайта көріңіз.',
  },
};

void main() {
  for (final code in _expected.keys) {
    for (final language in Language.values) {
      for (final tools in [false, true]) {
        test(
          '$code is safe and localized in ${language.code} (${tools ? 'tools' : 'chat'})',
          () async {
            Map<String, dynamic>? sent;
            final client = MockClient((request) async {
              sent = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'code': code,
                  'error': 'PRIVATE_UPSTREAM_DETAIL and CREDENTIAL_SENTINEL',
                  'message': 'PRIVATE_UPSTREAM_DETAIL',
                  'requestId': 'INTERNAL_REQUEST_SENTINEL',
                }),
                switch (code) {
                  'request_too_large' => 413,
                  'access_denied' => 403,
                  _ => 400,
                },
                headers: {'content-type': 'application/json'},
              );
            });
            addTearDown(client.close);
            final service = RemoteOrtaAgentService(
              client: client,
              baseUrl: 'http://test',
            );
            final context = AgentContext(
              currentScreen: 'life',
              relevantLifeContext: LifeContext(
                name: 'Local user',
                interfaceLanguage: language,
              ),
            );
            final response = tools
                ? service.toolTurn(
                    'Please help',
                    context,
                    const [],
                    const [],
                    const [],
                  )
                : service.respond('Please help', context, const AgentDraft());
            await expectLater(
              response,
              throwsA(
                isA<RemoteAgentException>().having(
                  (error) => error.message,
                  'localized error',
                  _expected[code]![language],
                ),
              ),
            );
            expect(sent!['locale'], language.code);
            expect(sent!['message'], 'Please help');
            expect(sent!['toolsEnabled'], tools ? true : isNull);
          },
        );
      }
    }
  }
}
