import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../theme/jeeb_color_roles.dart';

/// The two-shadow orange glow under a [JeebMicHero], as measured shape rather
/// than measured colour.
///
/// The board writes the glow as `rgba(215,59,0,α)`, which *is*
/// `jeebRoles.accent` — so only the alphas, offsets, blurs and spreads are
/// constants here; the hue is resolved from the token at paint time. MIDNIGHT
/// re-cuts the drops onto token sheet §7: the two rest discs take `ctaOrange`
/// (`0 14 32 @ .45`), the recording disc takes `micActive`. Each stack keeps its
/// own measured contact ring, which §7's flat entries do not carry.
@immutable
class JeebMicGlow {
  const JeebMicGlow({
    required this.ringAlpha,
    required this.ringSpread,
    required this.dropAlpha,
    required this.dropOffsetY,
    required this.dropBlur,
  });

  /// Ø56 — 04/R1's capsule mic at rest: ring `0 0 0 6 @ .22` + §7 `ctaOrange`.
  static const JeebMicGlow compact = JeebMicGlow(
    ringAlpha: 0.22,
    ringSpread: 6,
    dropAlpha: 0.45,
    dropOffsetY: 14,
    dropBlur: 32,
  );

  /// Ø118 — 01's decorative mic at rest: ring `0 0 0 10 @ .18` + §7 `ctaOrange`.
  static const JeebMicGlow large = JeebMicGlow(
    ringAlpha: 0.18,
    ringSpread: 10,
    dropAlpha: 0.45,
    dropOffsetY: 14,
    dropBlur: 32,
  );

  /// Ø128 — 05's recording mic: token sheet §7 `micActive`
  /// (`0 0 0 10 @ .2` + `0 20 46 @ .55`).
  static const JeebMicGlow hero = JeebMicGlow(
    ringAlpha: 0.20,
    ringSpread: 10,
    dropAlpha: 0.55,
    dropOffsetY: 20,
    dropBlur: 46,
  );

  /// Alpha of the tight contact ring (`0 0 0 N`).
  final double ringAlpha;

  /// Spread of the contact ring in logical px.
  final double ringSpread;

  /// Alpha of the soft drop glow.
  final double dropAlpha;

  /// Vertical offset of the drop glow.
  final double dropOffsetY;

  /// Blur radius of the drop glow.
  final double dropBlur;

  /// Paints this glow in [accent] (`jeebRoles.accent`).
  List<BoxShadow> resolve(Color accent) => <BoxShadow>[
    BoxShadow(
      color: accent.withValues(alpha: ringAlpha),
      spreadRadius: ringSpread,
    ),
    BoxShadow(
      color: accent.withValues(alpha: dropAlpha),
      offset: Offset(0, dropOffsetY),
      blurRadius: dropBlur,
    ),
  ];
}

/// The Jeeb mic (redesign-2026-08 §5 #15).
///
/// An accent disc with a white mic glyph, a size-matched two-shadow glow, an
/// optional radial halo and — new for 05 — an optional **max-duration arc**
/// drawn around it on a `surfaceContainerHighest` track.
///
/// Three measured diameters: [sizeCompact] (04), [sizeLarge] (01),
/// [sizeHero] (05). The glow stack differs per diameter and is picked
/// automatically; the halo and arc scale from the Ø128 measurement.
///
/// **Layout**: the widget lays out at [extentFor] — `size` when bare, larger
/// when the arc or halo is on — so the décor never overflows a parent. Only the
/// disc itself is a hit target; the halo and arc are inert.
///
/// **Gestures**: hold-to-talk is raw-pointer, not a `LongPressGestureRecognizer`
/// — recording must start on touch-down, and the arena's tap/long-press
/// hand-off would otherwise fire `onPressEnd` mid-hold. [onSlideCancel] fires
/// instead of [onPressEnd] when the finger travels [slideCancelThreshold]
/// toward the *start* edge; the sign flips under RTL. [onTap]/[onLongPress] are
/// the discrete callbacks 04 needs; a consumer that passes both families will
/// see a tap emit start → end → tap.
///
/// The satellite Ø46 buttons on 05 are the consumer's job (§5 #15).
class JeebMicHero extends StatefulWidget {
  const JeebMicHero({
    super.key,
    this.size = sizeHero,
    this.isRecording = false,
    this.progress,
    this.halo,
    this.glow,
    this.glyphSize,
    this.discColor,
    this.glyphColor,
    this.crossfadeGlyph,
    this.glyphCrossfade = 0,
    this.onPressStart,
    this.onPressEnd,
    this.onSlideCancel,
    this.onPressCancel,
    this.slideProgress,
    this.holdSlideOnRelease = false,
    this.onTap,
    this.onLongPress,
    this.onSemanticTap,
    this.semanticTapHint,
    this.onSemanticCancel,
    this.semanticCancelLabel,
    this.identifier,
    this.semanticLabel,
  }) : decorative = false;

