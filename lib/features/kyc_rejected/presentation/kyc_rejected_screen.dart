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

/// Wiring (30_BACKLOG JM-043 · 42_GUARDRAILS_MOCK): the structured rejection
class KycRejectedScreen extends StatelessWidget {
  const KycRejectedScreen({super.key, this.gateway});

  final KycGateway? gateway;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<KycRejectedCubit>(
      create: (_) => KycRejectedCubit(gateway ?? _resolveGateway())..load(),
      child: const _KycRejectedView(),
    );
  }

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
        appBar: OMDSAppBar(
          title: l10n.kycRejectedTitle,
          showBackButton: true,
          onBackPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed('customer-profile'),
        ),
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
            const _RejectionReasonSection(),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'kyc_rejected_appeal_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.kycRejectedAppealCta,
                onTap: () => context.goNamed('support-ticket'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'kyc_rejected_back_cta',
              button: true,
              container: true,
              child: TextButton(
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
          padding: const EdgeInsets.only(top: Spacing.large),
          child: _RejectionReasonNotice(reason: reason),
        );
      },
    );
  }
}

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
