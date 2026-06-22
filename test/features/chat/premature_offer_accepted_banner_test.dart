/// Regression test for the PREMATURE "Offer accepted!" chat banner.
///
/// Bug (flagged repeatedly in iter6 re-validation — FINAL2/FINAL3 anomaly
/// notes): when a CLIENT creates an order the conversation is `broadcasting`
/// with NO jeeber assigned (a one-sided shell), yet the chat flashed/persisted
/// the banner "Offer accepted! You are now chatting with your Jeeber." — even
/// though no offer had been accepted.
///
/// Root cause: [ChatState] defaults `phase` to `accepted`, and the real
/// [DioChatGateway.loadPhase] was a hardcoded `accepted` stub, so a
/// `broadcasting` conversation always reported `accepted` and the
/// accepted-only [OfferAcceptedBanner] rendered. The banner-gate
/// (`state.phase == accepted && winnerName != null`) was therefore never
/// pre-accept-safe because `winnerName` falls back to the counterpart name
/// (never null) and the phase was wrong.
///
/// Fix: the host ([ChatDetailScreen]) threads the authoritative create-or-get
/// phase into the cubit (`initialPhase`) AND the gateway (so `loadPhase`
/// echoes it). These tests assert the banner is GATED on the real phase:
///   * pre-accept (`broadcasting`/`pending`, no jeeber) → NO banner, honest
///     waiting copy instead;
///   * post-accept (live `PhaseChanged(accepted)`) → banner appears reactively;
///   * the `initialPhase` seed prevents the pre-`load()` `accepted` flash.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_accepted_banner.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart'
    show OfferAcceptResult;
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Localization helper
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

// ---------------------------------------------------------------------------
// Test double — a gateway that resolves a configurable phase and lets the test
// drive a live PhaseChanged event onto the open thread (mirroring the realtime
// broadcasting→accepted advance the gateway emits on a real accept).
// ---------------------------------------------------------------------------

class _PhaseGateway extends ChatGateway {
  _PhaseGateway({ConversationPhase phase = ConversationPhase.broadcasting})
      : _phase = phase;

  ConversationPhase _phase;
  final _ctrl = StreamController<ChatEvent>.broadcast();

  /// Pushes a live phase advance to subscribers — the same event
  /// [DioChatGateway] emits on accept and forwards from realtime `:5804`.
  void pushPhase(ConversationPhase phase, {String? deliveryId}) {
    _phase = phase;
    _ctrl.add(PhaseChanged(phase, deliveryId: deliveryId));
  }

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<ConversationPhase> loadPhase(String id) async => _phase;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _ctrl.stream;

  @override
  Future<OfferAcceptResult> acceptOffer(String conversationId, String offerId) async {
    _phase = ConversationPhase.accepted;
    _ctrl.add(const PhaseChanged(ConversationPhase.accepted));
    return OfferAcceptResult.empty;
  }
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _app(ChatCubit cubit) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (ctx) => ChatScreen(
              deliveryId: 'conv-premature-001',
              counterpartName: 'Kamal Hajj',
              cubit: ctx.read<ChatCubit>(),
            ),
          ),
        ),
      ),
    );

ChatCubit _cubit(
  _PhaseGateway gateway, {
  ConversationPhase initialPhase = ConversationPhase.broadcasting,
}) {
  final c = ChatCubit(
    deliveryId: 'conv-premature-001',
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    initialPhase: initialPhase,
  );
  addTearDown(c.close);
  return c;
}

void main() {
  setUpAll(_loadArb);

  group('Premature "Offer accepted!" banner — phase gating', () {
    testWidgets(
        'pre-accept (broadcasting, no jeeber) shows NO accepted banner', (tester) async {
      final gw = _PhaseGateway(phase: ConversationPhase.broadcasting);
      final cubit = _cubit(gw, initialPhase: ConversationPhase.broadcasting);
      await tester.pumpWidget(_app(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      // The accepted-only banner must NOT be present while broadcasting.
      expect(find.byType(OfferAcceptedBanner), findsNothing);
      expect(find.byKey(const Key('offer-accepted-banner')), findsNothing);
      // And the misleading copy must be absent.
      expect(find.text('Offer accepted!'), findsNothing);
      expect(
        find.text('You are now chatting with your Jeeber.'),
        findsNothing,
      );
    });

    testWidgets(
        'initialPhase seed prevents the pre-load "accepted" flash', (tester) async {
      // Before load() resolves, the cubit must already be in the seeded
      // broadcasting phase — NOT the legacy ChatState default of `accepted`.
      final gw = _PhaseGateway(phase: ConversationPhase.broadcasting);
      final cubit = _cubit(gw, initialPhase: ConversationPhase.broadcasting);
      expect(cubit.state.phase, ConversationPhase.broadcasting);

      await tester.pumpWidget(_app(cubit));
      // Pump a single frame (load() in flight, not yet settled) — the banner
      // must NOT flash on first paint.
      await tester.pump();
      expect(find.byType(OfferAcceptedBanner), findsNothing);
      expect(find.text('Offer accepted!'), findsNothing);

      await cubit.load();
      await tester.pumpAndSettle();
      expect(find.byType(OfferAcceptedBanner), findsNothing);
    });

    testWidgets(
        'banner flips waiting→accepted on the live PhaseChanged event', (tester) async {
      final gw = _PhaseGateway(phase: ConversationPhase.broadcasting);
      final cubit = _cubit(gw, initialPhase: ConversationPhase.broadcasting);
      await tester.pumpWidget(_app(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      // Pre-accept: no banner.
      expect(find.byType(OfferAcceptedBanner), findsNothing);

      // Simulate the realtime broadcasting→accepted advance.
      gw.pushPhase(ConversationPhase.accepted);
      await tester.pumpAndSettle();

      // Post-accept: the banner appears reactively, with the correct copy.
      expect(find.byType(OfferAcceptedBanner), findsOneWidget);
      expect(find.text('Offer accepted!'), findsOneWidget);
      expect(
        find.text('You are now chatting with your Jeeber.'),
        findsOneWidget,
      );
      expect(cubit.state.phase, ConversationPhase.accepted);
    });

    testWidgets(
        'unknown phase (degraded resolve) shows NO accepted banner', (tester) async {
      final gw = _PhaseGateway(phase: ConversationPhase.unknown);
      final cubit = _cubit(gw, initialPhase: ConversationPhase.unknown);
      await tester.pumpWidget(_app(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.byType(OfferAcceptedBanner), findsNothing);
      expect(find.text('Offer accepted!'), findsNothing);
    });
  });
}
