/// Widget tests for OfferCardBubble (T-MOB-015).
/// Tests cover:
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_card_bubble.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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

class _FakeGateway extends ChatGateway {
  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.broadcasting;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => const Stream.empty();
}

DeliveryChatMessage _offerMsg({
  String offerId = 'offer-test-1',
  double fee = 35.0,
  int etaMinutes = 20,
  String jeeberName = 'Kamal Hajj',
}) => DeliveryChatMessage.offerCard(
      id: 'msg-$offerId',
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 1, 12),
      status: MessageStatus.delivered,
      payload: OfferCardPayload(
        offerId: offerId,
        jeeberId: 'j-$offerId',
        jeeberName: jeeberName,
        fee: fee,
        currency: 'USD',
        etaMinutes: etaMinutes,
        note: 'Fast delivery guaranteed',
        rating: 4.8,
      ),
    );

Widget _buildApp({
  required DeliveryChatMessage message,
  ValueChanged<String>? onAccept,
  ValueChanged<String>? onDecline,
  bool isAccepting = false,
  bool acceptDisabled = false,
  Locale locale = const Locale('en'),
}) {
  final cubit = ChatCubit(
    deliveryId: 'conv-test',
    gateway: _FakeGateway(),
    pickerService: StubPhotoPickerService(),
  );
  return MaterialApp(
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
        child: OfferCardBubble(
          message: message,
          onAccept: onAccept ?? (_) {},
          onDecline: onDecline,
          isAccepting: isAccepting,
          acceptDisabled: acceptDisabled,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------

void main() {
  setUpAll(_loadArb);

  group('OfferCardBubble — rendering (T-MOB-015 AC2)', () {
    testWidgets('renders Jeeber name', (tester) async {
      await tester.pumpWidget(_buildApp(message: _offerMsg()));
      await tester.pumpAndSettle();

      expect(find.text('Kamal Hajj'), findsOneWidget);
    });

    testWidgets('Accept button visible (AC2)', (tester) async {
      await tester.pumpWidget(_buildApp(message: _offerMsg()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat-offer-accept-offer-test-1')),
        findsOneWidget,
      );
    });

    testWidgets('Decline button visible when onDecline provided', (tester) async {
      await tester.pumpWidget(
        _buildApp(message: _offerMsg(), onDecline: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat-offer-decline-offer-test-1')),
        findsOneWidget,
      );
    });

    testWidgets('Decline button hidden when onDecline is null', (tester) async {
      await tester.pumpWidget(_buildApp(message: _offerMsg(), onDecline: null));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat-offer-decline-offer-test-1')),
        findsNothing,
      );
    });
  });

  group('OfferCardBubble — interactions (T-MOB-015 AC1, AC4)', () {
    testWidgets('Accept callback fires with offerId (AC1)', (tester) async {
      String? accepted;
      await tester.pumpWidget(
        _buildApp(
          message: _offerMsg(offerId: 'offer-abc'),
          onAccept: (id) => accepted = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat-offer-accept-offer-abc')));
      await tester.pump();

      expect(accepted, 'offer-abc');
    });

    testWidgets('Decline callback fires with offerId (AC4)', (tester) async {
      String? declined;
      await tester.pumpWidget(
        _buildApp(
          message: _offerMsg(offerId: 'offer-def'),
          onDecline: (id) => declined = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat-offer-decline-offer-def')));
      await tester.pump();

      expect(declined, 'offer-def');
    });

    testWidgets('acceptDisabled=true blocks callback (AC3 race guard)', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _buildApp(
          message: _offerMsg(offerId: 'offer-ghi'),
          onAccept: (_) => taps++,
          acceptDisabled: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat-offer-accept-offer-ghi')));
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('OfferCardBubble — loading state (T-MOB-015 AC1)', () {
    testWidgets('isAccepting=true shows accepting label', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          message: _offerMsg(),
          isAccepting: true,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(find.text(l10n.chatOfferAccepting), findsOneWidget);
    });
  });

  group('OfferCardBubble — semantics (T-MOB-015 AC5)', () {
    testWidgets('Accept button key present for a11y tooling', (tester) async {
      await tester.pumpWidget(_buildApp(message: _offerMsg()));
      await tester.pumpAndSettle();

      // The Accept widget is keyed so screen-readers and Maestro can target it.
      expect(
        find.byKey(const Key('chat-offer-accept-offer-test-1')),
        findsOneWidget,
      );
    });

    testWidgets('Decline button key present for a11y tooling', (tester) async {
      await tester.pumpWidget(
        _buildApp(message: _offerMsg(), onDecline: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat-offer-decline-offer-test-1')),
        findsOneWidget,
      );
    });

    testWidgets('Offer card container has semantics identifier', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildApp(message: _offerMsg()));
      await tester.pumpAndSettle();

      // The outer card Padding widget carries the semantics identifier
      expect(
        find.bySemanticsIdentifier('chat_detail_message_msg-offer-test-1'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
