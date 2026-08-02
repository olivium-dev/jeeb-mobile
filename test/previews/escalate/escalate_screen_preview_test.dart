// Render tests for the EscalateScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// EscalateScreen picks ONE of three bodies off `EscalateState.phase` — the
// form, a centred spinner, or a centred error — and the form itself has four
// readings of the same evidence panel. Most of these previews would satisfy a
// render-only check while showing the wrong surface entirely: a fixture that
// started throwing looks exactly like the degraded state, and the degraded
// state looks exactly like a delivery with no chat history. Every state
// therefore pins a string only IT can produce, and the groups below pin the
// contracts the pairs exist for: pending vs submitting (which share their
// copy), and retryable vs dead-end errors.
//
// ## Fonts
//
// `preview_test_harness.dart` deliberately does NOT load the real faces, so
// every glyph is a 1-em square there — Latin measures ~2x and Arabic ~2.4x what
// it does on a device. That is fine for "did this build and show its own
// state", which is all the shared suite claims. It is NOT fine for any claim
// about fitting, so the geometry group below pumps through
// [_escalateScreenCanvas], which is the same canvas with `withGoldenTestFonts`
// applied: real Inter for Latin, a deterministic Noto subset for Arabic. The
// 320 pt overflow assertions live there and nowhere else.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The screen's subtitle — rendered THREE times by one form. Declared here so
/// the count assertion below reads as a pinned contract rather than a typo.
const String _kSubtitle =
    "Describe what went wrong and we'll connect you with our support team "
    'within 24 hours.';

/// The evidence panel's not-loaded placeholder. It is `escalateSubmitting`,
/// which is also what the submitting PHASE renders — the two states share one
/// string while meaning opposite things, which is why they are asserted apart.
const String _kSubmitting = 'Submitting…';

