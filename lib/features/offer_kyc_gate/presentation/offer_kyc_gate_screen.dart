import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import '../application/offer_kyc_gate_cubit.dart';
import '../application/offer_kyc_gate_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/offer_kyc_gate_screen_fixtures.dart';

/// offer-kyc-gate (JM-044, `/jeeber/offer-gate`). The D38 core-invariant
/// interstitial: an UNAPPROVED jeeber who taps "Make Offer" (`feed_make_offer_cta`)
/// is routed THROUGH this gate (never straight to the composer). "Get approved
/// to start sending offers" + the live KYC status + a "top-up still allowed"
/// note (D67) + the three exits. An APPROVED jeeber NEVER reaches this screen —
/// the JM-048 feed call site sends `feed_make_offer_cta` straight to the offer
/// composer (`offer_composer_root`) for approved jeebers (the gate is skipped),
/// so this screen owns only the unapproved branch.
///
/// Data: the optional status line reads the REAL decision from
/// `GET /v1/kyc/status` (mock-rewritten to `/user-management/v1/kyc`; the AC's
/// `GET /user-management/users/:userId/kyc`) via [KycGateway], using existing
/// `kycStatus*` copy. The gate's three exits + top-up note ALWAYS render and
/// never block on that fetch (R-F: the invariant is independent of the network).
///
/// Edges OWNED here (21_NAV_PLAN §C JM-044, 65_W2_TEST_PLAN §2 JM-044):
///   `gate_start_kyc_cta` → kyc-identity            (`kyc-status` → `kyc_wizard_root`)
///   `gate_register_link` → delivery-register-prompt (standalone route
///       `delivery-register-prompt` → `delivery_register_prompt`; W2 RD-1 fix —
///       see the call site for why a tab-pop was wrong)
///   `gate_back_cta`      → jeeber-requests-home     (DELIVERY tab feed → `jeeber_feed_root`)
///
/// Semantics ids exposed (EXACT per 65_W2_TEST_PLAN §2 JM-044):
///   `offer_kyc_gate` (root), `gate_topup_note`, `gate_start_kyc_cta`,
///   `gate_register_link`, `gate_back_cta`.
class OfferKycGateScreen extends StatelessWidget {
  const OfferKycGateScreen({super.key, this.cubit, this.gateway})
      : assert(cubit == null || gateway == null,
            'Provide either a cubit or a gateway, not both.');

  /// Injectable cubit for widget tests. When null the screen self-provides one
  /// from DI (or [gateway]).
  final OfferKycGateCubit? cubit;

  /// Injectable gateway for widget tests that want to drive the status branch
  /// without a full DI graph.
  final KycGateway? gateway;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<OfferKycGateCubit>.value(
        value: provided,
        child: const _OfferKycGateView(),
      );
    }
    return BlocProvider<OfferKycGateCubit>(
      create: (_) => OfferKycGateCubit(gateway: gateway ?? _resolveGateway()),
      child: const _OfferKycGateView(),
    );
  }

  KycGateway _resolveGateway() {
    if (sl.isRegistered<KycGateway>()) return sl<KycGateway>();
    // Harness fallback so mounting the screen without DI never throws a GetIt
    // "not registered" (matches KycWizardScreen's pattern).
    return FakeKycGateway();
  }
}

