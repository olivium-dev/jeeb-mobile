import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../motion/jeeb_motion.dart';
import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';

/// The composed illustration a [JeebEmptyState] draws — E1 plus its three
/// approved alternates (master plan §2.7).
enum JeebEmptyStateVariant {
  /// E1: mic on the route-dot ring, four medallions, waveform ears.
  e1,

  /// Sample A: the empty pocket, mic peeking out.
  pocket,

  /// Sample B: a neighbour asking off the balcony, scooter turning in.
  balcony,

  /// Sample C: the mic as a lighthouse, headlights converging.
  beacon,
}

/// Which of the three states of the pattern family is showing.
enum JeebEmptyStateStatus {
  /// The drawn illustration at rest.
  empty,

  /// Illustration skeleton breathing; the CTA is withheld.
  loading,

  /// Same illustration, danger-tinted centre.
  error,
}

/// The four drawn subjects of E1's ring — "bring me anything".
///
/// Flat two-tone art (white/periwinkle bodies, orange accents), traced from the
/// E1 SVG. The caption is explicit: **no stock art**, so these are drawn rather
/// than picked from a Material set.
enum JeebEmptyMedallionArt {
  /// Pill bottle: white body, accent cap, periwinkle label with a white cross.
  medicine,

  /// Grocery bag: white body, periwinkle handle, orangeSoft baguette, greens.
  groceries,

  /// Envelope: white body, periwinkle flap, accent seal.
  document,

  /// Gift box: white body, periwinkle lid, accent ribbon and bow.
  gift,
}

/// One medallion on the E1 route-dot ring — drawn [art] or a consumer glyph.
@immutable
class JeebEmptyMedallion {
  /// A Material glyph, for a subject the four drawn defaults do not cover.
  const JeebEmptyMedallion({
    required IconData this.icon,
    this.tint,
    this.semanticLabel,
  }) : art = null;

  /// One of E1's four drawn subjects. [tint] does not apply: the art is
  /// two-tone by construction.
  const JeebEmptyMedallion.art(this.art, {this.semanticLabel})
      : icon = null,
        tint = null;

  /// The glyph inside the glass disc, or null when [art] is set.
  final IconData? icon;

  /// The drawn subject, or null when [icon] is set.
  final JeebEmptyMedallionArt? art;

  /// Glyph ink. Null reads `onSurface`; pass an accent only where a tile draws
  /// one, per the orange budget.
  final Color? tint;

  /// Announced label. Null leaves the medallion decorative.
  final String? semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is JeebEmptyMedallion &&
      other.icon == icon &&
      other.art == art &&
      other.tint == tint &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(icon, art, tint, semanticLabel);
}

/// "Empty ≠ dead" — the Midnight empty / loading / error pattern (master plan
/// §2.7, study-notes ruling 1).
///
/// Draws a composed vector illustration, a white headline, a muted body and an
/// optional CTA. It never paints a `JeebMidnightField`: the field belongs to the
/// screen. Motion is exactly what `03-MOTION-NOTES.md` measured per element —
/// the route-dot ring and the medallions are STATIC.
class JeebEmptyState extends StatelessWidget {
  const JeebEmptyState({
    super.key,
    required this.headline,
    this.body,
    this.variant = JeebEmptyStateVariant.e1,
    this.status = JeebEmptyStateStatus.empty,
    this.center,
    this.medallions,
    this.action,
    this.illustrationSize = defaultIllustrationSize,
    this.padding = defaultPadding,
    this.identifier,
    this.headlineIdentifier,
    this.bodyIdentifier,
    this.semanticLabel,
  }) : compact = false;

  /// The inline form — a half-size illustration, tighter gaps and the `h2`
  /// headline, for an empty block sitting INSIDE a form or a card rather than
  /// owning the screen.
  const JeebEmptyState.compact({
    super.key,
    required this.headline,
    this.body,
    this.variant = JeebEmptyStateVariant.e1,
    this.status = JeebEmptyStateStatus.empty,
    this.center,
    this.medallions,
    this.action,
    this.illustrationSize = compactIllustrationSize,
    this.padding = compactPadding,
    this.identifier,
    this.headlineIdentifier,
    this.bodyIdentifier,
    this.semanticLabel,
  }) : compact = true;

  /// The board's illustration width (E1 draws a 300×280 viewBox at 300px).
  static const double defaultIllustrationSize = 300;

  /// The inline illustration width — half the board's, the point at which the
  /// medallion art still reads at a glance.
  static const double compactIllustrationSize = 150;

  /// E1's own block gutter — wider than the 24 screen default, as measured.
  static const EdgeInsetsGeometry defaultPadding = EdgeInsets.symmetric(
    horizontal: 36,
  );

  /// Inline gutter — the host form already owns the screen gutter.
  static const EdgeInsetsGeometry compactPadding = EdgeInsets.symmetric(
    horizontal: 16,
  );

  /// Gap under the illustration (board `margin:8px 0 0`).
  static const double headlineGap = 8;

  /// Gap between headline and body (board `margin:9px 0 0`).
  static const double bodyGap = 9;

  /// Gap above the CTA.
  static const double actionGap = 24;

  /// [JeebEmptyState.compact]'s gaps.
  static const double compactHeadlineGap = 4;
  static const double compactBodyGap = 5;
  static const double compactActionGap = 16;

  /// E1's four drawn subjects: medicine · groceries · documents · gift.
  static const List<JeebEmptyMedallion> defaultMedallions =
      <JeebEmptyMedallion>[
        JeebEmptyMedallion.art(JeebEmptyMedallionArt.medicine),
        JeebEmptyMedallion.art(JeebEmptyMedallionArt.groceries),
        JeebEmptyMedallion.art(JeebEmptyMedallionArt.document),
        JeebEmptyMedallion.art(JeebEmptyMedallionArt.gift),
      ];

