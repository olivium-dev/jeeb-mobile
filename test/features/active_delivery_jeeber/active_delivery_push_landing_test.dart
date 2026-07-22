// fix/push-tap-routing (run-23 CHECK B): tap-time edges of the
// `offer_accepted` push landing.
//
// The push-tap now routes the winning jeeber to
// `/jeeber/deliveries/:id/active` (see notification_deep_link.dart). By tap
// time the delivery may have moved on, so this pins the two edge landings the
// fix relies on — neither may regress into a blank/empty surface:
//
//   1. TERMINAL: the delivery already reached `Done` → the screen renders its
//      explicit `delivery_completed_state` panel (a sensible receipt-style
//      landing), NOT a stale "advance" affordance and NOT an empty list.
//   2. MISSING: the by-id fetch fails (expired/404/network) → the screen
//      renders the retryable OMDS error state, NOT a blank surface.

import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);

JeeberDelivery _delivery(JeeberDeliveryStatus status) =>
    JeeberDelivery(id: 'req-run23', status: status, dropOff: _dropOff);

class _FakeRepo implements ActiveDeliveryRepository {
  _FakeRepo({this.fetchResult, this.fetchThrows});

  final JeeberDelivery? fetchResult;
  final ActiveDeliveryException? fetchThrows;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    if (fetchThrows != null) throw fetchThrows!;
    return fetchResult ?? _delivery(JeeberDeliveryStatus.inTransit);
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async => to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'https://cdn.jeeb.app/proof/$deliveryId.jpg';
}

/// Repo whose `transition` blocks on [gate] so the test can observe the
/// OPTIMISTIC (status=done, transitioning) frame before server confirmation.
class _BlockingRepo implements ActiveDeliveryRepository {
  _BlockingRepo({required this.fetchResult, required this.gate});

  final JeeberDelivery fetchResult;
  final Completer<JeeberDeliveryStatus> gate;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async => fetchResult;

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) => gate.future;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'https://cdn.jeeb.app/proof/$deliveryId.jpg';
}

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

Widget _host(ActiveDeliveryRepository repo) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ActiveDeliveryJeeberScreen(
      deliveryId: 'req-run23',
      repository: repo,
      onOpenChat: () {},
    ),
  );
}

void main() {
  setUpAll(() {
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    _syncDelegate = _SyncAppLocalizationsDelegate({'en': en});
  });

  testWidgets('TERMINAL edge: a Done delivery at tap time renders the explicit '
      'delivery_completed_state panel (sensible landing, no stale CTA)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(_FakeRepo(fetchResult: _delivery(JeeberDeliveryStatus.done))),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('delivery_completed_state'),
      findsOneWidget,
      reason: 'a terminal delivery must land on the completed panel',
    );
    // No mark-delivered affordance on a finished delivery.
    expect(find.byType(OmdsErrorState), findsNothing);
    semantics.dispose();
  });

  for (final scenario
      in <({JeeberDeliveryStatus status, String semanticsId, String title})>[
        (
          status: JeeberDeliveryStatus.cancelled,
          semanticsId: 'delivery_cancelled_state',
          title: 'Delivery cancelled',
        ),
        (
          status: JeeberDeliveryStatus.expired,
          semanticsId: 'delivery_expired_state',
          title: 'Delivery expired',
        ),
      ]) {
    testWidgets(
      '${scenario.status.name} landing renders a distinct unsuccessful '
      'terminal state, never Done',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(_FakeRepo(fetchResult: _delivery(scenario.status))),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier(scenario.semanticsId),
          findsOneWidget,
        );
        expect(find.text(scenario.title), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('delivery_completed_state'),
          findsNothing,
        );
        expect(find.byType(OmdsStepIndicator), findsNothing);
        expect(
          find.bySemanticsIdentifier('active_delivery_stage_done'),
          findsNothing,
        );
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'MISSING edge: a failed by-id fetch renders the retryable error state '
    '(never a blank surface / empty list)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          _FakeRepo(
            fetchThrows: const ActiveDeliveryException(
              ActiveDeliveryFailure.network,
              'down',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OmdsErrorState), findsOneWidget);
    },
  );

  testWidgets('IN-FLIGHT (the P1 happy path): an active delivery renders the '
      'mark_delivered_root surface for the winning jeeber', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(_FakeRepo(fetchResult: _delivery(JeeberDeliveryStatus.inTransit))),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('mark_delivered_root'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('delivery_completed_state'),
      findsNothing,
      reason: 'an in-flight delivery must not show the completed panel',
    );
    semantics.dispose();
  });

  testWidgets('no premature Delivered panel while the optimistic AtDoor→Done is '
      'transitioning (JEBV4-276)', (tester) async {
    final gate = Completer<JeeberDeliveryStatus>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(JeeberDeliveryStatus.done);
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        _BlockingRepo(
          fetchResult: _delivery(JeeberDeliveryStatus.atDoor),
          gate: gate,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AtDoor: the mark-delivered surface is shown, no completed panel.
    expect(find.bySemanticsIdentifier('mark_delivered_cta'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('delivery_completed_state'),
      findsNothing,
    );

    // Optimistic AtDoor→Done: tapping flips status→done AND mode→transitioning
    // while the (blocked) server transition is in flight.
    await tester.ensureVisible(
      find.bySemanticsIdentifier('mark_delivered_cta'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('mark_delivered_cta'));
    await tester.pump();

    // Status is now optimistically `done` (the mark surface is gone)…
    expect(find.bySemanticsIdentifier('mark_delivered_cta'), findsNothing);
    // …but the fix keeps the completed panel hidden until the transition is
    // server-confirmed (!isTransitioning) — no premature Delivered banner.
    expect(
      find.bySemanticsIdentifier('delivery_completed_state'),
      findsNothing,
      reason: 'premature Delivered banner during the optimistic transition',
    );
    semantics.dispose();
  });
}
