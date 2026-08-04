/// JM-025 — Order Chat (compose=broadcast, pinned summary, dispute link).
/// Locks the three order-chat states the W1 flow drives (63_W1_TEST_PLAN §2.5):
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';

// ---------------------------------------------------------------------------
class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;
  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);
  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

void _loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncLocDelegate({'en': en, 'ar': ar});
}

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// Accepted-thread gateway (a winner is present, phase accepted) — drives the
/// JM-025 AC2/AC3 surfaces.
class _AcceptedGateway extends ChatGateway {
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => [
        DeliveryChatMessage.offerAccepted(
          id: 'sys-accepted-1',
          sentAt: DateTime(2026, 6, 18, 9, 25),
          payload: const SystemOfferPayload(
            offerId: 'offer-001',
            jeeberId: 'user-jeeber-002',
            jeeberName: 'Kamal Hajj',
          ),
        ),
      ];

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  @override
  Future<OfferAcceptResult> acceptOffer(String id, String offerId) async =>
      OfferAcceptResult.empty;

  Future<void> dispose() => _controller.close();
}

/// Active-delivery gateway: an in-flight delivery whose CONVERSATION reports a
/// phase the chat-service contract does not enumerate (`fromWire` → `unknown`).
/// Drives the JM-025 AC3 active-delivery seam where the dispute affordance must
class _ActiveDeliveryGateway extends ChatGateway {
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.unknown;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => [
        DeliveryChatMessage.offerAccepted(
          id: 'sys-accepted-active-1',
          sentAt: DateTime(2026, 6, 18, 9, 25),
          payload: const SystemOfferPayload(
            offerId: 'offer-001',
            jeeberId: 'user-jeeber-002',
            jeeberName: 'Kamal Hajj',
          ),
        ),
      ];

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  @override
  Future<OfferAcceptResult> acceptOffer(String id, String offerId) async =>
      OfferAcceptResult.empty;

  Future<void> dispose() => _controller.close();
}

/// Compose-thread gateway: empty history, broadcasting/unknown phase, no winner.
class _ComposeGateway extends ChatGateway {
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.broadcasting;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

ChatCubit _cubit(ChatGateway gw, {String id = 'conv-jm025'}) {
  final c = ChatCubit(
    deliveryId: id,
    gateway: gw,
    pickerService: StubPhotoPickerService(),
  );
  addTearDown(c.close);
  return c;
}

const _summary = OrderChatSummary(
  deliveryId: 'del-client-001-active',
  requestId: 'req-client-001-accepted',
  priceLabel: r'$9.00',
  jeeberName: 'Kamal Hajj',
  rating: 4.8,
  etaMinutes: 20,
  tierId: 'express',
  orderRef: 'ORD-503003',
  // P3 (b01-20260725): the INITIAL REQUIREMENT carried into the strip.
  description: '2 kilos apples from Spinneys',
);

void main() {
  // b02: the pinned header's expand choice is SESSION state and widget
  setUp(ChatHeaderExpansionStore.instance.reset);
  setUpAll(_loadArb);

  group('JM-025 AC2/AC3 — accepted order-chat', () {
    testWidgets('renders the pinned summary + view-summary link', (t) async {
      final gw = _AcceptedGateway();
      addTearDown(gw.dispose);
      var viewed = 0;
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'conv-journey-accepted',
        counterpartName: 'Kamal Hajj',
        cubit: _cubit(gw, id: 'conv-journey-accepted')..load(),
        isOrderChat: true,
        pinnedSummary: _summary,
        onViewSummary: () => viewed++,
        onOpenDispute: () {},
      )));
      await t.pumpAndSettle();

      expect(find.bySemanticsIdentifier('order_chat_pinned_summary'),
          findsOneWidget);
      // b02 chat-header redesign: the strip is collapsed by default; the
      await t.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await t.pump();
      final link = find.bySemanticsIdentifier('order_chat_view_summary_link');
      expect(link, findsOneWidget);

      await t.tap(link);
      await t.pump();
      expect(viewed, 1);
    });

