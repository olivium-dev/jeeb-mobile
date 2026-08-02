// Render tests for the JeeberKycGateBuilder previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// JeeberKycGateBuilder paints nothing, so "did it render" is a weak question
// here — all six previews would pass a render-only check while showing the same
// destination. The expected strings therefore pin `source · status →
// destination` for each state, and the group below pins the two behaviours the
// canvas cannot show at all: that a live read landing after the first build
// re-resolves the subtree, and that a non-Listenable gate is built without a
// ListenableBuilder at all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/previews/core/jeeber_kyc_gate_builder_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberKycGateBuilder',
    const <String, Widget Function()>{
      'none · register prompt': jeeberKycGateNotOnboarded,
      'pending · feed, offering gated': jeeberKycGatePending,
      'approved · offering unlocked': jeeberKycGateApproved,
      'rejected · terminal': jeeberKycGateRejected,
      'live · fetch in flight': jeeberKycGateLiveFetchInFlight,
      'live · approved lands late': jeeberKycGateLiveApprovedLandsLate,
    },
    // Each state names the gate it came from AND the destination it resolved,
    // so a preview wired to the wrong status — or six previews accidentally
    // sharing one gate — fails here rather than looking fine in the canvas.
    // `live · approved → feed` is the strongest of these: the live gate reports
    // `none` synchronously, so that string can only appear if the notify path
    // ran.
    expectedText: const <String, String>{
      'none · register prompt': 'sync · none → registerPrompt',
      'pending · feed, offering gated': 'sync · pending → feed',
      'approved · offering unlocked': 'sync · approved → feed',
      'rejected · terminal': 'sync · rejected → kycRejected',
      'live · fetch in flight': 'live · none → registerPrompt',
      'live · approved lands late': 'live · approved → feed',
    },
  );

  group('JeeberKycGateBuilder preview specifics', () {
    testWidgets('a pending jeeber browses the feed with offering gated (D38)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGatePending);

      // The W2-closer fix: `pending` must NOT collapse to the register prompt,
      // or `feed_make_offer_cta` → `offer_kyc_gate` becomes unreachable.
      expect(find.text('Available requests'), findsOneWidget);
      expect(find.text('Register as a delivery man'), findsNothing);
      expect(find.text('Offering gated'), findsOneWidget);
    });

    testWidgets('only approved unlocks offering, on the same destination', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGateApproved);

      // Same headline as the pending preview — the offering line is the only
      // thing that separates the two states.
      expect(find.text('Available requests'), findsOneWidget);
      expect(find.text('Offering unlocked'), findsOneWidget);
    });

    testWidgets('rejected resolves to the terminal destination, not the feed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGateRejected);

      expect(find.text("We couldn't verify your identity"), findsOneWidget);
      expect(find.text('Available requests'), findsNothing);
    });

    testWidgets('the release gate never default-approves before its first read', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGateLiveFetchInFlight);

      // JEBV4-267. The conservative half is right; the part this preview
      // exposes is that the pre-fetch window is rendered as the register prompt
      // — pixel-identical to "never onboarded" — because JeeberKycStatus has no
      // `unknown` member to render a loading state from.
      expect(find.text('Register as a delivery man'), findsOneWidget);
      expect(find.text('Offering gated'), findsOneWidget);
      expect(find.text('Available requests'), findsNothing);
    });

    testWidgets('a live read that lands AFTER the first build re-resolves', (
      WidgetTester tester,
    ) async {
      // The canvas cannot show this: the preview's fake resolves on a
      // microtask, so the `none` frame is gone before the first paint. Driving
      // the completer by hand is the only way to assert the ListenableBuilder
      // branch actually re-runs the builder.
      final _DeferredKycGateway gateway = _DeferredKycGateway();
      final LiveJeeberKycStatusGate gate = LiveJeeberKycStatusGate(
        gateway,
        useLiveSource: true,
      );
      addTearDown(gate.dispose);

      await tester.pumpWidget(
        previewCanvas(() => _probe(gate), const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.text('none → registerPrompt'), findsOneWidget);

      gateway.land(KycStatus.approved);
      await tester.pumpAndSettle();

      expect(
        find.text('approved → feed'),
        findsOneWidget,
        reason: 'the gate notified but the subtree did not re-resolve — an '
            'approved jeeber would be stuck on the register prompt until a '
            're-login, which is the whole reason JeeberKycGateBuilder exists',
      );
    });

    testWidgets('resubmit-requested lands on the feed with offering gated', (
      WidgetTester tester,
    ) async {
      // E19 tri-state (JEBV4-214): `ResubmitRequested` maps to `pending` for
      // this coarse gate. It has no preview of its own because it is visually
      // identical to `pending` — that identity is the thing worth pinning, so
      // that a future split of the mapping shows up here.
      final LiveJeeberKycStatusGate gate = LiveJeeberKycStatusGate(
        FakeKycGateway(
          initial: const KycSubmission(status: KycStatus.resubmitRequested),
        ),
        useLiveSource: true,
      );
      addTearDown(gate.dispose);

      await tester.pumpWidget(
        previewCanvas(() => _probe(gate), const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('pending → feed'), findsOneWidget);
      expect(gate.isApproved, isFalse);
    });

    testWidgets('a non-Listenable gate is built without a ListenableBuilder', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGateApproved);
      expect(
        find.descendant(
          of: find.byType(JeeberKycGateBuilder),
          matching: find.byType(ListenableBuilder),
        ),
        findsNothing,
        reason: 'the const seam gate and every test fake are built once; '
            'subscribing to them would be a listener that can never fire',
      );

      await pumpPreview(tester, jeeberKycGateLiveFetchInFlight);
      expect(
        find.descendant(
          of: find.byType(JeeberKycGateBuilder),
          matching: find.byType(ListenableBuilder),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the 200% rendering still fits the canvas box it declares', (
      WidgetTester tester,
    ) async {
      // `JeebPreview` renders every state a third time at textScaleFactor 2.0,
      // and nothing else in this suite exercises that. The rejected state
      // carries the longest headline of the three destinations, so it is the
      // one that decides whether the declared box is honest.
      await pumpPreview(tester, jeeberKycGateRejected);
      final double atOneX = tester
          .getRect(find.byKey(jeeberKycGatePreviewBodyKey))
          .height;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(jeeberKycGateRejected, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      final double atTwoX = tester
          .getRect(find.byKey(jeeberKycGatePreviewBodyKey))
          .height;

      expect(
        atTwoX,
        greaterThan(atOneX),
        reason: 'if these match, the MediaQuery override never reached the '
            'widget and this test is asserting nothing',
      );
      expect(
        atTwoX,
        lessThan(_canvasHeight),
        reason: 'measured 216 pt at 200% against the declared $_canvasHeight '
            'pt canvas box, with the test font, which is wider than the real '
            'one — so the canvas rendering has room too',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Mirrors the preview library's canvas height so the box it declares is
/// asserted rather than assumed.
const double _canvasHeight = 280;

/// The smallest possible consumer of the gate: renders `status → destination`
/// and nothing else, so a re-resolve is observable as a text change.
Widget _probe(JeeberKycStatusGate gate) => JeeberKycGateBuilder(
      gate: gate,
      builder: (BuildContext context, JeeberKycStatusGate gate) => Text(
        '${gate.status.name} → '
        '${JeeberDeliveryTabDestination.forStatus(gate.status).name}',
        textDirection: TextDirection.ltr,
      ),
    );

/// A [KycGateway] whose status read completes only when the test says so.
/// Extends production's in-memory [FakeKycGateway] so the other four members
/// stay inert without restating them.
class _DeferredKycGateway extends FakeKycGateway {
  final Completer<KycSubmission> _completer = Completer<KycSubmission>();

  @override
  Future<KycSubmission> fetchStatus() => _completer.future;

  void land(KycStatus status) =>
      _completer.complete(KycSubmission(status: status));
}
