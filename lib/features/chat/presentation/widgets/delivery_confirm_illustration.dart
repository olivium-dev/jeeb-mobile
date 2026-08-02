import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Navy line-art illustration (parcel box + clock + location pin) shown on the
/// delivery confirmation sheets (Figma nodes 56618:2992 / sheet illustration).
///
/// Drawn with a [CustomPainter] rather than a bundled raster so it stays crisp
/// at any density, recolours automatically for dark mode via the theme stroke
/// colour, and needs no asset-export step or remote hotlink. The stroke colour
/// is the brand navy (`colorScheme.secondaryContainer`); width is a UI token.
class DeliveryConfirmIllustration extends StatelessWidget {
  const DeliveryConfirmIllustration({super.key});

  static const double _aspectRatio = 271 / 150;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'confirm_delivery_illustration',
      label: l10n.confirmDeliveryActionIllustrationA11y,
      image: true,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: CustomPaint(
          painter: _ParcelClockPinPainter(
            stroke: colorScheme.secondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Paints the parcel/clock/pin line-art inside the given canvas, scaling its
/// reference geometry to fill the available size.
class _ParcelClockPinPainter extends CustomPainter {
  _ParcelClockPinPainter({required this.stroke});

  final Color stroke;

  static const Size _reference = Size(271, 150);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _reference.width;
    canvas.save();
    canvas.translate(
      (size.width - _reference.width * scale) / 2,
      (size.height - _reference.height * scale) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = UIConstants.strokeWidthThick
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    _drawParcel(canvas, paint);
    _drawClock(canvas, paint);
    _drawPin(canvas, paint);
    canvas.restore();
  }

  void _drawParcel(Canvas canvas, Paint paint) {
    const left = 78.0, right = 196.0, top = 36.0, bottom = 118.0;
    const midX = 137.0, ridgeY = 64.0;
    final box = Path()
      ..moveTo(left, ridgeY)
      ..lineTo(midX, top)
      ..lineTo(right, ridgeY)
      ..lineTo(right, bottom)
      ..lineTo(midX, bottom + 14)
      ..lineTo(left, bottom)
      ..close();
    canvas.drawPath(box, paint);
    canvas.drawLine(const Offset(left, ridgeY), const Offset(midX, 92), paint);
    canvas.drawLine(const Offset(right, ridgeY), const Offset(midX, 92), paint);
    canvas.drawLine(const Offset(midX, 92), const Offset(midX, bottom + 14), paint);
  }

  void _drawClock(Canvas canvas, Paint paint) {
    const center = Offset(46, 56);
    canvas.drawCircle(center, 30, paint);
    canvas.drawLine(center, center.translate(0, -16), paint);
    canvas.drawLine(center, center.translate(12, 4), paint);
  }

  void _drawPin(Canvas canvas, Paint paint) {
    const tip = Offset(214, 132);
    final pin = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(190, 108, 192, 86, 214, 86)
      ..cubicTo(236, 86, 238, 108, tip.dx, tip.dy)
      ..close();
    canvas.drawPath(pin, paint);
    canvas.drawCircle(const Offset(214, 100), 9, paint);
  }

  @override
  bool shouldRepaint(_ParcelClockPinPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/delivery_confirm_illustration_preview_test.dart
// ===========================================================================

// Widget previews for [DeliveryConfirmIllustration] — run with
// `flutter widget-preview start`.
//
// This widget takes no parameters. It is an [AspectRatio] wrapping a
// [CustomPaint], so everything it puts on screen is a function of exactly two
// ambient inputs: the [BoxConstraints] its parent hands it, and
// `colorScheme.secondaryContainer`. There is no cubit, no repository and no
// asset load — these previews are network-free because there is nothing to
// fetch, not merely because [jeebPreviewHost] guards the wire.
//
// Its "states" are therefore CONSTRAINT states, and that is what each preview
// below pins: the geometry the production sheet actually gives it, the same
// geometry on the narrowest supported device, the two host shapes a future
// caller is most likely to reach for (full-bleed, and height-driven inside a
// row), and the one shape that makes the painter misbehave — a box whose own
// aspect ratio does not match 271:150.
//
// **About the captions.** The widget renders no text, so `find.text` has
// nothing to bind to and a render test could otherwise pass while every state
// drew the same box. Each preview therefore carries a one-line caption naming
// the constraint under review — useful in the canvas, where five unlabelled
// line drawings are indistinguishable, and used by the test only to address a
// state. The assertion that actually proves the states differ is the measured
// box size in
// `test/previews/chat/delivery_confirm_illustration_preview_test.dart`.
//
// Two things these previews surface, both in the widget rather than in the
// previews — see [deliveryConfirmIllustrationSquashedBox] and the note on
// [deliveryConfirmIllustrationSheetGeometry] about the AR RTL dark rendering.

/// Phone width the confirmation sheet is designed against (Figma 56618:2992).
const double _deliveryConfirmIllustrationPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _deliveryConfirmIllustrationCompactPhoneWidth = 320;

/// The illustration's own reference ratio, restated here so the previews can
/// name the geometry they are producing without reaching into the widget.
const double _deliveryConfirmIllustrationIllustrationRatio = 271 / 150;

/// Canvas box for a sheet-sized rendering: 117pt of art plus the caption.
const Size _deliveryConfirmIllustrationSheetBox = Size(390, 200);

/// Canvas box for the compact-device rendering — the art is only 93pt tall.
const Size _deliveryConfirmIllustrationCompactBox = Size(390, 180);

/// Canvas box for the full-bleed rendering, which is 216pt of art on its own.
const Size _deliveryConfirmIllustrationFullBleedBox = Size(390, 300);

/// Canvas box deliberately taller than the widget it hosts, so the vertical
/// spill in [deliveryConfirmIllustrationSquashedBox] is visible rather than
/// clipped by the edge of the canvas.
const Size _deliveryConfirmIllustrationSpillBox = Size(390, 240);

/// Renders [constrained] above a caption naming the constraint under review.
///
/// The caption is preview scaffolding — see the library doc. It is deliberately
/// tiny and single-purpose so the 200%-text rendering of the matrix still shows
/// the illustration rather than a wall of label.
Widget _deliveryConfirmIllustrationMeasured(String caption, Widget constrained) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          constrained,
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

/// The production host, reproduced: a [deviceWidth]-wide sheet with
/// `Spacing.xLarge` gutters, a stretched column, and the illustration at 62% of
/// the content width.
///
/// Copied from `_SheetContent` in `confirm_delivery_action_sheet.dart` rather
/// than by importing the sheet, so this stays a preview of the illustration and
/// not of the sheet. If the sheet's `widthFactor` ever changes, this preview is
/// wrong and the size assertion in the test says so.
Widget _deliveryConfirmIllustrationSheetGeometry(double deviceWidth) => SizedBox(
      width: deviceWidth,
      child: const Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: 0.62,
              child: DeliveryConfirmIllustration(),
            ),
          ],
        ),
      ),
    );

/// The only geometry that ships today: the confirm-delivery sheet on a 390pt
/// phone, 24pt gutters, illustration at 62% of the content width.
///
/// Measures 212.0 × 117.4. Everything else here is a robustness state; this is
/// the one a designer signs off.
///
/// The rendering of this preview that is worth the most attention is **AR RTL
/// dark**, for two reasons that have nothing to do with Arabic text (there is
/// none):
///
///  * The painter never reads [Directionality]. Clock-left / pin-right is baked
///    into absolute canvas coordinates, so the AR rendering is pixel-identical
///    to the EN one instead of mirroring with the sheet around it.
///  * The stroke is `colorScheme.secondaryContainer`. In the light scheme that
///    is the brand navy on white and measures 17.13:1. The dark scheme is
///    `ColorScheme.fromSeed(_jeebNavy, dark)`, where the same role is a dark
///    tone sitting on an equally dark `surface` — 1.98:1, against the 3:1 WCAG
///    1.4.11 asks of a graphical object. The art is very nearly invisible in
///    dark mode, and no amount of stroke width fixes a palette choice.
@JeebPreview(group: 'chat', name: 'Sheet geometry (production)', size: _deliveryConfirmIllustrationSheetBox)
Widget deliveryConfirmIllustrationSheetGeometry() => _deliveryConfirmIllustrationMeasured(
      'Sheet geometry: 62% of 390pt',
      _deliveryConfirmIllustrationSheetGeometry(_deliveryConfirmIllustrationPhoneWidth),
    );

/// The same sheet on the narrowest supported device.
///
/// Measures 168.6 × 93.3, i.e. a 0.62 canvas scale. The painter applies
/// `canvas.scale()` *before* setting `strokeWidth`, so the 3pt
/// `UIConstants.strokeWidthThick` stroke is scaled too and lands at ~1.9pt
/// here. This is the smallest the line art gets on a real phone, and the
/// rendering to check for the strokes going hairline — especially in the dark
/// rendering, where a thinner line has less area to carry an already weak
/// contrast.
@JeebPreview(group: 'chat', name: 'Compact device (320pt)', size: _deliveryConfirmIllustrationCompactBox)
Widget deliveryConfirmIllustrationCompactDevice() => _deliveryConfirmIllustrationMeasured(
      'Compact device: 320pt sheet',
      _deliveryConfirmIllustrationSheetGeometry(_deliveryConfirmIllustrationCompactPhoneWidth),
    );

/// Full-bleed: the illustration given the whole phone width, no gutters and no
/// `widthFactor`.
///
/// Measures 390.0 × 215.9 — a 1.44 scale, where the stroke lands at ~4.3pt.
/// Not a shipping state today, but it is the obvious thing a second caller does
/// (an empty state, an onboarding panel), and it is the upper end of the range
/// the geometry has to survive. Included because the scale factor is the one
/// input to this widget nothing else exercises above 1.0.
@JeebPreview(group: 'chat', name: 'Full bleed (390pt)', size: _deliveryConfirmIllustrationFullBleedBox)
Widget deliveryConfirmIllustrationFullBleed() => _deliveryConfirmIllustrationMeasured(
      'Full bleed: 390pt wide',
      const SizedBox(width: _deliveryConfirmIllustrationPhoneWidth, child: DeliveryConfirmIllustration()),
    );

/// Height-driven: unbounded width, tight height — the shape a [Row] gives a
/// non-flex child.
///
/// This is the branch of `RenderAspectRatio` that the sheet never reaches:
/// width is infinite, so the ratio is resolved from the height instead.
/// Measures 180.7 × 100.0. Worth a preview because it is the state that would
/// *throw* if the widget were ever given both axes unbounded (a `Row` inside a
/// horizontally scrolling list), and because it is how anyone placing the art
/// beside a block of copy will constrain it.
@JeebPreview(group: 'chat', name: 'Height-driven in a row', size: _deliveryConfirmIllustrationSheetBox)
Widget deliveryConfirmIllustrationHeightDriven() => _deliveryConfirmIllustrationMeasured(
      'Height-driven: 100pt tall row',
      const SizedBox(
        width: _deliveryConfirmIllustrationPhoneWidth,
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[DeliveryConfirmIllustration()],
        ),
      ),
    );

