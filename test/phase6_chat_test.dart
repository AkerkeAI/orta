import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:orta/main.dart';
import 'package:orta/models/language.dart';
import 'package:orta/models/life_context.dart';
import 'package:orta/models/life_data.dart';
import 'package:orta/screens/core/orta_shell.dart';
import 'package:orta/services/agent_context_builder.dart';
import 'package:orta/services/ai_actions.dart';
import 'package:orta/services/life_repository.dart';
import 'package:orta/services/localization_service.dart';
import 'package:orta/services/orta_agent_service.dart';
import 'package:orta/services/orta_localization.dart';
import 'package:orta/services/product_strings.dart';
import 'package:orta/services/remote_orta_agent_service.dart';
import 'package:orta/services/storage_service.dart';

class ChatWidgetStorage implements LifeDataStorage {
  LifeData saved = LifeData(
    life: const LifeContext(
      name: 'Chat fixture',
      interfaceLanguage: Language.english,
      projects: [ProjectContext(id: 'portfolio', name: 'Portfolio')],
    ),
    onboardingCompleted: true,
  );

  @override
  Future<LifeData> loadLifeData() async => LifeData.fromJson(saved.toJson());

  @override
  Future<void> saveLifeData(LifeData value) async {
    saved = LifeData.fromJson(value.toJson());
  }
}

class RetryAgentService implements OrtaAgentService {
  final first = Completer<MockAgentResult>();
  int calls = 0;

  @override
  Future<MockAgentResult> respond(
    String message,
    AgentContext context,
    AgentDraft draft, {
    List<AgentMessage> conversation = const [],
  }) {
    calls++;
    if (calls == 1) return first.future;
    return Future.value(
      MockAgentResult(response: 'Now we can continue.', draft: draft),
    );
  }
}

