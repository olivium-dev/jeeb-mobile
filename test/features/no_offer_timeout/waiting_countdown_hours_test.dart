// Regression gate for the `1433:18 left to find a Jeeber` defect seen on real
// hardware during the live COD run.
//
// The waiting screen's private `_format` built its left-hand field from
// `Duration.inMinutes` — the TOTAL minutes of the duration, not the
// minutes-within-the-hour — so a window longer than an hour printed a raw
// minute count where a clock field belongs. The window came from the server's
// `offerDeadlineInSeconds`, and the gateway falls back to a 24 h
// `TierExpiryWindowResolver.SafeExpiryWindow` when a request's tier does not
// resolve, so a >1 h window is reachable in production and the client cannot
// prevent it.
//
// Controls this file runs:
//   POSITIVE — a 23 h 53 m 18 s window renders `23:53:18 left to find a Jeeber`
//              through the REAL screen, the REAL ARBs and the REAL localization
//              delegate (no stubbed l10n, no stubbed widget).
//   NEGATIVE — the same test asserts the pre-fix rendering `1433:18` is ABSENT.
//              Reverting `CountdownFormat.format` to `d.inMinutes` turns that
//              assertion red, and `oldFormula` below reproduces the defect
//              arithmetic in-test so the negative control is executable rather
//              than a claim: it is asserted to still produce `1433:18`, which
//              is what the screen must no longer show.
//   BOUNDARY — under an hour the format is unchanged (`4:30`), so the fix
//              cannot have silently changed the common case.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/countdown_format.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../../support/sync_app_localizations.dart';

/// The arithmetic the screen used BEFORE this fix, kept executable so the
/// negative control is demonstrated rather than asserted in prose.
String oldFormula(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

NoOfferTimeoutScreen _screen(Duration remaining) {
  final fixedNow = DateTime.utc(2026, 6, 18, 9, 0, 0);
  final seed = WaitingRequest(
    requestId: 'req-long-window',
    phase: WaitingRequestPhase.broadcasting,
    notifiedCount: 3,
    offerCount: 0,
    receivedAt: fixedNow,
    remainingAtReceipt: remaining,
  );
  return NoOfferTimeoutScreen(
    requestId: seed.requestId,
    repository: FakeWaitingRepository(seed: seed),
    cubitFactory: (repo, requestId) => WaitingCubit(
      repository: repo,
      requestId: requestId,
      now: () => fixedNow,
      refreshSignals: const Stream.empty(),
      clockTicks: const Stream.empty(),
    ),
  );
}

Future<void> _pumpScreen(WidgetTester tester, Duration remaining) async {
  await tester.pumpWidget(wrapForTest(_screen(remaining)));
  await tester.pump(); // schedule the async fake load
  await tester.pump(); // loaded → first paint
}

void main() {
  group('CountdownFormat', () {
    test('promotes to h:mm:ss at an hour or more', () {
      expect(
        CountdownFormat.format(
          const Duration(hours: 23, minutes: 53, seconds: 18),
        ),
        '23:53:18',
      );
      expect(CountdownFormat.format(const Duration(hours: 1)), '1:00:00');
      expect(
        CountdownFormat.format(const Duration(hours: 2, seconds: 5)),
        '2:00:05',
      );
    });

    test('keeps m:ss under an hour, unpadded leading field', () {
      expect(
        CountdownFormat.format(const Duration(minutes: 4, seconds: 30)),
        '4:30',
      );
      expect(CountdownFormat.format(const Duration(seconds: 4)), '0:04');
      expect(
        CountdownFormat.format(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('clamps an already-elapsed deadline to 0:00', () {
      expect(CountdownFormat.format(Duration.zero), '0:00');
      expect(CountdownFormat.format(const Duration(seconds: -5)), '0:00');
    });

    // NEGATIVE CONTROL, executable: the pre-fix arithmetic still produces the
    // defect string. If this ever stops being true the widget assertion below
    // would be checking for a string nothing could have produced, i.e. it
    // would have become a test that cannot fail.
    test('the pre-fix arithmetic really did produce 1433:18', () {
      const window = Duration(hours: 23, minutes: 53, seconds: 18);
      expect(oldFormula(window), '1433:18');
      expect(CountdownFormat.format(window), isNot(oldFormula(window)));
    });
  });

  group('waiting_countdown renders hours instead of raw minutes', () {
    testWidgets('a 23h53m18s window reads 23:53:18, never 1433:18', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        const Duration(hours: 23, minutes: 53, seconds: 18),
      );

      expect(
        find.bySemanticsIdentifier('waiting_countdown'),
        findsOneWidget,
        reason: 'the countdown node must still be the assertable surface',
      );
      expect(
        find.text('23:53:18 left to find a Jeeber'),
        findsOneWidget,
        reason: 'POSITIVE control — hours are promoted out of the minute field',
      );
      expect(
        find.text('1433:18 left to find a Jeeber'),
        findsNothing,
        reason: 'NEGATIVE control — the defect string must be gone',
      );
    });

    testWidgets('a sub-hour window is unchanged (4:30)', (tester) async {
      await _pumpScreen(tester, const Duration(minutes: 4, seconds: 30));

      expect(find.text('4:30 left to find a Jeeber'), findsOneWidget);
    });

    testWidgets('Arabic renders the same numeric run in the RTL sentence', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          _screen(const Duration(hours: 23, minutes: 53, seconds: 18)),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('23:53:18 متبقٍّ للعثور على جيبر'),
        findsOneWidget,
        reason: 'the Arabic sentence takes the same preformatted clock string',
      );
    });
  });
}
