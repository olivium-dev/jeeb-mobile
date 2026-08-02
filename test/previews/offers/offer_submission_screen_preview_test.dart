// Render tests for the OfferSubmissionScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The composer is a form with ONE body: every `OfferFormMode` that is not
// `submitting` renders the same widgets, and no static fixture can put a price
// in the field (it lives in a private `TextEditingController`), so five of the
// six previews below are byte-identical apart from the heading. A render-only
// check would therefore pass with every preview wired to the same fixture.
// Each state is consequently pinned by a string only IT can produce — for the
// three that differ solely by request id, that string is the `ORD-…` heading
// its `_displayRef` branch computes, which is itself the contract under test.
//
// ## Fonts
//
// `preview_test_harness.dart` deliberately does NOT load the real faces, so
// every glyph is a 1-em square there — Latin measures ~2x and Arabic ~2.4x what
// it does on a device. That is fine for "did this build and show its own
// state", which is all the shared suite claims. It is NOT fine for any claim
// about fitting, so the geometry group below pumps through
// [_offerSubmissionScreenCanvas], the same canvas with `withGoldenTestFonts`
// applied: real Inter for Latin, a deterministic Noto subset for Arabic. The
// 320 pt assertions live there and nowhere else.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// `offerSubmissionTitle`. Rendered TWICE by one screen — as the app-bar title
/// and, through `OfferComposerL10n.title`, as the economics card's section
/// header. Declared here so the count assertion reads as a pinned contract
/// rather than a typo.
const String _kScreenTitle = 'Send your offer';

/// The send CTA's label, which the `submitting` state replaces with a spinner.
const String _kSendCta = 'Send offer';

/// The sprint-009 §T5 identifier as the gateway sends it, and what the heading
/// must never echo.
const String _kRawIdentifier = '9c37b6af-4e21-4e4a-9c1b-1f2a3b4c5d6e';

