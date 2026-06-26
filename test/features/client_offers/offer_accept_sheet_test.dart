// JM-029 — Accept Offer Confirmation sheet (offer-accept-confirm).
//
// Proves, against the real ARBs + OMDS theme, that:
//   AC1: the sheet surfaces every EXACT Semantics identifier from
//        63_W1_TEST_PLAN §2.9 as its own queryable SemanticsNode
//        (`offer_accept_sheet`, `_jeeber_name`, `_price_label`,
//         `_other_offers_note`, `_confirm_cta`, `_cancel_cta`).
//   AC2: tapping `offer_accept_confirm_cta` accepts the chosen offer via the
//        repository (capturing the fee + closing losers server-side) and fires
//        `onConfirmed` with the server `conversationId` (the order-chat target).
//   AC3: tapping `offer_accept_cancel_cta` fires `onCancelled` (→ dismiss back
//        to offer-review-list) and does NOT accept.
//
// FAIL-WITHOUT: every `bySemanticsIdentifier` assertion `findsNothing` on the
// pre-JM-029 source (the sheet did not exist). Harness mirrors
// test/qa_keys_batch_test.dart (synchronous LocalizationsDelegate over the real
// ARBs + a tall/wide surface so nothing is culled off-screen).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_accept_sheet.dart';

import '../../support/scripted_offers_repository.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Offer _offer() => Offer(
      id: 'offer-001',
      jeeberId: 'user-jeeber-002',
      jeeberName: 'Kamal Hajj',
      fee: 6.0,
      currency: 'USD',
      etaMinutes: 20,
      vehicle: JeeberVehicle.scooter,
      rating: 4.8,
      ratingCount: 42,
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

ScriptedOffersRepository _repo({
  String? conversationId,
  String? deliveryId,
  OffersFailure? acceptFailure,
}) {
  final repo = ScriptedOffersRepository(
    snapshots: const <OffersSnapshot>[],
    acceptFailure: acceptFailure,
  )
    ..acceptConversationId = conversationId
    ..acceptDeliveryId = deliveryId;
  return repo;
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The sheet is normally hosted by showModalBottomSheet; here we mount it
    // directly inside a Scaffold body so the widget tree is the sheet content.
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('JM-029 OfferAcceptSheet', () {
    testWidgets('AC1 — surfaces every EXACT Semantics identifier (63 §2.9)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          OfferAcceptSheet(
            offer: _offer(),
            requestId: 'req-client-001-offers',
            repository: _repo(conversationId: 'conv-journey-accepted'),
          ),
        ),
      );
      await tester.pump();

      for (final id in const [
        'offer_accept_sheet',
        'offer_accept_jeeber_name',
        'offer_accept_price_label',
        'offer_accept_other_offers_note',
        'offer_accept_confirm_cta',
        'offer_accept_cancel_cta',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id must surface as its own SemanticsNode.',
        );
      }
    });

    testWidgets(
        'AC2 — confirm accepts the offer and reports the order-chat '
        'conversationId', (tester) async {
      final repo = _repo(
        conversationId: 'conv-journey-accepted',
        deliveryId: 'delivery-journey-001',
      );
      OfferAcceptResult? reported;
      var confirmedCount = 0;

      await tester.pumpWidget(
        _harness(
          OfferAcceptSheet(
            offer: _offer(),
            requestId: 'req-client-001-offers',
            repository: repo,
            onConfirmed: (result) {
              confirmedCount++;
              reported = result;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('offer_accept_confirm_cta'));
      await tester.pump(); // submitting
      await tester.pump(); // succeeded → listener fires

      expect(repo.acceptCalls, 1);
      expect(repo.lastAcceptedRequestId, 'req-client-001-offers');
      expect(repo.lastAcceptedOfferId, 'offer-001');
      expect(confirmedCount, 1);
      expect(reported?.conversationId, 'conv-journey-accepted');
      // The accept now creates an active delivery; its id is surfaced so the
      // order-chat "Track order" CTA is reachable.
      expect(reported?.deliveryId, 'delivery-journey-001');
    });

    testWidgets('AC2b — a null conversationId is reported (requestId fallback)',
        (tester) async {
      final repo = _repo();
      OfferAcceptResult? reported;
      var confirmedCount = 0;

      await tester.pumpWidget(
        _harness(
          OfferAcceptSheet(
            offer: _offer(),
            requestId: 'req-client-001-offers',
            repository: repo,
            onConfirmed: (result) {
              confirmedCount++;
              reported = result;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('offer_accept_confirm_cta'));
      await tester.pump();
      await tester.pump();

      expect(repo.acceptCalls, 1);
      expect(confirmedCount, 1);
      // A gateway that surfaces neither id reports a result with both null —
      // navigation then falls back to the requestId for the chat target.
      expect(reported?.conversationId, isNull);
      expect(reported?.deliveryId, isNull);
    });

    testWidgets(
        'T-APP-1 — show() opens chat-detail by the REQUEST id, NOT the '
        'phantom conversationId the accept response carries', (tester) async {
      // SHARED CHAT CONTRACT: after accept there is ONE real conversation keyed
      // by requestId, joined by BOTH the customer and the winning jeeber. The
      // accept response may carry a PHANTOM conversationId (`conv-for-<reqId>`)
      // the gateway mints before the real conversation exists. The app must open
      // chat by REQUEST id (resolve-or-create), never by trusting that phantom.
      const requestId = 'req-client-001-offers';
      const phantom = 'conv-for-$requestId';
      final repo = _repo(conversationId: phantom, deliveryId: 'dlv-1');

      String? routedChatId;
      String? routedDeliveryId;
      final router = GoRouter(
        initialLocation: '/offers',
        routes: [
          GoRoute(
            path: '/offers',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    key: const Key('open-accept-sheet'),
                    onPressed: () => OfferAcceptSheet.show(
                      context,
                      offer: _offer(),
                      requestId: requestId,
                      repository: repo,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            name: 'chat-detail',
            path: '/chat/:id',
            builder: (context, state) {
              routedChatId = state.pathParameters['id'];
              routedDeliveryId = state.uri.queryParameters['deliveryId'];
              return const Scaffold(
                body: Center(child: Text('chat', key: Key('chat-screen'))),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            _syncDelegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      );
      await tester.pump();

      // Open the sheet, then confirm the accept.
      await tester.tap(find.byKey(const Key('open-accept-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('offer_accept_confirm_cta'));
      await tester.pump(); // submitting
      await tester.pump(); // succeeded → listener navigates
      await tester.pumpAndSettle();

      expect(repo.acceptCalls, 1);
      expect(find.byKey(const Key('chat-screen')), findsOneWidget);
      // The load-bearing assertion: chat opened by the REQUEST id, never the
      // phantom conversationId from the accept response.
      expect(routedChatId, requestId);
      expect(routedChatId, isNot(phantom));
      // The real delivery id is still forwarded so the Track-order CTA works.
      expect(routedDeliveryId, 'dlv-1');
    });

    testWidgets('AC3 — cancel dismisses and does NOT accept', (tester) async {
      final repo = _repo(conversationId: 'conv-journey-accepted');
      var cancelledCount = 0;

      await tester.pumpWidget(
        _harness(
          OfferAcceptSheet(
            offer: _offer(),
            requestId: 'req-client-001-offers',
            repository: repo,
            onCancelled: () => cancelledCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('offer_accept_cancel_cta'));
      await tester.pump();

      expect(cancelledCount, 1);
      expect(repo.acceptCalls, 0);
    });
  });
}
