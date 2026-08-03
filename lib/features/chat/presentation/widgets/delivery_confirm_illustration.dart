import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/previews/jeeb_preview.dart';

/// Navy line-art illustration (parcel + clock + pin). CustomPainter stays crisp at any density,
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

/// Paints the parcel/clock/pin line-art inside the given canvas, scaling its reference geometry.
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
const double _deliveryConfirmIllustrationPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _deliveryConfirmIllustrationCompactPhoneWidth = 320;

/// The illustration's own reference ratio, restated here so the previews can
const double _deliveryConfirmIllustrationIllustrationRatio = 271 / 150;

/// Canvas box for a sheet-sized rendering: 117pt of art plus the caption.
const Size _deliveryConfirmIllustrationSheetBox = Size(390, 200);

/// Canvas box for the compact-device rendering — the art is only 93pt tall.
const Size _deliveryConfirmIllustrationCompactBox = Size(390, 180);

/// Canvas box for the full-bleed rendering, which is 216pt of art on its own.
const Size _deliveryConfirmIllustrationFullBleedBox = Size(390, 300);

/// Canvas box deliberately taller than the widget it hosts, so the vertical
const Size _deliveryConfirmIllustrationSpillBox = Size(390, 240);

/// Renders [constrained] above a caption naming the constraint under review.
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
@JeebPreview(group: 'chat', name: 'Sheet geometry (production)', size: _deliveryConfirmIllustrationSheetBox)
Widget deliveryConfirmIllustrationSheetGeometry() => _deliveryConfirmIllustrationMeasured(
      'Sheet geometry: 62% of 390pt',
      _deliveryConfirmIllustrationSheetGeometry(_deliveryConfirmIllustrationPhoneWidth),
    );

/// The same sheet on the narrowest supported device.
@JeebPreview(group: 'chat', name: 'Compact device (320pt)', size: _deliveryConfirmIllustrationCompactBox)
Widget deliveryConfirmIllustrationCompactDevice() => _deliveryConfirmIllustrationMeasured(
      'Compact device: 320pt sheet',
      _deliveryConfirmIllustrationSheetGeometry(_deliveryConfirmIllustrationCompactPhoneWidth),
    );

/// Full-bleed: the illustration given the whole phone width, no gutters and no
@JeebPreview(group: 'chat', name: 'Full bleed (390pt)', size: _deliveryConfirmIllustrationFullBleedBox)
Widget deliveryConfirmIllustrationFullBleed() => _deliveryConfirmIllustrationMeasured(
      'Full bleed: 390pt wide',
      const SizedBox(width: _deliveryConfirmIllustrationPhoneWidth, child: DeliveryConfirmIllustration()),
    );

/// Height-driven: unbounded width, tight height — the shape a [Row] gives a
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
double deliveryConfirmIllustrationNaturalHeight(double width) =>
    width / _deliveryConfirmIllustrationIllustrationRatio;
