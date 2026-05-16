import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/kyc_wizard_cubit.dart';
import '../application/kyc_wizard_state.dart';
import '../domain/kyc_submission.dart';

/// Terminal-state view for the wizard: pending, approved, or rejected.
///
/// Rejected renders the structured [KycRejectionReason] copy plus a "resubmit"
/// CTA that resets the wizard back to step 1. Approved/pending render the
/// matching headline + a back-to-profile CTA.
class KycStatusView extends StatelessWidget {
  const KycStatusView({super.key, this.onClose});

  static const Key pendingTitleKey = Key('kyc-status-pending-title');
  static const Key approvedTitleKey = Key('kyc-status-approved-title');
  static const Key rejectedTitleKey = Key('kyc-status-rejected-title');
  static const Key resubmitCtaKey = Key('kyc-status-resubmit');
  static const Key backCtaKey = Key('kyc-status-back');
  static const Key rejectionReasonKey = Key('kyc-status-rejection-reason');

  /// Optional close callback wired by the host (router) — defaults to a
  /// `Navigator.maybePop` so the view works standalone in tests.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<KycWizardCubit, KycWizardState>(
      builder: (context, state) {
        final cubit = context.read<KycWizardCubit>();
        if (state.isLoadingStatus) {
          return const Center(child: CircularProgressIndicator());
        }
        switch (state.submission.status) {
          case KycStatus.notSubmitted:
          case KycStatus.pending:
            return _StatusBody(
              titleKey: pendingTitleKey,
              icon: Icons.hourglass_top_rounded,
              title: l10n.kycStatusPendingTitle,
              body: l10n.kycStatusPendingBody,
              primaryCtaKey: backCtaKey,
              primaryCtaLabel: l10n.kycStatusBackToProfileCta,
              primaryCtaOnTap: () => _close(context),
            );
          case KycStatus.approved:
            return _StatusBody(
              titleKey: approvedTitleKey,
              icon: Icons.verified_rounded,
              title: l10n.kycStatusApprovedTitle,
              body: l10n.kycStatusApprovedBody,
              primaryCtaKey: backCtaKey,
              primaryCtaLabel: l10n.kycStatusBackToProfileCta,
              primaryCtaOnTap: () => _close(context),
            );
          case KycStatus.rejected:
            return _StatusBody(
              titleKey: rejectedTitleKey,
              icon: Icons.error_outline_rounded,
              title: l10n.kycStatusRejectedTitle,
              body: l10n.kycStatusRejectedBody,
              extra: _RejectionReasonNotice(
                reason: state.submission.rejectionReason,
              ),
              primaryCtaKey: resubmitCtaKey,
              primaryCtaLabel: l10n.kycStatusResubmitCta,
              primaryCtaOnTap: cubit.resubmit,
            );
        }
      },
    );
  }

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
      return;
    }
    Navigator.of(context).maybePop();
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    required this.titleKey,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryCtaKey,
    required this.primaryCtaLabel,
    required this.primaryCtaOnTap,
    this.extra,
  });

  final Key titleKey;
  final IconData icon;
  final String title;
  final String body;
  final Key primaryCtaKey;
  final String primaryCtaLabel;
  final VoidCallback primaryCtaOnTap;
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
          Icon(icon, size: 64, color: theme.colorScheme.primary),
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
          OmdsPrimaryButton(
            key: primaryCtaKey,
            text: primaryCtaLabel,
            onTap: primaryCtaOnTap,
          ),
        ],
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
      case KycRejectionReason.vehicleDocumentMissing:
        return l10n.kycRejectionReasonVehicleDocumentMissing;
      case KycRejectionReason.expired:
        return l10n.kycRejectionReasonExpired;
      case KycRejectionReason.other:
      case null:
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
        borderRadius: BorderRadius.circular(Spacing.small),
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
