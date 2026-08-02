import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/delivery_status_cubit.dart';
import '../application/delivery_status_state.dart';
import '../domain/delivery_snapshot.dart';
import '../domain/delivery_status_gateway.dart';
import 'widgets/delivery_details_card.dart';
import 'widgets/delivery_eta_badge.dart';
import 'widgets/delivery_jeeber_card.dart';
import 'widgets/delivery_lifecycle_banner.dart';
import 'widgets/delivery_stage_indicator.dart';

typedef ContactJeeberHandler = void Function(String phoneE164);

class DeliveryStatusScreen extends StatelessWidget {
  const DeliveryStatusScreen({
    super.key,
    required this.deliveryId,
    this.cubit,
    this.gateway,
    this.onContactJeeber,
  }) : assert(
          cubit == null || gateway == null,
          'Provide either a cubit or a gateway, not both.',
        );

  final String deliveryId;

  final DeliveryStatusCubit? cubit;

  final DeliveryStatusGateway? gateway;

  final ContactJeeberHandler? onContactJeeber;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<DeliveryStatusCubit>.value(
        value: provided,
        child: _Scaffold(
          deliveryId: deliveryId,
          onContactJeeber: onContactJeeber,
        ),
      );
    }
    return BlocProvider<DeliveryStatusCubit>(
      create: (_) => DeliveryStatusCubit(
        deliveryId: deliveryId,
        gateway: gateway ??
            InMemoryDeliveryStatusGateway(
              seed: demoDeliverySnapshot(id: deliveryId),
            ),
      ),
      child: _Scaffold(
        deliveryId: deliveryId,
        onContactJeeber: onContactJeeber,
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.deliveryId, this.onContactJeeber});

  final String deliveryId;
  final ContactJeeberHandler? onContactJeeber;

  static const Key rootKey = Key('delivery-status-screen');
  static const Key bodyScrollKey = Key('delivery-status-scroll');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'delivery_status_root',
      container: true,
      child: Scaffold(
        key: rootKey,
        appBar: OMDSAppBar(
          title: l10n.deliveryStatusTitle,
          showBackButton: true,
          centerTitle: false,
        ),
        body: SafeArea(
          child: BlocConsumer<DeliveryStatusCubit, DeliveryStatusState>(
            listenWhen: (prev, curr) =>
                prev.error != curr.error && curr.error != null,
            listener: _surfaceError,
            builder: (context, state) {
              switch (state.mode) {
                case DeliveryStatusViewMode.loading:
                  return _LoadingView(l10n: l10n);
                case DeliveryStatusViewMode.error:
                  return _ErrorView(
                    l10n: l10n,
                    onRetry: () =>
                        context.read<DeliveryStatusCubit>().retry(),
                  );
                case DeliveryStatusViewMode.ready:
                  final snapshot = state.snapshot;
                  if (snapshot == null) {
                    return _LoadingView(l10n: l10n);
                  }
                  return _ReadyView(
                    snapshot: snapshot,
                    isCancelling: state.isCancelling,
                    deliveryId: deliveryId,
                    onContactJeeber: onContactJeeber,
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  void _surfaceError(BuildContext context, DeliveryStatusState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryStatusCubit>();
    final message = _messageFor(l10n, state.error!);
    if (message != null) {
      showOmdsSnackbar(context, message: message);
    }
    cubit.acknowledgeError();
  }

  String? _messageFor(AppLocalizations l10n, DeliveryStatusError error) {
    switch (error) {
      case DeliveryStatusError.cancelTooLate:
        return l10n.deliveryErrorCancelTooLate;
      case DeliveryStatusError.cancelNetwork:
        return l10n.deliveryErrorCancelNetwork;
      case DeliveryStatusError.contactUnavailable:
        return l10n.deliveryErrorContactUnavailable;
      case DeliveryStatusError.streamLost:
        return l10n.deliveryErrorStreamLost;
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.l10n});

  final AppLocalizations l10n;

  static const Key rootKey = Key('delivery-status-loading');

  @override
  Widget build(BuildContext context) {
    return Center(
      key: rootKey,
      child: OmdsLoadingState(message: l10n.deliveryStatusLoading),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.l10n, required this.onRetry});

  final AppLocalizations l10n;
  final VoidCallback onRetry;

  static const Key rootKey = Key('delivery-status-error');

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rootKey,
      padding: const EdgeInsets.all(Spacing.large),
      child: Center(
        child: OmdsErrorState(
          title: l10n.deliveryStatusErrorTitle,
          message: l10n.deliveryStatusErrorBody,
          icon: Icons.cloud_off_outlined,
          retryLabel: l10n.deliveryStatusRetry,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.snapshot,
    required this.isCancelling,
    required this.deliveryId,
    this.onContactJeeber,
  });

  final DeliverySnapshot snapshot;
  final bool isCancelling;
  final String deliveryId;
  final ContactJeeberHandler? onContactJeeber;

  static const Key contactButtonKey = Key('delivery-status-contact-cta');
  static const Key cancelButtonKey = Key('delivery-status-cancel-cta');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: _Scaffold.bodyScrollKey,
      padding: const EdgeInsets.fromLTRB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeliveryLifecycleBanner(lifecycle: snapshot.lifecycle),
          if (snapshot.lifecycle != DeliveryLifecycle.active)
            const SizedBox(height: Spacing.medium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.deliveryStatusIdSubtitle(deliveryId),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (snapshot.isEtaVisible)
                DeliveryEtaBadge(minutes: snapshot.etaMinutes!),
            ],
          ),
          const SizedBox(height: Spacing.medium),
          DeliveryStageIndicator(snapshot: snapshot),
          const SizedBox(height: Spacing.large),
          DeliveryDetailsCard(snapshot: snapshot),
          const SizedBox(height: Spacing.medium),
          DeliveryJeeberCard(jeeber: snapshot.jeeber),
          const SizedBox(height: Spacing.large),
          _ActionBar(
            snapshot: snapshot,
            isCancelling: isCancelling,
            onContactJeeber: onContactJeeber,
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.snapshot,
    required this.isCancelling,
    this.onContactJeeber,
  });

  final DeliverySnapshot snapshot;
  final bool isCancelling;
  final ContactJeeberHandler? onContactJeeber;

  Future<void> _onCancelPressed(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryStatusCubit>();
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.deliveryCancelDialogTitle,
      content: l10n.deliveryCancelDialogBody,
      confirmText: l10n.deliveryCancelDialogConfirm,
      cancelText: l10n.deliveryCancelDialogDismiss,
      isDestructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!confirmed) return;
    await cubit.cancel();
  }

  void _onContactPressed(BuildContext context) {
    final cubit = context.read<DeliveryStatusCubit>();
    final number = cubit.requestContactNumber();
    if (number == null) return;
    HapticFeedback.selectionClick();
    onContactJeeber?.call(number);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!snapshot.isInFlight) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.canContactJeeber)
          Semantics(
            identifier: 'delivery_status_contact_cta',
            container: true,
            button: true,
            child: OmdsPrimaryButton(
              key: _ReadyView.contactButtonKey,
              text: l10n.deliveryActionContact,
              icon: const Icon(Icons.phone, size: 18),
              onTap: () => _onContactPressed(context),
            ),
          ),
        if (snapshot.canContactJeeber && snapshot.canCancel)
          const SizedBox(height: Spacing.small),
        if (snapshot.canCancel)
          Semantics(
            identifier: 'delivery_status_cancel_cta',
            container: true,
            button: true,
            child: OmdsPrimaryButton(
              key: _ReadyView.cancelButtonKey,
              text: isCancelling
                  ? l10n.deliveryActionCancellingLabel
                  : l10n.deliveryActionCancel,
              variant: OmdsButtonVariant.outlined,
              isEnabled: !isCancelling,
              onTap: () => _onCancelPressed(context),
            ),
          ),
      ],
    );
  }
}
