/// T-MOB-ACCEPTTRACK — accept→track gap fix (E2E happy-path map gaps G3 + G5).
///
/// G3 (deliveryId capture): the offer-accept path now surfaces the
/// server-created deliveryId. These tests assert the [ChatCubit] captures it
/// from both the [ChatGateway.acceptOffer] return value and the synthetic
/// [PhaseChanged] event, null-safely (no crash when absent).
///
/// G5 (Track-Order CTA): [OfferAcceptedBanner] renders a client "Track order"
/// CTA — keyed + Semantics(identifier: 'offer_accepted_track_cta') — only when
/// a delivery id is available, and tapping it routes to live tracking. The
/// fail-without test proves the CTA is absent when no callback is wired (the
/// dead-end this ticket removes).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_accepted_banner.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// G3 — cubit deliveryId capture
// ---------------------------------------------------------------------------

/// Gateway whose accept returns a scripted [OfferAcceptResult] and (optionally)
/// emits a [PhaseChanged] event carrying a delivery id, so the cubit's two
/// capture paths can be tested in isolation.
class _AcceptGateway extends ChatGateway {
  _AcceptGateway({
    this.acceptDeliveryId,
    this.eventDeliveryId,
    this.emitPhaseEvent = false,
  });

  /// deliveryId returned by [acceptOffer] (null = gateway surfaced none).
  final String? acceptDeliveryId;

  /// deliveryId carried on the [PhaseChanged] event (when [emitPhaseEvent]).
  final String? eventDeliveryId;

  /// When true, fires a [PhaseChanged] over the event stream on accept.
  final bool emitPhaseEvent;

  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  @override
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async {
    if (emitPhaseEvent && !_controller.isClosed) {
      _controller.add(
        PhaseChanged(ConversationPhase.accepted, deliveryId: eventDeliveryId),
      );
    }
    return OfferAcceptResult(deliveryId: acceptDeliveryId);
  }

  Future<void> dispose() => _controller.close();
}

ChatCubit _cubit(_AcceptGateway gw) {
  final c = ChatCubit(
    deliveryId: 'conv-track-001',
    gateway: gw,
    pickerService: StubPhotoPickerService(),
  );
  addTearDown(c.close);
  addTearDown(gw.dispose);
  return c;
}

// ---------------------------------------------------------------------------
// G5 — banner / chat-screen localization host
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

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

const _trackCtaKey = Key('offer-accepted-track-cta');

// Gateway that seeds an accepted thread (with a winner) so the ChatScreen
// renders the OfferAcceptedBanner. Accept returns a scripted delivery id.
class _ScreenGateway extends ChatGateway {
  _ScreenGateway({this.acceptDeliveryId});

