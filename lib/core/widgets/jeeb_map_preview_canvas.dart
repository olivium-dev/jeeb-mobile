import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Deterministic map-like fallback used when the native map layer is not
/// injected in dev seams or widget tests.
class JeebMapPreviewCanvas extends StatelessWidget {
  const JeebMapPreviewCanvas({
    super.key,
    this.showRoute = false,
    this.showCenterMarker = false,
  });

  final bool showRoute;
  final bool showCenterMarker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _JeebMapPreviewPainter(
              scheme: scheme,
              showRoute: showRoute,
            ),
          ),
          if (showCenterMarker)
            Center(
              child: Icon(
                Icons.navigation_rounded,
                size: Sizes.fourXLarge,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _JeebMapPreviewPainter extends CustomPainter {
  const _JeebMapPreviewPainter({required this.scheme, required this.showRoute});

  final ColorScheme scheme;
  final bool showRoute;

  static const _neighborhoodAlpha = UIConstants.opacityLow;
  static const _minorRoadAlpha = UIConstants.opacityMedium;
  static const _majorRoadWidth = UIConstants.strokeWidthExtraThick;
  static const _minorRoadWidth = UIConstants.strokeWidthNormal;
  static const _routeWidth = UIConstants.strokeWidthExtraThick;
  static const _pinRadius = Spacing.xSmall;
  static const _pickupX = 0.22;
  static const _pickupY = 0.66;
  static const _dropoffX = 0.78;
  static const _dropoffY = 0.28;
  static const _roadInset = 0.12;
  static const _roadMiddle = 0.5;
  static const _eastRoad = 0.72;
  static const _northRoad = 0.24;
  static const _southRoad = 0.74;

  @override
  void paint(Canvas canvas, Size size) {
    _drawNeighborhoods(canvas, size);
    _drawRoads(canvas, size);
    if (showRoute) _drawRoute(canvas, size);
  }

  void _drawNeighborhoods(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.tertiaryContainer.withValues(alpha: _neighborhoodAlpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * _roadInset,
          size.height * _northRoad,
          size.width * _roadMiddle,
          size.height * _roadMiddle,
        ),
        const Radius.circular(Spacing.medium),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * _roadMiddle,
          size.height * _roadInset,
          size.width * _northRoad,
          size.height * _southRoad,
        ),
        const Radius.circular(Spacing.large),
      ),
      paint
        ..color = scheme.secondaryContainer.withValues(
          alpha: _neighborhoodAlpha,
        ),
    );
  }

  void _drawRoads(Canvas canvas, Size size) {
    final major = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _majorRoadWidth
      ..color = scheme.surface;
    final minor = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _minorRoadWidth
      ..color = scheme.outlineVariant.withValues(alpha: _minorRoadAlpha);

    canvas
      ..drawLine(
        Offset(0, size.height * _roadMiddle),
        Offset(size.width, size.height * _northRoad),
        major,
      )
      ..drawLine(
        Offset(size.width * _roadInset, size.height),
        Offset(size.width * _eastRoad, 0),
        major,
      )
      ..drawLine(
        Offset(0, size.height * _southRoad),
        Offset(size.width, size.height * _southRoad),
        minor,
      )
      ..drawLine(
        Offset(size.width * _northRoad, 0),
        Offset(size.width * _roadInset, size.height),
        minor,
      )
      ..drawLine(
        Offset(0, size.height * _northRoad),
        Offset(size.width, size.height * _roadMiddle),
        minor,
      );
  }

  void _drawRoute(Canvas canvas, Size size) {
    final route = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _routeWidth
      ..color = scheme.primary;
    final path = Path()
      ..moveTo(size.width * _pickupX, size.height * _pickupY)
      ..quadraticBezierTo(
        size.width * _roadMiddle,
        size.height * _roadMiddle,
        size.width * _dropoffX,
        size.height * _dropoffY,
      );
    canvas.drawPath(path, route);

    final pin = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.error;
    canvas
      ..drawCircle(
        Offset(size.width * _pickupX, size.height * _pickupY),
        _pinRadius,
        pin..color = scheme.secondary,
      )
      ..drawCircle(
        Offset(size.width * _dropoffX, size.height * _dropoffY),
        _pinRadius,
        pin..color = scheme.error,
      );
  }

  @override
  bool shouldRepaint(_JeebMapPreviewPainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.showRoute != showRoute;
}