  /// The non-interactive mark — 01's onboarding stage.
  ///
  /// No gesture layer and no semantics node of its own, so the marketing collage
  /// can wrap it in `IgnorePointer` + `ExcludeSemantics` (or not) without
  /// fighting an inner recognizer.
  const JeebMicHero.decorative({
    super.key,
    this.size = sizeLarge,
    this.halo,
    this.glow,
    this.glyphSize,
  }) : decorative = true,
       isRecording = false,
       progress = null,
       discColor = null,
       glyphColor = null,
       crossfadeGlyph = null,
       glyphCrossfade = 0,
       onPressStart = null,
       onPressEnd = null,
       onSlideCancel = null,
       onPressCancel = null,
       slideProgress = null,
       holdSlideOnRelease = false,
       onTap = null,
       onLongPress = null,
       onSemanticTap = null,
       semanticTapHint = null,
       onSemanticCancel = null,
       semanticCancelLabel = null,
       identifier = null,
       semanticLabel = null;

  /// Ø56 — 04's navy request hero (`tpl 169`).
  static const double sizeCompact = 56;

  /// Ø118 — 01's decorative onboarding mic (`tpl 43`).
  static const double sizeLarge = 118;

  /// Ø128 — 05's recording mic (`tpl 277`).
  static const double sizeHero = 128;

  /// Slide-to-cancel travel in logical px, measured toward the start edge.
  static const double slideCancelThreshold = 64;

  /// Where an ARMED slide disarms again. The dead band is what stops a thumb
  /// parked on the wall from strobing every armed affordance at once.
  static const double slideCancelRelease = 52;

  /// Halo diameter as a fraction of the disc — 184/128 on 05 (`tpl 273`),
  /// concentric with the disc.
  static const double haloRatio = 184 / 128;

  /// Halo centre alpha; it fades to zero at [haloFadeStop].
  static const double haloAlpha = 0.16;

  /// Where the halo gradient reaches full transparency (CSS `… 0) 70%`).
  static const double haloFadeStop = 0.7;

  /// Gap between the disc edge and the arc centreline, as a fraction of the
  /// disc — 10/128 on 05 (disc r64, arc r74).
  static const double arcGapRatio = 10 / 128;

  /// Arc stroke as a fraction of the disc — 5/128 on 05.
  static const double arcStrokeRatio = 5 / 128;

  /// Disc diameter. Use [sizeCompact] / [sizeLarge] / [sizeHero].
  final double size;

  /// Whether audio is being captured. Drives the halo by default — the halo is
  /// on 05 (the only recording state the board draws) and on neither 01 nor 04.
  final bool isRecording;

  /// Max-duration arc, 0–1. Null draws no arc and no track at all.
  ///
  /// 05 passes `elapsed / maxDuration` while recording and null when idle.
  /// Values outside 0–1 are clamped.
  final double? progress;

  /// Forces the radial halo on or off. Null resolves to [isRecording].
  final bool? halo;

  /// Overrides the size-matched glow. Null picks the nearest measured stack:
  /// [JeebMicGlow.compact] · [JeebMicGlow.large] · [JeebMicGlow.hero].
  final JeebMicGlow? glow;

  /// Glyph size. Null uses the measured pairing (56→28, 118→54, 128→56),
  /// falling back to 45% of the disc.
  final double? glyphSize;

  /// Overrides the disc fill and the hue its glow and halo resolve from. Null
  /// uses `jeebRoles.accent`.
  final Color? discColor;

  /// Glyph ink. Null uses `jeebRoles.onAccent`, which is paired with the
  /// DEFAULT fill — a [discColor] that leaves accent must re-pick its own.
  final Color? glyphColor;

  /// A second glyph cross-faded over [Icons.mic] at [glyphCrossfade]. Null
  /// draws the mic alone, which is the shape every non-slide consumer keeps.
  final IconData? crossfadeGlyph;

  /// 0..1 blend from [Icons.mic] toward [crossfadeGlyph]. Inert when that is
  /// null. Values outside 0–1 are clamped.
  final double glyphCrossfade;

  /// Fires on touch-down. Hold-to-talk start.
  final VoidCallback? onPressStart;

  /// Fires on release, unless the slide-cancel gesture armed.
  final VoidCallback? onPressEnd;

  /// Fires on release *instead of* [onPressEnd] when the press travelled
  /// [slideCancelThreshold] toward the start edge. 05 wires this to
  /// `VoiceRecordingCubit.cancelRecording()`.
  final VoidCallback? onSlideCancel;

  /// Fires on `PointerCancel` instead of [onPressEnd] (null falls back to it).
  /// Only the platform cancels here, so it is an exact "touch stolen" signal.
  final VoidCallback? onPressCancel;

