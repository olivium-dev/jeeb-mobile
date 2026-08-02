// Shared, network-free fixtures for `CaptureLocationScreen`.
//
// DEV-ONLY. Nothing under `lib/devtool/` ships: the tree is excluded from
// preview coverage for the same reason it is compiled out of product builds.
// This file exists so the two dev surfaces that mock this screen — the widget
// previews at the bottom of
// `lib/features/location/presentation/capture_location_screen.dart` and any
// Screen Catalog entry added for it later — build their map from ONE source
// instead of two that drift.
//
// There was no catalog entry for `CaptureLocationScreen` when these were
// written (the catalog covers `LocationPickerScreen`, `ClientLocationScreen`
// and `SavedLocationsScreen` in `entries/batch_06_entries.dart`, not this one),
// so this is the fresh half of the "extract it once" rule rather than the
// extracted half. An entry that lands later should call these builders rather
// than grow a second fake map.
//
// ## Why the map has to be faked at all
//
// Production injects `GoogleMapCaptureView` through
// `CaptureLocationScreen.mapBuilder` — a `google_maps_flutter` platform view.
// A platform view cannot render headless (no engine surface), cannot render in
// the preview canvas, and on a device would need a Maps API key plus billed
// tile fetches to show a designer anything. So every surface here is a static
// stand-in: painted geometry, no tiles, no asset, no I/O. The Figma map raster
// is a mock and is deliberately never bundled (UI-GUARDRAILS §0), which is why
// nothing here loads an image either.
//
// The stand-in is deliberately abstract rather than map-like. Anyone looking at
// it should be able to tell in one glance that they are not looking at a map.

library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../features/location/presentation/widgets/gps_denied_state.dart';
import '../../../l10n/app_localizations.dart';

/// Map surfaces to hand `CaptureLocationScreen.mapBuilder`.
///
/// Each returns a [WidgetBuilder] because that is the screen's seam. The screen
/// layers its fixed centre pin over whatever comes back and puts its "Pin
/// Location" CTA underneath — which is exactly what makes
/// [permissionDenied] and [outsideServiceArea] worth looking at.
abstract final class CaptureLocationScreenPreviewFixtures {
  /// Beirut downtown — the coordinate `GoogleMapPickerLauncher` centres the
  /// real picker on when the caller supplies no initial point.
  static const double beirutLatitude = 33.8938;

  /// See [beirutLatitude].
  static const double beirutLongitude = 35.5018;

  /// The readout [liveMap] shows before the camera has been panned.
  ///
  /// Public because the render test pins it: it is the one string that tells a
  /// live-map state apart from every other state of this screen.
  static const String beirutReadout = '33.89380, 35.50180';

  /// A deterministic stand-in for `GoogleMapCaptureView`.
  ///
  /// Pannable, and it reports the camera centre the way the real view reports
  /// it to `MapCaptureController` on every camera-idle — which is what lets a
  /// preview show that the map stays live while the CTA is busy.
  ///
  /// [centreOnMe] mirrors the real view's rule: it only draws the "centre on my
  /// location" affordance when a GPS gateway was injected.
  static WidgetBuilder liveMap({bool centreOnMe = true}) =>
      (BuildContext context) =>
          CaptureLocationScreenFakeMap(centreOnMe: centreOnMe);

  /// Location permission denied: `GpsDeniedState`, the recovery surface written
  /// for this screen (T-MOB-012 AC4), pushed through the only seam the screen
  /// offers.
  ///
  /// The screen has no denied state of its own, so this is the *only* way a
  /// host can put it on this screen today — and the composition it produces is
  /// the point of the preview, not an artefact of the fixture.
  static WidgetBuilder permissionDenied({VoidCallback? onOpenSettings}) =>
      (BuildContext context) => _CaptureLocationScreenMessageSurface(
            child: GpsDeniedState(onOpenSettings: onOpenSettings),
          );

  /// The pinned point is outside the delivery footprint.
  ///
  /// The title is the shipped `captureLocationOutsideServiceArea` key (EN + AR)
  /// — copy that exists in both ARBs and that no screen in the app renders. The
  /// body is fixture copy, deliberately long: this is the longest-content state
  /// of the screen.
  static WidgetBuilder outsideServiceArea() =>
      (BuildContext context) => const _CaptureLocationScreenMessageSurface(
            child: _CaptureLocationScreenOutsideServiceArea(),
          );
}

/// Fixture copy for [CaptureLocationScreenPreviewFixtures.outsideServiceArea].
///
/// Not localized on purpose: there is no ARB key for it because there is no
/// screen state to key it to. Seeing English here in an Arabic rendering is
/// expected, and is itself a reminder that this state does not exist yet.
const String captureLocationScreenOutsideServiceAreaBody =
    'Jeeb does not deliver to the area under the pin yet. Pan the map back '
    'inside Beirut, Mount Lebanon or the North governorate to continue, or '
    'go back and choose one of your saved addresses instead.';

