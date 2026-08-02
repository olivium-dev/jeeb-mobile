// Render tests for the OnboardingFundingScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// ## What `expectedText` can and cannot prove here
//
// JM-041 is a mostly-static explainer whose only data is two optional amounts,
// each gated on `balance != null && balance.X > 0`. Four of the nine previews
// therefore render byte-identical English copy and differ only in which amounts
// are present — and two of them (`Fail-safe` and `Loading`) do not differ at
// all. Pinning a distinct real string per state keeps every preview honest about
// rendering its own COPY, but it cannot separate those two; the assertions that
// actually discriminate live in the groups below, and the `Loading` group pins
// the fact that it CANNOT be discriminated as the finding it is.
//
// ## Fonts
//
// `preview_test_harness.dart` loads no fonts, so text lays out in Flutter's
// 1-em-per-glyph test face — Latin ~2x too wide, Arabic ~2.4x — and every
// overflow or fold measured under it is inflated. Every geometry assertion below
// runs through [_goldenCanvas], which is `previewCanvas` plus
// `withGoldenTestFonts(...)`: real Inter for Latin and the deterministic Noto
// Arabic subset registered as a fallback family, which the stock `AppTheme` does
// not carry. Without that fallback the Arabic assertions here would be measuring
// the fake face too.
//
// The shared render suite still runs on `previewCanvas`, because it asserts only
// that each preview builds and renders its own strings — neither claim depends
// on glyph metrics.

import 'dart:io';

import 'package:flutter/material.dart';
// `RenderParagraph.getBoxesForSelection` — the laid-out line boxes, which is
// what exposes an amount broken across lines. `getSize` reports the clamped
// render box and hides it.
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/onboarding_funding_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

// The screen's real copy, declared here rather than imported so a preview
// quietly rewired to a different fixture fails instead of silently agreeing
// with itself.
const String _kTitle = 'Your starter credit';
const String _kStarterBody = 'Once your verification is approved you get a '
    'fixed, non-refundable starter credit to begin sending offers.';
const String _kReserveBody = "Each offer you send reserves 10% of its value "
    "from your wallet. It is charged only if you win, and released if you "
    "don't.";
const String _kTopupCta = 'How to add funds';
const String _kContinueCta = 'Continue';

/// The AR starter-credit body — the one string the shared suite can genuinely
/// use to discriminate the Arabic preview, which forces `Locale('ar')` from
/// inside the preview function and so renders Arabic even under an English pump.
const String _kArStarterBody = 'بمجرد الموافقة على توثيقك تحصل على رصيد ابتدائي '
    'ثابت وغير قابل للاسترداد لتبدأ بإرسال العروض.';
const String _kArTopupCta = 'كيفية إضافة الرصيد';
const String _kArContinueCta = 'متابعة';

/// The ceiling amount: `giftCredit` of [onboardingFundingScreenCeilingBalance]
/// through `_formatMoney`. 375.8 pt wide unwrapped at 200% text.
const String _kCeilingGift = '1234567.89 LBP';

late Map<String, String> _arbByTag;

/// The harness's sync ARB delegate, rebuilt here because the harness keeps its
/// own instance private and [_goldenCanvas] has to assemble its own
/// `MaterialApp` to inject the golden-font theme.
class _GoldenArbDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _GoldenArbDelegate();

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_GoldenArbDelegate old) => false;
}