  final String? acceptDeliveryId;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => [
        DeliveryChatMessage.offerAccepted(
          id: 'sys-accepted-1',
          sentAt: DateTime(2026, 6, 15, 9, 41),
          payload: const SystemOfferPayload(
            offerId: 'offer-kamal',
            jeeberId: 'jeeber-kamal',
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
      OfferAcceptResult(deliveryId: acceptDeliveryId);

  Future<void> dispose() => _controller.close();
}

void main() {
  // -------------------------------------------------------------------------
  // G3 — ChatCubit captures the deliveryId
  // -------------------------------------------------------------------------
  group('G3 — accept surfaces deliveryId into ChatState', () {
    test('captures deliveryId from the accept return value', () async {
      final gw = _AcceptGateway(acceptDeliveryId: 'dlv-golden-001');
      final cubit = _cubit(gw);
      await cubit.load();

      await cubit.acceptOffer('offer-kamal');

      expect(cubit.state.acceptedDeliveryId, 'dlv-golden-001');
      expect(cubit.state.canTrackDelivery, isTrue);
    });

    test('null deliveryId (legacy/golden-less body) leaves tracking off',
        () async {
      final gw = _AcceptGateway(acceptDeliveryId: null);
      final cubit = _cubit(gw);
      await cubit.load();

      await cubit.acceptOffer('offer-kamal');

      expect(cubit.state.acceptedDeliveryId, isNull);
      expect(cubit.state.canTrackDelivery, isFalse);
    });

    test('empty-string deliveryId is treated as not-available', () async {
      // OfferAcceptResult never stores '' from the parsers, but the guard must
      // hold even if a result is constructed with one directly.
      const state = ChatState(acceptedDeliveryId: '');
      expect(state.canTrackDelivery, isFalse);
    });

    test(
        'seeds the tracking deliveryId from initialDeliveryId (client accepted '
        'from the review-list sheet) — Track CTA reachable on load', () async {
      // The client accepted the offer in OfferAcceptSheet, which routed here
      // with the accept response deliveryId. The cubit must surface tracking
      // immediately, without an in-chat accept.
      final gw = _AcceptGateway(acceptDeliveryId: null);
      final cubit = ChatCubit(
        deliveryId: 'conv-track-001',
        gateway: gw,
        pickerService: StubPhotoPickerService(),
        initialDeliveryId: 'delivery-from-sheet-1',
      );
      addTearDown(cubit.close);
      addTearDown(gw.dispose);

      await cubit.load();

      expect(cubit.state.acceptedDeliveryId, 'delivery-from-sheet-1');
      expect(cubit.state.canTrackDelivery, isTrue);
    });

    test('an empty initialDeliveryId leaves tracking off', () async {
      final gw = _AcceptGateway(acceptDeliveryId: null);
      final cubit = ChatCubit(
        deliveryId: 'conv-track-001',
        gateway: gw,
        pickerService: StubPhotoPickerService(),
        initialDeliveryId: '',
      );
      addTearDown(cubit.close);
      addTearDown(gw.dispose);

      await cubit.load();

      expect(cubit.state.acceptedDeliveryId, isNull);
      expect(cubit.state.canTrackDelivery, isFalse);
    });

    test('captures deliveryId carried on a PhaseChanged event', () async {
      final gw = _AcceptGateway(
        acceptDeliveryId: null,
        emitPhaseEvent: true,
        eventDeliveryId: 'dlv-from-event-7',
      );
      final cubit = _cubit(gw);
      await cubit.load();

      await cubit.acceptOffer('offer-kamal');
      // Let the broadcast event propagate to the subscription.
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.acceptedDeliveryId, 'dlv-from-event-7');
      expect(cubit.state.canTrackDelivery, isTrue);
    });

    test('a later phase change without an id does NOT erase a captured id',
        () async {
      final gw = _AcceptGateway(acceptDeliveryId: 'dlv-sticky-1');
      final cubit = _cubit(gw);
      await cubit.load();
      await cubit.acceptOffer('offer-kamal');
      expect(cubit.state.acceptedDeliveryId, 'dlv-sticky-1');

      // Simulate a subsequent PhaseChanged with no delivery id.
      gw._controller.add(const PhaseChanged(ConversationPhase.accepted));
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.acceptedDeliveryId,
        'dlv-sticky-1',
        reason: 'copyWith must keep a previously captured tracking id',
      );
    });
  });

  // -------------------------------------------------------------------------
  // G5 — OfferAcceptedBanner Track-order CTA (widget)
  // -------------------------------------------------------------------------
  group('G5 — OfferAcceptedBanner Track-order CTA', () {
    setUpAll(_loadArb);

    testWidgets('renders the Track CTA with id + Key when a callback is wired',
        (tester) async {
      await tester.pumpWidget(
        _host(
          OfferAcceptedBanner(
            jeeberName: 'Kamal Hajj',
            onTrackOrder: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(_trackCtaKey), findsOneWidget);
      // Reuses the canonical "Track my order" copy (homeTrackOrderCta).
      expect(find.text('Track my order'), findsOneWidget);

      final SemanticsNode node = tester.getSemantics(find.byKey(_trackCtaKey));
      expect(node.identifier, 'offer_accepted_track_cta');
    });

    testWidgets('FAIL-WITHOUT: no Track CTA when no callback is wired',
        (tester) async {
      // This is the dead-end the ticket removes: a client banner with no path
      // to tracking. Without onTrackOrder the CTA must be entirely absent.
      await tester.pumpWidget(
        _host(const OfferAcceptedBanner(jeeberName: 'Kamal Hajj')),
      );
      await tester.pump();

      expect(find.byKey(_trackCtaKey), findsNothing);
      expect(find.text('Track my order'), findsNothing);
      // The success strip itself still renders.
      expect(find.byKey(const Key('offer-accepted-banner')), findsOneWidget);
    });

    testWidgets('tapping the Track CTA fires onTrackOrder exactly once',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          OfferAcceptedBanner(
            jeeberName: 'Kamal Hajj',
            onTrackOrder: () => taps++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(_trackCtaKey));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('Track CTA localizes to Arabic (RTL parity)', (tester) async {
      await tester.pumpWidget(
        _host(
          OfferAcceptedBanner(jeeberName: 'كمال', onTrackOrder: () {}),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();

      expect(find.text('تتبّع طلبي'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // G3 + G5 together — ChatScreen wires accept→Track CTA→navigation
  // -------------------------------------------------------------------------
  group('ChatScreen — accept surfaces a navigable Track CTA', () {
    setUpAll(_loadArb);

    testWidgets('Track CTA appears once an accept surfaces a deliveryId, and '
        'tapping it routes with that id', (tester) async {
      final gw = _ScreenGateway(acceptDeliveryId: 'dlv-golden-001');
      addTearDown(gw.dispose);
      final cubit = ChatCubit(
        deliveryId: 'conv-golden-001',
        gateway: gw,
        pickerService: StubPhotoPickerService(),
      );
      addTearDown(cubit.close);

      String? trackedId;
      await tester.pumpWidget(
        _host(
          ChatScreen(
            deliveryId: 'conv-golden-001',
            counterpartName: 'Kamal Hajj',
            cubit: cubit,
            onTrackOrder: (id) => trackedId = id,
          ),
        ),
      );
      await cubit.load();
      await tester.pump();

      // Banner is up (accepted phase + winner) but no tracking id yet.
      expect(find.byKey(const Key('offer-accepted-banner')), findsOneWidget);
      expect(find.byKey(_trackCtaKey), findsNothing);

      // Accept surfaces the delivery id → the CTA appears.
      await cubit.acceptOffer('offer-kamal');
      await tester.pump();
      expect(find.byKey(_trackCtaKey), findsOneWidget);

      await tester.ensureVisible(find.byKey(_trackCtaKey));
      await tester.tap(find.byKey(_trackCtaKey));
      await tester.pump();

      expect(trackedId, 'dlv-golden-001');
    });

    testWidgets(
        'NON-PREBUILT path: ChatScreen built with a gateway (not a cubit) '
        'forwards onTrackOrder so the Track CTA appears + routes', (tester) async {
      // FIX-A: the production/normal ChatScreen branch (no prebuilt cubit) must
      // forward onTrackOrder to _ChatScaffold exactly like the prebuilt branch.
      // The existing tests above all pass `cubit:`, exercising ONLY the prebuilt
      // branch; this one passes `gateway:` so ChatScreen takes the
      // BlocProvider.create(..)..load() path the real app uses.
      //
      // FAIL-WITHOUT: before FIX-A the non-prebuilt branch dropped onTrackOrder,
      // so _trackOrderCallback() saw a null handler and the CTA never rendered —
      // these assertions are red without the one-line forward.
      final gw = _ScreenGateway(acceptDeliveryId: 'dlv-nonprebuilt-9');
      addTearDown(gw.dispose);

      String? trackedId;
      await tester.pumpWidget(
        _host(
          ChatScreen(
            deliveryId: 'conv-nonprebuilt',
            counterpartName: 'Kamal Hajj',
            // No `cubit:` → ChatScreen owns the cubit via BlocProvider.create,
            // the real non-prebuilt branch.
            gateway: gw,
            onTrackOrder: (id) => trackedId = id,
          ),
        ),
      );
      // The create()..load() path resolves loadHistory/loadPhase synchronously
      // (the gateway returns immediately); pump to settle the initial emit.
      await tester.pump();
      await tester.pump();

      // Accepted thread with a winner → banner is up, but no tracking id yet.
      expect(find.byKey(const Key('offer-accepted-banner')), findsOneWidget);
      expect(find.byKey(_trackCtaKey), findsNothing);

      // Accept surfaces the delivery id → the forwarded callback makes the CTA
      // appear (this is exactly what the prebuilt branch already did).
      final ctx = tester.element(find.byKey(const Key('offer-accepted-banner')));
      await ctx.read<ChatCubit>().acceptOffer('offer-kamal');
      await tester.pump();
      expect(find.byKey(_trackCtaKey), findsOneWidget);

      await tester.ensureVisible(find.byKey(_trackCtaKey));
      await tester.tap(find.byKey(_trackCtaKey));
      await tester.pump();

      expect(trackedId, 'dlv-nonprebuilt-9');
    });

    testWidgets('no Track CTA when the accept response carries no deliveryId',
        (tester) async {
      final gw = _ScreenGateway(acceptDeliveryId: null);
      addTearDown(gw.dispose);
      final cubit = ChatCubit(
        deliveryId: 'conv-nogolden',
        gateway: gw,
        pickerService: StubPhotoPickerService(),
      );
      addTearDown(cubit.close);

      var called = false;
      await tester.pumpWidget(
        _host(
          ChatScreen(
            deliveryId: 'conv-nogolden',
            counterpartName: 'Kamal Hajj',
            cubit: cubit,
            onTrackOrder: (_) => called = true,
          ),
        ),
      );
      await cubit.load();
      await tester.pump();

      await cubit.acceptOffer('offer-kamal');
      await tester.pump();

      expect(find.byKey(_trackCtaKey), findsNothing);
      expect(called, isFalse);
    });
  });
}
