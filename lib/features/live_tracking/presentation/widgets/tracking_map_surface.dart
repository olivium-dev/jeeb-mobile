import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';
import 'courier_position_notice.dart';
import 'tracking_google_map.dart';

/// Map surface for the order-tracking screen.
///
/// T-MOB-017: when [info] is supplied and [useLiveMap] is true this renders a
/// live [TrackingGoogleMap] (route polyline + Jeeber marker driven by the
/// [LiveTrackingCubit] state). Otherwise it falls back to the deterministic
/// themed placeholder so the dev seam and widget tests can validate the chrome
/// without a Maps API key or a platform view (the Figma map raster is a mock and
/// is never bundled — UI-GUARDRAILS §0).
///
/// redesign-2026-08 §C task 6: the surface is a FIXED 250px `r20` card inset in
/// the screen's gutters, not an `Expanded` that eats the viewport — the board's
/// lower third is deliberately white. The floating ETA pill lives here because
/// it belongs to the map, not to the fact strip below it.
///
/// The Semantics identifier + [rootKey] are kept on the wrapper in both modes
/// so uiautomator/Maestro and widget tests target the surface identically, and
/// they sit OUTSIDE the rounded clip so neither can be clipped away.
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
  /// no caller may mount a keyless map by accident. Mirrors
  /// [LiveTrackingScreen.useLiveMap], which now defaults to true with the key
  /// provisioned.
  final bool useLiveMap;

  static const Key rootKey = Key('tracking_map');

  /// Board height (`12-live-tracking.html` tpl 749). A named const rather than
  /// a bare literal: `tool/check_design_tokens.sh` rejects `SizedBox(height: N)`
  /// and there is no OMDS token at 250.
  static const double mapHeight = 250;

  bool get _showsLiveMap => useLiveMap && info != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = info;
    return Semantics(
      identifier: 'tracking_map',
      image: true,
      label: l10n.trackingMapSemanticLabel,
      child: SizedBox(
        height: mapHeight,
        child: ClipRRect(
          borderRadius: OmdsBorderRadius.large,
          child: _MapBody(
            rootKey: rootKey,
            // OUTSIDE the `_showsLiveMap` branch on purpose. The notice explains
            // a marker that is NOT being drawn, so gating it on the live map
            // would put it behind the very condition (a provisioned Maps key, a
            // platform view) that is absent in every widget test and in the dev
            // seam — the affordance would exist only where nobody could check
            // it.
            overlay: snapshot == null ? null : CourierPositionNotice(info: snapshot),
            // The pill renders whenever there is a snapshot at all, known ETA or
            // not: Maestro `16-order-tracking.yaml:80` asserts
            // `tracking_eta_label` is visible and the fixture's ETA cannot be
            // guaranteed, so an unknown ETA becomes the pending copy rather than
            // a missing node.
            etaPill: snapshot == null
                ? null
                : _TrackingEtaPill(etaMinutes: snapshot.etaMinutes),
            child: _showsLiveMap
                ? TrackingGoogleMap(info: snapshot!)
                : const _MapPlaceholderMark(),
          ),
        ),
      ),
    );
  }
}

/// Themed container that anchors [rootKey] and frames the active surface, with
/// the ETA pill pinned to the top-START corner and the freshness notice pinned
/// to the bottom.
class _MapBody extends StatelessWidget {
  const _MapBody({
    required this.rootKey,
    required this.child,
    this.overlay,
    this.etaPill,
  });

  final Key rootKey;
  final Widget child;

  /// Rendered over [child], bottom-anchored. Null when there is nothing to
  /// overlay. [CourierPositionNotice] collapses itself to a zero-size box when
  /// the position is fine, so a non-null overlay is not the same as a visible
  /// one — the widget owns that decision, not this layout.
  final Widget? overlay;

  /// Rendered over [child], top-START-anchored (`tpl 764`).
  final Widget? etaPill;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: rootKey,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      // Always a Stack now — the pill is part of the map, not a sibling below
      // it, so the layout no longer changes shape between states.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: Center(child: child)),
          if (etaPill != null)
            PositionedDirectional(
              start: Spacing.medium,
              top: Spacing.medium,
              child: etaPill!,
            ),
          if (overlay != null)
            PositionedDirectional(
              start: Spacing.medium,
              end: Spacing.medium,
              bottom: Spacing.medium,
              child: Align(child: overlay!),
            ),
        ],
      ),
    );
  }
}

/// The floating "Arriving in 20 min" pill (`tpl 764`): white, pill radius,
/// `JeebShadows.floatPill`, navy w700 copy.
///
/// `liveRegion: true` is the point of the node — the ETA is the one number on
/// this screen that changes under the customer without them acting, so a screen
/// reader must announce it when it does.
class _TrackingEtaPill extends StatelessWidget {
  const _TrackingEtaPill({required this.etaMinutes});

  /// Live ETA in whole minutes; null renders the pending copy.
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final minutes = etaMinutes;
    return Semantics(
      identifier: 'tracking_eta_label',
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.small,
          vertical: Spacing.xSmall,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: OmdsBorderRadius.pill,
          boxShadow: JeebShadows.floatPill,
        ),
        child: Text(
          minutes == null ? l10n.summaryEtaPending : l10n.arrivingIn(minutes),
          style: context.jeebText.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
      ),
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