/// [previewCanvas] with the real font faces installed on the theme.
///
/// The shared canvas builds `AppTheme.light()` unmodified and the theme carries
/// no `fontFamilyFallback`, so Arabic falls back to the 1-em test face there.
/// `withGoldenTestFonts` is what adds the deterministic Noto family, and only
/// through it is a measurement on this screen worth anything.
Widget _escalateScreenCanvas(Widget Function() preview, Locale locale) {
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

Future<void> _pumpWithRealFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_escalateScreenCanvas(preview, locale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview except `Submitting`, whose spinner cannot settle. It gets a
  // dedicated pump-once group below.
  testPreviewsRender(
    'EscalateScreen',
    const <String, Widget Function()>{
      'Reason picker · evidence loaded': escalateScreenReasonPicker,
      'Evidence pending · auto-attach in flight':
          escalateScreenEvidencePending,
      'Evidence degraded · empty panel': escalateScreenEvidenceDegraded,
      'Evidence complete · photo cap reached': escalateScreenEvidenceComplete,
      'Error · network': escalateScreenErrorNetwork,
      'Error · already open (no retry)': escalateScreenErrorAlreadyOpen,
      'Longest content · compact 320': escalateScreenCompactCeiling,
    },
    expectedText: const <String, String>{
      // The resolved auto-attach: only a snapshot WITH a message count renders
      // the parenthesised counter.
      'Reason picker · evidence loaded': 'Conversations (12)',
      // The not-loaded branch of the same panel — over a form nobody has
      // submitted. See the group below for why this is not the submitting body.
      'Evidence pending · auto-attach in flight': _kSubmitting,
      // No timeline rows at all, so the panel falls back to one generic line.
      // Reachable ONLY from a failed (or genuinely empty) evidence read.
      'Evidence degraded · empty panel': 'Live tracking',
      // The fifth chip — the cap, which no other state reaches at 390.
      'Evidence complete · photo cap reached': 'Photo 5',
      // The classified transport branch of `_errorMessage`.
      'Error · network':
          'No internet connection. Your report will be retried automatically.',
      // …and the 409 branch, the only one rendered without a retry.
      'Error · already open (no retry)':
          'A report for this delivery is already open.',
      // A completed delivery's snapshot — the ceiling fixture's own count.
      'Longest content · compact 320': 'Conversations (248)',
    },
  );

  // The submitting body is an `OmdsLoadingState`, i.e. a repeating
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes, driven by fixed pumps instead.
  group('EscalateScreen previews · Submitting', () {
    Future<void> pumpSubmitting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(escalateScreenSubmitting, locale));
      await tester.pump(); // the pre-driven submit() emit
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Submitting · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSubmitting(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Submitting renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSubmitting(tester);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.text(_kSubmitting), findsOneWidget);
      // The whole form is replaced while the POST is in flight: the reason the
      // customer picked, the evidence they assembled and BOTH bottom-bar
      // buttons are gone, so there is nothing to cancel with.
      expect(find.text('Damaged item'), findsNothing);
      expect(find.text('Submit Report'), findsNothing);
      expect(find.text('Back to chat'), findsNothing);
    });
  });

  group('EscalateScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — the canvas produces the same widget types, so
    // the `BlocProvider` element is UPDATED rather than replaced and keeps the
    // cubit the first preview created.

    testWidgets('the pending panel is the EVIDENCE read, not a submit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenEvidencePending);

      // "Submitting…" over a form that is still fully interactive, with a
      // Submit button the customer has not pressed. `escalateSubmitting` is
      // reused as the evidence-panel placeholder, so the screen claims to be
      // sending a report while it is reading a chat snapshot.
      expect(find.text(_kSubmitting), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
      expect(find.text('Damaged item'), findsOneWidget);
      // Nothing from the resolved panel: no counter, no timeline rows, and not
      // the empty-timeline fallback either — the panel is simply not loaded.
      expect(find.textContaining('Conversations'), findsNothing);
      expect(find.text('Live tracking'), findsNothing);
      expect(find.text('Ordered'), findsNothing);
    });

    testWidgets('a resolved panel lists the timeline; a degraded one lists '
        'nothing', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenReasonPicker);

      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('Picked'), findsOneWidget);
      expect(find.text('In transit'), findsOneWidget);
      // The fallback line belongs to the EMPTY panel only.
      expect(find.text('Live tracking'), findsNothing);
    });

    testWidgets('the degraded panel is indistinguishable from "no evidence '
        'exists"', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenEvidenceDegraded);

      // `loadEvidence` swallows the failure and emits `EscalateEvidence.empty`,
      // so the panel renders the same thing it would for a delivery that never
      // had a conversation: a bare chat row with no count and one generic
      // tracking line. Nothing on this screen says the read failed.
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.textContaining('Conversations ('), findsNothing);
      expect(find.text('Live tracking'), findsOneWidget);
      expect(find.text('Ordered'), findsNothing);
    });

    testWidgets('the subtitle string is rendered THREE times by one form', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenReasonPicker);

      // `escalateSubtitle` is the subtitle, the `dispute_auto_attach_note` body
      // AND the evidence panel's header. Two of the three are captions for
      // something else entirely, and there is no separate key for either.
      expect(find.text(_kSubtitle), findsNWidgets(3));
    });

    testWidgets('reaching the photo cap REMOVES the only add-photo control', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenEvidenceComplete);

      expect(find.byType(OmdsChip), findsNWidgets(5));
      expect(find.text('Photo 1'), findsOneWidget);
      expect(find.text('Photo 5'), findsOneWidget);
      // `_PhotoSection` renders its CTA under `if (photos.length < 5)`, so at
      // the cap the button is gone rather than disabled — no label, no
      // explanation, and the remaining count survives only as a Semantics
      // label a sighted user never sees.
      expect(find.textContaining('of 5 attached'), findsNothing);
      // The captured clip reads "Recording ready" even though tapping it
      // DISCARDS the recording (the discard copy is on the semantics node).
      expect(find.text('Recording ready'), findsOneWidget);
      // A reason is set, so this is also the only form state with Submit armed.
      expect(
        tester
            .widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isTrue,
      );
    });

    testWidgets('the untouched form offers the CTA and disables Submit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenReasonPicker);

      expect(find.text('0 of 5 attached'), findsOneWidget);
      expect(find.byType(OmdsChip), findsNothing);
      expect(
        tester
            .widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isFalse,
        reason: 'canSubmit is reason != null',
      );
    });

    // The retryable / dead-end error pair — one enum value apart.
    testWidgets('a network failure keeps a retry', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenErrorNetwork);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The form is replaced entirely, so the retry is the only way back to the
      // reason the customer already picked.
      expect(find.text('Submit Report'), findsNothing);
    });

    testWidgets('an already-open dispute is a dead end — no retry, no link to '
        'the dispute that exists', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenErrorAlreadyOpen);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      // `onRetry: null` for this kind alone, which leaves a full-screen error
      // with nothing on it to tap: no retry, no route to the open dispute, and
      // no way back to the form the customer had filled in.
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Contact support'), findsNothing);
    });
  });

  // Geometry and fitting. These pump through [_escalateScreenCanvas] — the only
  // canvas in this file with the real faces on the theme — because a
  // measurement taken under the 1-em test face is inflated ~2x in Latin and
  // ~2.4x in Arabic and reports overflows that exist on no device.
  group('EscalateScreen preview geometry · real fonts', () {
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await _pumpWithRealFonts(tester, escalateScreenReasonPicker);

      expect(tester.getSize(find.byType(EscalateScreen)).width, 390);
    });

    testWidgets('the ceiling preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await _pumpWithRealFonts(tester, escalateScreenCompactCeiling);

      expect(tester.getSize(find.byType(EscalateScreen)).width, 320);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the 320 pt ceiling lays out clean in '
          '${locale.languageCode}', (WidgetTester tester) async {
        // The bottom bar is the risk: a `Row` of an intrinsically-sized "Back
        // to chat" button beside an `Expanded` Submit, inside `Spacing.large`
        // padding, on the narrowest supported phone. Measured through the real
        // faces so a pass here means it fits on a device.
        await _pumpWithRealFonts(
          tester,
          escalateScreenCompactCeiling,
          locale: locale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
