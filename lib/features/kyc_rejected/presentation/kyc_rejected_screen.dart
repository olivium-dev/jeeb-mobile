import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import '../application/kyc_rejected_cubit.dart';
import '../application/kyc_rejected_state.dart';

/// kyc-rejected (JM-043). FINAL rejection (D52/D87): there is NO resubmit CTA
/// (the divergence the JM-043 fix exists to remove — see 20_GAP_MAP). The only
/// path forward is an appeal via support; the secondary exit returns to the
/// customer profile.
///
/// Wiring (30_BACKLOG JM-043 · 42_GUARDRAILS_MOCK): the structured rejection
/// reason is fetched from `GET /v1/kyc/status` (the app-rewrite of
/// `GET /user-management/users/:userId/kyc`) through the existing [KycGateway]
/// (`DioKycGateway`, bound in `injection_container.dart`). The reason is lifted
/// from `KycStatusView`'s rejected branch and only enriches the body — a failed
/// or non-rejected fetch degrades to the generic FINAL copy, never resubmit.
///
/// Roots/ids match 65_W2_TEST_PLAN §2 JM-043 (`kyc_rejected_root` is the root;
/// `kyc_rejected_resubmit_cta` MUST stay ABSENT — assertNotVisible).
///
/// Edges OWNED here (21_NAV_PLAN §C JM-043):
///   kyc-rejected → support-ticket    (`kyc_rejected_appeal_cta`)  [JM-063, W4]
///   kyc-rejected → customer-profile  (`kyc_rejected_back_cta`)
///
/// MIDNIGHT M3-21 — **the board never drew this screen.** It is the terminal
/// leaf of **R23 "Become a Jeeber"**'s own funnel, so R23 is the chrome donor:
/// the `content` field with one quiet orange glow at the top END, no periwinkle
/// wash, decor STILL, an in-body [JeebTopBar] over 24px gutters, and ONE docked
/// [JeebCtaFooter]. The rejection itself is the empty-family error form
/// ([JeebEmptyState] on [JeebEmptyStateVariant.street] — E3's parked jeeber
/// scooter, the one drawn subject that is a jeeber standing still) and every
/// negative ink is danger-SOFT `onErrorContainer`, never full-strength `error`
/// (the R22 ruling). No new affordance, no reordering, no copy change.
class KycRejectedScreen extends StatelessWidget {
  const KycRejectedScreen({super.key, this.gateway});

  /// Injectable for widget tests; production resolves via DI (`sl<KycGateway>`).
  final KycGateway? gateway;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<KycRejectedCubit>(
      create: (_) => KycRejectedCubit(gateway ?? _resolveGateway())..load(),
      child: const _KycRejectedView(),
    );
  }

  /// Production resolves the real `DioKycGateway` from DI; the route-resolution
  /// gate (`test/core/router/w2_routes_resolve_test.dart`) builds this screen
  /// with a bare GetIt, so fall back to [FakeKycGateway] when unregistered
  /// (mirrors `KycWizardScreen._resolveGateway`). The Fake returns a
  /// non-rejected stored submission, so the screen simply shows the generic
  /// FINAL copy — never a crash, never a resubmit.
  KycGateway _resolveGateway() {
    if (sl.isRegistered<KycGateway>()) return sl<KycGateway>();
    return FakeKycGateway();
  }
}

/// R23's own gutter — token sheet §5's 24px screen default.
const double _kGutter = Spacing.xLarge;

/// R23 sets its first block `Spacing.large` under the bar; the bar's circles
/// carry a 4dp invisible tap overhang, so subtract it to land on 20 visible.
const double _kContentTopGap = Spacing.large - JeebTopBar.tapOverhang;

/// The empty-family subject: E3's scooter parked under a streetlamp is the only
/// drawn subject that is a JEEBER standing still, which is what a final
/// rejection makes of this applicant. Its sparkles are static (wave-B ruling 2),
/// so it is also the quietest of the four canonical variants.
const JeebEmptyStateVariant _kEmptyVariant = JeebEmptyStateVariant.street;