class _OfferKycGateView extends StatelessWidget {
  const _OfferKycGateView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'offer_kyc_gate',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.offerKycGateTitle,
          showBackButton: true,
          // JEBV4-13 P1-6: OMDSAppBar's default back action is `maybePop()`,
          // which intentionally no-ops when this screen is the stack root
          // (reached via `go`, not pushed) — otherwise it would pop the last
          // Navigator page. Without an explicit destination that leaves the
          // AppBar back arrow dead. Mirror the screen's own `gate_back_cta`
          // exit so both back affordances agree.
          onBackPressed: () => _popToDeliveryTab(context),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(Icons.verified_user_outlined,
                size: Sizes.sixXLarge, color: theme.colorScheme.primary),
            const SizedBox(height: Spacing.large),
            Text(l10n.offerKycGateHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.small),
            Text(l10n.offerKycGateBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            const _GateStatusLine(),
            const SizedBox(height: Spacing.large),
            // D67: top-up is allowed even while unapproved — surfaced so the
            // jeeber knows the wallet path is open before approval.
            Semantics(
              identifier: 'gate_topup_note',
              container: true,
              child: Text(l10n.gateTopupNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'gate_start_kyc_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.gateStartKycCta,
                // EDGE → kyc-identity (the KYC wizard, route `kyc-status`,
                // root `kyc_wizard_root`).
                onTap: () => context.goNamed('kyc-status'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'gate_register_link',
              button: true,
              container: true,
              child: TextButton(
                // EDGE → delivery-register-prompt (21_NAV §C JM-044, line 204).
                // W2 RESIDUAL FIX (66_W2_QA RD-1 / jm-044 AC3): the old wiring
                // popped back to the DELIVERY tab, but that tab re-resolves its
                // body from the LIVE `JeeberKycStatusGate` — and the gate is
                // reached by a `pending` jeeber (the reconciled JM-044 entry,
                // kyc_status=pending → feed), so popping back rendered
                // `jeeber_feed_root`, NOT `delivery_register_prompt`. The
                // register-prompt id is gate-state-dependent on the tab, so we
                // cannot rely on a pop. Navigate to the standalone register-
                // prompt route (21_NAV line 50 "optional ADD /jeeber/register-
                // prompt"), which renders `delivery_register_prompt`
                // unconditionally regardless of the live KYC status. `go` (not
                // `push`) matches the feed→gate entry edge (also a `go`).
                onPressed: () => context.goNamed('delivery-register-prompt'),
                child: Text(l10n.gateRegisterLink),
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Semantics(
              identifier: 'gate_back_cta',
              button: true,
              container: true,
              child: TextButton(
                // EDGE → jeeber-requests-home (the Dashboard feed tab, root
                // `jeeber_feed_root`). Tabs are not routes; pop back to the
                // shell-hosted DELIVERY tab the gate was pushed from.
                onPressed: () => _popToDeliveryTab(context),
                child: Text(l10n.gateBackCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns to the shell-hosted DELIVERY tab the gate was reached from — the
  /// `gate_back_cta` exit (→ jeeber-requests-home, `jeeber_feed_root`). The gate
  /// is entered from the feed via `go` (no pushed entry), so `canPop()` is false
  /// and we `go('/')`; for a `pending`/`approved` jeeber the tab renders the feed
  /// (`jeeber_feed_root`), satisfying AC4. NOTE: `gate_register_link` does NOT
  /// use this — popping back re-resolves the tab from the LIVE KYC gate and would
  /// land on `jeeber_feed_root` for a `pending` jeeber (the W2 RD-1 defect), so
  /// the register link navigates to the standalone `delivery-register-prompt`
  /// route instead.
  void _popToDeliveryTab(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// Optional, live KYC-status line. Renders ONLY for pending / rejected (using
/// the existing `kycStatus*` copy — no new l10n keys). For not-submitted/none
/// the headline + body already say "get approved to start sending offers", and
/// while loading / on a failed read we render nothing so the gate's exits are
/// never gated behind the network.
class _GateStatusLine extends StatelessWidget {
  const _GateStatusLine();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<OfferKycGateCubit, OfferKycGateState>(
      builder: (context, state) {
        if (state.phase != OfferKycGatePhase.ready) {
          return const SizedBox.shrink();
        }
        final (title, body, color) = switch (state.status) {
          // Pending = attention-needed → semantic warning role (was the brand
          // tertiary orange doing double duty as a state color).
          KycStatus.pending => (
              l10n.kycStatusPendingTitle,
              l10n.kycStatusPendingBody,
              context.jeebRoles.warning,
            ),
          KycStatus.rejected => (
              l10n.kycStatusRejectedTitle,
              l10n.kycStatusRejectedBody,
              theme.colorScheme.error,
            ),
          // E19 tri-state: a resubmit-requested submission is actionable, not
          // final — surface the fix-and-resend prompt with the warning role.
          KycStatus.resubmitRequested => (
              l10n.kycStatusResubmitTitle,
              l10n.kycStatusResubmitBody,
              context.jeebRoles.warning,
            ),
          // Approved jeebers never reach this gate (JM-048 skips it); notSubmitted
          // shows no extra line.
          _ => (null, null, null),
        };
        if (title == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
          child: Column(
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: Spacing.twoXSmall),
              Text(body!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/offer_kyc_gate/offer_kyc_gate_screen_preview_test.dart
// ===========================================================================
//
// [OfferKycGateScreen] is the D38 interstitial an UNAPPROVED jeeber is routed
// THROUGH when they tap "Make Offer". Four things differ from a widget preview.
//
// 1. It owns a `Scaffold` (OMDS app bar + `ListView` body) and [jeebPreviewHost]
//    wraps every child in one as well, so the canvas shows two nested
//    Scaffolds. The inner one is the real surface; the outer contributes a
//    background and a `SafeArea`.
//
// 2. The canvas box is a real device, not the harness's default 390x200 — an
//    icon, a headline, two paragraphs and three stacked exits cannot be judged
//    in a 200 pt strip. The device is pinned INSIDE the fixture (a `MediaQuery`
//    override plus a `SizedBox`), because the canvas honours `size:` but the
//    render tests pump onto a fixed 800 x 600 surface: a state that merely
//    ASKED for a 320 x 568 canvas would be measured at 800 x 600 and the
//    compact window would silently become the phone one.
//
// 3. State is driven the only way this screen allows — through the `gateway:`
//    seam, with the fakes shared with the Screen Catalog entry
//    (`lib/devtool/catalog/fixtures/offer_kyc_gate_screen_fixtures.dart`). The
//    screen builds its own [OfferKycGateCubit] internally, so a state is
//    reachable here only if some canned `fetchStatus()` behaviour produces it.
//    No preview constructs a Dio-backed gateway and the `sl<KycGateway>()`
//    branch is never reached — network-free by construction rather than by the
//    guard in [jeebPreviewHost].
//
// 4. All three of its affordances navigate, through go_router extensions that
//    THROW without a `Router` in scope, and none of them runs during `build` —
//    so a naive host paints perfectly and dies on the first tap. The fixture
//    host seeds the PRODUCTION stack: `goNamed('offer-kyc-gate')` from the feed
//    replaces the stack, so the gate is the lone page and `canPop()` is false.
//
// What these previews surfaced in the screen:
//
//  * **Four of the six reachable states are pixel-identical.** `_GateStatusLine`
//    returns `SizedBox.shrink()` when `phase != ready`, and its `switch` on
//    `status` falls into `_ => (null, null, null)` for `notSubmitted` AND for
//    `approved` — so LOADING, ERROR, `ready(notSubmitted)` and
//    `ready(approved)` render byte-identical surfaces. A jeeber whose status
//    read failed is shown the same screen as one who has never started KYC,
//    with no retry and nothing that says the read failed. The cubit's own
//    dartdoc calls this "degrade gracefully", and R-F makes it deliberate for
//    the CTAs — but the *silence* is total: `OfferKycGatePhase.error` exists,
//    is emitted, and is rendered by nothing. Pinned by the render test, which
//    is why every preview below carries a caption: without one the four states
//    are indistinguishable to a text finder.
//  * **`approved` is a live branch that says the opposite of the truth.** The
//    screen's dartdoc asserts "an APPROVED jeeber NEVER reaches this screen",
//    and the guarantee lives entirely at the JM-048 feed call site — nothing in
//    this file or in [OfferKycGateCubit] enforces it, and `state.isApproved`
//    is defined on [OfferKycGateState] and read nowhere. If the feed's routing
//    ever disagrees with the live decision (a stale feed payload, a race with
//    an approval that landed mid-session), the gate renders "Get approved to
//    start sending offers" to a jeeber who already is, with no exit to the
//    composer. [offerKycGateScreenApproved] is what that looks like.
//  * **The status line is a dead end for `rejected`.** The copy says "This
//    decision is final — you can appeal through support", and the only CTA on
//    the screen is "Start verification" → `kyc-status`, the wizard. There is no
//    edge to `kyc-rejected` (the appeal-via-support screen the router
//    registers, D52/D87), so the screen tells a rejected jeeber their decision
//    is final and then offers them the button that restarts it.
//  * **`resubmitRequested` renders its title and body and nothing actionable.**
//    The E19 tri-state is explicitly "actionable, not final", and the branch
//    exists in `_GateStatusLine` — but the per-slot `resubmitSteps` the
//    submission carries are never surfaced here, so the jeeber is told to "Fix
//    the items below" with no items below. (It is also the one branch the
//    Screen Catalog never had a state for until this wave.)
//  * **At the accessibility ceiling four of the five published ids are not
//    merely below the fold, they are not BUILT.** On a 320 x 568 device at 200%
//    text the body carries 2287 pt of scroll behind a ~512 pt viewport, and the
//    `ListView` stops building past its viewport plus cache extent:
//    `gate_topup_note`, `gate_start_kyc_cta`, `gate_register_link` and
//    `gate_back_cta` are all absent from the widget tree AND from the semantics
//    tree until the user scrolls. Those are four of the five ids
//    65_W2_TEST_PLAN §2 JM-044 publishes as the QA targets, so a driver — or a
//    screen reader — querying them on arrival finds nothing. The D67 note is
//    the one that stings: its whole purpose is to be read BEFORE the jeeber
//    decides what to do. (Treat the exact extent with care — `flutter_test`
//    renders every glyph as a square of the font size, which makes English
//    roughly twice as wide as Inter does, so a real device scrolls less. What
//    is not a font artifact is the ORDER: the note and the exits are last in
//    the `ListView`, so they are the first things to fall off.)
//  * The good news, recorded because it is cheap to lose: NOTHING overflows.
//    Every state renders clean in EN and in AR, at 100% and at 200% text, on a
//    390 x 844 phone and on a 320 x 568 one — the body is a `ListView`, so the
//    composition simply grows a scroll extent instead of clipping.

/// The canvas box for a whole screen: a real phone, plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _offerKycGateScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on, framed the
/// same way.
const Size _offerKycGateScreenCompactCanvas = Size(332, 612);

/// Every state is the same gate behind the same app bar, differing only in what
/// the canned `fetchStatus()` does — and four of them differ in nothing at all
/// on screen. So each one names itself in a caption.
///
/// The `OfferKycGateScreen(...)` is constructed HERE rather than inside the
/// fixture host on purpose: `tool/preview_coverage.dart` credits a section only
/// when it literally builds the widget its previews are named after, and it
/// keeps the fixture library free of a circular import back into this one.
Widget _offerKycGateScreenHosted(
  KycGateway gateway, {
  required String caption,
  OfferKycGateScreenWindow window = OfferKycGateScreenWindows.phone,
}) =>
    OfferKycGateScreenPreviewHost(
      window: window,
      caption: caption,
      screen: OfferKycGateScreen(gateway: gateway),
    );

/// The canonical gate: the reconciled JM-044 entry for a jeeber who has never
/// started KYC.
///
/// `ready(notSubmitted)` — `_GateStatusLine` deliberately renders nothing,
/// because the headline and body already say "get approved to start sending
/// offers". This is the reference reading of the whole composition: icon,
/// headline, body, the D67 top-up note, and the three exits.
///
/// Matrixed because this is the state to judge the SHAPE in, and both extra
/// cards earn their place. AR is where a centered column of three long
/// sentences and a `TextButton` stack has to mirror — the `ListView` uses
/// `EdgeInsetsDirectional`, so this is the card that proves it. 200% is where
/// the same column stops fitting a phone and becomes a scroll.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Not submitted',
  size: _offerKycGateScreenPhoneCanvas,
  matrix: true,
)
Widget offerKycGateScreenNotSubmitted() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(),
      caption: 'Not submitted · phone 390 × 844',
    );

/// `ready(pending)` — the state the W2 RD-1 fix was written against.
///
/// The JM-044 entry a `pending` jeeber takes: the gate adds "Submission
/// received" + the 24-hour review copy in the semantic WARNING role. Note what
/// does NOT change: the primary CTA is still "Start verification" → the wizard,
/// for a jeeber whose submission is already in review.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Pending',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenPending() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.pending),
      caption: 'Pending · phone 390 × 844',
    );

/// `ready(rejected)` — the longest content this screen can carry, and its
/// sharpest contradiction.
///
/// The status line renders in the error role: "We need a second look" + "This
/// decision is final — you can appeal through support." The only primary CTA
/// underneath is "Start verification", which restarts the wizard, and there is
/// no edge from here to `kyc-rejected` (the appeal screen the router registers
/// for D52/D87). So the screen states the decision is final and then offers the
/// button that contradicts it.
///
/// The second matrixed state: five paragraphs of centered copy is the worst
/// case for both mirroring and text scale, and this is where a reviewer should
/// look before believing "nothing overflows".
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Rejected',
  size: _offerKycGateScreenPhoneCanvas,
  matrix: true,
)
Widget offerKycGateScreenRejected() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.rejected),
      caption: 'Rejected · phone 390 × 844',
    );

/// `ready(resubmitRequested)` — the E19 tri-state, which had no mocked state on
/// ANY dev surface before this wave.
///
/// "Resubmit your documents. We need you to update part of your submission and
/// send it again. Fix the items below, then resubmit." There are no items
/// below: `KycSubmission.resubmitSteps` carries the per-slot list the
/// back-office filled in, and nothing on this screen reads it. The copy is
/// borrowed from the KYC status screen, where the list does render.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Resubmit requested',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenResubmitRequested() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(
        status: KycStatus.resubmitRequested,
      ),
      caption: 'Resubmit requested · phone 390 × 844',
    );

/// `OfferKycGatePhase.loading` — the cold-start frame, held open by a
/// `fetchStatus()` that never resolves.
///
/// The cubit emits `loading` from its constructor, so this is what every jeeber
/// sees until the read lands. It is the R-F invariant made visible: no spinner,
/// no skeleton, no blocked CTAs — the gate's exits and the top-up note are
/// already there and already tappable, and only the optional status line is
/// missing. It is also the first of the four states that are pixel-identical:
/// nothing here distinguishes "still loading" from "there is no status".
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Loading',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenLoading() => _offerKycGateScreenHosted(
      const OfferKycGateScreenPendingGateway(),
      caption: 'Loading · phone 390 × 844',
    );

/// `OfferKycGatePhase.error` — `GET /v1/kyc/status` threw.
///
/// `OfferKycGateCubit.loadStatus` catches everything and emits `error`, and
/// `_GateStatusLine` renders `SizedBox.shrink()` for it. So the phase is
/// emitted and read by nothing: this is byte-identical to
/// [offerKycGateScreenNotSubmitted] and to [offerKycGateScreenLoading]. A
/// jeeber whose status read failed is told they have not started KYC. There is
/// no retry, no stale-data note, and no way for the user or for QA to tell the
/// difference — which is what makes the caption the only honest label.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Status read failed',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenStatusReadFailed() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFailingGateway(),
      caption: 'Status read failed · phone 390 × 844',
    );

/// `ready(approved)` — the state the screen's dartdoc says cannot happen.
///
/// It is reachable: nothing in this file, in [OfferKycGateCubit] or in the
/// router enforces the claim — the JM-048 feed call site does, from outside. A
/// stale feed payload or an approval that lands mid-session is enough to put an
/// approved jeeber here, and the `_ => (null, null, null)` arm of
/// `_GateStatusLine` swallows the one signal that would have caught it:
/// `state.isApproved` is defined and never read. The result is a screen that
/// tells an approved jeeber to "Get approved to start sending offers" and
/// offers no route to the composer they were trying to reach.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Approved (should be unreachable)',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenApproved() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.approved),
      caption: 'Approved · phone 390 × 844',
    );

/// The worst case the app supports: the longest state on the smallest display
/// at the largest text.
///
/// A 64 pt icon, a two-line headline, a two-sentence body, the rejected status
/// block, the top-up note and three stacked CTAs at 200% on a 320 x 568 device.
/// Nothing overflows — the body is a `ListView`, so the composition becomes a
/// scroll rather than a clip (2287 pt of it behind a ~512 pt viewport). What it
/// costs is REACHABILITY: the `ListView` stops building past its viewport plus
/// cache extent, so on arrival `gate_topup_note`, `gate_start_kyc_cta`,
/// `gate_register_link` and `gate_back_cta` are all absent from the widget tree
/// AND from the semantics tree — four of the five ids 65_W2_TEST_PLAN §2 JM-044
/// publishes as the QA targets. Pinned by the render test.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Rejected · compact · 200% text',
  size: _offerKycGateScreenCompactCanvas,
)
Widget offerKycGateScreenCompactLargeText() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.rejected),
      caption: 'Rejected · compact 320 × 568 · 200% text',
      window: OfferKycGateScreenWindows.compactLargeText,
    );
