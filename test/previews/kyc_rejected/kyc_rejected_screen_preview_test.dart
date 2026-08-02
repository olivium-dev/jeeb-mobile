// Render tests for the KycRejectedScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// ## Why `expectedText` pins captions for five of the nine states
//
// `_RejectionReasonSection` renders `SizedBox.shrink()` whenever
// `state.rejectionReason == null`, so four different upstream outcomes —
// loading, a failed read, a rejected submission with no structured cause, and a
// non-rejected submission whose cause the cubit drops — paint the identical
// surface, and the compact card is an existing card at a different width. Those
// five have no screen copy of their own to pin; a suite that pinned copy would
// pass with two previews wired to the same fixture. The four states that DO
// carry a distinct sentence pin that sentence instead. The `preview specifics`
// group below then asserts the real state behind every caption, so the caption
// is never the whole proof.
//
// ## Fonts
//
// `loadInterTestFont()` runs before every test here, because the shared harness
// does not load fonts and Flutter's test face makes every glyph a 1-em square —
// Latin measures ~2x too wide, Arabic ~2.4x. The one claim in this file that
// depends on real metrics — "nothing overflows on a 320x568 device at 200% text,
// in either locale" — is measured through `withGoldenTestFonts`, which is the
// only way to get real Arabic metrics: the preview host builds `AppTheme.light()`
// unmodified and the theme carries no `fontFamilyFallback`, so under the shared
// harness every Arabic glyph still falls back to the test face.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The four localized causes, as `app_en.arb` spells them.
const String _idUnreadable =
    "We couldn't read the ID photos. Make sure both sides are sharp and "
    'well-lit.';
const String _selfieMismatch =
    "Your selfie didn't match the ID photo. Retake the selfie in better "
    'lighting.';
const String _expired = 'Your ID looks expired. Submit a current document.';
const String _other = 'Please review your details and resubmit.';

/// The FINAL copy every state shares.
const String _headline = "We couldn't verify your identity";
const String _finalBody = 'This decision is final. If you believe this is a '
    'mistake, you can appeal through support.';

/// `previewCanvas`, but with the deterministic Arabic face wired into the theme.
///
/// The shared harness cannot do this — it builds `AppTheme.light()` directly —
/// and without it every Arabic glyph is laid out in the 1-em test face, which is
/// ~2.4x too wide. Used only where a geometry claim is being made.
Widget _kycRejectedCanvasWithFonts(Widget Function() preview, Locale locale) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

