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

class OfferKycGateScreen extends StatelessWidget {
  const OfferKycGateScreen({super.key, this.cubit, this.gateway})
      : assert(cubit == null || gateway == null,
            'Provide either a cubit or a gateway, not both.');

  final OfferKycGateCubit? cubit;

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
                onTap: () => context.goNamed('kyc-status'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'gate_register_link',
              button: true,
              container: true,
              child: TextButton(
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
                onPressed: () => _popToDeliveryTab(context),
                child: Text(l10n.gateBackCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _popToDeliveryTab(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

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
          KycStatus.resubmitRequested => (
              l10n.kycStatusResubmitTitle,
              l10n.kycStatusResubmitBody,
              context.jeebRoles.warning,
            ),
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