  /// White headline, `h1` centred.
  final String headline;

  /// Muted body, `body` centred. Null draws no second line.
  final String? body;

  /// Which illustration to compose.
  final JeebEmptyStateVariant variant;

  /// Empty, loading or error.
  final JeebEmptyStateStatus status;

  /// Replaces the mic disc at the centre of [JeebEmptyStateVariant.e1]. The
  /// breathing halo, ring, arcs and waveform stay.
  final Widget? center;

  /// The four E1 medallions. Null uses [defaultMedallions]; extra entries past
  /// the four ring anchors are ignored.
  final List<JeebEmptyMedallion>? medallions;

  /// Optional CTA, hidden while loading.
  final Widget? action;

  /// Illustration width, clamped to the incoming constraints.
  final double illustrationSize;

  /// Block padding.
  final EdgeInsetsGeometry padding;

  /// Maestro / `find.bySemanticsIdentifier` id for the whole block.
  final String? identifier;

  /// Identifier slot on the headline.
  final String? headlineIdentifier;

  /// Identifier slot on the body.
  final String? bodyIdentifier;

  /// Accessibility label for the block.
  final String? semanticLabel;

  /// True for [JeebEmptyState.compact] — the inline density.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final _Ink ink = _Ink.of(context, status);
    final JeebTextStyles text = context.jeebText;
    final String? bodyText = body;
    final Widget? cta = status == JeebEmptyStateStatus.loading ? null : action;
    final TextStyle headlineStyle = compact ? text.h2 : text.h1;

    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _Illustration(
              variant: variant,
              status: status,
              ink: ink,
              center: center,
              medallions: medallions ?? defaultMedallions,
              size: illustrationSize,
            ),
            SizedBox(height: compact ? compactHeadlineGap : headlineGap),
            Semantics(
              identifier: headlineIdentifier,
              header: true,
              child: Text(
                headline,
                textAlign: TextAlign.center,
                style: headlineStyle.copyWith(color: ink.scheme.onSurface),
              ),
            ),
            if (bodyText != null) ...<Widget>[
              SizedBox(height: compact ? compactBodyGap : bodyGap),
              Semantics(
                identifier: bodyIdentifier,
                child: Text(
                  bodyText,
                  textAlign: TextAlign.center,
                  style: text.body.copyWith(color: ink.semantic.mutedText),
                ),
              ),
            ],
            if (cta != null) ...<Widget>[
              SizedBox(height: compact ? compactActionGap : actionGap),
              cta,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── ink ──

/// Resolved palette for the illustration. White-alpha décor derives from
/// `onSurface`; only the glass discs use the §4 glass ladder.
@immutable
class _Ink {
  const _Ink({
    required this.scheme,
    required this.semantic,
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.accentSoft,
    required this.onAccent,
    required this.periwinkle,
    required this.produce,
  });

  factory _Ink.of(BuildContext context, JeebEmptyStateStatus status) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final JeebSemanticColors semantic =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final JeebRoles roles = context.jeebRoles;
    final bool danger = status == JeebEmptyStateStatus.error;
    return _Ink(
      scheme: scheme,
      semantic: semantic,
      accent: danger ? scheme.error : roles.accent,
      accentBright: danger ? scheme.onErrorContainer : semantic.orangeBright,
      accentDeep: danger ? scheme.errorContainer : semantic.orangePressed,
      accentSoft: danger ? scheme.onErrorContainer : semantic.orangeSoft,
      onAccent: roles.onAccent,
      // The medallion art's second tone. Midnight periwinkle `#8A93D8`, not the
      // board SVG's retired `#777FC0` (token sheet §10).
      periwinkle: scheme.secondary,
      produce: roles.onSuccessContainer,
    );
  }

  final ColorScheme scheme;
  final JeebSemanticColors semantic;
  final Color accent;
  final Color accentBright;
  final Color accentDeep;
  final Color accentSoft;
  final Color onAccent;
  final Color periwinkle;
  final Color produce;

  Color white(double alpha) => scheme.onSurface.withValues(alpha: alpha);

  @override
  bool operator ==(Object other) =>
      other is _Ink &&
      other.scheme == scheme &&
      identical(other.semantic, semantic) &&
      other.accent == accent &&
      other.accentBright == accentBright &&
      other.accentDeep == accentDeep &&
      other.accentSoft == accentSoft &&
      other.onAccent == onAccent &&
      other.periwinkle == periwinkle &&
      other.produce == produce;

  @override
  int get hashCode => Object.hash(
    scheme,
    semantic,
    accent,
    accentBright,
    accentDeep,
    accentSoft,
    onAccent,
    periwinkle,
    produce,
  );
}

// ────────────────────────────────────────────────────── geometry ──

const Size _e1ViewBox = Size(300, 280);
const Size _sampleViewBox = Size(300, 270);

/// The route-dot pattern of token sheet §8 — `1 9`, period 10, which divides
/// `jDash`'s −40 travel exactly.
const double _dotDash = 1;
const double _dotGap = 9;

const List<Offset> _medallionAnchors = <Offset>[
  Offset(64, 76),
  Offset(236, 82),
  Offset(60, 204),
  Offset(238, 198),
];

const double _medallionRadius = 27;
const double _medallionGlyph = 26;

/// Inner-to-outer radius of the board's 4-point sparkle (3 / 11 diagonal).
const double _starInnerRatio = 0.386;

Paint _strokePaint(Color color, double width, [StrokeCap cap = StrokeCap.round]) =>
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap
      ..color = color;

Paint _fillPaint(Color color) => Paint()..color = color;

Path _dotted(Path source, {double dash = _dotDash, double gap = _dotGap}) =>
    JDashedPathPainter.dashed(source, dashLength: dash, gapLength: gap);

// ────────────────────────────────────────────────── illustration ──

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.variant,
    required this.status,
    required this.ink,
    required this.center,
    required this.medallions,
    required this.size,
  });

  final JeebEmptyStateVariant variant;
  final JeebEmptyStateStatus status;
  final _Ink ink;
  final Widget? center;
  final List<JeebEmptyMedallion> medallions;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool skeleton = status == JeebEmptyStateStatus.loading;
    final Size viewBox = skeleton || variant == JeebEmptyStateVariant.e1
        ? _e1ViewBox
        : _sampleViewBox;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? math.min(size, constraints.maxWidth)
            : size;
        return SizedBox(
          width: width,
          height: width * viewBox.height / viewBox.width,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.fromSize(
              size: viewBox,
              child: Stack(
                clipBehavior: Clip.none,
                children: skeleton ? _skeleton() : _layers(),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _skeleton() => <Widget>[
    Positioned.fill(
      child: JBreathe(
        child: _vector(
          'skeleton',
          ink,
          (Canvas canvas) => _paintSkeleton(canvas, ink),
        ),
      ),
    ),
  ];

  List<Widget> _layers() => switch (variant) {
    JeebEmptyStateVariant.e1 => _e1Layers(),
    JeebEmptyStateVariant.pocket => _pocketLayers(),
    JeebEmptyStateVariant.balcony => _balconyLayers(),
    JeebEmptyStateVariant.beacon => _beaconLayers(),
  };

  // E1 · lines 1637–1745. Animated: centre glow, waveform ears, 5 twinkles.
  List<Widget> _e1Layers() => <Widget>[
    Positioned.fill(child: _vector('e1-rings', ink, (Canvas canvas) => _paintE1Rings(canvas, ink))),
    Positioned(
      left: 76,
      top: 66,
      width: 148,
      height: 148,
      child: JBreathe(
        duration: const Duration(milliseconds: 3200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                ink.accent.withValues(alpha: 0.5),
                ink.accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    ),
    for (int i = 0; i < math.min(medallions.length, _medallionAnchors.length); i++)
      Positioned(
        left: _medallionAnchors[i].dx - _medallionRadius,
        top: _medallionAnchors[i].dy - _medallionRadius,
        width: _medallionRadius * 2,
        height: _medallionRadius * 2,
        child: _Medallion(medallion: medallions[i], ink: ink),
      ),
    Positioned.fill(child: _vector('e1-arcs', ink, (Canvas canvas) => _paintE1Arcs(canvas, ink))),
    if (center == null)
      Positioned.fill(child: _vector('e1-mic', ink, (Canvas canvas) => _paintE1Mic(canvas, ink)))
    else
      Positioned(left: 103, top: 93, width: 94, height: 94, child: center!),
    Positioned.fill(
      child: JWaveBar(
        duration: const Duration(milliseconds: 1400),
        child: _vector('e1-wave', ink, (Canvas canvas) => _paintE1Waveform(canvas, ink)),
      ),
    ),
    _Twinkle(
      center: const Offset(150, 37),
      radius: 11,
      color: ink.accentSoft,
      duration: const Duration(milliseconds: 2400),
    ),
    _Twinkle(
      center: const Offset(262, 148),
      radius: 8,
      color: ink.white(0.55),
      duration: const Duration(milliseconds: 2800),
      delay: const Duration(milliseconds: 700),
    ),
    _Twinkle(
      center: const Offset(36, 153),
      radius: 7,
      color: ink.white(0.4),
      duration: const Duration(seconds: 3),
      delay: const Duration(milliseconds: 1300),
    ),
    _Twinkle(
      center: const Offset(112, 52),
      radius: 3,
      color: ink.accent,
      dot: true,
      duration: const Duration(milliseconds: 2200),
      delay: const Duration(milliseconds: 1700),
    ),
    _Twinkle(
      center: const Offset(196, 236),
      radius: 3,
      color: ink.white(0.5),
      dot: true,
      duration: const Duration(milliseconds: 2600),
      delay: const Duration(milliseconds: 400),
    ),
  ];

  // Sample A · lines 1933–1971. Animated: ground glow, floating mic, 4 twinkles.
  List<Widget> _pocketLayers() => <Widget>[
    Positioned.fill(child: _vector('pocket-back', ink, (Canvas canvas) => _paintPocketBack(canvas, ink))),
    Positioned(
      left: 84,
      top: 80,
      width: 132,
      height: 24,
      child: JBreathe(
        duration: const Duration(milliseconds: 3200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(66, 12)),
            gradient: RadialGradient(
              colors: <Color>[
                ink.accent.withValues(alpha: 0.55),
                ink.accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    ),
    Positioned.fill(child: _vector('pocket-band', ink, (Canvas canvas) => _paintPocketBand(canvas, ink))),
    Positioned(
      left: 126,
      top: 62,
      width: 48,
      height: 48,
      child: JFloat(
        duration: const Duration(milliseconds: 3400),
        child: _vector(
          'pocket-mic',
          ink,
          (Canvas canvas) => _paintPocketMic(canvas, ink),
          origin: const Offset(126, 62),
        ),
      ),
    ),
    _Twinkle(
      center: const Offset(104, 64.4),
      radius: 8.4,
      color: ink.accentSoft,
      duration: const Duration(milliseconds: 2400),
    ),
    _Twinkle(
      center: const Offset(204, 51),
      radius: 7,
      color: ink.white(0.55),
      duration: const Duration(milliseconds: 2800),
      delay: const Duration(milliseconds: 600),
    ),
    _Twinkle(
      center: const Offset(180, 60),
      radius: 3,
      color: ink.accent,
      dot: true,
      duration: const Duration(milliseconds: 2200),
      delay: const Duration(milliseconds: 1100),
    ),
    _Twinkle(
      center: const Offset(122, 38),
      radius: 2.5,
      color: ink.white(0.4),
      dot: true,
      duration: const Duration(seconds: 3),
      delay: const Duration(milliseconds: 1600),
    ),
  ];

  // Sample B · lines 1972–2025. Animated: lit window, floating bubble + wave,
  // jDash route, headlight.
  List<Widget> _balconyLayers() => <Widget>[
    Positioned.fill(child: _vector('balcony-back', ink, (Canvas canvas) => _paintBalconyBack(canvas, ink))),
    Positioned.fill(
      child: JBreathe(
        duration: const Duration(milliseconds: 3400),
        child: _vector('balcony-window', ink, (Canvas canvas) => _paintBalconyWindow(canvas, ink)),
      ),
    ),
    Positioned.fill(child: _vector('balcony-mid', ink, (Canvas canvas) => _paintBalconyMid(canvas, ink))),
    Positioned.fill(
      child: JDashedPath(
        pathBuilder: (Size _) => _balconyRoutePath(),
        color: ink.accent.withValues(alpha: 0.85),
        strokeWidth: 3,
        dashLength: _dotDash,
        gapLength: _dotGap,
        duration: const Duration(milliseconds: 2400),
      ),
    ),
    Positioned.fill(child: _vector('balcony-scooter', ink, (Canvas canvas) => _paintBalconyScooter(canvas, ink))),
    Positioned.fill(
      child: JBreathe(
        duration: const Duration(milliseconds: 1800),
        child: _vector('balcony-lamp', ink, (Canvas canvas) => _paintBalconyHeadlight(canvas, ink)),
      ),
    ),
    Positioned(
      left: 126,
      top: 92,
      width: 94,
      height: 50,
      child: JFloat(
        duration: const Duration(milliseconds: 3600),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: _vector(
                'balcony-bubble',
                ink,
                (Canvas canvas) => _paintBalconyBubble(canvas, ink),
                origin: const Offset(126, 92),
              ),
            ),
            Positioned(
              left: 22.25,
              top: 8,
              width: 43.5,
              height: 22,
              child: JWaveBar(
                duration: const Duration(milliseconds: 1300),
                child: _vector(
                  'balcony-wave',
                  ink,
                  (Canvas canvas) => _paintBalconyWave(canvas, ink),
                  origin: const Offset(148.25, 100),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];

  // Sample C · lines 2026–2079. Animated: 3 twinkles, jHalo ring, 6 jArcPulse
  // arcs, 2 jDash routes, 2 breathing headlights.
  List<Widget> _beaconLayers() => <Widget>[
    Positioned.fill(child: _vector('beacon-back', ink, (Canvas canvas) => _paintBeaconBack(canvas, ink))),
    Positioned(
      left: 112,
      top: 72,
      width: 76,
      height: 76,
      child: JHalo(
        color: ink.accentSoft,
        strokeWidth: 2,
        child: const SizedBox.shrink(),
      ),
    ),
    Positioned.fill(child: _vector('beacon-mic', ink, (Canvas canvas) => _paintBeaconMic(canvas, ink))),
    for (int i = 0; i < 6; i++)
      Positioned.fill(
        child: JArcPulse(
          delay: Duration(milliseconds: (i % 3) * 400),
          child: _vector('beacon-arc-$i', ink, (Canvas c) => _drawBeaconArc(c, ink, i)),
        ),
      ),
    Positioned.fill(
      child: JDashedPath(
        pathBuilder: (Size _) => _beaconRoutePaths(),
        color: ink.accent,
        strokeWidth: 3,
        dashLength: _dotDash,
        gapLength: _dotGap,
      ),
    ),
    Positioned.fill(
      child: JBreathe(
        duration: const Duration(milliseconds: 1600),
        child: _vector(
          'beacon-lamp-start',
          ink,
          (Canvas c) => _drawBeaconHeadlight(c, ink, start: true),
        ),
      ),
    ),
    Positioned.fill(
      child: JBreathe(
        duration: const Duration(milliseconds: 1600),
        delay: const Duration(milliseconds: 800),
        child: _vector(
          'beacon-lamp-end',
          ink,
          (Canvas c) => _drawBeaconHeadlight(c, ink, start: false),
        ),
      ),
    ),
    _Twinkle(
      center: const Offset(88, 30),
      radius: 2,
      color: ink.white(0.45),
      dot: true,
      duration: const Duration(milliseconds: 2600),
    ),
    _Twinkle(
      center: const Offset(228, 40),
      radius: 2.5,
      color: ink.white(0.35),
      dot: true,
      duration: const Duration(seconds: 3),
      delay: const Duration(milliseconds: 900),
    ),
    _Twinkle(
      center: const Offset(256, 73),
      radius: 7,
      color: ink.white(0.5),
      duration: const Duration(milliseconds: 2400),
      delay: const Duration(milliseconds: 1400),
    ),
  ];
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.medallion, required this.ink});

  final JeebEmptyMedallion medallion;
  final _Ink ink;

  @override
  Widget build(BuildContext context) {
    final JeebEmptyMedallionArt? art = medallion.art;
    final Widget content = art == null
        ? Center(
            child: Icon(
              medallion.icon,
              size: _medallionGlyph,
              color: medallion.tint ?? ink.scheme.onSurface,
              semanticLabel: medallion.semanticLabel,
            ),
          )
        : Semantics(
            label: medallion.semanticLabel,
            child: CustomPaint(painter: _MedallionArt(art: art, ink: ink)),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ink.semantic.glassFillEmphasis,
        border: Border.all(color: ink.semantic.glassBorderStrong),
      ),
      child: content,
    );
  }
}

/// The drawn medallion subjects, traced from E1's SVG into the disc's own
/// 54×54 box (board anchor − 27 on both axes).
class _MedallionArt extends CustomPainter {
  const _MedallionArt({required this.art, required this.ink});

  final JeebEmptyMedallionArt art;
  final _Ink ink;

  @override
  void paint(Canvas canvas, Size size) {
    // Traced at Ø54; a compact illustration scales the whole disc down.
    final double scale = size.shortestSide / (_medallionRadius * 2);
    canvas.scale(scale);
    switch (art) {
      case JeebEmptyMedallionArt.medicine:
        _paintMedicine(canvas, ink);
      case JeebEmptyMedallionArt.groceries:
        _paintGroceries(canvas, ink);
      case JeebEmptyMedallionArt.document:
        _paintDocument(canvas, ink);
      case JeebEmptyMedallionArt.gift:
        _paintGift(canvas, ink);
    }
  }

  @override
  bool shouldRepaint(_MedallionArt oldDelegate) =>
      oldDelegate.art != art || oldDelegate.ink != ink;
}

RRect _rrect(double l, double t, double w, double h, double r) =>
    RRect.fromRectAndRadius(
      Rect.fromLTWH(l, t, w, h),
      Radius.circular(r),
    );

/// Pill bottle — white body, accent cap, periwinkle label, white cross.
void _paintMedicine(Canvas canvas, _Ink ink) {
  canvas
    ..drawRRect(_rrect(18, 19, 18, 23, 4), _fillPaint(ink.scheme.onSurface))
    ..drawRRect(_rrect(17, 12, 20, 8, 3), _fillPaint(ink.accent))
    ..drawRRect(_rrect(22, 25, 10, 10, 2), _fillPaint(ink.periwinkle))
    ..drawPath(
      Path()
        ..moveTo(25, 30)
        ..relativeLineTo(4, 0)
        ..moveTo(27, 28)
        ..relativeLineTo(0, 4),
      _strokePaint(ink.scheme.onSurface, 1.6),
    );
}

/// Grocery bag — white body, periwinkle handle, orangeSoft loaf, green produce.
void _paintGroceries(Canvas canvas, _Ink ink) {
  canvas
    ..drawPath(
      Path()
        ..moveTo(17, 19)
        ..relativeLineTo(20, 0)
        ..relativeLineTo(-2.5, 22)
        ..relativeLineTo(-15, 0)
        ..close(),
      _fillPaint(ink.scheme.onSurface),
    )
    ..drawPath(
      Path()
        ..moveTo(21, 19)
        ..relativeLineTo(0, -4)
        ..arcToPoint(
          const Offset(33, 15),
          radius: const Radius.circular(6),
        )
        ..relativeLineTo(0, 4),
      _strokePaint(ink.periwinkle, 2.2),
    )
    ..save()
    ..translate(32, 15)
    ..rotate(24 * math.pi / 180)
    ..translate(-32, -15)
    ..drawRRect(_rrect(29, 7, 6, 16, 3), _fillPaint(ink.accentSoft))
    ..restore()
    ..drawCircle(const Offset(22, 15), 4.5, _fillPaint(ink.produce));
}

/// Envelope — white body, periwinkle flap, accent seal.
void _paintDocument(Canvas canvas, _Ink ink) {
  canvas
    ..drawRRect(_rrect(15, 17, 25, 18, 2.5), _fillPaint(ink.scheme.onSurface))
    ..drawPath(
      Path()
        ..moveTo(15, 19.5)
        ..lineTo(27, 29)
        ..lineTo(40, 19.5),
      _strokePaint(ink.periwinkle, 2, StrokeCap.butt),
    )
    ..drawCircle(const Offset(27, 31), 3.4, _fillPaint(ink.accent));
}

/// Gift box — white body, periwinkle lid, accent ribbon and bow.
void _paintGift(Canvas canvas, _Ink ink) {
  canvas
    ..drawRRect(_rrect(15, 21, 24, 19, 2.5), _fillPaint(ink.scheme.onSurface))
    ..drawRRect(_rrect(13, 15, 28, 7, 2.5), _fillPaint(ink.periwinkle))
    ..drawRect(
      const Rect.fromLTWH(25, 15, 4.5, 25),
      _fillPaint(ink.accent),
    )
    ..drawPath(
      Path()
        ..moveTo(27, 14)
        ..relativeCubicTo(-7, -1, -9, -8, -4, -9)
        ..relativeCubicTo(4, -1, 5, 5, 4, 9)
        ..close()
        ..moveTo(27, 14)
        ..relativeCubicTo(7, -1, 9, -8, 4, -9)
        ..relativeCubicTo(-4, -1, -5, 5, -4, 9)
        ..close(),
      _fillPaint(ink.accent),
    );
}

/// A `jTwinkle` sparkle or star dot placed by its board-space centre.
class _Twinkle extends StatelessWidget {
  const _Twinkle({
    required this.center,
    required this.radius,
    required this.color,
    required this.duration,
    this.delay = Duration.zero,
    this.dot = false,
  });

  final Offset center;
  final double radius;
  final Color color;
  final Duration duration;
  final Duration delay;
  final bool dot;

  @override
  Widget build(BuildContext context) => Positioned(
    left: center.dx - radius,
    top: center.dy - radius,
    width: radius * 2,
    height: radius * 2,
    child: JTwinkle(
      duration: duration,
      delay: delay,
      child: dot
          ? DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            )
          : CustomPaint(painter: _StarPainter(color)),
    ),
  );
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double outer = size.shortestSide / 2;
    final Offset middle = size.center(Offset.zero);
    final Path path = Path();
    for (int i = 0; i < 8; i++) {
      final double angle = -math.pi / 2 + i * math.pi / 4;
      final double radius = i.isEven ? outer : outer * _starInnerRatio;
      final Offset point =
          middle + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), _fillPaint(color));
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.color != color;
}

// ────────────────────────────────────────────────────── painting ──

typedef _Draw = void Function(Canvas canvas);

CustomPaint _vector(
  String id,
  _Ink ink,
  _Draw draw, {
  Offset origin = Offset.zero,
}) => CustomPaint(
  painter: _Vector(id: id, ink: ink, draw: draw, origin: origin),
);

/// One painter for every static layer: the draw callbacks work in board
/// coordinates, [origin] shifts them into a sub-rect of the viewBox.
class _Vector extends CustomPainter {
  const _Vector({
    required this.id,
    required this.ink,
    required this.draw,
    required this.origin,
  });

  final String id;
  final _Ink ink;
  final _Draw draw;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(-origin.dx, -origin.dy);
    draw(canvas);
  }

  @override
  bool shouldRepaint(_Vector oldDelegate) =>
      oldDelegate.id != id ||
      oldDelegate.ink != ink ||
      oldDelegate.origin != origin;
}

// ── E1 ──

void _paintE1Rings(Canvas canvas, _Ink ink) {
  canvas.drawCircle(
    const Offset(150, 140),
    132,
    _strokePaint(ink.white(0.07), 1.5),
  );
  final Path ring = Path()
    ..addOval(Rect.fromCircle(center: const Offset(150, 140), radius: 97));
  canvas.drawPath(_dotted(ring), _strokePaint(ink.white(0.16), 1.5));
}

void _paintE1Arcs(Canvas canvas, _Ink ink) {
  final Paint paint = _strokePaint(ink.accent.withValues(alpha: 0.4), 2.5);
  final Path top = Path()
    ..moveTo(84, 96)
    ..arcToPoint(
      const Offset(216, 98),
      radius: const Radius.circular(97),
    );
  final Path bottom = Path()
    ..moveTo(82, 186)
    ..arcToPoint(
      const Offset(216, 184),
      radius: const Radius.circular(97),
      clockwise: false,
    );
  canvas
    ..drawPath(_dotted(top), paint)
    ..drawPath(_dotted(bottom), paint);
}

void _paintE1Mic(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(150, 140), 47, _fillPaint(ink.accentDeep))
    ..drawCircle(
      const Offset(150, 138),
      45,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[ink.accentBright, ink.accentDeep],
        ).createShader(
          Rect.fromCircle(center: const Offset(150, 138), radius: 45),
        ),
    )
    ..drawPath(
      Path()
        ..moveTo(118, 118)
        ..arcToPoint(const Offset(148, 96), radius: const Radius.circular(45)),
      _strokePaint(ink.onAccent.withValues(alpha: 0.45), 4),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(141, 114, 18, 32),
        const Radius.circular(9),
      ),
      _fillPaint(ink.onAccent),
    )
    ..drawPath(
      Path()
        ..moveTo(133, 138)
        ..arcToPoint(
          const Offset(167, 138),
          radius: const Radius.circular(17),
          clockwise: false,
        ),
      _strokePaint(ink.onAccent, 4),
    )
    ..drawPath(
      Path()
        ..moveTo(150, 156)
        ..lineTo(150, 165)
        ..moveTo(141, 166)
        ..lineTo(159, 166),
      _strokePaint(ink.onAccent, 4),
    );
}

void _paintE1Waveform(Canvas canvas, _Ink ink) {
  final Paint paint = _strokePaint(ink.accentSoft, 3.5);
  const List<List<double>> bars = <List<double>>[
    <double>[205, 128, 24],
    <double>[214, 122, 36],
    <double>[223, 132, 16],
    <double>[95, 128, 24],
    <double>[86, 122, 36],
    <double>[77, 132, 16],
  ];
  for (final List<double> bar in bars) {
    canvas.drawLine(
      Offset(bar[0], bar[1]),
      Offset(bar[0], bar[1] + bar[2]),
      paint,
    );
  }
}

void _paintSkeleton(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(150, 140), 132, _strokePaint(ink.white(0.07), 1.5))
    ..drawPath(
      _dotted(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(150, 140), radius: 97)),
      ),
      _strokePaint(ink.white(0.16), 1.5),
    )
    ..drawCircle(
      const Offset(150, 140),
      47,
      _fillPaint(ink.semantic.glassFillEmphasis),
    )
    ..drawCircle(
      const Offset(150, 140),
      47,
      _strokePaint(ink.semantic.glassBorderStrong, 1),
    );
  for (final Offset anchor in _medallionAnchors) {
    canvas
      ..drawCircle(
        anchor,
        _medallionRadius,
        _fillPaint(ink.semantic.glassFill),
      )
      ..drawCircle(
        anchor,
        _medallionRadius,
        _strokePaint(ink.semantic.glassBorder, 1),
      );
  }
}

