import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/domain/wallet_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/onboarding_funding_screen_fixtures.dart';

/// onboarding-funding (JM-041). Starter-credit explainer shown after KYC is
/// submitted: a fixed, non-refundable starter credit usable post-KYC (D42) +
/// the reserve-10%-per-offer rule (D1). NO in-app payment (D92/D93) — top-up is
/// done at a store via wallet-charge-info. Top-up is allowed pre-approval
/// (D38/D39), so Continue lands on kyc-pending-status.
///
/// DATA (CTO-D2 wallet model): the explainer is enriched with the LIVE wallet
/// snapshot from the real backend endpoint (W1m `GET /v1/jeeb/wallet`, surfaced
/// through [WalletRepository] — `giftCredit` is the D42 starter credit,
/// `reservedNow` the sum of live 10% reserves, D1). It depends only on the
/// wallet `domain/` contract (no cross-feature `application/` import) and reads
/// `sl<WalletRepository>()` — until W1m is live the DI default is the
/// INTEGRATOR-STUB, so the explainer still renders real numbers from a
/// deterministic snapshot. The static explainer copy is the AC and is ALWAYS
/// visible — it is NEVER gated on the network call, so `funding_explainer` +
/// both CTAs survive a slow/failed wallet fetch (fail-safe,
/// 40_GUARDRAILS_ARCH §3). The live amounts only *enrich* the copy when loaded.
///
/// Edges OWNED here (21_NAV_PLAN §C JM-041):
///   onboarding-funding → wallet-charge-info  (`funding_topup_cta`)
///   onboarding-funding → kyc-pending-status  (`funding_continue_cta`)
class OnboardingFundingScreen extends StatefulWidget {
  const OnboardingFundingScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletRepository? repository;

  @override
  State<OnboardingFundingScreen> createState() =>
      _OnboardingFundingScreenState();
}

