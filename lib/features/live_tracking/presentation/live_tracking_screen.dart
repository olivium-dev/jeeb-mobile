import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/live_tracking_cubit.dart';
import '../application/live_tracking_state.dart';
import '../domain/delivery_tracking_info.dart';
import 'widgets/delivery_tracking_panel.dart';
import 'widgets/tracking_map_surface.dart';

/// Order-tracking screen (Figma 56560:1772 — PROVISIONAL/draft frame).
///
/// Full-bleed map filling the space under the navbar, with a bottom status
/// panel (3-stage stepper + distance + ETA). Live position, polyline and the
/// distance/ETA values arrive from the gateway tracking feed; the map raster
/// itself is injected in production (see [TrackingMapSurface]).
class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.trackingTitle,
        showBackButton: true,
        centerTitle: true,
      ),
      body: BlocBuilder<LiveTrackingCubit, LiveTrackingState>(
        builder: (context, state) => _TrackingStateView(state: state),
      ),
    );
  }
}

class _TrackingStateView extends StatelessWidget {
  const _TrackingStateView({required this.state});

  final LiveTrackingState state;

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
        return _TrackingBody(info: state.trackingInfo!);
    }
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.info});

  final DeliveryTrackingInfo info;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Expanded(child: TrackingMapSurface()),
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
