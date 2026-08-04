import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/motion/jeeb_motion.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'walkthrough_glass.dart';

/// W3's decorative map copy, verbatim from the tile.
///
/// TODO(midnight): l10n-queued `walkthroughTrackingCashChip` — the ARB lane
/// owns `lib/l10n` (see l10n-queue/M2-21-r5-w123). The ETA chip already has an
/// exact key and uses it.
abstract final class WalkthroughTrackingCopy {
  static const String cashChip = 'Pay cash at the door';

  /// The tile's ETA, fed to the existing `trackingArrivingIn` key.
  static const int etaMinutes = 20;
}

/// W3's stage art: the night map with the glowing scooter mid-route.
///
/// Motion (03-MOTION-NOTES W3, 5 animated elements): the route is the **only
/// `jDash` on any R/W tile** — 2.6s linear, and R3 draws the identical path
/// still, so this must not be propagated there; the courier halo is `jHalo`
/// 2.2s, the fastest halo on the board; the destination pin floats at 2.8s; and
/// the two chips run the 4s / 4.4s + 1.4s ladder. The courier disc, the roads
/// and the blocks do not move.
class WalkthroughTrackingArt extends StatelessWidget {
  const WalkthroughTrackingArt({super.key});

  /// Board `jDash 2.6s linear`.
  static const Duration routeDuration = Duration(milliseconds: 2600);

  /// Board `jHalo 2.2s ease-out`.
  static const Duration courierHaloDuration = Duration(milliseconds: 2200);

  /// Board `jFloat 2.8s` — the short map-pin period, not the 4s card-art one.
  static const Duration pinDuration = Duration(milliseconds: 2800);

  /// Board `stroke-dasharray="1 12"`, `stroke-width:5`, round cap.
  static const double routeDash = 1;
  static const double routeGap = 12;
  static const double routeStroke = 5;

  /// A multiple of the 13dp dash period, so the loop point cannot jump.
  static const double routeTravel = -39;

  /// Board `rgba(215,59,0,.9)`.
  static const double routeAlpha = 0.9;

  /// The board lays the map out in a 440×560 zone anchored to the canvas top;
  /// the stage band this widget fills starts 51dp lower.
  static const double designWidth = 440;
  static const double stageOriginY = -51;

  /// Courier: ring Ø54, disc Ø38, glyph 21, centre `(235, 291)` in map space.
  static const double courierRing = 54;
  static const double courierDisc = 38;
  static const double courierGlyph = 21;
  static const double courierCentreX = 235;
  static const double courierCentreY = 291;

  /// Pin: 28dp marker with a `0 0 14 rgba(255,82,82,.6)` bloom.
  static const double pinSize = 28;
  static const double pinGlowBlur = 14;
  static const double pinGlowAlpha = 0.6;
  static const double pinEndInset = 62;
  static const double pinTopY = 112;

  /// Chips: `left:24/top:400` and `right:24/top:452` in map space.
  static const double chipInset = Spacing.xLarge;
  static const double etaChipTopY = 400;
  static const double cashChipTopY = 452;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // `PositionedDirectional.start` already measures from the reading edge,
        // so the board's LTR x mirrors for free — only the painters need told.
        final double sx = constraints.maxWidth / designWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _NightMapPainter(
                  road: semantics.glassFill,
                  block: semantics.mutedSurface,
                  mirror: rtl,
                ),
              ),
            ),
            Positioned.fill(
              child: JDashedPath(
                pathBuilder: (Size size) => _routePath(size, rtl),
                color: roles.accent.withValues(alpha: routeAlpha),
                strokeWidth: routeStroke,
                dashLength: routeDash,
                gapLength: routeGap,
                duration: routeDuration,
                travel: routeTravel,
              ),
            ),
            PositionedDirectional(
              start:
                  courierCentreX * sx -
                  courierRing / JeebMotion.haloStartScale / 2,
              top:
                  courierCentreY +
                  stageOriginY -
                  courierRing / JeebMotion.haloStartScale / 2,
              child: const _CourierMark(),
            ),
            const PositionedDirectional(
              end: pinEndInset,
              top: pinTopY + stageOriginY,
              child: JFloat(
                duration: pinDuration,
                child: _DestinationPin(),
              ),
            ),
            PositionedDirectional(
              start: chipInset,
              top: etaChipTopY + stageOriginY,
              child: WalkthroughFloatChip(
                label: AppLocalizations.of(
                  context,
                ).trackingArrivingIn(WalkthroughTrackingCopy.etaMinutes),
                tone: WalkthroughGlassTone.glass,
                duration: WalkthroughFloat.lead,
              ),
            ),
            const PositionedDirectional(
              end: chipInset,
              top: cashChipTopY + stageOriginY,
              child: WalkthroughFloatChip(
                label: WalkthroughTrackingCopy.cashChip,
                tone: WalkthroughGlassTone.accent,
                duration: WalkthroughFloat.trail,
                delay: WalkthroughFloat.mapChipDelay,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The board's `M80 470 C 150 420, 160 330, 240 290 S 350 210, 360 140`.
  /// Horizontal is scaled to the box and mirrored under RTL; vertical is a pure
  /// translation, because stretching it would bend the route off the courier.
  static Path _routePath(Size size, bool mirror) {
    final double sx = size.width / designWidth;
    Offset p(double x, double y) => Offset(
      mirror ? size.width - x * sx : x * sx,
      y + stageOriginY,
    );
    final Offset start = p(80, 470);
    // The `S` command reflects the previous control point: 240+(240-160)=320.
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        p(150, 420).dx,
        p(150, 420).dy,
        p(160, 330).dx,
        p(160, 330).dy,
        p(240, 290).dx,
        p(240, 290).dy,
      )
      ..cubicTo(
        p(320, 250).dx,
        p(320, 250).dy,
        p(350, 210).dx,
        p(350, 210).dy,
        p(360, 140).dx,
        p(360, 140).dy,
      );
  }
}

