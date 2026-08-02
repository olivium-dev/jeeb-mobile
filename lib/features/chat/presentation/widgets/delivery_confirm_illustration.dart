import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Navy line-art illustration (parcel + clock + pin). CustomPainter stays crisp at any density,
/// recolours for dark mode via theme stroke, no asset-export or hotlink.
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