// ── Sample A · the empty pocket ──

Path _pocketBodyPath() => Path()
  ..moveTo(78, 88)
  ..lineTo(222, 88)
  ..quadraticBezierTo(228, 88, 227.4, 94)
  ..lineTo(216, 168)
  ..quadraticBezierTo(150, 218, 84, 168)
  ..lineTo(72.6, 94)
  ..quadraticBezierTo(72, 88, 78, 88)
  ..close();

void _paintPocketBack(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(150, 135), 120, _strokePaint(ink.white(0.07), 1.5))
    ..drawPath(
      _dotted(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(150, 135), radius: 88)),
      ),
      _strokePaint(ink.white(0.13), 1.5),
    )
    ..drawPath(_pocketBodyPath(), _fillPaint(ink.semantic.glassFillEmphasis))
    ..drawPath(_pocketBodyPath(), _strokePaint(ink.white(0.28), 2))
    ..drawPath(
      _dotted(
        Path()
          ..moveTo(88, 100)
          ..lineTo(212, 100)
          ..lineTo(202, 162)
          ..quadraticBezierTo(150, 204, 98, 162)
          ..close(),
        dash: 5,
        gap: 6,
      ),
      _strokePaint(ink.semantic.mutedText.withValues(alpha: 0.8), 2.2),
    );
}

