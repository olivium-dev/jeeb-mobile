import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
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
/// redesign-2026-08: re-skinned onto the Jeeb design system against screen 22
/// (its neighbour in the jeeber journey) — in-body [JeebTopBar] instead of a
/// Material app bar, 24px gutters, a start-aligned type ladder off
/// `context.jeebText`, the structured reason as a kit [JeebInfoNote], and the
/// two existing actions docked in a [JeebCtaFooter]. Re-skin only: no new
/// affordance, no reordering, no copy change.
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

class _KycRejectedView extends StatelessWidget {
  const _KycRejectedView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_rejected_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        // The board's header is an in-body row, not a Material app bar
        // (redesign §3 / kit #1), so the Scaffold carries no `appBar:`.
        body: SafeArea(
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
                // fallback when there's nothing to pop — unchanged behaviour
                // from the OMDSAppBar this replaced.
                onLeadingPressed: () => context.canPop()
                    ? context.pop()
                    : context.goNamed('customer-profile'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    Spacing.xLarge,
                    Spacing.xLarge,
                    Spacing.xLarge,
                    Spacing.large,
                  ),
                  children: [
                    const _RejectionMark(),
                    const SizedBox(height: Spacing.large),
                    Text(
                      l10n.kycRejectedHeadline,
                      style: context.jeebText.h1.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    Text(
                      l10n.kycRejectedBody,
                      // Brown is the board's secondary ink; periwinkle is
                      // forbidden as body text on white (§4.1).
                      style: context.jeebText.body.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Structured rejection reason from GET /v1/kyc/status (when
                    // the back-office returned one). Self-spacing so the layout
                    // collapses cleanly when no structured reason is present.
                    const _RejectionReasonSection(),
                  ],
                ),
              ),
              // R1: the residual space above the footer stays plain white —
              // the two actions dock, in their existing order.
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
                  child: JeebCtaButton.primary(
                    label: l10n.kycRejectedAppealCta,
                    // EDGE → support-ticket (JM-063 AC6, D76). W4 landed the
                    // SupportTicketScreen + registered `support-ticket`
                    // (path `/support`, app_router.dart) so this is now an
                    // honest navigation, not the AP-9 guarded coming-soon it
                    // was before the route existed. Mirrors account-status /
                    // dispute-status, which both `goNamed('support-ticket')` to
                    // the same `support_root`.
                    onTap: () => context.goNamed('support-ticket'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen's state mark. The board has no rejection screen and therefore no
/// hero-glyph component; this is the kit's own tonal-disc idiom
/// (`JeebInfoNote.success`'s check disc) scaled to a screen-level mark, so the
/// error reads as a soft tinted badge rather than the naked Ø64 red slab the
/// screen carried before. Decoration only — not a tappable affordance.
class _RejectionMark extends StatelessWidget {
  const _RejectionMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      // Directional: the board's bands are start-aligned, never centred.
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: Sizes.fiveXLarge,
        height: Sizes.fiveXLarge,
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.error_outline_rounded,
          size: Sizes.xLarge,
          color: scheme.onErrorContainer,
        ),
      ),
    );
  }
}

/// Renders the structured rejection cause (when the status fetch resolves to a
/// rejected submission carrying a `rejection_reason`). Silent while loading or
/// on failure so the FINAL copy is never blocked.
class _RejectionReasonSection extends StatelessWidget {
  const _RejectionReasonSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KycRejectedCubit, KycRejectedState>(
      builder: (context, state) {
        // The reason chip is a NON-BLOCKING enrichment: the FINAL copy + CTAs
        // above are the primary content and must never wait on the status
        // fetch. So while loading (or on error / no structured reason) we render
        // nothing rather than an infinite-ticker spinner — this also keeps the
        // route-resolution gate's pumpAndSettle from hanging.
        final reason = state.rejectionReason;
        if (reason == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: Spacing.xLarge),
          child: _RejectionReasonNotice(reason: reason),
        );
      },
    );
  }
}

/// Error-toned kit note naming the structured rejection cause. Copy is reused
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
        // The D20-removed `vehicleDocumentMissing` reason now folds into "other".
        return l10n.kycRejectionReasonOther;
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
