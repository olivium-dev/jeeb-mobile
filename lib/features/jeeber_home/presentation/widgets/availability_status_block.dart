import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class AvailabilityStatusBlock extends StatelessWidget {
  const AvailabilityStatusBlock({super.key, required this.view});

  static const Key rootKey = Key('availability-status-block-root');
  static const Key activeDeliveriesKey =
      Key('availability-status-block-active-deliveries');

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: rootKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusHeadline(view: view),
        if (view.status.isOnline) ...[
          const SizedBox(height: Spacing.twoXSmall),
          _ActiveDeliveriesLine(count: view.status.activeDeliveryCount),
          const SizedBox(height: Spacing.twoXSmall),
          const _IdleHintLine(),
        ],
      ],
    );
  }
}

class _StatusHeadline extends StatelessWidget {
  const _StatusHeadline({required this.view});

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _headline(context),
      textAlign: TextAlign.start,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _headline(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (view.isToggleInFlight) return l10n.availabilityTransitioning;
    return switch (view.status.state) {
      AvailabilityState.online => l10n.availabilityStatusOnline,
      AvailabilityState.offline => l10n.availabilityStatusOffline,
      AvailabilityState.autoOffline => l10n.availabilityStatusAutoOffline,
    };
  }
}

class _ActiveDeliveriesLine extends StatelessWidget {
  const _ActiveDeliveriesLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.availabilityActiveDeliveries(count),
      key: AvailabilityStatusBlock.activeDeliveriesKey,
      textAlign: TextAlign.start,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _IdleHintLine extends StatelessWidget {
  const _IdleHintLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context).availabilityAutoOfflineHint,
      textAlign: TextAlign.start,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

/// Reference phone width, matching the rest of the preview folder.
const double _availabilityStatusBlockPhoneWidth = 390;

const double availabilityStatusBlockSlotWidth = 290;

/// Breathing room so the canvas shows the block's leading edge rather than the
/// viewport's. Directional-neutral, so it does not mask an RTL defect.
const EdgeInsets _availabilityStatusBlockHostPadding =
    EdgeInsets.all(Spacing.medium);

const Size _availabilityStatusBlockHeadlineBox =
    Size(_availabilityStatusBlockPhoneWidth, 150);

const Size _availabilityStatusBlockFullStackBox =
    Size(_availabilityStatusBlockPhoneWidth, 400);

AvailabilityViewState _availabilityStatusBlockView(
  AvailabilityState state, {
  int activeDeliveryCount = 0,
  bool isToggleInFlight = false,
}) {
  return AvailabilityViewState(
    loadPhase: AvailabilityLoadPhase.ready,
    status: AvailabilityStatus(
      state: state,
      activeDeliveryCount: activeDeliveryCount,
    ),
    isToggleInFlight: isToggleInFlight,
  );
}

Widget _availabilityStatusBlockHosted(AvailabilityViewState view) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: Padding(
      padding: _availabilityStatusBlockHostPadding,
      child: SizedBox(
        width: availabilityStatusBlockSlotWidth,
        child: AvailabilityStatusBlock(view: view),
      ),
    ),
  );
}

@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · headline only',
  size: _availabilityStatusBlockHeadlineBox,
)
Widget availabilityStatusBlockOffline() => _availabilityStatusBlockHosted(
      _availabilityStatusBlockView(AvailabilityState.offline),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'Auto-offline · 2 deliveries dropped',
  size: _availabilityStatusBlockHeadlineBox,
)
Widget availabilityStatusBlockAutoOfflineHoldingWork() =>
    _availabilityStatusBlockHosted(
      _availabilityStatusBlockView(
        AvailabilityState.autoOffline,
        activeDeliveryCount: 2,
      ),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · empty queue',
  size: _availabilityStatusBlockFullStackBox,
)
Widget availabilityStatusBlockOnlineEmpty() => _availabilityStatusBlockHosted(
      _availabilityStatusBlockView(AvailabilityState.online),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · 2 deliveries',
  size: _availabilityStatusBlockFullStackBox,
)
Widget availabilityStatusBlockOnlineTwo() => _availabilityStatusBlockHosted(
      _availabilityStatusBlockView(
        AvailabilityState.online,
        activeDeliveryCount: 2,
      ),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'Going online · in flight',
  size: _availabilityStatusBlockHeadlineBox,
)
Widget availabilityStatusBlockGoingOnline() => _availabilityStatusBlockHosted(
      _availabilityStatusBlockView(
        AvailabilityState.offline,
        isToggleInFlight: true,
      ),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'Going offline · in flight, 3 deliveries',
  size: _availabilityStatusBlockFullStackBox,
)
Widget availabilityStatusBlockGoingOffline() => _availabilityStatusBlockHosted(
      _availabilityStatusBlockView(
        AvailabilityState.online,
        activeDeliveryCount: 3,
        isToggleInFlight: true,
      ),
    );