void _paintPocketBand(Canvas canvas, _Ink ink) {
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(78, 84, 144, 10),
        const Radius.circular(5),
      ),
      _fillPaint(ink.white(0.18)),
    )
    ..drawPath(
      Path()
        ..moveTo(143, 143)
        ..lineTo(157, 157)
        ..moveTo(157, 143)
        ..lineTo(143, 157),
      _strokePaint(ink.white(0.22), 2.5),
    );
}

void _paintPocketMic(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(150, 86), 24, _fillPaint(ink.accent))
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(144.5, 72, 11, 19),
        const Radius.circular(5.5),
      ),
      _fillPaint(ink.onAccent),
    )
    ..drawPath(
      Path()
        ..moveTo(139, 82)
        ..arcToPoint(
          const Offset(161, 82),
          radius: const Radius.circular(11),
          clockwise: false,
        ),
      _strokePaint(ink.onAccent, 3),
    );
}

// ── Sample B · ask from the balcony ──

void _paintBalconyBack(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(238, 46), 16, _fillPaint(ink.white(0.14)))
    ..drawCircle(const Offset(232, 42), 14, _fillPaint(ink.scheme.surface))
    ..drawCircle(const Offset(60, 34), 2, _fillPaint(ink.white(0.5)))
    ..drawCircle(const Offset(196, 24), 2.5, _fillPaint(ink.white(0.35)))
    ..drawCircle(const Offset(270, 96), 2, _fillPaint(ink.white(0.4)))
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 52, 92, 158),
        const Radius.circular(6),
      ),
      _fillPaint(ink.semantic.glassFill),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 52, 92, 158),
        const Radius.circular(6),
      ),
      _strokePaint(ink.white(0.2), 1.5),
    );
  for (final Offset window in const <Offset>[
    Offset(54, 68),
    Offset(96, 68),
    Offset(54, 152),
    Offset(96, 152),
  ]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(window.dx, window.dy, 20, 24),
        const Radius.circular(3),
      ),
      _fillPaint(ink.white(0.1)),
    );
  }
}

