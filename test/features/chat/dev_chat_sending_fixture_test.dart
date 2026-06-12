// Screen-12 "sending my initial request" (Figma 56535:6469) fixture guard.
//
// The pre-offers `sending` state is the client's just-sent initial request
// BEFORE any offer arrives: a single outgoing read bubble over an empty scroll
// area, with the composer. This is distinct from the `broadcasting` state
// (Figma 56535:6659), which is this state PLUS the stacked offer cards.
//
// These tests pin the contract that:
//   1. DevChatFixtureGateway(sending: true) seeds EXACTLY ONE outgoing, read
//      message and ZERO offer cards (the frame's subject).
//   2. The plain `broadcasting` fixture is UNCHANGED — still 1 outgoing bubble
//      + 2 offer cards (no regression to flows 02/13).
//   3. DevChatPreviewScreen(selector: 'sending') mounts the populated list +
//      the read double-tick, with NO offer card and NO "Accept only one offer"
//      footer — and the `broadcasting` selector still shows that footer.
//
// kDebugMode is true under `flutter test`, so the dev-seam fixtures are live.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/data/dev_chat_fixture_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/dev_chat_preview_screen.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  assert(kDebugMode, 'dev-seam fixture tests must run in debug');

  group('DevChatFixtureGateway sending thread (Figma 56535:6469)', () {
    test('seeds exactly one outgoing, read message and no offer cards', () async {
      final gateway = DevChatFixtureGateway(
        phase: ConversationPhase.broadcasting,
        sending: true,
      );

      final history = await gateway.loadHistory('dev-chat');

      expect(history, hasLength(1),
          reason: 'the pre-offers frame shows a single bubble');
      final only = history.single;
      expect(only.author, ChatAuthor.me,
          reason: 'the bubble is the client\'s own outgoing request');
      expect(only.status, MessageStatus.read,
          reason: 'Figma draws a teal read double-tick');
      expect(only.kind, MessageKind.text);
      expect(
        only.text,
        'I need 3 kilos of potatoes and water gallon and coffee from blend',
      );
      expect(history.where((m) => m.isOfferCard), isEmpty,
          reason: 'no offers have arrived in the sending state');

      await gateway.dispose();
    });

    test('reports the broadcasting phase so the composer stays visible '
        'and no counterpart header renders', () async {
      final gateway = DevChatFixtureGateway(
        phase: ConversationPhase.broadcasting,
        sending: true,
      );
      expect(await gateway.loadPhase('dev-chat'),
          ConversationPhase.broadcasting);
      await gateway.dispose();
    });

    test('REGRESSION: the plain broadcasting fixture is unchanged — '
        'one outgoing bubble + two offer cards', () async {
      final gateway = DevChatFixtureGateway(
        phase: ConversationPhase.broadcasting,
      );

      final history = await gateway.loadHistory('dev-chat');

      final offers = history.where((m) => m.isOfferCard).toList();
      expect(offers, hasLength(2),
          reason: 'broadcasting still seeds Kamal + Rana offer cards');
      expect(
        history.where((m) => m.author == ChatAuthor.me && m.kind == MessageKind.text),
        hasLength(1),
        reason: 'still exactly one outgoing request bubble',
      );

      await gateway.dispose();
    });

    test('REGRESSION: the accepted + delivery-man fixtures are unchanged',
        () async {
      final accepted =
          DevChatFixtureGateway(phase: ConversationPhase.accepted);
      final acceptedHistory = await accepted.loadHistory('dev-chat');
      expect(acceptedHistory, hasLength(3));
      expect(acceptedHistory.where((m) => m.isOfferCard), isEmpty);
      await accepted.dispose();

      final dm = DevChatFixtureGateway(
        phase: ConversationPhase.accepted,
        deliveryMan: true,
      );
      final dmHistory = await dm.loadHistory('dev-chat');
      expect(dmHistory, hasLength(2));
      expect(dmHistory.first.author, ChatAuthor.them,
          reason: 'jeeber sees the client request as incoming');
      await dm.dispose();
    });
  });

  group('DevChatPreviewScreen(selector: sending)', () {
    testWidgets('mounts the single-bubble list with the read tick and '
        'NO offer card / NO "accept only one" footer', (tester) async {
      await tester.pumpWidget(
        wrapForTest(const DevChatPreviewScreen(selector: 'sending')),
      );
      await tester.pumpAndSettle();

      // The populated thread mounted (not the empty state).
      expect(find.byKey(ChatScreen.messageListKey), findsOneWidget);
      expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);

      // The outgoing read double-tick is present (the "sent into broadcast"
      // signal the frame draws).
      expect(
        find.bySemanticsIdentifier('chat_detail_message_read'),
        findsOneWidget,
      );

      // The composer input is present.
      expect(
        find.bySemanticsIdentifier('chat_detail_message_input'),
        findsOneWidget,
      );

      // No offers yet: neither an offer card nor the "Accept only one offer"
      // footer renders.
      expect(
        find.bySemanticsIdentifier('chat_detail_offer_only_one_note'),
        findsNothing,
        reason: 'the offer-note footer is gated on offer cards being present',
      );
    });

    testWidgets('REGRESSION: the broadcasting selector still renders the '
        '"accept only one" offer footer', (tester) async {
      await tester.pumpWidget(
        wrapForTest(const DevChatPreviewScreen(selector: 'broadcasting')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ChatScreen.messageListKey), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('chat_detail_offer_only_one_note'),
        findsOneWidget,
        reason: 'broadcasting seeds offer cards, so the footer must render',
      );
    });
  });
}