  /// Optional 0..1 sink the widget WRITES the live slide-to-cancel travel to,
  /// 1.0 landing exactly where [onSlideCancel] arms. Never read or painted here.
  final ValueNotifier<double>? slideProgress;

  /// When true the sink KEEPS its release value so the consumer can animate it
  /// home; pointer-down and pointer-cancel still zero it.
  final bool holdSlideOnRelease;

  /// Discrete tap — 04 routes to `/voice-request` with it.
  final VoidCallback? onTap;

  /// Discrete long press — 04 routes with this too.
  final VoidCallback? onLongPress;

  /// Screen-reader activation for a hold-only mic: it sits on the semantics
  /// node alone, so no finger tap reaches it. Wire it to a start/stop toggle.
  final VoidCallback? onSemanticTap;

  /// `onTapHint` for [onSemanticTap] — TalkBack reads "Double tap to {hint}".
  final String? semanticTapHint;

  /// Assistive-only escape hatch, published as a custom action: the slide is
  /// raw pointer, so without it a screen reader cannot abandon a recording.
  final VoidCallback? onSemanticCancel;

  /// The action label a screen reader reads for [onSemanticCancel].
  final String? semanticCancelLabel;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// [Semantics] wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label for the disc.
  final String? semanticLabel;

  /// True for [JeebMicHero.decorative].
  final bool decorative;

  /// The square the widget lays out at, décor included.
  ///
  /// Bare disc → [size]. With the arc → the arc's outer stroke edge. With the
  /// halo → [haloRatio] × [size] (which always wins over the arc).
  static double extentFor({
    required double size,
    bool halo = false,
    bool arc = false,
  }) {
    double extent = size;
    if (arc) {
      final double outerRadius =
          size / 2 + size * arcGapRatio + size * arcStrokeRatio / 2;
      extent = math.max(extent, outerRadius * 2);
    }
    if (halo) extent = math.max(extent, size * haloRatio);
    return extent;
  }

  @override
  State<JeebMicHero> createState() => _JeebMicHeroState();
}

class _JeebMicHeroState extends State<JeebMicHero> {
  /// Screen-space dx of the active press, or null when no press is down.
  double? _pressOriginDx;

  /// Whether the current press has travelled far enough to cancel. Mirrored to
  /// [JeebMicHero.slideProgress], which pins at 1 for exactly this state.
  bool _cancelArmed = false;

  bool get _tracksPress =>
      widget.onPressStart != null ||
      widget.onPressEnd != null ||
      widget.onSlideCancel != null ||
      widget.onPressCancel != null;

  bool get _hasDiscreteTaps =>
      widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = widget.discColor ?? context.jeebRoles.accent;
    final Color onAccent = widget.glyphColor ?? context.jeebRoles.onAccent;

    final bool haloOn = widget.halo ?? widget.isRecording;
    final double? progress = widget.progress?.clamp(0.0, 1.0);
    final double extent = JeebMicHero.extentFor(
      size: widget.size,
      halo: haloOn,
      arc: progress != null,
    );

    final double glyphSize = widget.glyphSize ?? _glyphForSize(widget.size);
    final IconData? crossfade = widget.crossfadeGlyph;
    final double blend = widget.glyphCrossfade.clamp(0.0, 1.0);
    final Widget mic = Icon(Icons.mic, size: glyphSize, color: onAccent);

