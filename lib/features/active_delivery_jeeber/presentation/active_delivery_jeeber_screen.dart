import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/active_delivery_cubit.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';
import 'widgets/delivery_status_stepper.dart';

/// Jeeber active-delivery screen (T-MOB-031).
///
/// Route: /jeeber/deliveries/:id/active
///
/// Shows the drop-off address, status stepper, Open in Maps deep-link,
/// and Open chat shortcut. Each status-advance calls POST
/// /v1/deliveries/{id}/transition (AC2). Last step transitions to OTP
/// handover (AC-last-step).
class ActiveDeliveryJeeberScreen extends StatelessWidget {
  const ActiveDeliveryJeeberScreen({
    super.key,
    required this.deliveryId,
    required this.onOpenChat,
    required this.onOpenOtp,
    this.repository,
    this.cubit,
    this.mapsUrlBuilder,
  });

  final String deliveryId;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenOtp;

  /// Injectable repo — production uses DI; tests supply a fake.
  final ActiveDeliveryRepository? repository;

  /// Pre-built cubit — optional test seam.
  final ActiveDeliveryCubit? cubit;

  /// Override for url_launcher in tests.
  final Future<void> Function(String url)? mapsUrlBuilder;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider.value(
        value: provided,
        child: _Body(
          deliveryId: deliveryId,
          onOpenChat: onOpenChat,
          onOpenOtp: onOpenOtp,
          mapsUrlBuilder: mapsUrlBuilder,
        ),
      );
    }
    final repo = repository;
    if (repo == null) {
      return const _Unavailable();
    }
    return BlocProvider<ActiveDeliveryCubit>(
      create: (_) =>
          ActiveDeliveryCubit(repository: repo, deliveryId: deliveryId)
            ..loadDelivery(),
      child: _Body(
        deliveryId: deliveryId,
        onOpenChat: onOpenChat,
        onOpenOtp: onOpenOtp,
        mapsUrlBuilder: mapsUrlBuilder,
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.activeDeliveryTitle),
      body: Center(child: Text(l10n.activeDeliveryUnavailable)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.deliveryId,
    required this.onOpenChat,
    required this.onOpenOtp,
    this.mapsUrlBuilder,
  });

  final String deliveryId;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenOtp;
  final Future<void> Function(String url)? mapsUrlBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActiveDeliveryCubit, ActiveDeliveryState>(
      listener: _onStateChange,
      builder: _buildScaffold,
    );
  }

  void _onStateChange(BuildContext context, ActiveDeliveryState state) {
    if (state.transitionError != null) {
      // EXEMPT: OMDS exports no standalone toast/snackbar widget; ScaffoldMessenger
      // + showOmdsSnackbar is the approved fleet pattern for transient feedback.
      showOmdsSnackbar(context, message: state.transitionError!);
      context.read<ActiveDeliveryCubit>().acknowledgeTransitionError();
    }
    if (state.delivery?.status == JeeberDeliveryStatus.done) {
      onOpenOtp();
    }
  }

  Widget _buildScaffold(BuildContext context, ActiveDeliveryState state) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.activeDeliveryTitle,
        showBackButton: true,
      ),
      body: _buildBody(context, state, l10n),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ActiveDeliveryState state,
    AppLocalizations l10n,
  ) {
    switch (state.mode) {
      case ActiveDeliveryMode.loading:
        return const Center(child: OmdsLoadingState());
      case ActiveDeliveryMode.error:
        return OmdsErrorState(
          message: state.errorMessage ?? l10n.activeDeliveryLoadError,
          onRetry: () => context.read<ActiveDeliveryCubit>().loadDelivery(),
        );
      case ActiveDeliveryMode.ready:
      case ActiveDeliveryMode.transitioning:
        final delivery = state.delivery;
        if (delivery == null) return const SizedBox.shrink();
        return _ReadyContent(
          delivery: delivery,
          isTransitioning: state.isTransitioning,
          onAdvance: () =>
              context.read<ActiveDeliveryCubit>().advanceStatus(),
          onOpenChat: onOpenChat,
          onOpenMaps: () => _launchMaps(delivery),
          l10n: l10n,
        );
    }
  }

  Future<void> _launchMaps(JeeberDelivery delivery) async {
    final lat = delivery.dropOff.lat;
    final lng = delivery.dropOff.lng;
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final launch = mapsUrlBuilder;
    if (launch != null) {
      await launch(url);
    }
    // Production: url_launcher.launchUrl called from the router/page.
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.delivery,
    required this.isTransitioning,
    required this.onAdvance,
    required this.onOpenChat,
    required this.onOpenMaps,
    required this.l10n,
  });

  final JeeberDelivery delivery;
  final bool isTransitioning;
  final VoidCallback onAdvance;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMaps;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.medium),
      children: [
        _AddressCard(delivery: delivery, l10n: l10n),
        const SizedBox(height: Spacing.large),
        DeliveryStatusStepper(
          currentStatus: delivery.status,
          isTransitioning: isTransitioning,
          onAdvance: onAdvance,
        ),
        const SizedBox(height: Spacing.large),
        _ActionButtons(
          onOpenMaps: onOpenMaps,
          onOpenChat: onOpenChat,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.delivery, required this.l10n});

  final JeeberDelivery delivery;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activeDeliveryDropOffLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              delivery.dropOff.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (delivery.dropOff.detail != null) ...[
              const SizedBox(height: Spacing.xSmall),
              Text(
                delivery.dropOff.detail!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onOpenMaps,
    required this.onOpenChat,
    required this.l10n,
  });

  final VoidCallback onOpenMaps;
  final VoidCallback onOpenChat;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmdsPrimaryButton(
          text: l10n.activeDeliveryOpenMapsButton,
          icon: const Icon(Icons.map_outlined),
          onTap: onOpenMaps,
        ),
        const SizedBox(height: Spacing.small),
        OmdsPrimaryButton(
          text: l10n.activeDeliveryOpenChatButton,
          variant: OmdsButtonVariant.outlined,
          icon: const Icon(Icons.chat_bubble_outline),
          onTap: onOpenChat,
        ),
      ],
    );
  }
}