/// The courier: a still orange disc inside a pulsing ring SIBLING. `jHalo` never
/// rides the disc it surrounds (cheat-sheet rule 2); the primitive's .75 rest
/// scale is what lands the ring on the board's Ø54 hairline.
class _CourierMark extends StatelessWidget {
  const _CourierMark();

  /// Board `0 0 0 9px rgba(215,59,0,.22)` + `0 0 44px rgba(215,59,0,.65)`.
  static const double contactSpread = 9;
  static const double contactAlpha = 0.22;
  static const double bloomBlur = 44;
  static const double bloomAlpha = 0.65;
  static const double ringStroke = 2;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    const double haloBox =
        WalkthroughTrackingArt.courierRing / JeebMotion.haloStartScale;
    return SizedBox.square(
      dimension: haloBox,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          JHalo(
            color: semantics.orangeSoft,
            strokeWidth: ringStroke,
            duration: WalkthroughTrackingArt.courierHaloDuration,
            child: const SizedBox.square(dimension: haloBox),
          ),
          Container(
            width: WalkthroughTrackingArt.courierDisc,
            height: WalkthroughTrackingArt.courierDisc,
            decoration: BoxDecoration(
              color: roles.accent,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: roles.accent.withValues(alpha: contactAlpha),
                  spreadRadius: contactSpread,
                ),
                BoxShadow(
                  color: roles.accent.withValues(alpha: bloomAlpha),
                  blurRadius: bloomBlur,
                ),
              ],
            ),
            child: Icon(
              Icons.moped,
              size: WalkthroughTrackingArt.courierGlyph,
              color: roles.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// The drop-off marker. The glow IS its shadow on this board.
class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.location_on,
      size: WalkthroughTrackingArt.pinSize,
      color: scheme.error,
      shadows: <Shadow>[
        Shadow(
          color: scheme.error.withValues(
            alpha: WalkthroughTrackingArt.pinGlowAlpha,
          ),
          blurRadius: WalkthroughTrackingArt.pinGlowBlur,
        ),
      ],
    );
  }
}

/// Roads and city blocks. Static on the tile, and one painter rather than seven
/// positioned boxes so a narrow device cannot overflow on the rotated strips.
class _NightMapPainter extends CustomPainter {
  const _NightMapPainter({
    required this.road,
    required this.block,
    required this.mirror,
  });

  /// Board strip geometry inside the 440×560 map zone.
  static const double roadThick = 10;
  static const double roadThickWide = 12;
  static const double roadThickNarrow = 11;
  static const double horizontalOneY = 190;
  static const double horizontalTwoY = 350;
  static const double horizontalTwoTilt = -6;
  static const double verticalOneX = 110;
  static const double verticalTwoX = 300;
  static const double verticalTopY = 60;
  static const double blockOneX = 30;
  static const double blockOneY = 250;
  static const Size blockOneSize = Size(60, 50);
  static const double blockTwoEnd = 40;
  static const double blockTwoY = 120;
  static const Size blockTwoSize = Size(66, 52);
  static const double blockRadius = 10;

  final Color road;
  final Color block;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / WalkthroughTrackingArt.designWidth;
    double x(double v) =>
        mirror ? size.width - v * sx : v * sx;
    double y(double v) => v + WalkthroughTrackingArt.stageOriginY;
    final Paint roadPaint = Paint()..color = road;
    final Paint blockPaint = Paint()..color = block;
    final double roadTop = y(verticalTopY);

    canvas.drawRect(
      Rect.fromLTWH(0, y(horizontalOneY), size.width, roadThick),
      roadPaint,
    );
    canvas
      ..save()
      ..translate(size.width / 2, y(horizontalTwoY))
      ..rotate(horizontalTwoTilt * math.pi / 180)
      ..drawRect(
        Rect.fromLTWH(-size.width, 0, size.width * 2, roadThickWide),
        roadPaint,
      )
      ..restore();
    for (final (double mapX, double thickness) in <(double, double)>[
      (verticalOneX, roadThick),
      (verticalTwoX, roadThickNarrow),
    ]) {
      final double left = mirror ? x(mapX) - thickness : x(mapX);
      canvas.drawRect(
        Rect.fromLTWH(left, roadTop, thickness, size.height - roadTop),
        roadPaint,
      );
    }

    for (final (Offset origin, Size box) in <(Offset, Size)>[
      (const Offset(blockOneX, blockOneY), blockOneSize),
      (
        Offset(
          WalkthroughTrackingArt.designWidth - blockTwoEnd - blockTwoSize.width,
          blockTwoY,
        ),
        blockTwoSize,
      ),
    ]) {
      final double left = mirror
          ? x(origin.dx) - box.width
          : x(origin.dx);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y(origin.dy), box.width, box.height),
          const Radius.circular(blockRadius),
        ),
        blockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_NightMapPainter oldDelegate) =>
      oldDelegate.road != road ||
      oldDelegate.block != block ||
      oldDelegate.mirror != mirror;
}