/// The state that breaks: a box that is tight on BOTH axes at a ratio other
/// than 271:150.
///
/// `RenderAspectRatio` short-circuits on tight constraints and returns
/// `constraints.smallest`, so the [AspectRatio] stops defending the ratio and
/// the widget's box really is 300 × 60. The painter, however, derives its scale
/// from `size.width` alone (`scale = size.width / 271`), so it draws 166pt of
/// art and then centres it vertically with a NEGATIVE translate. `CustomPaint`
/// does not clip, so ~53pt of line art is painted above the box and ~53pt below
/// it, on top of whatever the parent put there — with no overflow stripe and no
/// exception to notice it by.
///
/// In the canvas this is unmistakable: the parcel runs straight through the
/// caption beneath it. Nothing ships this geometry today (the sheet's
/// `FractionallySizedBox` leaves the height unbounded), which is exactly why it
/// is worth having a picture of before someone drops the illustration into a
/// fixed-height slot.
@JeebPreview(group: 'chat', name: 'Squashed box (spills, unclipped)', size: _deliveryConfirmIllustrationSpillBox)
Widget deliveryConfirmIllustrationSquashedBox() => _deliveryConfirmIllustrationMeasured(
      'Squashed: tight 300x60 box',
      const SizedBox(
        width: 300,
        height: 60,
        child: DeliveryConfirmIllustration(),
      ),
    );

/// The natural height this widget takes for a given [width], per its own
/// 271:150 reference. Exposed so the render test can state the spill in
/// [deliveryConfirmIllustrationSquashedBox] as a measurement rather than as a
/// magic number.
double deliveryConfirmIllustrationNaturalHeight(double width) =>
    width / _deliveryConfirmIllustrationIllustrationRatio;
