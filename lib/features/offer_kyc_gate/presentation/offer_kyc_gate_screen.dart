import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import '../application/offer_kyc_gate_cubit.dart';
import '../application/offer_kyc_gate_state.dart';

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
/// redesign-2026-08: re-skinned onto the Jeeb kit to match its neighbour
/// (screen 22 `become-a-jeeber`, the KYC wizard this gate hands off to) —
/// in-body [JeebTopBar] instead of the Material `OMDSAppBar`, start-aligned
/// `jeebText` headline/body instead of a centred hero glyph, the status line
/// and the top-up note as [JeebInfoNote] panels, and the three exits docked in
/// a [JeebCtaFooter]. No flow, copy, affordance or identifier changed.
///
/// MIDNIGHT M3-19: no tile was drawn for the gate. NEAREST TILE = **R23
/// (become-a-jeeber)** — the gate wears R23's funnel chrome and `gate_start_kyc_cta`
/// lands ON R23 one tap later, so the two must not disagree. Carried over:
/// the `content` field with ONE quiet orange glow at the **top end** (wave-C
/// listed R23 in the top-END class) and no periwinkle wash (R23 declares none);
/// `onSurface` headline over `onSurfaceVariant` body; calm-glass `muted` info
/// panels; the docked act as the ORANGE pill R23 draws for `Submit for review`
/// (R17, the gated action, docks its own act orange too — both neighbours
/// agree, which is what lifts this off `primary`). The band under the notes
/// stays empty field: R23 draws ~340dp of nothing above its own CTA.
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
///   `gate_register_link`, `gate_back_cta`; plus `offer_kyc_gate_back` on the
///   redesign's new top-bar circle.
class OfferKycGateScreen extends StatelessWidget {
  const OfferKycGateScreen({super.key, this.cubit, this.gateway})
    : assert(
        cubit == null || gateway == null,
        'Provide either a cubit or a gateway, not both.',
      );

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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'offer_kyc_gate',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // No Material app bar: the redesign's header is a body row, so the
        // gate wears the same Ø40 back circle + ink title as the KYC wizard
        // it hands off to.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          // R23's anchor. No wash: R23 declares zero periwinkle, and
          // `washPlacement` would paint that layer unconditionally.
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar.back(
                  title: l10n.offerKycGateTitle,
                  identifier: 'offer_kyc_gate_back',
                  // JEBV4-13 P1-6: the kit's default leading action is
                  // `maybePop()`, which intentionally no-ops when this screen is
                  // the stack root (reached via `go`, not pushed) — otherwise it
                  // would pop the last Navigator page. Without an explicit
                  // destination that leaves the back circle dead. Mirror the
                  // screen's own `gate_back_cta` exit so both back affordances
                  // agree.
                  onLeadingPressed: () => _popToDeliveryTab(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      Spacing.xLarge,
                      Spacing.large,
                      Spacing.xLarge,
                      Spacing.large,
                    ),
                    // Top-aligned, nothing stretched: R23 leaves the band under
                    // its last panel as empty field, not a gap to fill.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.offerKycGateHeadline,
                          style: context.jeebText.h1.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: Spacing.xSmall),
                        Text(
                          l10n.offerKycGateBody,
                          style: context.jeebText.body.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const _GateStatusLine(),
                        const SizedBox(height: Spacing.large),
                        // D67: top-up is allowed even while unapproved — surfaced
                        // so the jeeber knows the wallet path is open before
                        // approval. Load-bearing product copy; the note only
                        // changed panel, never wording.
                        JeebInfoNote.muted(
                          identifier: 'gate_topup_note',
                          // Outline glyph: R23 draws its calm info panel with
                          // one, and keeps filled marks for STATE.
                          icon: Icons.account_balance_wallet_outlined,
                          text: l10n.gateTopupNote,
                        ),
                      ],
                    ),
                  ),
                ),
                JeebCtaFooter.single(
                  below: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        identifier: 'gate_register_link',
                        button: true,
                        container: true,
                        child: JeebCtaButton.text(
                          // EDGE → delivery-register-prompt (21_NAV §C JM-044,
                          // line 204). W2 RESIDUAL FIX (66_W2_QA RD-1 /
                          // jm-044 AC3): the old wiring popped back to the
                          // DELIVERY tab, but that tab re-resolves its body from
                          // the LIVE `JeeberKycStatusGate` — and the gate is
                          // reached by a `pending` jeeber (the reconciled JM-044
                          // entry, kyc_status=pending → feed), so popping back
                          // rendered `jeeber_feed_root`, NOT
                          // `delivery_register_prompt`. The register-prompt id is
                          // gate-state-dependent on the tab, so we cannot rely on
                          // a pop. Navigate to the standalone register-prompt
                          // route (21_NAV line 50 "optional ADD
                          // /jeeber/register-prompt"), which renders
                          // `delivery_register_prompt` unconditionally regardless
                          // of the live KYC status. `go` (not `push`) matches the
                          // feed→gate entry edge (also a `go`).
                          label: l10n.gateRegisterLink,
                          // The label is the longest string on the screen; the
                          // kit ellipsizes at one line, so give it the whole
                          // 24px-gutter width instead of the default 0/22 inset.
                          contentPadding: EdgeInsetsDirectional.zero,
                          onTap: () =>
                              context.goNamed('delivery-register-prompt'),
                        ),
                      ),
                      Semantics(
                        identifier: 'gate_back_cta',
                        button: true,
                        container: true,
                        child: JeebCtaButton.text(
                          // EDGE → jeeber-requests-home (the Dashboard feed tab,
                          // root `jeeber_feed_root`). Tabs are not routes; pop
                          // back to the shell-hosted DELIVERY tab the gate was
                          // pushed from.
                          label: l10n.gateBackCta,
                          contentPadding: EdgeInsetsDirectional.zero,
                          onTap: () => _popToDeliveryTab(context),
                        ),
                      ),
                    ],
                  ),
                  child: Semantics(
                    identifier: 'gate_start_kyc_cta',
                    button: true,
                    container: true,
                    // ORANGE: this is the same forward act R23 draws as
                    // `Submit for review`, and it lands on that very screen.
                    child: JeebCtaButton.accent(
                      label: l10n.gateStartKycCta,
                      // EDGE → kyc-identity (the KYC wizard, route `kyc-status`,
                      // root `kyc_wizard_root`).
                      onTap: () => context.goNamed('kyc-status'),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

/// The live KYC-status line — the gate's only stateful slot.
///
/// R-F is unchanged: the exits and the top-up note never wait on this fetch.
/// What MIDNIGHT M3-19 changes is that `loading` and `error` stop rendering
/// nothing. Both now occupy the slot as a calm-glass `muted` strip, so the
/// panel does not pop in under the body copy and the two catalog states that
/// have always existed ("Loading", "Status Read Failed") finally look like
/// themselves. `muted` and not `error`: a failed *read* is not a decision, and
/// `JeebInfoNoteTone.error` is reserved for the surface where "the decision IS
/// the message" (`kyc_status_view.dart`'s rejection notice).
///
/// redesign-2026-08: the bare coloured title/body pair became a [JeebInfoNote]
/// so the state reads as the same panel the rest of the app uses. The tone
/// carries the colour, which is why this file no longer names a role directly:
/// `warning` resolves to `jeebRoles.warningContainer` and `error` to the Wave-0
/// soft error family — the same semantic mapping as before, one layer up.
class _GateStatusLine extends StatelessWidget {
  const _GateStatusLine();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OfferKycGateCubit, OfferKycGateState>(
      builder: (context, state) {
        if (state.phase == OfferKycGatePhase.loading) {
          return _GateStatusStrip(
            key: const Key('gate-status-loading'),
            icon: Icons.hourglass_empty,
            // TODO(midnight): l10n-queued — offerKycGateStatusChecking.
            text: l10n.kycStatusPlaceholder,
          );
        }
        if (state.phase == OfferKycGatePhase.error) {
          return _GateStatusStrip(
            key: const Key('gate-status-unavailable'),
            icon: Icons.cloud_off_outlined,
            // TODO(midnight): l10n-queued — offerKycGateStatusUnavailable.
            text: l10n.requestSummaryErrorGeneric,
          );
        }
        final (title, body, tone, icon) = switch (state.status) {
          // Pending = attention-needed → semantic warning tone (never the
          // brand accent doing double duty as a state colour).
          KycStatus.pending => (
            l10n.kycStatusPendingTitle,
            l10n.kycStatusPendingBody,
            JeebInfoNoteTone.warning,
            Icons.access_time_filled,
          ),
          KycStatus.rejected => (
            l10n.kycStatusRejectedTitle,
            l10n.kycStatusRejectedBody,
            JeebInfoNoteTone.error,
            Icons.error,
          ),
          // E19 tri-state: a resubmit-requested submission is actionable, not
          // final — surface the fix-and-resend prompt with the warning tone.
          KycStatus.resubmitRequested => (
            l10n.kycStatusResubmitTitle,
            l10n.kycStatusResubmitBody,
            JeebInfoNoteTone.warning,
            Icons.assignment_late,
          ),
          // Approved jeebers never reach this gate (JM-048 skips it); notSubmitted
          // shows no extra line.
          _ => (null, null, null, null),
        };
        if (title == null) return const SizedBox.shrink();
        return _GateStatusSlot(
          child: JeebInfoNote(
            tone: tone!,
            icon: icon,
            title: title,
            text: body,
          ),
        );
      },
    );
  }
}

/// The one gap above the status panel, so every phase sits at the same offset.
class _GateStatusSlot extends StatelessWidget {
  const _GateStatusSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
    child: child,
  );
}

/// The single-line `muted` strip the loading and failed-read phases occupy.
class _GateStatusStrip extends StatelessWidget {
  const _GateStatusStrip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => _GateStatusSlot(
    child: JeebInfoNote.muted(icon: icon, text: text),
  );
}
