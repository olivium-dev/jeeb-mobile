import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
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
/// MIDNIGHT R3: the map is the FULL BACKGROUND ([fillViewport]), dimmed at the
/// edges by the field's `map` variant, with the back circle and the ETA chip
/// floating on it. The legacy inset 250px card is what every widget test mounts,
/// so it stays the default.
///
/// The Semantics identifier + [rootKey] are kept on the wrapper in both modes
/// so uiautomator/Maestro and widget tests target the surface identically, and
/// they sit OUTSIDE the rounded clip so neither can be clipped away.
class TrackingMapSurface extends StatelessWidget {
  const TrackingMapSurface({
    super.key,
    this.info,
    this.useLiveMap = false,
    this.fillViewport = false,
    this.onBack,
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

  /// R3's full-bleed background reading: no rounded clip, no claimed height,
  /// and the top overlay row inset by the status bar.
  final bool fillViewport;

  /// Mounts the floating back circle beside the ETA chip and gives it
  /// `tracking_back`. Null draws the chip alone (the legacy inset card).
  final VoidCallback? onBack;

  static const Key rootKey = Key('tracking_map');

  /// Board height of the legacy inset card. A named const rather than a bare
  /// literal: `tool/check_design_tokens.sh` rejects `SizedBox(height: N)`.
  static const double mapHeight = 250;

  /// Gap between the back circle and the ETA chip (board 13).
  static const double topRowGap = 17;

  bool get _showsLiveMap => useLiveMap && info != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = info;
    final body = _MapBody(
      rootKey: rootKey,
      fillViewport: fillViewport,
      // OUTSIDE the `_showsLiveMap` branch on purpose. The notice explains a
      // marker that is NOT being drawn, so gating it on the live map would put
      // it behind the very condition (a provisioned Maps key, a platform view)
      // that is absent in every widget test and in the dev seam.
      overlay: snapshot == null ? null : CourierPositionNotice(info: snapshot),
      // The chip renders whenever there is a snapshot at all, known ETA or not:
      // Maestro `16-order-tracking.yaml:80` asserts `tracking_eta_label` is
      // visible and the fixture's ETA cannot be guaranteed, so an unknown ETA
      // becomes the pending copy rather than a missing node.
      etaPill: snapshot == null
          ? null
          : _TrackingEtaPill(etaMinutes: snapshot.etaMinutes),
      onBack: onBack,
      child: _showsLiveMap
          ? TrackingGoogleMap(info: snapshot!)
          : const TrackingMapPlaceholder(),
    );

    return Semantics(
      identifier: 'tracking_map',
      image: true,
      label: l10n.trackingMapSemanticLabel,
      child: SizedBox(
        height: mapHeight,
        child: fillViewport
            ? body
            : ClipRRect(
                borderRadius: BorderRadius.circular(JeebRadii.lg),
                child: body,
              ),
      ),
    );
  }
}

/// Themed container that anchors [rootKey] and frames the active surface, with
/// the top overlay row (back circle + ETA chip) and the freshness notice
/// stacked over it.
class _MapBody extends StatelessWidget {
  const _MapBody({
    required this.rootKey,
    required this.child,
    required this.fillViewport,
    this.overlay,
    this.etaPill,
    this.onBack,
  });

  final Key rootKey;
  final Widget child;
  final bool fillViewport;

  /// [CourierPositionNotice] collapses itself to a zero-size box when the
  /// position is fine, so a non-null overlay is not the same as a visible one.
  final Widget? overlay;

  final Widget? etaPill;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: rootKey,
      decoration: BoxDecoration(color: scheme.surfaceContainerLowest),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: Center(child: child)),
          // Board-still tile: the field's arcs/twinkles never tick here.
          const Positioned.fill(
            child: IgnorePointer(
              child: JeebMidnightField(
                variant: JeebFieldVariant.map,
                animateDecor: false,
              ),
            ),
          ),
          if (etaPill != null || onBack != null)
            PositionedDirectional(
              start: 0,
              end: 0,
              top: 0,
              child: _TopOverlay(
                fillViewport: fillViewport,
                etaPill: etaPill,
                onBack: onBack,
              ),
            ),
          if (overlay != null)
            PositionedDirectional(
              start: Spacing.medium,
              end: Spacing.medium,
              // Anchored under the top row, never the bottom: on R3 the sheet
              // covers the map's bottom edge.
              top: fillViewport ? _TopOverlay.noticeInset : Spacing.large * 2,
              child: Align(child: overlay!),
            ),
        ],
      ),
    );
  }
}

/// The floating top row: back circle + ETA chip, on the board's own gutter.
class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.fillViewport,
    this.etaPill,
    this.onBack,
  });

  /// Where the freshness notice hangs below the top row when the map is
  /// full-bleed (row height + the status bar is added by [SafeArea]).
  static const double noticeInset = 78;

  final bool fillViewport;
  final Widget? etaPill;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final pill = etaPill;
    final back = onBack;
    if (back == null) {
      // Legacy inset card: the chip alone, pinned to the START corner.
      return Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: pill,
        ),
      );
    }
    final bar = JeebTopBar.back(
      identifier: 'tracking_back',
      leadingTreatment: JeebTopBarLeadingTreatment.floating,
      onLeadingPressed: back,
      gap: TrackingMapSurface.topRowGap,
      titleSlot: pill == null
          ? null
          : Align(alignment: AlignmentDirectional.centerStart, child: pill),
    );
    return fillViewport ? SafeArea(bottom: false, child: bar) : bar;
  }
}

