// Render tests for the JeeberKycGateBuilder previews.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberKycGateBuilder',
    const <String, Widget Function()>{
      'none · register prompt': jeeberKycGateBuilderNotOnboarded,
      'pending · feed, offering gated': jeeberKycGateBuilderPending,
      'approved · offering unlocked': jeeberKycGateBuilderApproved,
      'rejected · terminal': jeeberKycGateBuilderRejected,
      'live · fetch in flight': jeeberKycGateBuilderLiveFetchInFlight,
      'live · approved lands late': jeeberKycGateBuilderLiveApprovedLandsLate,
    },
    // Each state names the gate it came from AND the destination it resolved,
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
      await pumpPreview(tester, jeeberKycGateBuilderPending);

      // The W2-closer fix: `pending` must NOT collapse to the register prompt,
      expect(find.text('Available requests'), findsOneWidget);
      expect(find.text('Register as a delivery man'), findsNothing);
      expect(find.text('Offering gated'), findsOneWidget);
    });

    testWidgets('only approved unlocks offering, on the same destination', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGateBuilderApproved);

      // Same headline as the pending preview — the offering line is the only
      expect(find.text('Available requests'), findsOneWidget);
      expect(find.text('Offering unlocked'), findsOneWidget);
    });

    testWidgets('rejected resolves to the terminal destination, not the feed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGateBuilderRejected);

      expect(find.text("We couldn't verify your identity"), findsOneWidget);
      expect(find.text('Available requests'), findsNothing);
    });

    testWidgets('the release gate never default-approves before its first read', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberKycGateBuilderLiveFetchInFlight);

      // JEBV4-267. The conservative half is right; the part this preview
      expect(find.text('Register as a delivery man'), findsOneWidget);
      expect(find.text('Offering gated'), findsOneWidget);
      expect(find.text('Available requests'), findsNothing);
    });

    testWidgets('a live read that lands AFTER the first build re-resolves', (
      WidgetTester tester,
    ) async {
      // The canvas cannot show this: the preview's fake resolves on a
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
      await pumpPreview(tester, jeeberKycGateBuilderApproved);
      expect(
        find.descendant(
          of: find.byType(JeeberKycGateBuilder),
          matching: find.byType(ListenableBuilder),
        ),
        findsNothing,
        reason: 'the const seam gate and every test fake are built once; '
            'subscribing to them would be a listener that can never fire',
      );

      await pumpPreview(tester, jeeberKycGateBuilderLiveFetchInFlight);
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
      await pumpPreview(tester, jeeberKycGateBuilderRejected);
      final double atOneX = tester
          .getRect(find.byKey(jeeberKycGateBuilderPreviewBodyKey))
          .height;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(jeeberKycGateBuilderRejected, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      final double atTwoX = tester
          .getRect(find.byKey(jeeberKycGateBuilderPreviewBodyKey))
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