/// Pumps [preview] into a FRESH element tree.
///
/// Every preview in this file is the same widget tree — `_KycRejectedScreenHost`
/// → `Router` → `KycRejectedScreen` — differing only in the gateway handed to
/// it, so pumping a second preview over the first would reuse the first
/// preview's element and with it the first preview's cubit: the assertion would
/// then be about the state that is still on screen. Pumping a bare `SizedBox`
/// first unmounts everything, because the root widget type changes.
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// Every string the surface is currently painting, minus the dev-chrome caption
/// and the preview stand-ins. Two states that produce the same list are the same
/// picture.
List<String> _paintedCopy(WidgetTester tester) {
  final List<String> out = <String>[
    for (final Text text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data case final String data)
        if (!data.startsWith('preview')) data,
  ];
  out.sort();
  return out;
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'KycRejectedScreen',
    const <String, Widget Function()>{
      'Reason · ID unreadable': kycRejectedScreenIdUnreadable,
      'Reason · selfie mismatch': kycRejectedScreenSelfieMismatch,
      'Reason · document expired': kycRejectedScreenExpired,
      'Reason · other/generic': kycRejectedScreenOtherReason,
      'Rejected · no structured reason': kycRejectedScreenNoStructuredReason,
      'Loading · status in flight': kycRejectedScreenStatusInFlight,
      'Error · status read failed': kycRejectedScreenStatusReadFailed,
      'resubmitRequested · reason dropped': kycRejectedScreenResubmitRequested,
      'Longest reason · compact viewport': kycRejectedScreenCompactLongest,
    },
    expectedText: const <String, String>{
      // The four states that carry a sentence only THEY can produce.
      'Reason · ID unreadable': _idUnreadable,
      'Reason · selfie mismatch': _selfieMismatch,
      'Reason · document expired': _expired,
      'Reason · other/generic': _other,
      // The five that do not — see the header note.
      'Rejected · no structured reason':
          KycRejectedScreenCaptions.noStructuredReason,
      'Loading · status in flight': KycRejectedScreenCaptions.statusInFlight,
      'Error · status read failed': KycRejectedScreenCaptions.statusReadFailed,
      'resubmitRequested · reason dropped':
          KycRejectedScreenCaptions.resubmitRequested,
      'Longest reason · compact viewport':
          KycRejectedScreenCaptions.compactLongest,
    },
  );

  // The shared suite pumps at the tester's default 800x600 surface, where this
  // screen has 410 pt of width it does not have on a phone. These pump each
  // preview at the box its `@JeebPreview(size:)` declares, at the text scales
  // the canvas matrix renders, which is the only way the declared size stays
  // honest.
  group('KycRejectedScreen previews · at the declared canvas box', () {
    /// A real device rather than the test default: [Size] in logical pixels at
    /// dpr 1, so `physicalSize` is the box the preview declares. Fonts are the
    /// real ones — every assertion in this group is about geometry.
    Future<void> pumpAtBox(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_kycRejectedCanvasWithFonts(preview, locale));
      await tester.pumpAndSettle();
    }

    const Map<String, Widget Function()> all = <String, Widget Function()>{
      'Reason · ID unreadable': kycRejectedScreenIdUnreadable,
      'Reason · selfie mismatch': kycRejectedScreenSelfieMismatch,
      'Reason · document expired': kycRejectedScreenExpired,
      'Reason · other/generic': kycRejectedScreenOtherReason,
      'Rejected · no structured reason': kycRejectedScreenNoStructuredReason,
      'Loading · status in flight': kycRejectedScreenStatusInFlight,
      'Error · status read failed': kycRejectedScreenStatusReadFailed,
      'resubmitRequested · reason dropped': kycRejectedScreenResubmitRequested,
      'Longest reason · compact viewport': kycRejectedScreenCompactLongest,
    };

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry in all.entries) {
        testWidgets('${entry.key} · ${locale.languageCode} · 390x844', (
          WidgetTester tester,
        ) async {
          await pumpAtBox(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    // The claim the section header makes, and the reason this screen has no
    // KNOWN-overflow table while its siblings do: the body is a `ListView`, so
    // the accessibility ceiling on the narrowest supported device pushes the
    // CTAs below the fold instead of past the edge. Measured with real fonts —
    // under the 1-em test face these numbers would be inflated ~2x (Latin) and
    // ~2.4x (Arabic), and an overflow measured there may exist on no device.
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final double scale in const <double>[1.0, 1.5, 2.0]) {
        testWidgets(
          'the longest reason is clean on a 320x568 device at '
          '${(scale * 100).round()}% text · ${locale.languageCode}',
          (WidgetTester tester) async {
            await pumpAtBox(
              tester,
              kycRejectedScreenCompactLongest,
              locale: locale,
              textScale: scale,
              size: const Size(320, 568),
            );

            expect(tester.takeException(), isNull);
            expect(
              find.bySemanticsIdentifier('kyc_rejected_root'),
              findsOneWidget,
            );
            expect(find.byType(Scrollable), findsOneWidget);
          },
        );
      }
    }

    // The consequence of that scroll, and the finding a non-scrolling sibling
    // cannot produce: a `ListView` does not build what is past the fold, so at
    // 150% text on a 320 pt device the appeal CTA — the primary action, and the
    // only route to an appeal on a FINAL decision — is not in the element tree
    // at all until the user scrolls. Nothing is lost (the scroll reaches it, and
    // the sliver reports scrollable semantics), but any harness that asserts on
    // `kyc_rejected_appeal_cta` being present — 65_W2_TEST_PLAN §2 JM-043 pairs
    // it with the `kyc_rejected_resubmit_cta` absence check — is device- and
    // text-scale-dependent, and passes on a 390 pt phone while failing on a
    // compact one.
    testWidgets(
      'KNOWN: at 150% on a 320x568 device the appeal CTA is not built until '
      'scrolled',
      (WidgetTester tester) async {
        await pumpAtBox(
          tester,
          kycRejectedScreenCompactLongest,
          textScale: 1.5,
          size: const Size(320, 568),
        );

        expect(
          find.bySemanticsIdentifier('kyc_rejected_appeal_cta'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('kyc_rejected_back_cta'),
          findsNothing,
        );
        // ...while the two ids the JM-043 scenario asserts ARE reachable on the
        // reference phone, which is what makes this a device-dependent check
        // rather than a broken screen.
        expect(find.bySemanticsIdentifier('kyc_rejected_root'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Back to profile'),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        // Scrolling builds them, and both exits are real.
        expect(
          find.bySemanticsIdentifier('kyc_rejected_appeal_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('kyc_rejected_back_cta'),
          findsOneWidget,
        );
        expect(tester.getTopLeft(find.text('Back to profile')).dy, lessThan(568));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('on the 390x844 reference phone nothing is deferred at 100%', (
      WidgetTester tester,
    ) async {
      await pumpAtBox(tester, kycRejectedScreenIdUnreadable);

      for (final String id in const <String>[
        'kyc_rejected_root',
        'kyc_rejected_reason',
        'kyc_rejected_appeal_cta',
        'kyc_rejected_back_cta',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('KycRejectedScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree —
    // `_KycRejectedScreenHost` → `Router` → `KycRejectedScreen` — differing only
    // in the gateway handed to it, so pumping a second preview into the same
    // tester would reuse the first preview's element and with it the first
    // preview's cubit.

    testWidgets('the reason states show the JM-043 signature ids', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycRejectedScreenIdUnreadable);

      for (final String id in const <String>[
        'kyc_rejected_root',
        'kyc_rejected_reason',
        'kyc_rejected_appeal_cta',
        'kyc_rejected_back_cta',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget);
      }
      expect(find.text(_headline), findsOneWidget);
      expect(find.text(_idUnreadable), findsOneWidget);
    });

    testWidgets('each structured cause renders ITS OWN sentence', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycRejectedScreenSelfieMismatch);

      expect(find.text(_selfieMismatch), findsOneWidget);
      expect(find.text(_idUnreadable), findsNothing);
      expect(find.text(_expired), findsNothing);
      expect(find.text(_other), findsNothing);
    });

    testWidgets('no state anywhere offers a resubmit CTA (D52/D87)', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        kycRejectedScreenIdUnreadable,
        kycRejectedScreenOtherReason,
        kycRejectedScreenNoStructuredReason,
        kycRejectedScreenResubmitRequested,
      ]) {
        await _pumpFresh(tester, preview);

        expect(
          find.bySemanticsIdentifier('kyc_rejected_resubmit_cta'),
          findsNothing,
        );
        expect(find.text('Appeal via support'), findsOneWidget);
      }
    });

    // KNOWN DEFECT, pinned deliberately — the first finding in the section
    // header of `kyc_rejected_screen.dart`.
    //
    // The screen's contract is that the decision is FINAL and offers no
    // resubmit, and `test/decision_violations_test.dart` enforces that with
    // `expect(find.textContaining('resubmit'), findsNothing)`. That test builds
    // a bare `FakeKycGateway()`, whose stored submission is `notSubmitted`, so
    // no reason ever renders and the assertion never sees the copy below. The
    // catalog's own `Reason — other/generic` state does render it.
    //
    // This asserts the CURRENT behaviour. When the reason copy is rewritten for
    // the FINAL surface it fails; that is the signal to delete it, not to change
    // the fixture.
    testWidgets(
      "KNOWN: the 'other' cause tells a user with no resubmit path to resubmit",
      (WidgetTester tester) async {
        await pumpPreview(tester, kycRejectedScreenOtherReason);

        expect(find.text(_finalBody), findsOneWidget);
        expect(find.text(_other), findsOneWidget);
        expect(find.textContaining('resubmit'), findsOneWidget);
        // ...and there is nowhere to do it.
        expect(
          find.bySemanticsIdentifier('kyc_rejected_resubmit_cta'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'KNOWN: two more causes give instructions this screen cannot honour',
      (WidgetTester tester) async {
        await _pumpFresh(tester, kycRejectedScreenExpired);
        expect(find.textContaining('Submit a current document'), findsOneWidget);

        await _pumpFresh(tester, kycRejectedScreenSelfieMismatch);
        expect(find.textContaining('Retake the selfie'), findsOneWidget);
      },
    );

    // The second finding: a failed read, a hung read and a rejection with no
    // structured cause are ONE picture. Nothing on the surface — no spinner, no
    // banner, no retry — separates them.
    testWidgets('loading, failed and no-reason paint the identical surface', (
      WidgetTester tester,
    ) async {
      await _pumpFresh(tester, kycRejectedScreenNoStructuredReason);
      final List<String> loaded = _paintedCopy(tester);

      await _pumpFresh(tester, kycRejectedScreenStatusInFlight);
      final List<String> loading = _paintedCopy(tester);

      await _pumpFresh(tester, kycRejectedScreenStatusReadFailed);
      final List<String> failed = _paintedCopy(tester);

      expect(loaded, containsAll(<String>[_headline, _finalBody]));
      expect(loading, loaded);
      expect(failed, loaded);
      // And none of them names a cause.
      expect(find.bySemanticsIdentifier('kyc_rejected_reason'), findsNothing);

      // The control, and the reason the three equalities above mean anything:
      // a state that DOES carry a cause produces a different list through the
      // same helper. Without this, an element-reuse bug in `_pumpFresh` would
      // make this test pass by comparing one surface with itself three times.
      await _pumpFresh(tester, kycRejectedScreenIdUnreadable);
      final List<String> withReason = _paintedCopy(tester);
      expect(withReason, isNot(loaded));
      expect(withReason, contains(_idUnreadable));
    });

    testWidgets('the failed read shows no error affordance at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycRejectedScreenStatusReadFailed);

      expect(tester.takeException(), isNull);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.bySemanticsIdentifier('kyc_rejected_reason'), findsNothing);
      // The FINAL copy is up regardless, which is the deliberate half of this.
      expect(find.text(_headline), findsOneWidget);
    });

    // The fourth finding: `load()` clears the reason for any status that is not
    // `rejected`, so an ACTIONABLE resubmitRequested decision — reason attached,
    // `resubmitSteps` attached — is rendered as the appeal-only dead end.
    testWidgets('a resubmitRequested submission is shown as FINAL', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycRejectedScreenResubmitRequested);

      expect(find.text(_finalBody), findsOneWidget);
      // The cause the back-office attached is dropped on the floor.
      expect(find.bySemanticsIdentifier('kyc_rejected_reason'), findsNothing);
      expect(find.text(_idUnreadable), findsNothing);
    });

    testWidgets('the appeal CTA reaches support-ticket', (
      WidgetTester tester,
    ) async {
      // Proves the preview host is honest to tap in: the screen's
      // `goNamed('support-ticket')` needs a Router, and a preview without one
      // would throw here instead of navigating.
      await pumpPreview(tester, kycRejectedScreenIdUnreadable);

      await tester.tap(find.bySemanticsIdentifier('kyc_rejected_appeal_cta'));
      await tester.pumpAndSettle();

      expect(find.text('support-ticket (JM-063)'), findsOneWidget);
    });

    testWidgets('the back CTA reaches customer-profile', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycRejectedScreenIdUnreadable);

      await tester.tap(find.bySemanticsIdentifier('kyc_rejected_back_cta'));
      await tester.pumpAndSettle();

      expect(find.text('customer-profile (JM-043 exit)'), findsOneWidget);
    });

    // JEBV4-13 P1-6, reproduced in the canvas: the host's `initialLocation` is
    // this route with nothing beneath it — the stack `goNamed('kyc-rejected')`
    // leaves — so `context.canPop()` is false and the arrow must take the
    // explicit fallback rather than no-op. Guarded independently by
    // `test/back_arrow_dead_at_root_test.dart`; asserted here so a preview host
    // that quietly gained a page beneath the screen stops reproducing the bug it
    // exists to show.
    testWidgets('the AppBar arrow at stack root lands on customer-profile', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycRejectedScreenIdUnreadable);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('customer-profile (JM-043 exit)'), findsOneWidget);
    });
  });
}
