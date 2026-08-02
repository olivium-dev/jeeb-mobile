import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_state.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_card.dart';

import '../../support/sync_app_localizations.dart';

/// `AppResumeSignals` coalesces at a 2 s floor with a TRAILING re-emission.
const _resumeSettle = Duration(seconds: 3);

/// Sixty ticks of the deleted 5 s poll — the "no cadence was reintroduced"
/// control.
const _idleWindow = Duration(minutes: 5);

const _requestId = 'req-n8';

/// Scripted [OffersRepository] whose bid set the test mutates BETWEEN reads,
/// and whose reads can be held open to exercise the in-flight latch.
class _ScriptedOffersRepository implements OffersRepository {
  int offerCount = 1;
  bool requestIsOpen = true;
  int fetchCount = 0;
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();

  void release() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    fetchCount++;
    await _gate?.future;
    return OffersSnapshot(
      offers: <Offer>[
        for (var index = 0; index < offerCount; index++)
          Offer(
            id: 'offer-$index',
            jeeberId: 'jeeber-$index',
            jeeberName: 'Nadia Karam $index',
            fee: (10 + index).toDouble(),
            currency: 'USD',
            etaMinutes: 12,
            vehicle: JeeberVehicle.motorcycle,
            rating: 4.5,
            ratingCount: 8,
            submittedAt: DateTime.utc(2026, 7, 28, 9, index),
          ),
      ],
      windowExpiresAt: null,
      requestIsOpen: requestIsOpen,
    );
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async => const OfferAcceptResult(deliveryId: 'del-1');
}

/// The REAL screen with only the two seams the existing widget tests use.
Widget _screen(_ScriptedOffersRepository repository) => wrapForTest(
  ClientOffersScreen(
    requestId: _requestId,
    repository: repository,
    cubitFactory: (repo, requestId) => ClientOffersCubit(
      repository: repo,
      requestId: requestId,
      refreshSignals: const Stream<void>.empty(),
      clockTicks: const Stream<void>.empty(),
    ),
  ),
);

Future<void> _driveToBackground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _driveToForeground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

Future<void> _resume(WidgetTester tester) async {
  await _driveToBackground(tester);
  await _driveToForeground(tester);
  await tester.pump(_resumeSettle);
  await tester.pump();
}

Future<void> _pumpLoaded(
  WidgetTester tester,
  _ScriptedOffersRepository repository,
) async {
  await tester.pumpWidget(_screen(repository));
  await tester.pumpAndSettle();
  expect(
    repository.fetchCount,
    1,
    reason: 'the mount one-shot — the other half of the owner ruling',
  );
  expect(find.byType(OfferCard), findsOneWidget);
}

void main() {
  tearDown(() async {
    await AppResumeSignals.debugReset();
  });

  group('N8 client offers — resume backstop', () {
    testWidgets(
      'background → foreground on a VISIBLE screen issues exactly ONE refetch '
      'and the new bid appears',
      (tester) async {
        final repository = _ScriptedOffersRepository();
        await _pumpLoaded(tester, repository);

        // A second bid lands while the app is BACKGROUNDED: the push reaches
        repository.offerCount = 2;
        await tester.pump();
        expect(
          find.byType(OfferCard),
          findsOneWidget,
          reason: 'control: the server-side change is invisible without a read',
        );

        await _resume(tester);

        expect(
          repository.fetchCount,
          2,
          reason: 'exactly one re-read on top of the mount read',
        );
        expect(
          find.byType(OfferCard),
          findsNWidgets(2),
          reason: 'the bid the push was about is now on screen',
        );
      },
    );

    testWidgets(
      'a resume while the screen is BURIED reads nothing, and returning pays '
      'exactly ONE',
      (tester) async {
        final repository = _ScriptedOffersRepository();
        await _pumpLoaded(tester, repository);

        final context = tester.element(find.byType(ClientOffersScreen));
        // Not awaited: the pushed route outlives this call.
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('jeeber profile')),
          ),
        );
        await tester.pumpAndSettle();

        repository.offerCount = 2;
        await _resume(tester);
        expect(
          repository.fetchCount,
          1,
          reason: 'an invisible surface must not read',
        );

        Navigator.of(tester.element(find.text('jeeber profile'))).pop();
        await tester.pumpAndSettle();

        expect(
          repository.fetchCount,
          2,
          reason: 'deferred, not dropped: paid once on return',
        );
        expect(find.byType(OfferCard), findsNWidgets(2));
      },
    );

    testWidgets('a rapid background/foreground FLAP costs ONE read, not N', (
      tester,
    ) async {
      final repository = _ScriptedOffersRepository();
      await _pumpLoaded(tester, repository);

      repository.hold();
      await _driveToBackground(tester);
      await _driveToForeground(tester);
      await _driveToBackground(tester);
      await _driveToForeground(tester);
      await _driveToBackground(tester);
      await _driveToForeground(tester);
      await tester.pump(_resumeSettle);
      await tester.pump();

      expect(
        repository.fetchCount,
        2,
        reason: 'one mount read plus ONE resume read for three flaps',
      );

      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'the backstop introduces NO cadence: five idle minutes cost zero reads',
      (tester) async {
        final repository = _ScriptedOffersRepository();
        await _pumpLoaded(tester, repository);

        await tester.pump(_idleWindow);
        await tester.pump();
        expect(
          repository.fetchCount,
          1,
          reason: 'the deleted 5 s Stream.periodic must stay deleted',
        );

        // POSITIVE CONTROL — the fixture can still produce a read.
        await _resume(tester);
        expect(repository.fetchCount, 2);
      },
    );
  });

  group('N8 client offers — resume coalescing (cubit level)', () {
    test('two resume events with one fetch IN FLIGHT produce ONE fetch', () async {
      final repository = _ScriptedOffersRepository();
      final cubit = ClientOffersCubit(
        repository: repository,
        requestId: _requestId,
        refreshSignals: const Stream<void>.empty(),
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, OffersScreenStatus.loaded);
      expect(repository.fetchCount, 1);

      repository.hold();
      cubit.refreshOnResume();
      await Future<void>.delayed(Duration.zero);
      cubit.refreshOnResume();
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.fetchCount,
        2,
        reason: 'the second resume coalesces onto the read already on the wire',
      );

      repository.release();
      await Future<void>.delayed(Duration.zero);

      // POSITIVE CONTROL — the latch releases; it is not permanently wedged.
      cubit.refreshOnResume();
      await Future<void>.delayed(Duration.zero);
      expect(repository.fetchCount, 3);
    });

    test('a resume on a CLOSED request reads nothing', () async {
      final repository = _ScriptedOffersRepository();
      final cubit = ClientOffersCubit(
        repository: repository,
        requestId: _requestId,
        refreshSignals: const Stream<void>.empty(),
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      repository.requestIsOpen = false;
      await cubit.load();
      expect(repository.fetchCount, 1);

      cubit.refreshOnResume();
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.fetchCount,
        1,
        reason: 'an accepted/cancelled request has a final bid list',
      );
    });
  });
}
