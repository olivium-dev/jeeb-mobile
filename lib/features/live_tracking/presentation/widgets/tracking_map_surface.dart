import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_tracking_info.dart';
import 'tracking_google_map.dart';

/// Full-bleed map surface for the order-tracking screen (Figma 56560:1772).
///
/// T-MOB-017: when [info] is supplied and [useLiveMap] is true this renders a
/// live [TrackingGoogleMap] (route polyline + Jeeber heading marker driven by
/// the [LiveTrackingCubit] state). Otherwise it falls back to the deterministic
/// themed placeholder so the dev seam and widget tests can validate the navbar
/// + bottom status-panel chrome without a Maps API key or a platform view
/// (the Figma map raster is a mock and is never bundled — UI-GUARDRAILS §0).
///
/// The Semantics identifier + [rootKey] are kept on the wrapper in both modes
/// so uiautomator/Maestro and widget tests target the surface identically.
class TrackingMapSurface extends StatelessWidget {
  const TrackingMapSurface({
    super.key,
    this.info,
    this.useLiveMap = false,
  });

  /// Latest tracking snapshot from the cubit. Null before the first fetch.
  final DeliveryTrackingInfo? info;

  /// When false the deterministic placeholder is used even if [info] is present
  /// (a real GoogleMap can't render in `flutter test`).
  ///
  /// DEFAULTS TO FALSE (sprint-009 P0): with no `com.google.android.geo.API_KEY`
  /// in the manifest, mounting a live GoogleMap is a native FATAL (SIGKILL), so
  /// no caller may mount a keyless map by accident. sprint-013 flips this back
  /// with the provisioned key. Mirrors [LiveTrackingScreen.useLiveMap].
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
        child: _showsLiveMap
            ? TrackingGoogleMap(info: info!)
            : const _MapPlaceholderMark(),
      ),
    );
  }
}

/// Themed container that anchors [rootKey] and frames the active surface.
class _MapBody extends StatelessWidget {
  const _MapBody({required this.rootKey, required this.child});

  final Key rootKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: rootKey,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: child,
    );
  }
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
