import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
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
      child: Scaffold(
        appBar: OMDSAppBar(title: l10n.kycRejectedTitle, showBackButton: true),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(Icons.error_outline_rounded,
                size: Sizes.sixXLarge, color: theme.colorScheme.error),
            const SizedBox(height: Spacing.large),
            Text(l10n.kycRejectedHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.small),
            Text(l10n.kycRejectedBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            // Structured rejection reason from GET /v1/kyc/status (when the
            // back-office returned one). Self-spacing so the layout collapses
            // cleanly when no structured reason is present.
            const _RejectionReasonSection(),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'kyc_rejected_appeal_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.kycRejectedAppealCta,
                // EDGE → support-ticket (JM-063 AC6, D76). W4 landed the
                // SupportTicketScreen + registered `support-ticket`
                // (path `/support`, app_router.dart) so this is now an honest
                // navigation, not the AP-9 guarded coming-soon it was before the
                // route existed. Mirrors account-status / dispute-status, which
                // both `goNamed('support-ticket')` to the same `support_root`.
                onTap: () => context.goNamed('support-ticket'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'kyc_rejected_back_cta',
              button: true,
              container: true,
              child: TextButton(
                // EDGE → customer-profile.
                onPressed: () => context.goNamed('customer-profile'),
                child: Text(l10n.kycRejectedBackCta),
              ),
            ),
          ],
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
          padding: const EdgeInsets.only(top: Spacing.large),
          child: _RejectionReasonNotice(reason: reason),
        );
      },
    );
  }
}

/// Error-container notice naming the structured rejection cause. Copy is reused
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
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_rejected_reason',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                _label(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
