// Render tests for the KycStatusView previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
// All six previews are the SAME widget over the same cubit, told apart only by
// the canned status the fake gateway answers with — so every state pins a
// DISTINCT string from the ARB. A suite that only asked "did something render?"
// would pass on six copies of the pending body.
//
// `Status read in flight` is the one state with no text to pin: its body is a
// bare `OmdsLoadingState` with no message. It is pinned negatively instead — a
// spinner AND none of the four status titles — in the specifics group below.
//
// The last group is not preview hygiene. It is what these previews exposed:
// the CTA inversion between the two pending states, the label a re-check in
// flight throws away, the borrowed copy on two primary CTAs, and the height the
// unscrollable status body needs at 200% text on a real phone-width box.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/previews/kyc/kyc_status_view_preview.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _pendingTitle = 'Submission received';
const String _autoCheckStopped =
    "We've stopped checking automatically. "
    'Tap Check again to look for a decision.';
const String _approvedTitle = "You're approved";
const String _rejectedTitle = 'We need a second look';
const String _resubmitTitle = 'Resubmit your documents';
const String _checkAgainCta = 'Check again';
const String _topUpCta = 'Top up';
const String _selfieMismatch =
    "Your selfie didn't match the ID photo. "
    'Retake the selfie in better lighting.';

/// The status titles, so "renders its own state" can be asserted negatively for
/// the one preview that renders no text at all.
const List<String> _allTitles = <String>[
  _pendingTitle,
  _approvedTitle,
  _rejectedTitle,
  _resubmitTitle,
];

/// How many pixels a captured layout error overflowed by, or 0 when [error] is
/// not an overflow at all. Read from the message rather than pinned as an exact
/// constant: the fact under test is "this does not fit on a phone", and an exact
/// pixel count would break on a font metric change without meaning anything.
int _overflowPixels(Object? error) {
  if (error == null) return 0;
  final RegExpMatch? match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

Finder _byIdentifier(String id) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is Semantics && widget.properties.identifier == id,
  );
}

