// Render tests for the OfferKycGateScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/offer_kyc_gate_screen_fixtures.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

/// The three exits 65_W2_TEST_PLAN §2 JM-044 publishes as the QA targets, plus
/// the D67 note and the screen root.
const List<String> _gateSemanticsIds = <String>[
  'offer_kyc_gate',
  'gate_topup_note',
  'gate_start_kyc_cta',
  'gate_register_link',
  'gate_back_cta',
];

/// The status-line titles `_GateStatusLine` can render.
const String _pendingTitle = 'Submission received';
const String _rejectedTitle = 'We need a second look';
const String _resubmitTitle = 'Resubmit your documents';

/// The headline every state shows, whatever the status read did.
const String _headline = 'Get approved to start sending offers';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OfferKycGateScreen',
    const <String, Widget Function()>{
      'Not submitted': offerKycGateScreenNotSubmitted,
      'Pending': offerKycGateScreenPending,
      'Rejected': offerKycGateScreenRejected,
      'Resubmit requested': offerKycGateScreenResubmitRequested,
      'Loading': offerKycGateScreenLoading,
      'Status read failed': offerKycGateScreenStatusReadFailed,
      'Approved (should be unreachable)': offerKycGateScreenApproved,
      'Rejected · compact · 200% text': offerKycGateScreenCompactLargeText,
    },
    // Each state names its own fixture. Four of them paint identical copy, so
    expectedText: const <String, String>{
      'Not submitted': 'Not submitted · phone 390 × 844',
      'Pending': 'Pending · phone 390 × 844',
      'Rejected': 'Rejected · phone 390 × 844',
      'Resubmit requested': 'Resubmit requested · phone 390 × 844',
      'Loading': 'Loading · phone 390 × 844',
      'Status read failed': 'Status read failed · phone 390 × 844',
      'Approved (should be unreachable)': 'Approved · phone 390 × 844',
      'Rejected · compact · 200% text':
          'Rejected · compact 320 × 568 · 200% text',
    },
  );

  group('OfferKycGateScreen preview specifics', () {
    /// Pumps [preview] onto an EMPTY tree.
    /// Calling `pumpPreview` twice in one test reconciles the second preview
    Future<void> pumpFresh(
      WidgetTester tester,
      Widget Function() preview,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPreview(tester, preview);
    }

    testWidgets('only pending / rejected / resubmit carry a status line', (
      WidgetTester tester,
    ) async {
      await pumpFresh(tester, offerKycGateScreenPending);
      expect(find.text(_pendingTitle), findsOneWidget);

      await pumpFresh(tester, offerKycGateScreenRejected);
      expect(find.text(_rejectedTitle), findsOneWidget);
      expect(
        find.text(
          'Your submission was rejected for the reason below. This decision is '
          'final — you can appeal through support.',
        ),
        findsOneWidget,
      );

      await pumpFresh(tester, offerKycGateScreenResubmitRequested);
      expect(find.text(_resubmitTitle), findsOneWidget);
      // "Fix the items below, then resubmit" — and there are no items below.
      expect(
        find.text(
          'We need you to update part of your submission and send it again. '
          'Fix the items below, then resubmit.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'loading, error, notSubmitted and approved are the SAME surface',
      (WidgetTester tester) async {
        // `_GateStatusLine` returns `SizedBox.shrink()` for `phase != ready`,
        for (final Widget Function() preview in <Widget Function()>[
          offerKycGateScreenNotSubmitted,
          offerKycGateScreenLoading,
          offerKycGateScreenStatusReadFailed,
          offerKycGateScreenApproved,
        ]) {
          await pumpFresh(tester, preview);

          expect(find.text(_headline), findsOneWidget);
          for (final String title in <String>[
            _pendingTitle,
            _rejectedTitle,
            _resubmitTitle,
          ]) {
            expect(find.text(title), findsNothing);
          }
          // Nothing anywhere reports the failure or the in-flight read.
          expect(find.text('Retry'), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        }
      },
    );

    testWidgets('R-F: the exits and the top-up note never wait on the read', (
      WidgetTester tester,
    ) async {
      // The D38 invariant is independent of the network. Assert it on the two
      for (final Widget Function() preview in <Widget Function()>[
        offerKycGateScreenLoading,
        offerKycGateScreenStatusReadFailed,
      ]) {
        await pumpFresh(tester, preview);

        for (final String id in _gateSemanticsIds) {
          expect(
            find.bySemanticsIdentifier(id),
            findsOneWidget,
            reason: '$id must be up before the status read resolves',
          );
        }
      }
    });

    testWidgets('each exit reaches its own destination', (
      WidgetTester tester,
    ) async {
      // All three call into go_router and none of them runs during `build`, so
      Future<void> pumpBare(WidgetTester tester) => pumpFresh(
            tester,
            () => const OfferKycGateScreenPreviewHost(
              screen: OfferKycGateScreen(
                gateway: OfferKycGateScreenFakeGateway(),
              ),
            ),
          );

      Future<void> tapId(WidgetTester tester, String id) async {
        final Finder target = find.bySemanticsIdentifier(id);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await pumpBare(tester);
      await tapId(tester, 'gate_start_kyc_cta');
      expect(find.text(offerKycGateScreenKycStandInLabel), findsOneWidget);

      await pumpBare(tester);
      await tapId(tester, 'gate_register_link');
      // The W2 RD-1 fix: a POP would have re-resolved the DELIVERY tab and
      expect(find.text(offerKycGateScreenRegisterStandInLabel), findsOneWidget);
      expect(find.text(offerKycGateScreenFeedStandInLabel), findsNothing);

      await pumpBare(tester);
      await tapId(tester, 'gate_back_cta');
      expect(find.text(offerKycGateScreenFeedStandInLabel), findsOneWidget);
    });

    testWidgets('the app-bar arrow agrees with gate_back_cta (JEBV4-13 P1-6)', (
      WidgetTester tester,
    ) async {
      // `OMDSAppBar`'s default is `maybePop()`, which no-ops on a stack-root
      await pumpFresh(
        tester,
        () => const OfferKycGateScreenPreviewHost(
          screen: OfferKycGateScreen(gateway: OfferKycGateScreenFakeGateway()),
        ),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text(offerKycGateScreenFeedStandInLabel), findsOneWidget);
    });

    testWidgets('at the ceiling the note and all three exits are below the '
        'fold, and not built', (WidgetTester tester) async {
      await pumpFresh(tester, offerKycGateScreenCompactLargeText);

      // Nothing overflows — the body is a `ListView`, so the composition just
      expect(tester.takeException(), isNull);
      final ScrollableState body = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(OfferKycGateScreen),
          matching: find.byType(Scrollable),
        ),
      );
      // ~2287 pt of it behind a ~512 pt viewport, under this renderer.
      expect(body.position.maxScrollExtent, greaterThan(0));

      // FOUR of the five ids 65_W2_TEST_PLAN §2 JM-044 publishes are past the
      for (final String id in <String>[
        'gate_topup_note',
        'gate_start_kyc_cta',
        'gate_register_link',
        'gate_back_cta',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
      }
      // The screen root and the headline are up, so this is a reachability
      expect(find.bySemanticsIdentifier('offer_kyc_gate'), findsOneWidget);
      expect(find.text(_headline), findsOneWidget);

      // ...and they ARE there once you scroll to them.
      await tester.scrollUntilVisible(
        find.bySemanticsIdentifier('gate_back_cta'),
        200,
        scrollable: find.descendant(
          of: find.byType(OfferKycGateScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('gate_back_cta'), findsOneWidget);
    });

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, both
      Future<Size> frame(Widget Function() preview) async {
        await pumpFresh(tester, preview);
        return tester.getRect(find.byType(OfferKycGateScreen)).size;
      }

      expect(await frame(offerKycGateScreenRejected), _phoneFrame);
      expect(await frame(offerKycGateScreenCompactLargeText), _compactFrame);
    });

    testWidgets('only the compact window is text-scaled', (
      WidgetTester tester,
    ) async {
      // `OfferKycGateScreenWindow.textScale` is null on the phone window so the
      Future<double> scaleOf(Widget Function() preview) async {
        await pumpFresh(tester, preview);
        return MediaQuery.of(
          tester.element(find.byType(OfferKycGateScreen)),
        ).textScaler.scale(10);
      }

      expect(await scaleOf(offerKycGateScreenRejected), 10);
      expect(await scaleOf(offerKycGateScreenCompactLargeText), 20);
    });

    testWidgets('the fixture gateways answer only fetchStatus', (
      WidgetTester tester,
    ) async {
      // The cubit calls exactly one method. The other four throw rather than
      const OfferKycGateScreenFakeGateway gateway =
          OfferKycGateScreenFakeGateway(status: KycStatus.pending);

      expect((await gateway.fetchStatus()).status, KycStatus.pending);
      expect(() => gateway.fetchFormSchema(), throwsUnsupportedError);
      expect(() => gateway.fetchContractTemplate(), throwsUnsupportedError);
      expect(
        () => gateway.submit(
          const KycSubmission(status: KycStatus.notSubmitted),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