/// A pannable, tile-free stand-in for the live `GoogleMap` viewport.
///
/// Painted geometry that shifts with the drag, plus a readout of the coordinate
/// currently under the screen's centre pin. Nothing here fetches, decodes or
/// caches anything, so it is network-free by construction rather than by the
/// `CatalogNetworkGuard` the hosts install around it.
class CaptureLocationScreenFakeMap extends StatefulWidget {
  const CaptureLocationScreenFakeMap({super.key, this.centreOnMe = true});

  /// Draw the "centre on my location" affordance, as the real view does when a
  /// GPS gateway is injected.
  final bool centreOnMe;

  @override
  State<CaptureLocationScreenFakeMap> createState() =>
      _CaptureLocationScreenFakeMapState();
}

class _CaptureLocationScreenFakeMapState
    extends State<CaptureLocationScreenFakeMap> {
  /// Roughly the degrees a logical pixel covers at the picker's zoom 16. Only
  /// the determinism matters — the same drag always yields the same readout.
  static const double _degreesPerPixel = 0.00002;

  Offset _pan = Offset.zero;

  /// The coordinate under the screen's fixed centre pin, in the same
  /// five-decimal form the delivery-create flow logs.
  String get _readout {
    final double latitude =
        CaptureLocationScreenPreviewFixtures.beirutLatitude +
            _pan.dy * _degreesPerPixel;
    final double longitude =
        CaptureLocationScreenPreviewFixtures.beirutLongitude -
            _pan.dx * _degreesPerPixel;
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (DragUpdateDetails details) =>
          setState(() => _pan += details.delta),
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _CaptureLocationScreenGridPainter(
                  offset: _pan,
                  ink: scheme.outlineVariant,
                ),
              ),
            ),
            PositionedDirectional(
              top: Spacing.medium,
              start: Spacing.medium,
              child: _CaptureLocationScreenReadout(coordinates: _readout),
            ),
            if (widget.centreOnMe)
              PositionedDirectional(
                bottom: Spacing.large,
                end: Spacing.large,
                child: _CaptureLocationScreenCentreOnMe(
                  onPressed: () => setState(() => _pan = Offset.zero),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The coordinate chip. Two lines: what this surface is, and where the pin is.
class _CaptureLocationScreenReadout extends StatelessWidget {
  const _CaptureLocationScreenReadout({required this.coordinates});

  final String coordinates;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: OmdsBorderRadius.large,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.small,
          vertical: Spacing.xSmall,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Map stand-in · no tiles, no network',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              coordinates,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors `GoogleMapCaptureView._CentreOnMeButton`, including its Semantics
/// identifier and its bottom-end placement, so the RTL rendering of a preview
/// shows the same mirroring the real screen shows.
///
/// `heroTag: null` on purpose: the preview canvas can put several previews in
/// one route, and two FABs sharing the default tag throw there.
class _CaptureLocationScreenCentreOnMe extends StatelessWidget {
  const _CaptureLocationScreenCentreOnMe({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'capture_location_my_location',
      button: true,
      label: l10n.captureLocationMyLocation,
      child: FloatingActionButton.small(
        heroTag: null,
        onPressed: onPressed,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

/// Fills the map slot with a message instead of a map.
///
/// The screen gives its `mapBuilder` an `Expanded`, so anything handed back has
/// to survive being stretched to the whole map area; centring is the fixture's
/// job, not the message widget's.
class _CaptureLocationScreenMessageSurface extends StatelessWidget {
  const _CaptureLocationScreenMessageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Center(child: child),
    );
  }
}

/// "Outside service area" — shipped copy, no shipped screen state.
class _CaptureLocationScreenOutsideServiceArea extends StatelessWidget {
  const _CaptureLocationScreenOutsideServiceArea();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.wrong_location_outlined,
            size: Sizes.fiveXLarge,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.captureLocationOutsideServiceArea,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            captureLocationScreenOutsideServiceAreaBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A 40 pt grid that slides with the pan, so a drag is visible without tiles.
class _CaptureLocationScreenGridPainter extends CustomPainter {
  const _CaptureLocationScreenGridPainter({
    required this.offset,
    required this.ink,
  });

  static const double _step = 40;

  final Offset offset;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = ink
      ..strokeWidth = 1;
    final double dx = offset.dx % _step;
    final double dy = offset.dy % _step;
    for (double x = dx - _step; x <= size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = dy - _step; y <= size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_CaptureLocationScreenGridPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.ink != ink;
}