class _OnboardingFundingScreenState extends State<OnboardingFundingScreen> {
  /// The live wallet snapshot, or `null` while loading / on failure. The
  /// explainer never blocks on it (fail-safe): a `null` snapshot simply hides
  /// the enrichment amounts and shows the static copy alone.
  WalletBalance? _balance;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final repo = widget.repository ?? sl<WalletRepository>();
    try {
      final balance = await repo.fetchBalance();
      if (mounted) setState(() => _balance = balance);
    } on WalletRepositoryException {
      // Fail-safe: the explainer is static copy; a failed wallet fetch must not
      // hide it. Leave `_balance` null so only the enrichment is omitted.
    } catch (_) {
      // Same — any unexpected error must not break the explainer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = _balance;
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.fundingTitle,
        showBackButton: true,
        // Normally pushed after KYC submission, but also reachable via deep
        // link with an empty Navigator stack. Pop when we can (pushed
        // entry), else return to the shell — never pop the last page
        // (which would leave an empty Navigator → black surface).
        onBackPressed: () =>
            context.canPop() ? context.pop() : context.go('/'),
      ),
      // `funding_explainer` is the screen ROOT (65_W2_TEST_PLAN §2 JM-041) and is
      // ALWAYS present regardless of the wallet load state — the explainer is the
      // AC, not the live numbers.
      body: Semantics(
        identifier: 'funding_explainer',
        container: true,
        explicitChildNodes: true,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            // ── Starter credit (D42) ──────────────────────────────────────
            OMDSSectionCard(
              title: l10n.fundingTitle,
              showDivider: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fundingStarterCreditBody,
                    style: theme.textTheme.bodyLarge,
                  ),
                  // Live enrichment: the actual D42 gift-credit amount, shown
                  // only once the wallet snapshot loads and it is non-zero.
                  if (balance != null && balance.giftCredit > 0)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(top: Spacing.small),
                      child: Semantics(
                        identifier: 'funding_starter_credit_amount',
                        child: Text(
                          _formatMoney(balance.giftCredit, balance.currency),
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.medium),
            // ── Reserve-10%-per-offer (D1) ────────────────────────────────
            OMDSSectionCard(
              title: l10n.fundingTitle,
              showDivider: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fundingReserveBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  // Live enrichment: the amount currently reserved across live
                  // offers (D1), shown only when non-zero.
                  if (balance != null && balance.reservedNow > 0)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(top: Spacing.small),
                      child: Semantics(
                        identifier: 'funding_reserved_now_amount',
                        child: Text(
                          _formatMoney(balance.reservedNow, balance.currency),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xLarge),
            // ── Top up → wallet-charge-info (D92/D93, NO in-app pay) ───────
            Semantics(
              identifier: 'funding_topup_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingTopupCta,
                variant: OmdsButtonVariant.secondary,
                // EDGE → wallet-charge-info (D92/D93, JM-054).
                onTap: () => context.goNamed('wallet-charge-info'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            // ── Continue → kyc-pending-status (top-up allowed pre-approval) ─
            Semantics(
              identifier: 'funding_continue_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingContinueCta,
                // EDGE → kyc-pending-status (top-up allowed pre-approval,
                // D38/D39). The KYC wizard hosts the status view at
                // `/profile/kyc?step=status` (registered name `kyc-status`).
                // The `step=status` param is forward-compatible: JM-042 wires the
                // wizard to open the status view on it; the route resolves
                // honestly today either way.
                onTap: () => context.goNamed(
                  'kyc-status',
                  queryParameters: const {'step': 'status'},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amount + currency. Amounts/currency codes are not translatable copy, so this
/// composes a neutral display without a new l10n key (the .arb is integrator-
/// owned and untouched here).
String _formatMoney(double amount, String currency) {
  final value = amount.toStringAsFixed(2);
  return currency.isEmpty ? value : '$value $currency';
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/jeeber_onboarding_funding/onboarding_funding_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so it previews differently from a widget twice over.
//
// 1. It owns its own `Scaffold` (app bar + list) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([onboardingFundingScreenPhoneBox], 390x844, and the smallest phone the
//    app supports, [onboardingFundingScreenCompactBox], 320x568) rather than
//    the harness's default 390x200 — two explainer cards and two stacked CTAs
//    cannot be judged in a 200 pt strip.
//
// 2. It has TWO independent axes, and only one of them is data. The wallet read
//    (`WalletRepository.fetchBalance`, injected through the constructor seam)
//    decides whether the two enrichment amounts render; the navigation stack
//    decides where the app-bar arrow goes. Both fixtures are shared with the
//    Screen Catalog entry
//    (`lib/devtool/catalog/fixtures/onboarding_funding_screen_fixtures.dart`)
//    so the designer-facing tool and the canvas cannot drift.
//
// The router in that fixture is not decoration. Every affordance here leaves
// the screen — `funding_topup_cta` → `goNamed('wallet-charge-info')`,
// `funding_continue_cta` → `goNamed('kyc-status')`, arrow → `pop()` or
// `go('/')` — and the preview canvas provides no `Router`, so without it these
// previews would not merely be unrealistic, they would throw the moment
// anything was tapped.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * **both section cards are titled `l10n.fundingTitle`**, and so is the app
//    bar. "Your starter credit" is therefore painted THREE times on a screen
//    with two sections, and the D1 reserve-10%-per-offer card — whose body is
//    about reserving money, not about the gift — is labelled with the other
//    card's heading. There is no `fundingReserveTitle` key in the .arb to use
//    instead, so this is a copy gap, not a typo; `Enriched` is the card to read
//    it on and the render test pins the count at 3 so it cannot change silently;
//  * **a successful read and a failed read can look identical.** Both
//    enrichment amounts are gated on `balance != null && balance.X > 0`, so a
//    jeeber who has not sent an offer yet (`reservedNow == 0`, the FIRST state
//    every post-KYC jeeber is in) sees exactly the reserve card a network
//    failure produces. `Nothing reserved yet` and `Fail-safe` are the same
//    pixels for that card. The fail-safe itself is deliberate and correct
//    (40_GUARDRAILS_ARCH §3 — the explainer is the AC); what the previews show
//    is that it is also SILENT: there is no retry, no stale hint, nothing that
//    says a number is missing rather than zero;
//  * **there is no loading affordance at all.** `initState` fires the fetch and
//    the first frame is painted long before it can return, so `Loading` is what
//    100% of users see first and it is pixel-identical to `Fail-safe`. Nothing
//    ever appears or disappears to mark the transition except the amounts
//    themselves, which pop in unannounced under the reader's eye;
//  * **a large amount is broken MID-NUMBER at the accessibility ceiling.**
//    `_formatMoney` never groups digits and always prints two decimals, so a
//    weak-unit currency yields `1234567.89 LBP` in `headlineSmall` — 375.8 pt
//    wide unwrapped at 200% text, against a card 310 pt wide on a 390 pt phone
//    and 240 pt wide on a 320 pt one. The only break opportunity in that string
//    is the single space, so on the 390 the currency code is orphaned onto its
//    own line, and on the 320 (`Ceiling · 200% text on a 320 phone`) the
//    paragraph breaks inside the digits themselves: the number reads as two
//    numbers. `Text` wraps rather than throwing, so nothing in CI notices;
//  * **at 200% text the CTAs leave the screen.** On a 390x844 phone at 200%
//    with a long amount, neither `funding_topup_cta` nor
//    `funding_continue_cta` is even BUILT in English — both are past the
//    `ListView`'s cache extent. Arabic at 200% (with the ordinary amounts) is
//    milder and still wrong: `Continue` lays out at y 839–879 against an 844 pt
//    viewport, i.e. clipped to a 5 pt sliver. The only affordance that advances
//    onboarding is reachable solely by scrolling a page whose layout gives no
//    hint that it scrolls. At NORMAL text size the same content overruns the
//    smallest supported phone by just 4 pt (`Compact 320x568`) and both CTAs
//    stay on screen, which is why that card is a regression guard rather than a
//    bug report;
//  * one methodological note, because it changed an answer here: the Arabic
//    reading above is measured through the REAL Noto face. Under the 1-em test
//    face `preview_test_harness.dart` defaults to, Arabic glyphs are ~2.4x too
//    wide and BOTH Arabic CTAs measure off screen — a defect that exists on no
//    device. The render test wraps its theme with `withGoldenTestFonts` for
//    exactly this reason;
//  * **the `pop()` half of the arrow is dead code today.** The KYC wizard
//    chains here with `context.goNamed('onboarding-funding')`, which REPLACES
//    the stack, and the dev-seam landing starts here cold — so `canPop()` is
//    always false and the arrow always takes `go('/')`. The screen's own
//    comment ("Normally pushed after KYC submission, but also reachable via
//    deep link with an empty Navigator stack") has it the wrong way round.
//    `Pushed on the KYC wizard` keeps the other branch reviewable because it is
//    one `pushNamed` away from being live.

/// The canvas box for a whole screen: a real phone, not the harness default.
///
/// Public so the render test can reproduce the canvas box with
/// `setSurfaceSize` — a preview whose state is a DEVICE SIZE is not reproduced
/// by calling its function alone.
const Size onboardingFundingScreenPhoneBox = Size(390, 844);

/// The smallest phone the app supports (iPhone SE 1st gen / small Androids).
///
/// Worth its own card twice over: at normal text size it is the frame the
/// explainer only just fits (4 pt of scroll), and at 200% it is the frame on
/// which a long amount stops wrapping cleanly and starts breaking inside the
/// number.
const Size onboardingFundingScreenCompactBox = Size(320, 568);

/// Hosts the real screen on the stack named by [entry], reading [repository],
/// optionally at [textScale] and in [arabic].
///
/// The locale/text-scale overrides are applied HERE rather than left to the
/// `matrix:` flag on purpose: the matrix renders AR at 100% and 200% in EN, so
/// the combination that actually breaks Arabic copy — RTL *and* 200% together —
/// is the one reading the canvas cannot give you.
Widget _onboardingFundingScreenHosted({
  WalletRepository repository = const OnboardingFundingScreenStaticWallet(
    onboardingFundingScreenEnrichedBalance,
  ),
  OnboardingFundingScreenEntry entry = OnboardingFundingScreenEntry.standalone,
  double textScale = 1,
  bool arabic = false,
}) {
  final Widget hosted = OnboardingFundingScreenHost(
    entry: entry,
    screen: OnboardingFundingScreen(repository: repository),
  );
  final Widget scaled = textScale == 1
      ? hosted
      : Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: hosted,
          ),
        );
  if (!arabic) return scaled;
  return Builder(
    builder: (BuildContext context) => Localizations.override(
      context: context,
      locale: const Locale('ar'),
      child: Directionality(textDirection: TextDirection.rtl, child: scaled),
    ),
  );
}

/// The one state in which the screen shows everything it can show: the D42
/// starter credit AND a live D1 reserve, both enrichment amounts rendered.
///
/// Read the headings. The app bar says "Your starter credit"; so does the first
/// card; so does the SECOND card, whose body is the reserve-10%-per-offer rule
/// and has nothing to do with the gift. Both cards pass `l10n.fundingTitle`,
/// and the .arb has no second title key to pass instead.
///
/// Matrixed because this is the state with the most moving parts: two
/// `EdgeInsetsDirectional` paddings that must mirror, two latin amount strings
/// that must NOT mirror, and copy whose length swings by locale.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Enriched · starter credit + live reserve',
  size: onboardingFundingScreenPhoneBox,
  matrix: true,
)
Widget onboardingFundingScreenEnriched() => _onboardingFundingScreenHosted();

/// The state every real jeeber is in on arrival: the starter credit is on file,
/// but no offer has been sent yet, so `reservedNow` is 0.
///
/// The reserve card drops its amount — `balance.reservedNow > 0` is false — and
/// what is left is byte-identical to the card a failed read produces. A
/// successful read that returns a legitimate zero and a read that never
/// happened are the same pixels.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Nothing reserved yet',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenNothingReserved() =>
    _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenStaticWallet(
        onboardingFundingScreenUnreservedBalance,
      ),
    );

/// The mirror image: the starter credit has been spent (`giftCredit` 0) and
/// everything left is reserved against live offers.
///
/// Now it is the STARTER-CREDIT card that loses its amount while the reserve
/// card keeps one — on a screen whose whole purpose is to explain the starter
/// credit. Worth a card because the two gates are independent, so the screen has
/// four enrichment shapes, not two.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Gift spent · everything reserved',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenGiftSpent() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenStaticWallet(
        onboardingFundingScreenGiftSpentBalance,
      ),
    );

/// The fail-safe branch: `fetchBalance()` throws the typed
/// [WalletRepositoryException] and the screen swallows it, leaving `_balance`
/// null.
///
/// The explainer survives intact — that is the AC (40_GUARDRAILS_ARCH §3), and
/// it is the right call. What this card shows is the cost of it: there is no
/// error strip, no retry, no "amounts unavailable" hint. The screen makes the
/// same claim about the user's wallet whether the read succeeded, returned
/// zero, or never came back at all.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Fail-safe · wallet read failed',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenLoadFailed() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenFailingWallet(),
    );

/// The first frame, and the only one 100% of users are guaranteed to see:
/// `initState` fires the fetch, the frame is painted, and the amounts arrive
/// later or not at all.
///
/// It renders exactly the same strings as `Fail-safe · wallet read failed`
/// above, and nothing else on the screen reads `_balance`, so the two cards are
/// the same picture — no spinner, no skeleton, no placeholder row. Put them side
/// by side in the canvas: nothing distinguishes "still loading" from "gave up".
/// The render test pins that equality directly, comparing the full list of
/// painted strings between the two, because no single string could.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Loading · read still in flight',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenLoading() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenPendingWallet(),
    );

/// The other half of the arrow's contract: the screen sitting ON TOP of the KYC
/// wizard, where `context.canPop()` is true and back POPS.
///
/// Tap the arrow in the canvas and the kyc-status stand-in comes up instead of
/// the app shell. In the app today this is unreachable — the wizard chains here
/// with `goNamed`, which replaces the stack — so the `context.pop()` half of
/// `onBackPressed` never runs and the screen's own comment describes this as the
/// normal case exactly backwards. Kept because it is one `pushNamed` away from
/// being live and nothing else would notice if it broke.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Pushed on the KYC wizard · back pops',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenPushedOnWizard() =>
    _onboardingFundingScreenHosted(
      entry: OnboardingFundingScreenEntry.pushedOnKycWizard,
    );

/// The floor: the smallest supported phone at NORMAL text size.
///
/// Measured, this one is GOOD news, and it is a card because it is one
/// paragraph of copy away from not being: the whole explainer — both cards,
/// both amounts and both CTAs — overruns 320x568 by only 4 pt, and the
/// `funding_continue_cta` label ends 34 pt above the bottom edge. The render
/// test pins that label inside the viewport, so the next time a line of copy is
/// added to either card this is the card that fails.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Compact 320x568',
  size: onboardingFundingScreenCompactBox,
)
Widget onboardingFundingScreenCompact() => _onboardingFundingScreenHosted();

/// The accessibility ceiling with the longest content the formatter can
/// produce, on the frame where it breaks: 200% text, a weak-unit currency, and
/// a 320 pt phone.
///
/// `1234567.89 LBP` measures 375.8 pt unwrapped at 200%, and the card here is
/// 240 pt wide. The string's ONLY break opportunity is the single space before
/// the currency code, so the paragraph gives up and breaks inside the digits:
/// the starter credit renders as two numbers stacked on top of each other. Pump
/// the same preview on a 390 pt phone (the render test does) and the break
/// lands on the space instead, orphaning a lone `LBP` on line two — better, but
/// still not an amount.
///
/// This is a realistic snapshot rather than a stress test: LBP is a live
/// currency for this app and `_formatMoney` neither groups digits nor drops the
/// two decimals a weak unit has no use for.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Ceiling · 200% text on a 320 phone',
  size: onboardingFundingScreenCompactBox,
)
Widget onboardingFundingScreenCeiling() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenStaticWallet(
        onboardingFundingScreenCeilingBalance,
      ),
      textScale: 2,
    );

/// The combination the standard matrix cannot render: Arabic AND 200% text.
///
/// RTL mirrors the `EdgeInsetsDirectional` list padding and both cards, while
/// the amounts stay latin and stay left-to-right inside the mirrored column —
/// which is correct, and is the thing to check here.
///
/// It is also the second half of the CTA finding, and the milder half: Arabic
/// keeps `funding_topup_cta` on screen at 200% where the English ceiling loses
/// both, but `Continue` still lands at y 839–879 on an 844 pt viewport —
/// clipped to a 5 pt sliver at the bottom edge, with 63 pt of scroll behind it.
/// Both numbers are measured through the real Noto Arabic face; under the test
/// face this preview reports a fold that no device has.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'AR · 200% text',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenArabicLargeText() =>
    _onboardingFundingScreenHosted(textScale: 2, arabic: true);