/// Pumps a preview into a real phone-width box at [textScale], the way the
/// canvas renders it, instead of into the 800x600 default test surface. The
/// width is the point: at 800 dp this body has room it never has on a phone.
Future<void> _pumpInPreviewBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = const Size(390, 700),
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'KycStatusView',
    const <String, Widget Function()>{
      'Status read in flight': kycStatusViewLoading,
      'Pending · re-check in flight': kycStatusViewPendingChecking,
      'Pending · auto-check stopped': kycStatusViewPendingAutoCheckStopped,
      'Approved': kycStatusViewApproved,
      'Rejected · selfie mismatch': kycStatusViewRejected,
      'Resubmit requested · all slots': kycStatusViewResubmitRequested,
    },
    expectedText: const <String, String>{
      // The two pending states share every string but this one, so the
      // stopped note is what tells them apart; the specifics group below
      // asserts the rest of the difference (the CTA inversion).
      'Pending · re-check in flight': _pendingTitle,
      'Pending · auto-check stopped': _autoCheckStopped,
      'Approved': _approvedTitle,
      'Rejected · selfie mismatch': _selfieMismatch,
      'Resubmit requested · all slots': _resubmitTitle,
    },
  );

  group('KycStatusView preview specifics', () {
    testWidgets('the in-flight read renders a spinner and NO status body', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewLoading);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      for (final String title in _allTitles) {
        expect(find.text(title), findsNothing, reason: title);
      }
      // JEBV4-271 round 6: this branch short-circuits before the status
      // switch, so nothing below it can render while the flag is set.
      expect(find.byKey(KycStatusView.approvedTitleKey), findsNothing);
    });

    testWidgets('the in-flight spinner carries no label of any kind', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewLoading);

      final OmdsLoadingState spinner = tester.widget<OmdsLoadingState>(
        find.byType(OmdsLoadingState),
      );
      expect(spinner.message, isNull);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a re-check in flight replaces the CTA label with a spinner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewPendingChecking);

      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byKey(KycStatusView.checkAgainCtaKey),
      );
      expect(cta.isLoading, isTrue);
      expect(find.text(_checkAgainCta), findsNothing);
      // Still the pending body, and still NOT the expired one.
      expect(find.text(_pendingTitle), findsOneWidget);
      expect(find.text(_autoCheckStopped), findsNothing);
      expect(_byIdentifier('kyc_status_poll_expired'), findsNothing);
    });

    // The two halves of the CTA inversion are deliberately SEPARATE tests.
    // Pumping a second preview into the same tester reconciles element-for
    // -element with the first — same MaterialApp, same BlocProvider, same
    // KycStatusView — so the cubit is NOT rebuilt, `didChangeDependencies`
    // does not re-run, and the second preview silently renders the first
    // preview's state. One preview per test.
    testWidgets('while the poller has budget, top-up is above the re-check', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewPendingChecking);

      expect(_byIdentifier('kyc_status_poll_expired'), findsNothing);
      expect(
        tester.getTopLeft(_byIdentifier('kyc_status_topup_cta')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(KycStatusView.checkAgainCtaKey)).dy,
        ),
      );
    });

    testWidgets('once the auto-check stops, the re-check is promoted above it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewPendingAutoCheckStopped);

      expect(_byIdentifier('kyc_status_poll_expired'), findsOneWidget);
      expect(find.text(_autoCheckStopped), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(KycStatusView.checkAgainCtaKey)).dy,
        lessThan(tester.getTopLeft(_byIdentifier('kyc_status_topup_cta')).dy),
      );
      // Promotion is colour as well as order: the re-check takes the primary
      // fill it did not have while the poller was still running.
      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byKey(KycStatusView.checkAgainCtaKey),
      );
      expect(
        cta.backgroundColor,
        Theme.of(
          tester.element(find.byType(KycStatusView)),
        ).colorScheme.primary,
      );
    });

    testWidgets('the approved primary CTA ships a borrowed section heading', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewApproved);

      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
      // L10N-REQ in the production file: this button should read "Go to feed".
      expect(find.text('Available requests'), findsOneWidget);
      expect(find.text('Go to feed'), findsNothing);
      // All three post-approval entry points are present.
      expect(_byIdentifier('kyc_status_feed_cta'), findsOneWidget);
      expect(_byIdentifier('kyc_status_wallet_cta'), findsOneWidget);
      expect(_byIdentifier('kyc_status_topup_cta'), findsOneWidget);
    });

    testWidgets('rejection is final: a reason, no resubmit CTA (D52/D87)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewRejected);

      expect(find.byKey(KycStatusView.rejectionReasonKey), findsOneWidget);
      expect(find.text(_selfieMismatch), findsOneWidget);
      expect(_byIdentifier('kyc_status_view_rejection'), findsOneWidget);
      expect(_byIdentifier('kyc_status_resubmit_cta'), findsNothing);
      // L10N-REQ: this button should read "View rejection details".
      expect(find.text('View status'), findsOneWidget);
    });

    testWidgets('resubmit lists every flagged slot AND offers the resubmit CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycStatusViewResubmitRequested);

      expect(_byIdentifier('kyc_status_resubmit_steps'), findsOneWidget);
      for (final String line in const <String>[
        'Re-capture the front of your ID',
        'Re-capture the back of your ID',
        'Retake your selfie',
        'Re-check your ID number',
        'Review your submission details',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(_byIdentifier('kyc_status_resubmit_cta'), findsOneWidget);
      expect(_byIdentifier('kyc_status_view_rejection'), findsNothing);
    });

    testWidgets('every state localizes: no English leaks into the AR reading', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        kycStatusViewPendingAutoCheckStopped,
        locale: const Locale('ar'),
      );

      expect(find.text('توقفنا عن التحقق تلقائيًا. اضغط "تحقق مرة أخرى" للبحث عن قرار.'), findsOneWidget);
      expect(find.text(_autoCheckStopped), findsNothing);
      expect(find.text(_topUpCta), findsNothing);
      final Element title = tester.element(
        find.byKey(KycStatusView.pendingTitleKey),
      );
      expect(Directionality.of(title), TextDirection.rtl);
    });
  });

  // These are the defects the previews exposed, held as assertions so they
  // cannot regress unnoticed — and so that FIXING them fails this file loudly
  // rather than leaving a stale claim behind.
  //
  // None of them is visible in the default reading: `testPreviewsRender` pumps
  // into the 800x600 test surface, where this body has 100 dp of headroom it
  // never has on a phone. Every number below is from a 390x700 box — a 844 dp
  // phone minus the wizard's AppBar, status bar and home indicator.
  group('KycStatusView layout ceiling (390x700 phone body)', () {
    testWidgets('nothing scrolls: the body is a bare Column + Spacer', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycStatusViewApproved,
        textScale: 1.0,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byType(Scrollable),
        findsNothing,
        reason:
            'with no scroll view, anything that outgrows the viewport is '
            'clipped and unreachable rather than scrolled to',
      );
    });

    testWidgets('resubmit with every slot flagged overflows at 100% text', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycStatusViewResubmitRequested,
        textScale: 1.0,
      );

      expect(
        _overflowPixels(tester.takeException()),
        greaterThan(0),
        reason:
            'five "what to fix" lines plus the reason notice is a shape the '
            'back-office can produce at will, at the DEFAULT text size',
      );
    });

    testWidgets('the stopped pending body overflows at 100% text', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycStatusViewPendingAutoCheckStopped,
        textScale: 1.0,
      );

      expect(
        _overflowPixels(tester.takeException()),
        greaterThan(0),
        reason:
            'the auto-check-stopped note is what tips the pending body over: '
            'the same body without it (re-check in flight) fits',
      );
    });

    testWidgets('the SHORTEST body overflows at 200%, taking its CTAs off', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycStatusViewApproved,
        textScale: 2.0,
      );

      expect(_overflowPixels(tester.takeException()), greaterThan(0));
      // Not merely clipped decoration — the third post-approval entry point is
      // laid out past the bottom of the phone, with nothing to scroll to it.
      expect(
        tester.getRect(_byIdentifier('kyc_status_topup_cta')).bottom,
        greaterThan(700),
        reason: 'the top-up CTA is off the bottom of a 700 dp body at 200%',
      );
    });
  });
}
