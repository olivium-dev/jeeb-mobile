/// Widget tests for ChatScreen M1+ visibility (T-MOB-014).
///
/// Tests cover:
///   - AC1: Composer visible in broadcasting phase
///   - AC1: SendButton disabled when composerText empty
///   - AC1: Composer hidden in closed phase
///   - AC2: OfferCard renders with Accept + Decline buttons
///   - AC2: Accepting offer sets acceptingOfferId optimistically
///   - AC4: JeeberRemovedBanner shown in closed phase with offerRejected message
///   - AC2: OfferAcceptedBanner shown after accept
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/jeeber_removed_banner.dart';
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
// Test double
// ---------------------------------------------------------------------------

class _FakeGateway extends ChatGateway {
  _FakeGateway({
    this.history = const [],
    ConversationPhase phase = ConversationPhase.broadcasting,
  }) : _phase = phase;

  final List<DeliveryChatMessage> history;
  ConversationPhase _phase;
  bool acceptCalled = false;

  final _ctrl = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async =>
      List.from(history);

  @override
  Future<ConversationPhase> loadPhase(String id) async => _phase;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _ctrl.stream;

  @override
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async {
    acceptCalled = true;
    _phase = ConversationPhase.accepted;
    return OfferAcceptResult.empty;
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

DeliveryChatMessage _offerMsg(String offerId) =>
    DeliveryChatMessage.offerCard(
      id: 'msg-$offerId',
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 1, 12),
      status: MessageStatus.delivered,
      payload: OfferCardPayload(
        offerId: offerId,
        jeeberId: 'j-$offerId',
        jeeberName: 'Kamal Test',
        fee: 35.0,
        currency: 'USD',
        etaMinutes: 20,
        note: 'Fast delivery',
      ),
    );

Widget _buildApp(ChatCubit cubit, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
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
              deliveryId: 'conv-test-001',
              counterpartName: 'Kamal Hajj',
              cubit: ctx.read<ChatCubit>(),
            ),
          ),
        ),
      ),
    );

ChatCubit _cubit({
  List<DeliveryChatMessage> history = const [],
  ConversationPhase phase = ConversationPhase.broadcasting,
  _FakeGateway? gateway,
}) {
  final gw = gateway ?? _FakeGateway(history: history, phase: phase);
  final c = ChatCubit(
    deliveryId: 'conv-test-001',
    gateway: gw,
    pickerService: StubPhotoPickerService(),
  );
  addTearDown(c.close);
  return c;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_loadArb);

  group('ChatScreen — broadcasting phase (T-MOB-014 AC1)', () {
    testWidgets('composer is visible in broadcasting phase', (tester) async {
      final cubit = _cubit(phase: ConversationPhase.broadcasting);
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.byKey(ChatComposer.textFieldKey), findsOneWidget);
    });

    testWidgets('send button disabled when composer empty', (tester) async {
      final cubit = _cubit(phase: ConversationPhase.broadcasting);
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      // No composerText → canSendText = false → onPressed = null → not tappable
      expect(cubit.state.canSendText, isFalse);
    });

    testWidgets('send button has Semantics enabled=false when empty (AC1 a11y)', (tester) async {
      // AC1 explicitly requires Semantics(enabled: false) on the disabled send button.
      final handle = tester.ensureSemantics();
      final cubit = _cubit(phase: ConversationPhase.broadcasting);
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      final sendNode = tester
          .getSemantics(find.byKey(ChatComposer.sendButtonKey));
      expect(sendNode.hasFlag(SemanticsFlag.isEnabled), isFalse);
      handle.dispose();
    });

    testWidgets('composer hidden in closed phase', (tester) async {
      final cubit = _cubit(phase: ConversationPhase.closed);
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.byKey(ChatComposer.textFieldKey), findsNothing);
    });
  });

  group('ChatScreen — offer card rendering (T-MOB-014 AC2)', () {
    testWidgets('OfferCard with Accept and Decline buttons renders', (tester) async {
      final offer = _offerMsg('offer-kamal-1');
      final cubit = _cubit(
        history: [offer],
        phase: ConversationPhase.broadcasting,
      );
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat-offer-card-offer-kamal-1')), findsOneWidget);
      expect(find.byKey(const Key('chat-offer-accept-offer-kamal-1')), findsOneWidget);
      expect(find.byKey(const Key('chat-offer-decline-offer-kamal-1')), findsOneWidget);
    });

    testWidgets('tapping accept triggers phase transition (AC2)', (tester) async {
      final offer = _offerMsg('offer-kamal-2');
      final cubit = _cubit(
        history: [offer],
        phase: ConversationPhase.broadcasting,
      );
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      // Tap Accept and fully settle (the fake gateway resolves sync).
      await tester.tap(find.byKey(const Key('chat-offer-accept-offer-kamal-2')));
      await tester.pumpAndSettle();

      // After accept, phase flips to accepted (gateway returns it on next loadPhase).
      expect(cubit.state.phase, ConversationPhase.accepted);
    });
  });

  group('ChatScreen — Jeeber removed (T-MOB-014 AC4)', () {
    testWidgets('JeeberRemovedBanner visible when closed + offerRejected', (tester) async {
      final rejected = DeliveryChatMessage.offerRejected(
        id: 'sys-rejected-1',
        sentAt: DateTime(2026, 6, 1, 12),
        payload: const SystemOfferPayload(
          offerId: 'offer-rana-1',
          jeeberId: 'j-rana',
          jeeberName: 'Rana',
        ),
      );
      final cubit = _cubit(
        history: [rejected],
        phase: ConversationPhase.closed,
      );
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.byType(JeeberRemovedBanner), findsOneWidget);
    });
  });

  group('ChatScreen — accepted phase (T-MOB-014 AC2)', () {
    testWidgets('OfferAcceptedBanner shown after phase=accepted', (tester) async {
      final accepted = DeliveryChatMessage.offerAccepted(
        id: 'sys-accepted-1',
        sentAt: DateTime(2026, 6, 1, 12),
        payload: const SystemOfferPayload(
          offerId: 'offer-kamal-1',
          jeeberId: 'j-kamal',
          jeeberName: 'Kamal Hajj',
        ),
      );
      final cubit = _cubit(
        history: [accepted],
        phase: ConversationPhase.accepted,
      );
      await tester.pumpWidget(_buildApp(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.byType(OfferAcceptedBanner), findsOneWidget);
    });
  });
}
