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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/delivery_status_screen_fixtures.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryStatusScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _deliveryStatusScreenCompactBox = Size(320, 568);

final class DeliveryStatusScreenCaptions {
  DeliveryStatusScreenCaptions._();

  /// No snapshot has landed yet — the first frame of every delivery.
  static const String connecting = 'preview · cold start · no snapshot yet';

  /// Pre-pickup: the only state with both CTAs.
  static const String matched = 'preview · matched · cancel + contact';

  /// Matched, but the snapshot carries no courier.
  static const String awaitingJeeber = 'preview · matched · no courier yet';

  /// In transit: ETA appears, cancel is withdrawn.
  static const String inTransit = 'preview · in transit · ETA, no cancel';

  /// Delivered — and still looking for a Jeeber.
  static const String delivered = 'preview · delivered · terminal';

  /// Cancelled — banner against a zeroed stepper.
  static const String cancelled = 'preview · cancelled · terminal';

  /// The service was already down when the screen opened.
  static const String streamLostOnOpen = 'preview · stream lost on open';

  /// A live delivery, then a transport failure.
  static const String streamDropped = 'preview · stream dropped mid-delivery';

  /// Cancel tapped, the write still in the air.
  static const String cancelInFlight = 'preview · cancel in flight · tap Cancel';

  /// Every string at its longest plausible length.
  static const String longestContent = 'preview · longest content';

  /// The in-transit reading on the narrowest supported device.
  static const String compact = 'preview · in transit · 320x568 viewport';
}

Widget _deliveryStatusScreenHosted(
  DeliveryStatusScreenDesignedState state,
  String caption,
) {
  return TickerMode(
    enabled: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeliveryStatusScreenCaption(caption: caption),
        Expanded(
          child: DeliveryStatusScreen(
            deliveryId: state.deliveryId,
            gateway: state.gateway,
          ),
        ),
      ],
    ),
  );
}

/// The dev-chrome line painted above each device frame.
class _DeliveryStatusScreenCaption extends StatelessWidget {
  const _DeliveryStatusScreenCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // Dev chrome: LTR and unscaled, so the AR card still reads it as one
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

@JeebPreview(
  group: 'delivery_status',
  name: 'Cold start · no snapshot yet',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenConnecting() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.connecting,
      DeliveryStatusScreenCaptions.connecting,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Matched · cancel + contact',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenMatched() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.matched,
      DeliveryStatusScreenCaptions.matched,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Matched · no courier yet',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenAwaitingJeeber() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.awaitingJeeber,
      DeliveryStatusScreenCaptions.awaitingJeeber,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'In transit · ETA, no cancel',
  size: _deliveryStatusScreenPhoneBox,
  matrix: true,
)
Widget deliveryStatusScreenInTransit() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.inTransit,
      DeliveryStatusScreenCaptions.inTransit,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Delivered · terminal',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenDelivered() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.delivered,
      DeliveryStatusScreenCaptions.delivered,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Cancelled · terminal',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenCancelled() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.cancelled,
      DeliveryStatusScreenCaptions.cancelled,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Stream lost on open',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenStreamLostOnOpen() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.streamLostOnOpen,
      DeliveryStatusScreenCaptions.streamLostOnOpen,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Stream dropped mid-delivery',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenStreamDropped() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.streamDroppedMidDelivery,
      DeliveryStatusScreenCaptions.streamDropped,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Cancel in flight · tap Cancel',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenCancelInFlight() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.cancelInFlight,
      DeliveryStatusScreenCaptions.cancelInFlight,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'Longest content',
  size: _deliveryStatusScreenPhoneBox,
  matrix: true,
)
Widget deliveryStatusScreenLongestContent() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.longestContent,
      DeliveryStatusScreenCaptions.longestContent,
    );

@JeebPreview(
  group: 'delivery_status',
  name: 'In transit · compact 320x568',
  size: _deliveryStatusScreenCompactBox,
)
Widget deliveryStatusScreenCompact() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.compactViewport,
      DeliveryStatusScreenCaptions.compact,
    );