void _paintBalconyWindow(Canvas canvas, _Ink ink) {
  const Rect glow = Rect.fromLTWH(52, 106, 66, 34);
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(glow, const Radius.circular(4)),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            ink.semantic.amber.withValues(alpha: 0.5),
            ink.semantic.amber.withValues(alpha: 0),
          ],
        ).createShader(glow),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 108, 62, 30),
        const Radius.circular(3.5),
      ),
      _fillPaint(ink.semantic.amber.withValues(alpha: 0.28)),
    );
}

void _paintBalconyMid(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(78, 122), 6.5, _fillPaint(ink.scheme.surface))
    ..drawPath(
      Path()
        ..moveTo(68, 138)
        ..quadraticBezierTo(78, 126, 88, 138)
        ..close(),
      _fillPaint(ink.scheme.surface),
    )
    ..drawPath(
      Path()
        ..moveTo(46, 140)
        ..lineTo(124, 140)
        ..moveTo(52, 140)
        ..lineTo(52, 150)
        ..moveTo(66, 140)
        ..lineTo(66, 150)
        ..moveTo(80, 140)
        ..lineTo(80, 150)
        ..moveTo(94, 140)
        ..lineTo(94, 150)
        ..moveTo(108, 140)
        ..lineTo(108, 150)
        ..moveTo(46, 150)
        ..lineTo(124, 150),
      _strokePaint(ink.white(0.35), 2.5),
    )
    ..drawLine(
      const Offset(28, 212),
      const Offset(272, 212),
      _strokePaint(ink.white(0.22), 3),
    );
}