Future<void> showChat(
  WidgetTester tester,
  LifeRepository repo, {
  OrtaAgentService? service,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => AgentSheet(
                repository: repo,
                contextBuilder: () =>
                    AgentContextBuilder.build(repo.data, screen: 'home'),
                agentService: service ?? MockOrtaAgentService(),
              ),
            ),
            child: const Text('Open chat'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open chat'));
  await tester.pumpAndSettle();
}

Widget shell(LifeRepository repo) => MaterialApp(
  home: OrtaShell(
    repository: repo,
    onResetOnboarding: () {},
    currentLocale: AppLocale.english,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatWidgetStorage storage;
  late LifeRepository repo;
  late ToolRegistry registry;

  setUp(() async {
    storage = ChatWidgetStorage();
    registry = await ToolRegistry.load();
  });
  tearDown(() => repo.dispose());

  testWidgets(
    'actual shell opens compact/expanded chat from every Core screen and returns to that screen',
    (tester) async {
      repo = await LifeRepository.open(storage);
      await tester.pumpWidget(shell(repo));
      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(AgentButton));
        await tester.pumpAndSettle();
        expect(find.byType(AgentSheet), findsOneWidget);
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
        expect(
          find.byTooltip(productText(Language.english, 'send')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text(
            productText(
              Language.english,
              'viewing',
              name: productText(
                Language.english,
                ['home', 'plan', 'life', 'progress'][index],
              ),
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.byTooltip(productText(Language.english, 'expand')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byTooltip(productText(Language.english, 'collapse')),
          findsOneWidget,
        );
        await tester.tap(
          find.byTooltip(productText(Language.english, 'collapse')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byTooltip(productText(Language.english, 'close')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AgentSheet), findsNothing);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'long Markdown remains scrollable with compact/expanded chat, keyboard and inert model images',
    (tester) async {
      repo = await LifeRepository.open(storage);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final markdown =
          '''# A detailed reply

**Important saved facts** can be read in a conversational reply.

![Image stays local and inert](file:///private/tmp/unread-model-image.png)

${List.generate(40, (i) => 'Paragraph $i: A longer explanation with **emphasis**, a practical next step, and a [reference](https://example.com).').join('\n\n')}

Final readable paragraph.''';
      await repo.appendMessage(markdown, isUser: false);
      await showChat(tester, repo);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
        markdown,
      );
      expect(find.text('Image stays local and inert'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(productText(Language.english, 'expand')));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(AgentSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
      );
      await tester.drag(scrollable, const Offset(0, 240));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'A follow-up\nwith another line.',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(
        find.byTooltip(productText(Language.english, 'send')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThanOrEqualTo(524),
      );
      await tester.tap(
        find.byTooltip(productText(Language.english, 'collapse')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new chat and history restore only their own messages and pending action cards',
    (tester) async {
      repo = await LifeRepository.open(storage);
      final original = repo.data.activeConversationId;
      await repo.appendMessage('Old conversation question', isUser: true);
      await repo.proposeTools(registry, [
        {
          'name': 'create_project',
          'arguments': {'name': 'Old proposal project'},
        },
      ]);
      final originalProposal = repo.data.currentProposals.single.id;
      await showChat(tester, repo);
      expect(find.textContaining('Old proposal project'), findsOneWidget);
      await tester.tap(
        find.byTooltip(productText(Language.english, 'newChat')),
      );
      await tester.pumpAndSettle();
      final second = repo.data.activeConversationId;
      expect(second, isNot(original));
      expect(
        find.text(productText(Language.english, 'welcome')),
        findsOneWidget,
      );
      expect(find.textContaining('Old proposal project'), findsNothing);
      expect(find.text('Old conversation question'), findsNothing);
      await repo.appendMessage('New conversation question', isUser: true);
      await repo.proposeTools(registry, [
        {
          'name': 'create_project',
          'arguments': {'name': 'New proposal project'},
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('New proposal project'), findsOneWidget);
      expect(find.textContaining('Old proposal project'), findsNothing);
      await tester.tap(
        find.byTooltip(productText(Language.english, 'history')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(productText(Language.english, 'retention')),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(ListTile, 'Old conversation question'),
      );
      await tester.pumpAndSettle();
      expect(repo.data.activeConversationId, original);
      expect(find.textContaining('Old proposal project'), findsOneWidget);
      expect(find.textContaining('New proposal project'), findsNothing);
      expect(repo.data.currentProposals.single.id, originalProposal);
      expect(find.text(originalProposal), findsNothing);
      expect(repo.data.life.projects.map((p) => p.name), ['Portfolio']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed request shows retry and retry preserves one user message while duplicate sends stay disabled',
    (tester) async {
      repo = await LifeRepository.open(storage);
      final service = RetryAgentService();
      await showChat(tester, repo, service: service);
      await tester.enterText(
        find.byType(TextField),
        'My exact follow-up question.',
      );
      await tester.tap(find.byTooltip(productText(Language.english, 'send')));
      await tester.pump();
      expect(service.calls, 1);
      expect(
        find.text(productText(Language.english, 'thinking')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.add_comment_outlined),
            )
            .onPressed,
        isNull,
      );
      final userMessageId = repo.data.conversation.single.id;
      service.first.completeError(
        const RemoteAgentException('A temporary connection error.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('A temporary connection error.'), findsOneWidget);
      expect(
        find.text(productText(Language.english, 'retry')).hitTestable(),
        findsOneWidget,
      );
      expect(repo.data.conversation.length, 1);
      await tester.tap(find.text(productText(Language.english, 'retry')));
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(
        repo.data.conversation.where((m) => m.isUser).single.id,
        userMessageId,
      );
      expect(repo.data.conversation.map((m) => m.text), [
        'My exact follow-up question.',
        'Now we can continue.',
      ]);
      expect(find.text(productText(Language.english, 'retry')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'settings are reachable and change the real interface and chat through Russian, Kazakh and English',
    (tester) async {
      repo = await LifeRepository.open(storage);
      await tester.pumpWidget(OrtaAppWrapper(storage: storage));
      await tester.pumpAndSettle();
      var previous = Language.english;
      for (final language in [
        Language.russian,
        Language.kazakh,
        Language.english,
      ]) {
        await tester.tap(find.byTooltip(productText(previous, 'settings')));
        await tester.pumpAndSettle();
        expect(
          find.text(productText(previous, 'interfaceLanguage')),
          findsOneWidget,
        );
        await tester.tap(find.text(language.displayName));
        await tester.pumpAndSettle();
        expect(storage.saved.life.interfaceLanguage, language);
        expect(
          tester.widget<OrtaShell>(find.byType(OrtaShell)).currentLocale,
          AppLocaleExtension.fromLanguage(language),
        );
        expect(
          find.byTooltip(productText(language, 'settings')),
          findsOneWidget,
        );
        await tester.tap(find.byType(AgentButton));
        await tester.pumpAndSettle();
        expect(find.text(productText(language, 'welcome')), findsOneWidget);
        expect(
          find.byTooltip(productText(language, 'newChat')),
          findsOneWidget,
        );
        expect(
          find.byTooltip(productText(language, 'history')),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
          productText(language, 'message'),
        );
        await tester.tap(find.byTooltip(productText(language, 'close')));
        await tester.pumpAndSettle();
        previous = language;
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      final reopened = await LifeRepository.open(storage);
      expect(reopened.data.life.interfaceLanguage, Language.english);
      reopened.dispose();
    },
  );

  testWidgets(
    'opening a saved Life record passes a readable selected title into the conversation',
    (tester) async {
      repo = await LifeRepository.open(storage);
      await tester.pumpWidget(shell(repo));
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Portfolio'));
      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentSheet), findsOneWidget);
      expect(
        find.text(productText(Language.english, 'viewing', name: 'Portfolio')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AgentSheet>(find.byType(AgentSheet))
            .contextBuilder()
            .currentEntityId,
        'portfolio',
      );
      await tester.tap(find.byTooltip(productText(Language.english, 'close')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'selected built-in goal caption uses its localized title in every interface language',
    (tester) async {
      repo = await LifeRepository.open(storage);
      for (final language in Language.values) {
        await tester.pumpWidget(const SizedBox());
        final localized = ChatWidgetStorage();
        localized.saved = localized.saved.copyWith(
          life: localized.saved.life.copyWith(
            interfaceLanguage: language,
            goals: [
              const GoalContext(
                id: 'localized-goal',
                titleKey: 'school_university',
                areaKey: 'education',
              ),
            ],
          ),
        );
        await tester.pumpWidget(OrtaAppWrapper(storage: localized));
        await tester.pumpAndSettle();
        final title = AppLocalizations(
          AppLocaleExtension.fromLanguage(language),
        ).goal('school_university');
        await tester.tap(find.textContaining(title));
        await tester.pumpAndSettle();
        expect(find.byType(AgentSheet), findsOneWidget);
        expect(
          find.text(productText(language, 'viewing', name: title)),
          findsOneWidget,
        );
        expect(find.text('school_university'), findsNothing);
        expect(
          tester
              .widget<AgentSheet>(find.byType(AgentSheet))
              .contextBuilder()
              .currentEntityType,
          'goal',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
