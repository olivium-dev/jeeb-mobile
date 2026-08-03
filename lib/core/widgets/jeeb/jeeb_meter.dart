import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'jeeb_surface_tone.dart';

/// Which of the three realized meter forms a [JeebMeter] is.
enum _JeebMeterKind { bar, scrubber, segmented }

/// The rounded progress track (redesign-2026-08 §5 #20).
///
/// One track shape, three realized forms — all `r9`, all reading their ink
/// from [JeebSurfaceTone] so a meter dropped onto a selected (navy) card
/// inverts without the consumer asking:
///
///  * **[JeebMeter]** — 11's offer-window countdown: `70×5`, accent fill over a
///    `surfaceContainerHighest` track (`11 tpl 658/659`, drawn at 65%).
///  * **[JeebMeter.scrubber]** — 06's replay scrubber: full-width `h5` track
///    plus a Ø14 knob with an accent-tinted `0 2 6` shadow (`06 tpl 315-317`),
///    optionally seekable.
///  * **[JeebMeter.segmented]** — 22's two-step KYC progress: n `flex:1`
///    segments, `h6`, gap 8 (`22 tpl 1304-1306`).
///
/// [value] is nullable everywhere and `null` means **track only**. That is the
/// honest degraded state for 11, whose window total is session-observed and
/// absent on some paths; a meter must never fabricate a fraction.
///
/// The widget is silent in the semantics tree unless given an [identifier] or
/// [semanticLabel], so a consumer that owns its own node (06 wraps this in
/// `Semantics(slider: true, value: …)`) does not get a nested one.
class JeebMeter extends StatelessWidget {
  /// The plain bar. Defaults are 11's measured `70×5 r9`.
  const JeebMeter({
    super.key,
    this.value,
    this.width = 70,
    this.height = 5,
    this.radius = 9,
    this.trackColor,
    this.fillColor,
    this.identifier,
    this.semanticLabel,
  })  : _kind = _JeebMeterKind.bar,
        knobSize = 0,
        onSeek = null,
        steps = 0,
        filled = 0,
        gap = 0;

  /// The bar plus a draggable knob (06).
  ///
  /// [width] defaults to `double.infinity`, so this **must** be given a bounded
  /// width — an `Expanded` (what 06's audio card does) or a `SizedBox`.
  ///
  /// The knob is 14px on a 5px track, so the widget reserves `max(height,
  /// knobSize)` and centres the track inside it. The board lets the knob
  /// overflow a 5px div; Flutter would paint outside its own box and clip the
  /// shadow, so the layout is 9px taller than the CSS. Consumers matching the
  /// board's rhythm should subtract that from the gap below (06's `margin-top:
  /// 8` becomes `Spacing.twoXSmall`).
  const JeebMeter.scrubber({
    super.key,
    this.value,
    this.width = double.infinity,
    this.height = 5,
    this.radius = 9,
    this.knobSize = 14,
    this.onSeek,
    this.trackColor,
    this.fillColor,
    this.identifier,
    this.semanticLabel,
  })  : _kind = _JeebMeterKind.scrubber,
        steps = 0,
        filled = 0,
        gap = 0;

  /// n equal segments, the first [filled] of them in the fill ink (22).
  ///
  /// A plain `Row` of `Expanded` cells, so it mirrors under RTL for free.
  const JeebMeter.segmented({
    super.key,
    required this.steps,
    required this.filled,
    this.height = 6,
    this.gap = 8,
    this.radius = 9,
    this.trackColor,
    this.fillColor,
    this.identifier,
    this.semanticLabel,
  })  : _kind = _JeebMeterKind.segmented,
        value = null,
        width = double.infinity,
        knobSize = 0,
        onSeek = null;

  /// Alpha applied to the fill ink for the scrubber knob's shadow
  /// (`rgba(215,59,0,.4)` — 06 `tpl 317`). Derived from the fill rather than
  /// hardcoded, so it stays correct when the tone inverts on navy.
  static const double knobShadowOpacity = 0.4;

  /// Progress in `0..1`, clamped. `null` renders the track with no fill.
  final double? value;

  /// Track width; 70 on 11. Pass `double.infinity` for a full-width bar — the
  /// default for the scrubber and segmented forms, all of which then need a
  /// bounded parent (`Expanded`, `SizedBox`, a `Column`).
  final double width;

  /// Track height: 5 on 06/11, 6 on 22.
  final double height;

