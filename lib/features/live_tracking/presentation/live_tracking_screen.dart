import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/live_tracking_cubit.dart';
import '../application/live_tracking_state.dart';
import '../domain/delivery_tracking_info.dart';
import 'widgets/delivery_tracking_panel.dart';
import 'widgets/tracking_map_surface.dart';
import 'widgets/otp_at_door_card.dart';

/// T-MOB-017: Order-tracking screen — full-bleed map with status panel.
///
/// AC3: shows "Jeeber is on the way" snack on in_transit transition.
/// AC4: slides in the OTP card and half-collapses the map on at_door.
/// AC5: reconnect handled by the 5s poll timer in [LiveTrackingCubit].
class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({
    super.key,
    required this.deliveryId,
    this.useLiveMap = true,
  });

  final String deliveryId;

  /// T-MOB-017: when false the deterministic map placeholder is rendered
  /// instead of a live GoogleMap. The router sets this false for the dev-seam
  /// `/tracking` capture (no Maps key / unstable emulator) and tests rely on
  /// the default-false widget-test path; production renders the live map.
  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.trackingTitle,
        showBackButton: true,
        centerTitle: true,
      ),
      body: BlocConsumer<LiveTrackingCubit, LiveTrackingState>(
        listenWhen: _hasNewEvent,
        listener: _onEvent,
        builder: (context, state) => _TrackingStateView(
          state: state,
          deliveryId: deliveryId,
          useLiveMap: useLiveMap,
        ),
      ),
    );
  }

  bool _hasNewEvent(LiveTrackingState prev, LiveTrackingState next) =>
      next.pendingEvent != LiveTrackingEvent.none;

  void _onEvent(BuildContext context, LiveTrackingState state) {
    final l10n = AppLocalizations.of(context);
    if (state.pendingEvent == LiveTrackingEvent.jeeberOnTheWay) {
      showOmdsSnackbar(context, message: l10n.trackingJeeberOnTheWay);
    }
  }
}

class _TrackingStateView extends StatelessWidget {
  const _TrackingStateView({
    required this.state,
    required this.deliveryId,
    required this.useLiveMap,
  });

  final LiveTrackingState state;
  final String deliveryId;
  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    switch (state.mode) {
      case LiveTrackingViewMode.loading:
        return const Center(child: OmdsLoadingState());
      case LiveTrackingViewMode.error:
        return _TrackingErrorBody(
          message: state.errorMessage,
          onRetry: () => context.read<LiveTrackingCubit>().retry(),
        );
      case LiveTrackingViewMode.ready:
        return _TrackingBody(
          info: state.trackingInfo!,
          isAtDoor: state.isAtDoor,
          deliveryId: deliveryId,
          useLiveMap: useLiveMap,
        );
    }
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({
    required this.info,
    required this.isAtDoor,
    required this.deliveryId,
    required this.useLiveMap,
  });

  final DeliveryTrackingInfo info;
  final bool isAtDoor;
  final String deliveryId;
  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // AC4: half-collapse the map when at_door
          Expanded(
            flex: isAtDoor ? 1 : 2,
            child: TrackingMapSurface(info: info, useLiveMap: useLiveMap),
          ),
          if (isAtDoor)
            Expanded(
              flex: 1,
              child: OtpAtDoorCard(deliveryId: deliveryId),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.medium,
                vertical: Spacing.large,
              ),
              child: DeliveryTrackingPanel(info: info),
            ),
        ],
      ),
    );
  }
}

class _TrackingErrorBody extends StatelessWidget {
  const _TrackingErrorBody({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: OmdsErrorState(
        message: message ?? l10n.trackingGpsLostBody,
        icon: Icons.location_off_outlined,
        onRetry: onRetry,
        retryLabel: l10n.trackingGpsLostRetry,
      ),
    );
  }
}