/// [previewCanvas] with the real font faces installed on the theme.
///
/// The shared canvas builds `AppTheme.light()` unmodified and the theme carries
/// no `fontFamilyFallback`, so Arabic falls back to the 1-em test face there.
/// `withGoldenTestFonts` is what adds the deterministic Noto family, and only
/// through it is a measurement on this screen worth anything.
Widget _offerSubmissionScreenCanvas(Widget Function() preview, Locale locale) {
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
  await tester.pumpWidget(_offerSubmissionScreenCanvas(preview, locale));
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
    'OfferSubmissionScreen',
    const <String, Widget Function()>{
      'Idle · empty draft': offerSubmissionScreenIdle,
      'Validation errors': offerSubmissionScreenValidationErrors,
      'Order ref · opaque id (§T5)': offerSubmissionScreenOpaqueOrderRef,
      'Insufficient balance sheet · 402':
          offerSubmissionScreenInsufficientBalance,
      'Longest content · compact 320': offerSubmissionScreenCompactCeiling,
    },
    expectedText: const <String, String>{
      // The shortened tail of the reference request's UUID — the heading is the
      // only thing that distinguishes this card from the other composers.
      'Idle · empty draft': 'Your offer · ORD-A1B2C3',
      // Hardcoded in `OfferFormCubit._validatePrice`, and reachable from no
      // other state.
      'Validation errors': 'Price must be greater than 0',
      // The §T5 identifier, shortened. See the specifics group for the
      // assertion that the raw form is absent.
      'Order ref · opaque id (§T5)': 'Your offer · ORD-4C5D6E',
      // The 402's `needed`, and the only real amount rendered anywhere on this
      // screen.
      'Insufficient balance sheet · 402': 'Needed: 12.50 USD',
      // The SAME identifier through the branch `_displayRef` passes through
      // verbatim.
      'Longest content · compact 320':
          'Your offer · ORD-9C37B6AF-4E21-4E4A-9C1B-1F2A3B4C5D6E',
    },
  );

  // The send CTA's loading state is an `OmdsButtonLoading`, i.e. a repeating
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes, driven by fixed pumps instead.
  group('OfferSubmissionScreen previews · Submitting', () {
    Future<void> pumpSubmitting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(offerSubmissionScreenSubmitting, locale),
      );
      await tester.pump(); // the pre-driven submit() emit + the wallet read
      await tester.pump(const Duration(milliseconds: 300)); // switcher settles
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

      expect(find.text('Your offer · ORD-D4E5F6'), findsOneWidget);
      // The CTA label is swapped for the spinner and the button stops
      // accepting taps…
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_kSendCta), findsNothing);
      // …and that is the ONLY thing that changes. The price field, the ETA
      // picker and the note stay editable while the offer is on the wire, and
      // there is nothing on screen to cancel with.
      expect(find.bySemanticsIdentifier('offer_composer_price_field'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('offer_composer_eta_dropdown'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('offer_composer_note_field'),
          findsOneWidget);
    });
  });

  group('OfferSubmissionScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — the canvas produces the same widget types, so
    // the `BlocProvider` element is UPDATED rather than replaced and keeps the
    // cubit the first preview created.

    testWidgets('the screen title is rendered TWICE by one screen', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSubmissionScreenIdle);

      // `OfferComposerL10n.title` is both the `OMDSAppBar` title and the
      // `OMDSSectionCard` header over the economics block, so the same three
      // words label the whole screen and one card inside it. There is no
      // separate key for the card.
      expect(find.text(_kScreenTitle), findsNWidgets(2));
    });

    testWidgets('no fixture can reach the economics AMOUNTS', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSubmissionScreenIdle);

      // The price lives in `_OfferComposerState._priceController` with no ctor
      // seam, so `_price` is null on every dev surface and all three economics
      // lines render their pending phrasing. The wallet snapshot IS loaded
      // (`walletRepository` answers 25.00 USD) and its currency never appears,
      // because the currency is only rendered beside an amount.
      expect(find.text('Platform fee: 10% of your offer'), findsOneWidget);
      expect(
        find.text('You earn (cash): your full offer, paid by the customer'),
        findsOneWidget,
      );
      expect(find.textContaining('USD'), findsNothing);
    });

    testWidgets('the §T5 guard holds for a bare gateway UUID', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSubmissionScreenOpaqueOrderRef);

      expect(find.text('Your offer · ORD-4C5D6E'), findsOneWidget);
      expect(find.textContaining(_kRawIdentifier), findsNothing);
      expect(find.textContaining(_kRawIdentifier.toUpperCase()), findsNothing);
    });

    testWidgets('…and does NOT hold once the id already carries an ORD prefix',
        (WidgetTester tester) async {
      await pumpPreview(tester, offerSubmissionScreenCompactCeiling);

      // `_displayRef` returns anything starting with `ORD` verbatim, so the
      // shortening never runs and the full reference is back in the heading —
      // the same raw string sprint-009 §T5 graded an F, one prefix away.
      expect(
        find.textContaining(_kRawIdentifier.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('inline validation errors are hardcoded English in Arabic too',
        (WidgetTester tester) async {
      await pumpPreview(
        tester,
        offerSubmissionScreenValidationErrors,
        locale: const Locale('ar'),
      );

      // The surrounding form IS localized…
      expect(find.text('أرسل عرضك'), findsWidgets);
      // …while both validation strings come from `OfferFormCubit`, which has
      // no localization seam at all. JEBV4-246 fixed exactly this class of
      // defect for the error snack and did not reach the field errors.
      expect(find.text('Price must be greater than 0'), findsOneWidget);
      expect(find.text('ETA must be greater than 0'), findsOneWidget);
    });

    testWidgets('the 402 sheet shows both figures and both exits', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSubmissionScreenInsufficientBalance);

      expect(find.text('Not enough balance'), findsOneWidget);
      expect(find.text('Needed: 12.50 USD'), findsOneWidget);
      expect(find.text('Available: 3.75 USD'), findsOneWidget);
      // Top up (→ wallet-charge-info, D92/D93) and keep editing (dismiss,
      // draft preserved).
      expect(find.text('Top up'), findsOneWidget);
      expect(find.text('Keep editing'), findsOneWidget);
    });
  });

  // Geometry and fitting. These pump through [_offerSubmissionScreenCanvas] —
  // the only canvas in this file with the real faces on the theme — because a
  // measurement taken under the 1-em test face is inflated ~2x in Latin and
  // ~2.4x in Arabic and reports overflows that exist on no device.
  group('OfferSubmissionScreen preview geometry · real fonts', () {
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await _pumpWithRealFonts(tester, offerSubmissionScreenIdle);

      expect(tester.getSize(find.byType(OfferSubmissionScreen)).width, 390);
    });

    testWidgets('the ceiling preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await _pumpWithRealFonts(tester, offerSubmissionScreenCompactCeiling);

      expect(tester.getSize(find.byType(OfferSubmissionScreen)).width, 320);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the 320 pt ceiling lays out clean in '
          '${locale.languageCode}', (WidgetTester tester) async {
        // The risk is the heading: a 40-character reference with no `maxLines`
        // and no `overflow`, over a price field, a bounded ETA picker and a
        // three-sentence economics card. Measured through the real faces so a
        // pass here means it fits on a device.
        await _pumpWithRealFonts(
          tester,
          offerSubmissionScreenCompactCeiling,
          locale: locale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
