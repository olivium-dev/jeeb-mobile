import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_tracking_info.dart';
import 'courier_position_notice.dart';
import 'tracking_google_map.dart';

class TrackingMapSurface extends StatelessWidget {
  const TrackingMapSurface({
    super.key,
    this.info,
    this.useLiveMap = false,
  });

  final DeliveryTrackingInfo? info;

  final bool useLiveMap;

  static const Key rootKey = Key('tracking_map');

  bool get _showsLiveMap => useLiveMap && info != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_map',
      image: true,
      label: l10n.trackingMapSemanticLabel,
      child: _MapBody(
        rootKey: rootKey,
        overlay: info == null ? null : CourierPositionNotice(info: info!),
        child: _showsLiveMap
            ? TrackingGoogleMap(info: info!)
            : const _MapPlaceholderMark(),
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.rootKey, required this.child, this.overlay});

  final Key rootKey;
  final Widget child;

  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: rootKey,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: overlay == null ? child : _stacked(child, overlay!),
    );
  }

  static Widget _stacked(Widget child, Widget overlay) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: Center(child: child)),
          PositionedDirectional(
            start: Spacing.medium,
            end: Spacing.medium,
            bottom: Spacing.medium,
            child: Align(child: overlay),
          ),
        ],
      );
}

class _MapPlaceholderMark extends StatelessWidget {
  const _MapPlaceholderMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor =
        scheme.onSurfaceVariant.withValues(alpha: UIConstants.opacityMedium);
    return Icon(
      Icons.navigation_outlined,
      size: Sizes.fiveXLarge,
      color: iconColor,
    );
  }
}