    Widget disc = SizedBox.square(
      dimension: widget.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          boxShadow: (widget.glow ?? _glowForSize(widget.size)).resolve(accent),
        ),
        child: Center(
          child: crossfade == null
              ? mic
              : Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Opacity(opacity: 1 - blend, child: mic),
                    Opacity(
                      opacity: blend,
                      child: Icon(
                        crossfade,
                        size: glyphSize,
                        color: onAccent,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (!widget.decorative) {
      if (_hasDiscreteTaps) {
        disc = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: disc,
        );
      }
      if (_tracksPress) {
        // Opaque: the disc is a circle of colour with a small glyph, so hit
        // testing must not defer to the child or only the glyph would respond.
        disc = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: disc,
        );
      }
    }

    final Widget stack = SizedBox(
      width: extent,
      height: extent,
      child: Stack(
        // Concentric, so a plain centre alignment is already directional-safe.
        alignment: Alignment.center,
        children: <Widget>[
          if (haloOn)
            IgnorePointer(
              child: SizedBox.square(
                dimension: widget.size * JeebMicHero.haloRatio,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        accent.withValues(alpha: JeebMicHero.haloAlpha),
                        accent.withValues(alpha: 0.0),
                      ],
                      stops: const <double>[0.0, JeebMicHero.haloFadeStop],
                    ),
                  ),
                ),
              ),
            ),
          if (progress != null)
            IgnorePointer(
              child: CustomPaint(
                size: Size.square(extent),
                painter: _JeebMicArcPainter(
                  progress: progress,
                  radius:
                      widget.size / 2 + widget.size * JeebMicHero.arcGapRatio,
                  strokeWidth: widget.size * JeebMicHero.arcStrokeRatio,
                  trackColor: scheme.surfaceContainerHighest,
                  arcColor: accent,
                ),
              ),
            ),
          disc,
        ],
      ),
    );

    if (widget.decorative ||
        (widget.identifier == null &&
            widget.semanticLabel == null &&
            widget.onSemanticTap == null &&
            widget.onSemanticCancel == null &&
            !_hasDiscreteTaps &&
            !_tracksPress)) {
      return stack;
    }

    final VoidCallback? cancel = widget.onSemanticCancel;
    final String? cancelLabel = widget.semanticCancelLabel;
    return Semantics(
      identifier: widget.identifier,
      label: widget.semanticLabel,
      button: true,
      onTap: widget.onSemanticTap,
      onTapHint: widget.onSemanticTap == null ? null : widget.semanticTapHint,
      customSemanticsActions: cancel == null || cancelLabel == null
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: cancelLabel): cancel,
            },
      // Mandatory pair (§7.5): without them this node merges into the
      // consumer's wrapper and its id disappears from the tree.
      container: true,
      explicitChildNodes: true,
      child: stack,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pressOriginDx = event.position.dx;
    _cancelArmed = false;
    widget.slideProgress?.value = 0;
    widget.onPressStart?.call();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final double? origin = _pressOriginDx;
    if (origin == null || widget.onSlideCancel == null) return;
    // Direction-signed: the cancel affordance sits at the cluster start, which
    // is the left edge in LTR and the right edge in RTL.
    final double sign = Directionality.of(context) == TextDirection.rtl
        ? -1
        : 1;
    final double travel = sign * (event.position.dx - origin);
    final bool armed = _cancelArmed
        ? travel <= -JeebMicHero.slideCancelRelease
        : travel <= -JeebMicHero.slideCancelThreshold;
    // Arming weighs more than disarming: one is about to destroy a recording.
    if (armed != _cancelArmed) {
      if (armed) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    _cancelArmed = armed;
    // Pinned at 1 for the whole armed band, so the disc, the hint and the
    // release verdict read one number and can never disagree.
    widget.slideProgress?.value = armed
        ? 1
        : (-travel / JeebMicHero.slideCancelThreshold).clamp(0.0, 1.0);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pressOriginDx == null) return;
    _pressOriginDx = null;
    if (!widget.holdSlideOnRelease) widget.slideProgress?.value = 0;
    if (_cancelArmed && widget.onSlideCancel != null) {
      _cancelArmed = false;
      widget.onSlideCancel!.call();
      return;
    }
    _cancelArmed = false;
    widget.onPressEnd?.call();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_pressOriginDx == null) return;
    _pressOriginDx = null;
    widget.slideProgress?.value = 0;
    _cancelArmed = false;
    (widget.onPressCancel ?? widget.onPressEnd)?.call();
  }

  /// Nearest measured glow stack. Midpoints, so 56/118/128 each land on their
  /// own measurement and anything in between takes the closer one.
  JeebMicGlow _glowForSize(double size) {
    if (size <= (JeebMicHero.sizeCompact + JeebMicHero.sizeLarge) / 2) {
      return JeebMicGlow.compact;
    }
    if (size <= (JeebMicHero.sizeLarge + JeebMicHero.sizeHero) / 2) {
      return JeebMicGlow.large;
    }
    return JeebMicGlow.hero;
  }

  /// Measured glyph pairings (04 `tpl 170`, 01 `_kMicGlyphSize`, 05 `tpl 278`);
  /// anything else falls back to 45% of the disc.
  double _glyphForSize(double size) {
    if (size == JeebMicHero.sizeCompact) return 28;
    if (size == JeebMicHero.sizeLarge) return 54;
    if (size == JeebMicHero.sizeHero) return 56;
    return size * 0.45;
  }
}

/// The max-duration arc: a full `surfaceContainerHighest` track with an accent
/// sweep from 12 o'clock.
///
/// The sweep stays clockwise under RTL. A time budget reads as a clock in every
/// locale, and Material's own `CircularProgressIndicator` does not mirror
/// either — mirroring it would make "time remaining" run backwards in Arabic.
class _JeebMicArcPainter extends CustomPainter {
  const _JeebMicArcPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.trackColor,
    required this.arcColor,
  });

  final double progress;
  final double radius;
  final double strokeWidth;
  final Color trackColor;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(centre, radius, track);

    if (progress <= 0) return;

    final Paint sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(_JeebMicArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.arcColor != arcColor;
}
