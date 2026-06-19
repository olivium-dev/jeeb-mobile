import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/kyc_wizard_cubit.dart';
import '../application/kyc_wizard_state.dart';
import '../domain/kyc_submission.dart';

/// Terminal-state view for the wizard: pending, approved, or rejected (JM-042).
///
/// Hosted inside [KycWizardScreen] at `/profile/kyc?step=status` (route name
/// `kyc-status`) — the wizard provides the Scaffold/AppBar, so this view only
/// renders the body. The body root carries `Semantics(identifier:
/// 'kyc_status_root')` (65_W2_TEST_PLAN §2 JM-042).
///
/// Status is read from `KycWizardCubit` state, which is hydrated by
/// `KycWizardCubit.loadStatus()` → `KycGateway.fetchStatus()` →
/// `GET /v1/kyc/status` (DioKycGateway, bound to the real Dio in DI). The mock
/// returns `{ state, rejection_reason?, submitted_at }` and 404 when none.
///
/// Per-variant CTAs + edges (21_NAV_PLAN §C JM-042; D38/D39/D52/D67):
///   approved → `kyc_status_feed_cta`    → jeeber-requests-home (`shell`)
///           → `kyc_status_wallet_cta`   → wallet-hub (`wallet`)
///           → `kyc_status_topup_cta`    → wallet-charge-info (`wallet-charge-info`)
///   pending  → `kyc_status_topup_cta`   → wallet-charge-info (top-up allowed
///              pre-approval, D38/D39) + `kyc_status_topup_allowed_note`
///   rejected → `kyc_status_view_rejection` → kyc-rejected (`kyc-rejected`)
///
/// D52/D87: rejection is FINAL — there is NO resubmit CTA here. The old
/// `kyc-status-resubmit` path was removed for JM-042/043; the rejected branch
/// now hands off to the dedicated `kyc-rejected` screen (appeal-via-support).
class KycStatusView extends StatelessWidget {
  const KycStatusView({super.key, this.onClose});

  static const Key pendingTitleKey = Key('kyc-status-pending-title');
  static const Key approvedTitleKey = Key('kyc-status-approved-title');
  static const Key rejectedTitleKey = Key('kyc-status-rejected-title');
  static const Key backCtaKey = Key('kyc-status-back');
  static const Key rejectionReasonKey = Key('kyc-status-rejection-reason');

  /// Optional close callback wired by the host (router) — defaults to a
  /// `Navigator.maybePop` so the view works standalone in tests. Used as the
  /// secondary "back to profile" exit on the pending/rejected variants.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<KycWizardCubit, KycWizardState>(
      builder: (context, state) {
        final Widget body;
        if (state.isLoadingStatus) {
          body = const Center(child: OmdsLoadingState());
        } else {
          body = _bodyFor(context, state, l10n);
        }
        return Semantics(
          identifier: 'kyc_status_root',
          container: true,
          child: body,
        );
      },
    );
  }

  Widget _bodyFor(
    BuildContext context,
    KycWizardState state,
    AppLocalizations l10n,
  ) {
    switch (state.submission.status) {
      case KycStatus.notSubmitted:
      case KycStatus.pending:
        return _PendingBody(onBackToProfile: () => _close(context));
      case KycStatus.approved:
        return const _ApprovedBody();
      case KycStatus.rejected:
        return _RejectedBody(
          reason: state.submission.rejectionReason,
          onBackToProfile: () => _close(context),
        );
    }
  }

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
      return;
    }
    Navigator.of(context).maybePop();
  }
}

/// Shared scaffolding for a status body: icon + title + body copy + a column of
/// CTAs pushed to the bottom. Keeps the three variants visually consistent.
class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({
    required this.titleKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.actions,
    this.extra,
  });

  final Key titleKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  /// CTA widgets, top-to-bottom (primary first).
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Spacing.xLarge),
          Icon(icon, size: Sizes.sixXLarge, color: iconColor),
          const SizedBox(height: Spacing.large),
          Text(
            title,
            key: titleKey,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (extra != null) ...[
            const SizedBox(height: Spacing.large),
            extra!,
          ],
          const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.small),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Pending / submitted: documents under review. Top-up is allowed pre-approval