/// The floating "Arriving in 20 min" chip (`03-r3` header) — hero glass, pill
/// radius, white w700 copy.
///
/// `liveRegion: true` is the point of the node — the ETA is the one number on
/// this screen that changes under the customer without them acting.
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
      child: JeebGlassCapsule(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.large - Spacing.twoXSmall,
          vertical: Spacing.xSmall + Spacing.twoXSmall / 2,
        ),
        shadow: JeebShadows.overlay,
        child: Text(
          minutes == null ? l10n.summaryEtaPending : l10n.arrivingIn(minutes),
          style: context.jeebText.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// The deterministic stand-in for the platform map — what widget tests, the dev
/// seam and every catalog capture actually render.
///
/// R3's frame, drawn statically (03-MOTION-NOTES: R3 animates nothing): a night
/// road grid, the dotted orange route and the glowing courier disc.
class TrackingMapPlaceholder extends StatelessWidget {
  const TrackingMapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return CustomPaint(
      isComplex: true,
      willChange: false,
      painter: _MapPlaceholderPainter(
        // The board's own land gradient (token sheet §8 base wash), which is
        // also what `assets/map_styles/midnight.json` paints on the live map.
        land: <Color>[
          scheme.surfaceContainerHighest,
          scheme.surface,
          scheme.surfaceContainerLow,
        ],
        road: semantics.glassFill,
        route: context.jeebRoles.accent,
        courierGlyph: context.jeebRoles.onAccent,
        destination: scheme.error,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// R3's map frame: three roads, a dotted route rising to the drop-off pin, and
/// the courier disc with its halo. Fractional so it reads at any size.
class _MapPlaceholderPainter extends CustomPainter {
  const _MapPlaceholderPainter({
    required this.land,
    required this.road,
    required this.route,
    required this.courierGlyph,
    required this.destination,
  });

  /// Board `stroke-dasharray: 1 12` at 5px round caps.
  static const double _dotRadius = 2.5;
  static const double _dotStride = 13;

  /// Ø34 courier disc (`tpl 758`), halved for the radius.
  static const double _courierRadius = 17;

  /// Board road width, as a fraction of the short side (11 px on a 440 frame).
  static const double _roadFactor = 0.026;

  /// The drop-off pin (`tpl 761-763`).
  static const double _pinSize = 26;

  final List<Color> land;
  final Color road;
  final Color route;
  final Color courierGlyph;
  final Color destination;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: land,
          stops: const <double>[0, 0.45, 1],
        ).createShader(rect),
    );
    final roadPaint = Paint()
      ..color = road
      ..strokeWidth = size.shortestSide * _roadFactor
      ..strokeCap = StrokeCap.square;
    canvas
      ..drawLine(
        Offset(size.width * 0.26, 0),
        Offset(size.width * 0.22, size.height),
        roadPaint,
      )
      ..drawLine(
        Offset(size.width * 0.74, 0),
        Offset(size.width * 0.82, size.height),
        roadPaint,
      )
      ..drawLine(
        Offset(0, size.height * 0.34),
        Offset(size.width, size.height * 0.28),
        roadPaint,
      );

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.74,
        size.width * 0.54,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.30,
        size.width * 0.84,
        size.height * 0.20,
      );
    _drawDots(canvas, path);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.last;
    final end = metric.getTangentForOffset(metric.length)?.position;
    if (end != null) {
      // The pin's tip is its anchor, so it hangs above the route's last point.
      _drawGlyph(canvas, Icons.place, _pinSize, destination,
          end - const Offset(0, _pinSize / 2));
    }
    _drawCourier(canvas, size);
  }

  void _drawDots(Canvas canvas, Path path) {
    final dot = Paint()..color = route;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d <= metric.length; d += _dotStride) {
        final position = metric.getTangentForOffset(d)?.position;
        if (position != null) canvas.drawCircle(position, _dotRadius, dot);
      }
    }
  }

  void _drawCourier(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.54, size.height * 0.52);
    canvas
      ..drawCircle(
        centre,
        _courierRadius * 2,
        Paint()
          ..color = route.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..drawCircle(centre, _courierRadius, Paint()..color = route);
    _drawGlyph(canvas, Icons.two_wheeler, 19, courierGlyph, centre);
  }

  /// Paints [icon] centred on [centre]. Material glyphs are a font, so this is
  /// a `TextPainter` and not an `Icon` widget.
  void _drawGlyph(
    Canvas canvas,
    IconData icon,
    double size,
    Color color,
    Offset centre,
  ) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
    )..layout();
    painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_MapPlaceholderPainter old) =>
      old.land != land ||
      old.road != road ||
      old.route != route ||
      old.courierGlyph != courierGlyph ||
      old.destination != destination;
}