Path _balconyRoutePath() => Path()
  ..moveTo(210, 132)
  ..quadraticBezierTo(236, 162, 218, 200);

void _paintBalconyScooter(Canvas canvas, _Ink ink) {
  final Paint rim = _strokePaint(ink.white(0.6), 3);
  canvas
    ..drawCircle(const Offset(212, 200), 10, _fillPaint(ink.scheme.surface))
    ..drawCircle(const Offset(212, 200), 10, rim)
    ..drawCircle(const Offset(252, 200), 10, _fillPaint(ink.scheme.surface))
    ..drawCircle(const Offset(252, 200), 10, rim)
    ..drawPath(
      Path()
        ..moveTo(208, 192)
        ..quadraticBezierTo(222, 176, 242, 184)
        ..lineTo(250, 190),
      _strokePaint(ink.white(0.4), 5),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(216, 176, 22, 9),
        const Radius.circular(4.5),
      ),
      _fillPaint(ink.accent),
    );
}

void _paintBalconyHeadlight(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(258, 188), 4, _fillPaint(ink.semantic.amber))
    ..drawPath(
      Path()
        ..moveTo(262, 188)
        ..lineTo(288, 194)
        ..lineTo(288, 182)
        ..close(),
      _fillPaint(ink.semantic.amber.withValues(alpha: 0.14)),
    );
}