class _KycRejectedView extends StatelessWidget {
  const _KycRejectedView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'kyc_rejected_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The header is an in-body row over the field, not a Material app bar,
        // so the last light-theme slab on this screen is gone.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          // R23's measured anchor: ORANGE glow top-end, and NO periwinkle wash
          // (its least-squares fit found none). Board-still → decor off.
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar(
                  title: l10n.kycRejectedTitle,
                  // New interactive element -> `<screen>_<element>`. The in-body
                  // `kyc_rejected_back_cta` below keeps its own id untouched.
                  identifier: 'kyc_rejected_back',
                  // JEBV4-13 P1-6: the kit's default leading action is the
                  // guarded `maybePop()`, which no-ops when this screen is the
                  // stack root, leaving the back circle dead. Mirror the screen's
                  // own `kyc_rejected_back_cta` exit (→ customer-profile) as the
                  // fallback when there's nothing to pop.
                  onLeadingPressed: () => context.canPop()
                      ? context.pop()
                      : context.goNamed('customer-profile'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      _kGutter,
                      _kContentTopGap,
                      _kGutter,
                      _kGutter,
                    ),
                    children: const [
                      _RejectionBlock(),
                      _RejectionReasonSection(),
                    ],
                  ),
                ),
                JeebCtaFooter.single(
                  below: Semantics(
                    identifier: 'kyc_rejected_back_cta',
                    button: true,
                    container: true,
                    child: JeebCtaButton.text(
                      label: l10n.kycRejectedBackCta,
                      // EDGE → customer-profile.
                      onTap: () => context.goNamed('customer-profile'),
                    ),
                  ),
                  child: Semantics(
                    identifier: 'kyc_rejected_appeal_cta',
                    button: true,
                    container: true,
                    // Periwinkle, not accent: R23 spends its ONE orange pill on
                    // the funnel's forward act, and this screen closes the
                    // funnel ("when in doubt: not orange", theme ruling 3).
                    child: JeebCtaButton.primary(
                      label: l10n.kycRejectedAppealCta,
                      // EDGE → support-ticket (JM-063 AC6, D76). Mirrors
                      // account-status / dispute-status, which both
                      // `goNamed('support-ticket')` to the same `support_root`.
                      onTap: () => context.goNamed('support-ticket'),
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
}

/// The decision itself, as the empty family's ERROR form: the danger-tinted E3
/// scene over the white `onSurface` headline and the muted body. Replaces the
/// pass-1 Ø64 tonal disc, which had no Midnight idiom behind it.
class _RejectionBlock extends StatelessWidget {
  const _RejectionBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      status: JeebEmptyStateStatus.error,
      variant: _kEmptyVariant,
      headline: l10n.kycRejectedHeadline,
      body: l10n.kycRejectedBody,
    );
  }
}

/// Renders the structured rejection cause (when the status fetch resolves to a
/// rejected submission carrying a `rejection_reason`).
///
/// The cause is a NON-BLOCKING enrichment: the FINAL copy and the two exits are
/// the primary content and must never wait on `GET /v1/kyc/status`. So the
/// loading, fetch-error and no-structured-reason states all render the same
/// designed frame — the one above, complete on its own — rather than a skeleton
/// or an apology for an optional line. Deliberate silence, not a gap; the three
/// states are mounted in the catalog so each is captured.
class _RejectionReasonSection extends StatelessWidget {
  const _RejectionReasonSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KycRejectedCubit, KycRejectedState>(
      builder: (context, state) {
        final reason = state.rejectionReason;
        if (reason == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: Spacing.large),
          child: _RejectionReasonNotice(reason: reason),
        );
      },
    );
  }
}

/// Danger-toned kit note naming the structured rejection cause. Copy is reused
/// from `KycStatusView`'s rejected branch (the source this screen was extracted
/// from) so the localized causes stay consistent across the two surfaces.
class _RejectionReasonNotice extends StatelessWidget {
  const _RejectionReasonNotice({required this.reason});

  final KycRejectionReason reason;

  String _label(AppLocalizations l10n) {
    switch (reason) {
      case KycRejectionReason.idUnreadable:
        return l10n.kycRejectionReasonIdUnreadable;
      case KycRejectionReason.selfieMismatch:
        return l10n.kycRejectionReasonSelfieMismatch;
      case KycRejectionReason.expired:
        return l10n.kycRejectionReasonExpired;
      case KycRejectionReason.other:
        // D52: this screen is FINAL, so it must not say "resubmit" the way the
        // shared kycRejectionReasonOther does for KycStatusView.
        return l10n.kycRejectedReasonOtherFinal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'kyc_rejected_reason',
      container: true,
      child: JeebInfoNote.error(
        icon: Icons.info_outline_rounded,
        text: _label(l10n),
      ),
    );
  }
}