/// [previewCanvas] with real font metrics in BOTH scripts.
Widget _goldenCanvas(Widget Function() preview, Locale locale) => MaterialApp(
      theme: withGoldenTestFonts(AppTheme.light()),
      darkTheme: withGoldenTestFonts(AppTheme.dark()),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        _GoldenArbDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: jeebPreviewHost(preview()),
    );

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
    _arbByTag = <String, String>{
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    };
  });

  testPreviewsRender(
    'OnboardingFundingScreen',
    const <String, Widget Function()>{
      'Enriched · starter credit + live reserve': onboardingFundingScreenEnriched,
      'Nothing reserved yet': onboardingFundingScreenNothingReserved,
      'Gift spent · everything reserved': onboardingFundingScreenGiftSpent,
      'Fail-safe · wallet read failed': onboardingFundingScreenLoadFailed,
      'Loading · read still in flight': onboardingFundingScreenLoading,
      'Pushed on the KYC wizard · back pops':
          onboardingFundingScreenPushedOnWizard,
      'Compact 320x568': onboardingFundingScreenCompact,
      'Ceiling · 200% text on a 320 phone': onboardingFundingScreenCeiling,
      'AR · 200% text': onboardingFundingScreenArabicLargeText,
    },
    expectedText: const <String, String>{
      // The D42 gift amount — only the enriched snapshot carries this one.
      'Enriched · starter credit + live reserve': '50.00 USD',
      // A jeeber with the credit and no live offers.
      'Nothing reserved yet': '25.00 USD',
      // …and its mirror image, the credit spent and everything reserved.
      'Gift spent · everything reserved': '7.50 USD',
      // No amount survives a failed read, so these two pin explainer copy. The
      // strings are distinct from each other but NOT exclusive to their state —
      // see the `Loading` group, which is exactly the point.
      'Fail-safe · wallet read failed': _kReserveBody,
      'Loading · read still in flight': _kStarterBody,
      // The CTA the previous card's tap test drives.
      'Pushed on the KYC wizard · back pops': _kTopupCta,
      // The reserve amount of the same snapshot as the first card.
      'Compact 320x568': '20.00 USD',
      // Only the ceiling fixture renders an LBP amount.
      'Ceiling · 200% text on a 320 phone': _kCeilingGift,
      // The AR preview forces its own locale, so it renders Arabic even here.
      'AR · 200% text': _kArStarterBody,
    },
  );

  group('OnboardingFundingScreen preview specifics', () {
    /// Pumps [preview] with the surface set to the canvas box the preview's
    /// `@JeebPreview` declares, so the render test sees what the canvas draws.
    /// `@JeebPreview(size:)` is honoured by the preview canvas only — calling the
    /// function alone gets the tester's default 800x600 desktop surface, which
    /// is not a phone and would hide every fold question below.
    Future<void> pumpOnDevice(
      WidgetTester tester,
      Widget Function() preview,
      Size box, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(box);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_goldenCanvas(preview, locale));
      await tester.pumpAndSettle();
    }

    /// Every string the screen currently paints, in paint order.
    List<String> visibleText(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .toList();

    /// The line boxes the DIGITS of [_kCeilingGift] occupy. More than one means
    /// the number itself was broken across lines.
    List<TextBox> digitBoxes(WidgetTester tester) =>
        tester.renderObject<RenderParagraph>(find.text(_kCeilingGift))
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 10),
            );

    // ── Copy ──────────────────────────────────────────────────────────────

    testWidgets('both section cards AND the app bar carry the same title', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenEnriched,
        onboardingFundingScreenPhoneBox,
      );

      // The app bar, the starter-credit card and the reserve-10% card all pass
      // `l10n.fundingTitle`, so "Your starter credit" is painted three times on
      // a two-section screen and the D1 reserve card is labelled with the other
      // card's heading. There is no second title key in the .arb to pass
      // instead, so this is a copy gap rather than a typo — pinned at 3 so it
      // cannot change silently in either direction.
      expect(find.text(_kTitle), findsNWidgets(3));
      expect(find.text(_kStarterBody), findsOneWidget);
      expect(find.text(_kReserveBody), findsOneWidget);
    });

    // ── The four enrichment shapes ────────────────────────────────────────
    //
    // The two amounts are gated independently (`giftCredit > 0`,
    // `reservedNow > 0`), so the screen has four data shapes, not two, and three
    // of them are missing at least one number.

    testWidgets('enriched is the only state that renders BOTH amounts', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenEnriched,
        onboardingFundingScreenPhoneBox,
      );

      expect(find.text('50.00 USD'), findsOneWidget);
      expect(find.text('20.00 USD'), findsOneWidget);
      expect(find.textContaining('USD'), findsNWidgets(2));
    });

    testWidgets('a legitimate zero reserve looks exactly like no data', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenNothingReserved,
        onboardingFundingScreenPhoneBox,
      );

      // The FIRST state every post-KYC jeeber is in: credit on file, no offer
      // sent, so `reservedNow` is 0 and the `> 0` gate drops the amount. The
      // reserve card is now byte-identical to the one a failed read produces.
      expect(find.text('25.00 USD'), findsOneWidget);
      expect(find.textContaining('USD'), findsOneWidget);
      expect(find.text(_kReserveBody), findsOneWidget);
    });

    testWidgets('a spent gift drops the amount from the STARTER card', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenGiftSpent,
        onboardingFundingScreenPhoneBox,
      );

      // The mirror image, on the card the whole screen is named after.
      expect(find.text('7.50 USD'), findsOneWidget);
      expect(find.textContaining('USD'), findsOneWidget);
      expect(find.text(_kStarterBody), findsOneWidget);
    });

    testWidgets('the fail-safe keeps the whole explainer and both CTAs', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenLoadFailed,
        onboardingFundingScreenPhoneBox,
      );

      // 40_GUARDRAILS_ARCH §3: `funding_explainer` is the AC and must survive a
      // failed wallet read. It does — and it does so silently: no error strip,
      // no retry, no "amounts unavailable" hint anywhere.
      expect(find.text(_kStarterBody), findsOneWidget);
      expect(find.text(_kReserveBody), findsOneWidget);
      expect(find.text(_kTopupCta), findsOneWidget);
      expect(find.text(_kContinueCta), findsOneWidget);
      expect(find.textContaining('USD'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // ── Loading ───────────────────────────────────────────────────────────

    testWidgets('a read still in flight is INDISTINGUISHABLE from a failed one',
        (WidgetTester tester) async {
      // `initState` fires the fetch and the first frame is painted long before
      // it can return, so this is what 100% of users see first. Nothing marks
      // it: no spinner, no skeleton, no placeholder row.
      await pumpOnDevice(
        tester,
        onboardingFundingScreenLoading,
        onboardingFundingScreenPhoneBox,
      );
      final List<String> loading = visibleText(tester);

      // Unmount completely between the two pumps. Both previews build the same
      // widget types, so pumping the second over the first would UPDATE the
      // `OnboardingFundingScreen` element rather than replace it — `initState`
      // would never re-run and the second repository would never be read.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await pumpOnDevice(
        tester,
        onboardingFundingScreenLoadFailed,
        onboardingFundingScreenPhoneBox,
      );

      expect(
        visibleText(tester),
        equals(loading),
        reason: 'if these ever diverge the screen grew a loading affordance — '
            'good news, but this test and the preview prose must be updated',
      );
      expect(loading, contains(_kStarterBody));
    });

    // ── Navigation ────────────────────────────────────────────────────────
    //
    // Every affordance on this screen leaves it, and without the local router in
    // the shared fixture the canvas would throw on the first tap.

    testWidgets('standalone · nothing to pop, so back goes to the shell', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenEnriched,
        onboardingFundingScreenPhoneBox,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // The production shape: the KYC wizard chains here with `goNamed`, which
      // REPLACES the stack, so `canPop()` is false and `context.go('/')` runs.
      expect(find.text(onboardingFundingScreenShellLabel), findsOneWidget);
    });

    testWidgets('pushed on the wizard · back POPS to the caller', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenPushedOnWizard,
        onboardingFundingScreenPhoneBox,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // The other half of `onBackPressed`. Unreachable in the app today — no
      // caller pushes — which is why nothing but this preview would notice if
      // it broke.
      expect(find.text(onboardingFundingScreenKycStatusLabel), findsOneWidget);
      expect(find.text(onboardingFundingScreenShellLabel), findsNothing);
    });

    testWidgets('funding_topup_cta reaches wallet-charge-info by NAME', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenEnriched,
        onboardingFundingScreenPhoneBox,
      );

      await tester.tap(find.text(_kTopupCta));
      await tester.pumpAndSettle();

      // D92/D93: top-up is an instruction screen, never an in-app payment.
      expect(find.text(onboardingFundingScreenChargeInfoLabel), findsOneWidget);
    });

    testWidgets('funding_continue_cta reaches kyc-status by NAME', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenEnriched,
        onboardingFundingScreenPhoneBox,
      );

      await tester.tap(find.text(_kContinueCta));
      await tester.pumpAndSettle();

      // D38/D39: top-up is allowed pre-approval, so Continue lands on the
      // pending-status view rather than gating on it.
      expect(find.text(onboardingFundingScreenKycStatusLabel), findsOneWidget);
    });

    // ── Geometry ──────────────────────────────────────────────────────────

    testWidgets('the phone previews pin a 390x844 frame, not the canvas', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800x600 desktop surface: a preview whose fold
      // question was left to the host would measure 800 here, and none of the
      // layout below applies there.
      await pumpOnDevice(
        tester,
        onboardingFundingScreenEnriched,
        onboardingFundingScreenPhoneBox,
      );

      expect(
        tester.getSize(find.byType(OnboardingFundingScreen)),
        onboardingFundingScreenPhoneBox,
      );
    });

    testWidgets('the whole explainer fits the smallest supported phone', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenCompact,
        onboardingFundingScreenCompactBox,
      );

      // Measured: 4 pt of scroll on a 568 pt viewport, with the Continue label
      // ending 34 pt above the bottom edge. That is the good news and it is one
      // paragraph of copy from being bad news, so it is pinned: this assertion
      // is what fails the next time either card grows.
      expect(
        tester.getBottomLeft(find.text(_kContinueCta)).dy,
        lessThan(onboardingFundingScreenCompactBox.height),
        reason: 'the only affordance that advances onboarding left the viewport',
      );
      expect(find.text(_kTopupCta), findsOneWidget);
    });

    testWidgets('at the EN ceiling neither CTA is even BUILT', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenCeiling,
        onboardingFundingScreenPhoneBox,
      );

      // Past the ListView's cache extent, i.e. far off screen — the user has to
      // scroll a page whose layout gives no hint that it scrolls to reach the
      // only step forward. Note this is the LONG-amount fixture, whose two
      // amounts take two lines each at 200%; the AR case below is the enriched
      // one, so the two are not a like-for-like locale comparison.
      expect(find.text(_kCeilingGift), findsOneWidget);
      expect(find.text(_kTopupCta), findsNothing);
      expect(find.text(_kContinueCta), findsNothing);
    });

    testWidgets('at the AR ceiling Continue is cut by the bottom edge', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenArabicLargeText,
        onboardingFundingScreenPhoneBox,
      );

      expect(find.text(_kArStarterBody), findsOneWidget);
      // Measured through the REAL Noto Arabic face: the top-up CTA survives at
      // y 778.5–819.5, and `Continue` lays out at 839–879 against an 844 pt
      // viewport — 5 pt of its label above the fold and the rest below it, with
      // 63 pt of scroll behind the page. Under the 1-em test face both CTAs
      // measure off screen entirely, which is a phantom: that face is ~2.4x too
      // wide per Arabic glyph and no device renders it.
      expect(find.text(_kArTopupCta), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text(_kArContinueCta)).dy,
        greaterThan(onboardingFundingScreenPhoneBox.height),
        reason: 'the Continue label is clipped by the viewport at 200% text',
      );
      expect(
        tester.getTopLeft(find.text(_kArContinueCta)).dy,
        lessThan(onboardingFundingScreenPhoneBox.height),
        reason: 'a sliver of it is visible, which is worse than none at all — '
            'it is the only affordance that advances onboarding',
      );
    });

    testWidgets('a long amount breaks INSIDE the number on a 320 phone', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenCeiling,
        onboardingFundingScreenCompactBox,
      );

      // `1234567.89 LBP` is 375.8 pt wide unwrapped at 200% text against a
      // 240 pt card, and its only break opportunity is the single space. The
      // paragraph gives up and breaks inside the digit run, so the starter
      // credit renders as two numbers stacked on each other. `Text` wraps
      // instead of throwing, which is why nothing else in CI notices.
      expect(
        digitBoxes(tester).length,
        greaterThan(1),
        reason: 'the digits of the amount occupy more than one line box',
      );
    });

    testWidgets('the same amount only orphans its currency code on a 390 phone',
        (WidgetTester tester) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenCeiling,
        onboardingFundingScreenPhoneBox,
      );

      // 310 pt of card fits the 285.8 pt digit run, so the break lands on the
      // space and `LBP` ends up alone on line two. Better than the 320 pt case
      // and still not an amount — and the pair is what shows the defect is a
      // width threshold rather than a constant.
      final RenderParagraph paragraph =
          tester.renderObject<RenderParagraph>(find.text(_kCeilingGift));
      expect(digitBoxes(tester).length, 1);
      expect(
        paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 14),
            )
            .length,
        2,
        reason: 'the amount still wraps onto a second line',
      );
    });

    testWidgets('AR mirrors the layout and leaves the amounts latin', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingFundingScreenArabicLargeText,
        onboardingFundingScreenPhoneBox,
      );

      expect(
        Directionality.of(
          tester.element(find.byType(OnboardingFundingScreen)),
        ),
        TextDirection.rtl,
      );
      // The amounts are not translatable copy and must not be mirrored or
      // localized into eastern-arabic digits.
      expect(find.text('50.00 USD'), findsOneWidget);
      expect(find.text('20.00 USD'), findsOneWidget);
    });
  });
}