  /// Corner radius of both the track and the fill (9 everywhere on the board).
  final double radius;

  /// Knob diameter, scrubber only.
  final double knobSize;

  /// Gap between segments, segmented only.
  final double gap;

  /// Segment count, segmented only.
  final int steps;

  /// How many leading segments are filled, segmented only.
  final int filled;

  /// Reports a `0..1` fraction on tap or drag, already mirrored for RTL.
  /// `null` leaves the knob a display-only mark rather than a false
  /// affordance.
  final ValueChanged<double>? onSeek;

  /// Track ink; defaults to `JeebSurfaceTone.of(context).meterEmpty`
  /// (`surfaceContainerHighest` on white, `rgba(255,255,255,.25)` on navy).
  final Color? trackColor;

  /// Fill ink; defaults to `JeebSurfaceTone.of(context).meterFill`
  /// (`jeebRoles.accent` on white, `onPrimary` on navy).
  final Color? fillColor;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label. Omit it when the consumer supplies its own node.
  final String? semanticLabel;

  final _JeebMeterKind _kind;

  @override
  Widget build(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final Color track = trackColor ?? tone.meterEmpty;
    final Color fill = fillColor ?? tone.meterFill;

    final Widget meter = switch (_kind) {
      _JeebMeterKind.bar => _bar(track, fill),
      _JeebMeterKind.scrubber => _scrubber(context, track, fill),
      _JeebMeterKind.segmented => _segmented(track, fill),
    };

    if (identifier == null && semanticLabel == null) {
      return meter;
    }
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      container: true,
      child: meter,
    );
  }

  Widget _bar(Color track, Color fill) =>
      _trackBox(track, fill, width: width, height: height);

  /// The track itself. The fill is a [FractionallySizedBox] aligned to
  /// `centerStart`, so the playhead grows from the start edge and mirrors
  /// under RTL — a hard `left:` would invert it under `ar`.
  Widget _trackBox(
    Color track,
    Color fill, {
    required double width,
    required double height,
  }) {
    final BorderRadius corner = BorderRadius.circular(radius);
    final double? fraction = value?.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: track, borderRadius: corner),
        child: fraction == null
            ? null
            : FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fill, borderRadius: corner),
                ),
              ),
      ),
    );
  }

  Widget _scrubber(BuildContext context, Color track, Color fill) {
    final double fraction = (value ?? 0).clamp(0.0, 1.0);
    final double boxHeight = math.max(height, knobSize);

    final Widget stack = SizedBox(
      width: width,
      height: boxHeight,
      child: Stack(
        // The knob and its shadow stand proud of the 5px track.
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          _trackBox(track, fill, width: double.infinity, height: height),
          if (value != null)
            Align(
              // -1 = start edge, 1 = end edge; AlignmentDirectional mirrors it.
              alignment: AlignmentDirectional(fraction * 2 - 1, 0),
              child: _knob(fill),
            ),
        ],
      ),
    );

    if (onSeek == null) {
      return stack;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails d) => _seek(context, d.globalPosition),
      onHorizontalDragStart: (DragStartDetails d) =>
          _seek(context, d.globalPosition),
      onHorizontalDragUpdate: (DragUpdateDetails d) =>
          _seek(context, d.globalPosition),
      child: stack,
    );
  }

  Widget _knob(Color fill) => SizedBox(
        width: knobSize,
        height: knobSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: fill.withValues(alpha: knobShadowOpacity),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      );

  void _seek(BuildContext context, Offset globalPosition) {
    final RenderObject? render = context.findRenderObject();
    if (render is! RenderBox || render.size.width <= 0) {
      return;
    }
    final double raw =
        (render.globalToLocal(globalPosition).dx / render.size.width)
            .clamp(0.0, 1.0);
    // Local x always runs left→right; under RTL the start edge is on the
    // right, so the reported fraction has to be mirrored.
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    onSeek!(rtl ? 1 - raw : raw);
  }

  Widget _segmented(Color track, Color fill) {
    final BorderRadius corner = BorderRadius.circular(radius);
    final List<Widget> cells = <Widget>[];
    for (var index = 0; index < steps; index++) {
      if (index > 0) {
        cells.add(SizedBox(width: gap));
      }
      cells.add(
        Expanded(
          child: SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: index < filled ? fill : track,
                borderRadius: corner,
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: cells);
  }
}
