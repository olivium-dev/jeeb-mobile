/// Widget previews for [DeliveryConfirmIllustration] — run with
/// `flutter widget-preview start`.
///
/// This widget takes no parameters. It is an [AspectRatio] wrapping a
/// [CustomPaint], so everything it puts on screen is a function of exactly two
/// ambient inputs: the [BoxConstraints] its parent hands it, and
/// `colorScheme.secondaryContainer`. There is no cubit, no repository and no
/// asset load — these previews are network-free because there is nothing to
/// fetch, not merely because [jeebPreviewHost] guards the wire.
///
/// Its "states" are therefore CONSTRAINT states, and that is what each preview
/// below pins: the geometry the production sheet actually gives it, the same
/// geometry on the narrowest supported device, the two host shapes a future
/// caller is most likely to reach for (full-bleed, and height-driven inside a
/// row), and the one shape that makes the painter misbehave — a box whose own
/// aspect ratio does not match 271:150.
///
/// **About the captions.** The widget renders no text, so `find.text` has
/// nothing to bind to and a render test could otherwise pass while every state
/// drew the same box. Each preview therefore carries a one-line caption naming
/// the constraint under review — useful in the canvas, where five unlabelled
/// line drawings are indistinguishable, and used by the test only to address a
/// state. The assertion that actually proves the states differ is the measured
/// box size in
/// `test/previews/chat/delivery_confirm_illustration_preview_test.dart`.
///
/// Two things these previews surface, both in the widget rather than in the
/// previews — see [deliveryConfirmIllustrationSquashedBox] and the note on
/// [deliveryConfirmIllustrationSheetGeometry] about the AR RTL dark rendering.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/chat/presentation/widgets/delivery_confirm_illustration.dart';
import '../harness/jeeb_preview.dart';

/// Phone width the confirmation sheet is designed against (Figma 56618:2992).
const double _phoneWidth = 390;

/// The narrowest device the app still supports.
const double _compactPhoneWidth = 320;

/// The illustration's own reference ratio, restated here so the previews can
/// name the geometry they are producing without reaching into the widget.
const double _illustrationRatio = 271 / 150;

/// Canvas box for a sheet-sized rendering: 117pt of art plus the caption.
const Size _sheetBox = Size(390, 200);

/// Canvas box for the compact-device rendering — the art is only 93pt tall.
const Size _compactBox = Size(390, 180);

/// Canvas box for the full-bleed rendering, which is 216pt of art on its own.
const Size _fullBleedBox = Size(390, 300);

/// Canvas box deliberately taller than the widget it hosts, so the vertical
/// spill in [deliveryConfirmIllustrationSquashedBox] is visible rather than
/// clipped by the edge of the canvas.
const Size _spillBox = Size(390, 240);

/// Renders [constrained] above a caption naming the constraint under review.
///
/// The caption is preview scaffolding — see the library doc. It is deliberately
/// tiny and single-purpose so the 200%-text rendering of the matrix still shows
/// the illustration rather than a wall of label.
Widget _measured(String caption, Widget constrained) => Center(
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
Widget _sheetGeometry(double deviceWidth) => SizedBox(
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
@JeebPreview(group: 'chat', name: 'Sheet geometry (production)', size: _sheetBox)
Widget deliveryConfirmIllustrationSheetGeometry() => _measured(
      'Sheet geometry: 62% of 390pt',
      _sheetGeometry(_phoneWidth),
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
@JeebPreview(group: 'chat', name: 'Compact device (320pt)', size: _compactBox)
Widget deliveryConfirmIllustrationCompactDevice() => _measured(
      'Compact device: 320pt sheet',
      _sheetGeometry(_compactPhoneWidth),
    );

/// Full-bleed: the illustration given the whole phone width, no gutters and no
/// `widthFactor`.
///
/// Measures 390.0 × 215.9 — a 1.44 scale, where the stroke lands at ~4.3pt.
/// Not a shipping state today, but it is the obvious thing a second caller does
/// (an empty state, an onboarding panel), and it is the upper end of the range
/// the geometry has to survive. Included because the scale factor is the one
/// input to this widget nothing else exercises above 1.0.
@JeebPreview(group: 'chat', name: 'Full bleed (390pt)', size: _fullBleedBox)
Widget deliveryConfirmIllustrationFullBleed() => _measured(
      'Full bleed: 390pt wide',
      const SizedBox(width: _phoneWidth, child: DeliveryConfirmIllustration()),
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
@JeebPreview(group: 'chat', name: 'Height-driven in a row', size: _sheetBox)
Widget deliveryConfirmIllustrationHeightDriven() => _measured(
      'Height-driven: 100pt tall row',
      const SizedBox(
        width: _phoneWidth,
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
@JeebPreview(group: 'chat', name: 'Squashed box (spills, unclipped)', size: _spillBox)
Widget deliveryConfirmIllustrationSquashedBox() => _measured(
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
    width / _illustrationRatio;