    testWidgets('renders the dispute affordance and invokes the handler',
        (t) async {
      final gw = _AcceptedGateway();
      addTearDown(gw.dispose);
      var disputed = 0;
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'conv-journey-accepted',
        counterpartName: 'Kamal Hajj',
        cubit: _cubit(gw, id: 'conv-journey-accepted')..load(),
        isOrderChat: true,
        pinnedSummary: _summary,
        onViewSummary: () {},
        onOpenDispute: () => disputed++,
      )));
      await t.pumpAndSettle();

      final dispute = find.bySemanticsIdentifier('order_chat_open_dispute');
      expect(dispute, findsOneWidget);

      await t.tap(dispute);
      await t.pump();
      expect(disputed, 1);
    });

    testWidgets(
        'JM-031 AC4: the in-chat pinned strip also exposes order_summary_pinned '
        '+ field ids', (t) async {
      final gw = _AcceptedGateway();
      addTearDown(gw.dispose);
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'conv-journey-accepted',
        counterpartName: 'Kamal Hajj',
        cubit: _cubit(gw, id: 'conv-journey-accepted')..load(),
        isOrderChat: true,
        pinnedSummary: _summary,
        onViewSummary: () {},
        onOpenDispute: () {},
      )));
      await t.pumpAndSettle();

      // b02 chat-header redesign: the strip is collapsed by default; the
      await t.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await t.pump();
      // The chat-context rendering of order-summary-pinned (CTO-D3) carries the
      expect(find.bySemanticsIdentifier('order_summary_pinned'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_price'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_jeeber_name'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_tier'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_cash_label'),
          findsOneWidget);
      // P3/M18: the new initial-requirement row joins the JM-031 field-id set
      expect(find.bySemanticsIdentifier('order_summary_item'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_chat_request_description'),
          findsOneWidget);
    });

    testWidgets(
        'P3/M16: the JEEBER shape — the strip renders with NO link even when '
        'the conversation phase is not literally accepted', (t) async {
      final gw = _ActiveDeliveryGateway();
      addTearDown(gw.dispose);
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'del-client-001-active',
        counterpartName: 'Alice Client',
        cubit: _cubit(gw, id: 'del-client-001-active')..load(),
        // The Jeeber leg: no order-chat composer ids, no owner-scoped link.
        isOrderChat: false,
        pinnedSummary: _summary,
        onViewSummary: null,
        viewerIsJeeber: true,
      )));
      await t.pumpAndSettle();

      expect(find.bySemanticsIdentifier('order_chat_pinned_summary'),
          findsOneWidget);
      // b02 chat-header redesign: the strip is collapsed by default; the
      await t.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await t.pump();
      expect(find.bySemanticsIdentifier('order_chat_view_summary_link'),
          findsNothing);
      expect(find.bySemanticsIdentifier('order_chat_request_description'),
          findsOneWidget);
      expect(find.text('2 kilos apples from Spinneys'), findsOneWidget);
    });

    testWidgets(
        'JM-025 AC3: dispute affordance renders on an active delivery whose '
        'conversation phase is not literally accepted', (t) async {
      final gw = _ActiveDeliveryGateway();
      addTearDown(gw.dispose);
      var disputed = 0;
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'del-client-001-active',
        counterpartName: 'Kamal Hajj',
        cubit: _cubit(gw, id: 'del-client-001-active')..load(),
        isOrderChat: true,
        onOpenDispute: () => disputed++,
      )));
      await t.pumpAndSettle();

      final dispute = find.bySemanticsIdentifier('order_chat_open_dispute');
      expect(dispute, findsOneWidget);

      await t.tap(dispute);
      await t.pump();
      expect(disputed, 1);
    });

    testWidgets('exposes the order_chat_composer_* ids when isOrderChat',
        (t) async {
      final gw = _AcceptedGateway();
      addTearDown(gw.dispose);
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'conv-journey-accepted',
        counterpartName: 'Kamal Hajj',
        cubit: _cubit(gw, id: 'conv-journey-accepted')..load(),
        isOrderChat: true,
        pinnedSummary: _summary,
        onViewSummary: () {},
        onOpenDispute: () {},
      )));
      await t.pumpAndSettle();

      expect(find.bySemanticsIdentifier('order_chat_composer_input'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('order_chat_composer_send'),
          findsOneWidget);
    });

    testWidgets('legacy chat keeps chat_detail_* composer ids (no regression)',
        (t) async {
      final gw = _AcceptedGateway();
      addTearDown(gw.dispose);
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'conv-legacy',
        counterpartName: 'Kamal Hajj',
        cubit: _cubit(gw, id: 'conv-legacy')..load(),
        // isOrderChat defaults false, no pinned summary, no dispute.
      )));
      await t.pumpAndSettle();

      expect(find.bySemanticsIdentifier('chat_detail_message_input'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_detail_send_button'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('order_chat_open_dispute'),
          findsNothing);
      expect(find.bySemanticsIdentifier('order_chat_pinned_summary'),
          findsNothing);
    });
  });

  group('JM-025 AC1 — compose → broadcast', () {
    testWidgets('first message fires onFirstMessageBroadcast exactly once',
        (t) async {
      final gw = _ComposeGateway();
      addTearDown(gw.dispose);
      final broadcasts = <String>[];
      final messages = <String>[];
      await t.pumpWidget(_host(ChatScreen(
        deliveryId: 'req-client-001-new',
        counterpartName: '',
        cubit: _cubit(gw, id: 'req-client-001-new')..load(),
        isOrderChat: true,
        // New signature: (requestId, firstMessage) -> Future<bool>. Returning
        onFirstMessageBroadcast: (requestId, firstMessage) async {
          broadcasts.add(requestId);
          messages.add(firstMessage);
          return true;
        },
      )));
      await t.pumpAndSettle();

      // The order-chat composer exposes its W1 send id on the compose surface.
      expect(find.bySemanticsIdentifier('order_chat_composer_input'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('order_chat_composer_send'),
          findsOneWidget);

      // Type into the composer + send (interact via the stable widget keys; the
      await t.enterText(find.byKey(ChatComposer.textFieldKey),
          'I need standard delivery from downtown to airport');
      await t.pump();
      await t.tap(find.byKey(ChatComposer.sendButtonKey));
      await t.pump(); // optimistic append → listener fires broadcast
      await t.pumpAndSettle();

      expect(broadcasts, ['req-client-001-new']);
      // AC1: the composed first message is forwarded as the request
      expect(messages, ['I need standard delivery from downtown to airport']);

      // A second send must NOT re-broadcast (one-shot guard).
      await t.enterText(
          find.byKey(ChatComposer.textFieldKey), 'second message');
      await t.pump();
      await t.tap(find.byKey(ChatComposer.sendButtonKey));
      await t.pump();
      await t.pumpAndSettle();

      expect(broadcasts, ['req-client-001-new']);
    });
  });
}