void _paintBalconyBubble(Canvas canvas, _Ink ink) {
  final Path bubble = Path()
    ..moveTo(136, 92)
    ..lineTo(210, 92)
    ..quadraticBezierTo(220, 92, 220, 102)
    ..lineTo(220, 120)
    ..quadraticBezierTo(220, 130, 210, 130)
    ..lineTo(158, 130)
    ..lineTo(146, 142)
    ..lineTo(146, 130)
    ..lineTo(136, 130)
    ..quadraticBezierTo(126, 130, 126, 120)
    ..lineTo(126, 102)
    ..quadraticBezierTo(126, 92, 136, 92)
    ..close();
  canvas
    ..drawPath(bubble, _fillPaint(ink.white(0.12)))
    ..drawPath(bubble, _strokePaint(ink.white(0.3), 1.5));
}

void _paintBalconyWave(Canvas canvas, _Ink ink) {
  final Paint paint = _strokePaint(ink.accent, 3.5);
  const List<List<double>> bars = <List<double>>[
    <double>[150, 106, 10],
    <double>[160, 102, 18],
    <double>[170, 108, 7],
    <double>[180, 100, 22],
    <double>[190, 106, 10],
  ];
  for (final List<double> bar in bars) {
    canvas.drawLine(
      Offset(bar[0], bar[1]),
      Offset(bar[0], bar[1] + bar[2]),
      paint,
    );
  }
}