/// (D38/D39) so the top-up CTA + the "allowed while pending" note both show.
class _PendingBody extends StatelessWidget {
  const _PendingBody({required this.onBackToProfile});

  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StatusScaffold(
      titleKey: KycStatusView.pendingTitleKey,
      icon: Icons.hourglass_top_rounded,
      iconColor: theme.colorScheme.primary,
      title: l10n.kycStatusPendingTitle,
      body: l10n.kycStatusPendingBody,
      // "Top-up allowed while pending" note (D38/D39). Reuses the gate's
      // top-up-in-review copy (L10N-REQ: kycStatusTopupAllowedNote — see
      // 50_ROUTE_REQUESTS JM-042).
      extra: _TopupAllowedNote(text: l10n.gateTopupNote),
      actions: [
        // → wallet-charge-info (D92/D93 — no in-app payment). Top-up is the
        // primary action a pending jeeber can take.
        Semantics(
          identifier: 'kyc_status_topup_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusTopupCta — reusing walletTopUpCta ("Top up").
            text: l10n.walletTopUpCta,
            variant: OmdsButtonVariant.secondary,
            onTap: () => context.goNamed('wallet-charge-info'),
          ),
        ),
        Semantics(
          identifier: 'kyc_status_back',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            key: KycStatusView.backCtaKey,
            text: l10n.kycStatusBackToProfileCta,
            variant: OmdsButtonVariant.text,
            onTap: onBackToProfile,
          ),
        ),
      ],
    );
  }
}

/// Approved: the three post-approval entry points (feed / wallet / top-up).
class _ApprovedBody extends StatelessWidget {
  const _ApprovedBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StatusScaffold(
      titleKey: KycStatusView.approvedTitleKey,
      icon: Icons.verified_rounded,
      iconColor: theme.colorScheme.primary,
      title: l10n.kycStatusApprovedTitle,
      body: l10n.kycStatusApprovedBody,
      actions: [
        // → jeeber-requests-home. The feed lives in the DELIVERY tab of the
        // shell (no dedicated route); `shell` lands the approved jeeber on the
        // feed (`jeeber_feed_root`, JM-036).
        Semantics(
          identifier: 'kyc_status_feed_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusFeedCta ("Go to feed") — reusing
            // jeeberFeedSectionTitle ("Available requests").
            text: l10n.jeeberFeedSectionTitle,
            onTap: () => context.goNamed('shell'),
          ),
        ),
        // → wallet-hub (`wallet`, lands `wallet_available_balance`).
        Semantics(
          identifier: 'kyc_status_wallet_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusWalletCta — reusing shellWalletChipLabel
            // ("Wallet").
            text: l10n.shellWalletChipLabel,
            variant: OmdsButtonVariant.secondary,
            onTap: () => context.goNamed('wallet'),
          ),
        ),
        // → wallet-charge-info (how to add funds; D92/D93).
        Semantics(
          identifier: 'kyc_status_topup_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusTopupCta — reusing walletTopUpCta ("Top up").
            text: l10n.walletTopUpCta,
            variant: OmdsButtonVariant.text,
            onTap: () => context.goNamed('wallet-charge-info'),
          ),
        ),
      ],
    );
  }
}

/// Rejected: FINAL decision (D52/D87). No resubmit. The reason notice plus a
/// hand-off to the dedicated `kyc-rejected` screen (appeal via support).
class _RejectedBody extends StatelessWidget {
  const _RejectedBody({
    required this.reason,
    required this.onBackToProfile,
  });

  final KycRejectionReason? reason;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StatusScaffold(
      titleKey: KycStatusView.rejectedTitleKey,
      icon: Icons.error_outline_rounded,
      iconColor: theme.colorScheme.error,
      title: l10n.kycStatusRejectedTitle,
      body: l10n.kycStatusRejectedBody,
      extra: _RejectionReasonNotice(reason: reason),
      actions: [
        // → kyc-rejected (JM-043): the appeal-only final screen. This REPLACES
        // the old resubmit CTA (D52/D87).
        Semantics(
          identifier: 'kyc_status_view_rejection',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusViewRejectionCta ("View rejection details") —
            // reusing profileKycViewCta ("View status").
            text: l10n.profileKycViewCta,
            onTap: () => context.goNamed('kyc-rejected'),
          ),
        ),
        Semantics(
          identifier: 'kyc_status_back',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            key: KycStatusView.backCtaKey,
            text: l10n.kycStatusBackToProfileCta,
            variant: OmdsButtonVariant.text,
            onTap: onBackToProfile,
          ),
        ),
      ],
    );
  }
}

/// "You can still top up while pending" informational note (D38/D39).
class _TopupAllowedNote extends StatelessWidget {
  const _TopupAllowedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_status_topup_allowed_note',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectionReasonNotice extends StatelessWidget {
  const _RejectionReasonNotice({required this.reason});

  final KycRejectionReason? reason;

  String _label(AppLocalizations l10n) {
    switch (reason) {
      case KycRejectionReason.idUnreadable:
        return l10n.kycRejectionReasonIdUnreadable;
      case KycRejectionReason.selfieMismatch:
        return l10n.kycRejectionReasonSelfieMismatch;
      case KycRejectionReason.expired:
        return l10n.kycRejectionReasonExpired;
      case KycRejectionReason.other:
      case null:
        // The D20-removed `vehicleDocumentMissing` reason now folds into "other".
        return l10n.kycRejectionReasonOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: KycStatusView.rejectionReasonKey,
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
    );
  }
}