// ── Sample C · the beacon ──

void _paintBeaconBack(Canvas canvas, _Ink ink) {
  final Path hill = Path()
    ..moveTo(20, 232)
    ..quadraticBezierTo(150, 168, 280, 232)
    ..close();
  const Rect glow = Rect.fromLTWH(70, 40, 160, 140);
  canvas
    ..drawPath(hill, _fillPaint(ink.white(0.07)))
    ..drawPath(hill, _strokePaint(ink.white(0.2), 2))
    ..drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            ink.accent.withValues(alpha: 0.5),
            ink.accent.withValues(alpha: 0),
          ],
        ).createShader(glow),
    )
    ..drawLine(
      const Offset(150, 148),
      const Offset(150, 182),
      _strokePaint(ink.white(0.4), 5),
    );
}

void _paintBeaconMic(Canvas canvas, _Ink ink) {
  canvas
    ..drawCircle(const Offset(150, 112), 36, _fillPaint(ink.accentDeep))
    ..drawCircle(
      const Offset(150, 110),
      34,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[ink.accentBright, ink.accentDeep],
        ).createShader(
          Rect.fromCircle(center: const Offset(150, 110), radius: 34),
        ),
    )
    ..drawPath(
      Path()
        ..moveTo(126, 96)
        ..arcToPoint(const Offset(148, 79), radius: const Radius.circular(34)),
      _strokePaint(ink.onAccent.withValues(alpha: 0.45), 3.5),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(143.5, 92, 13, 24),
        const Radius.circular(6.5),
      ),
      _fillPaint(ink.onAccent),
    )
    ..drawPath(
      Path()
        ..moveTo(137, 110)
        ..arcToPoint(
          const Offset(163, 110),
          radius: const Radius.circular(13),
          clockwise: false,
        ),
      _strokePaint(ink.onAccent, 3.2),
    );
}

/// The six broadcast arcs: two mirrored fans of three, radii 52 / 72 / 94.
void _drawBeaconArc(Canvas canvas, _Ink ink, int index) {
  const List<List<double>> fan = <List<double>>[
    <double>[196, 88, 52, 46],
    <double>[212, 76, 72, 70],
    <double>[228, 64, 94, 94],
  ];
  final List<double> arc = fan[index % 3];
  final bool startSide = index >= 3;
  final double x = startSide ? 300 - arc[0] : arc[0];
  canvas.drawPath(
    Path()
      ..moveTo(x, arc[1])
      ..arcToPoint(
        Offset(x, arc[1] + arc[3]),
        radius: Radius.circular(arc[2]),
        clockwise: !startSide,
      ),
    _strokePaint(ink.accentSoft, 4),
  );
}

Path _beaconRoutePaths() => Path()
  ..moveTo(42, 236)
  ..quadraticBezierTo(84, 216, 118, 196)
  ..moveTo(258, 236)
  ..quadraticBezierTo(216, 216, 182, 196);

void _drawBeaconHeadlight(Canvas canvas, _Ink ink, {required bool start}) {
  final double sign = start ? 1 : -1;
  final double cx = start ? 46 : 254;
  canvas
    ..drawCircle(Offset(cx, 234), 6, _fillPaint(ink.semantic.amber))
    ..drawPath(
      Path()
        ..moveTo(cx + 6 * sign, 232)
        ..lineTo(cx + 36 * sign, 220)
        ..lineTo(cx + 32 * sign, 234)
        ..close(),
      _fillPaint(ink.semantic.amber.withValues(alpha: 0.15)),
    );
}
