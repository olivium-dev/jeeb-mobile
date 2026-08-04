import 'package:flutter/material.dart';

import '../../../../core/theme/jeeb_color_roles.dart';

/// R2's two concentric orange field rings, centred above the mic — the tile's
/// "the light source IS the action" halo the `JeebMidnightField` glow alone
/// cannot draw (the field's own orbit arcs live at the top end, not here).
///
/// Static: `03-MOTION-NOTES` §R2 lists the field ring under "does not move".
class MicFieldRings extends StatelessWidget {
  const MicFieldRings({super.key});

  /// Ring centre as a fraction of the field — measured on the tile at
  /// (0.50, 0.77); the mic disc sits ~0.09 h below it.
  static const Alignment center = Alignment(0, 0.54);

  /// Radii as a fraction of the field width (measured 0.48 / 0.34).
  static const List<double> radiusFactors = <double>[0.48, 0.34];

  /// Measured stroke alphas — the outer ring is the fainter of the two.
  static const List<double> alphas = <double>[0.14, 0.20];

  static const double strokeWidth = 1;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _MicFieldRingsPainter(accent: context.jeebRoles.accent),
        ),
      ),
    );
  }
}

class _MicFieldRingsPainter extends CustomPainter {
  const _MicFieldRingsPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Offset centre = MicFieldRings.center.alongSize(size);
    for (int i = 0; i < MicFieldRings.radiusFactors.length; i++) {
      canvas.drawCircle(
        centre,
        size.width * MicFieldRings.radiusFactors[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = MicFieldRings.strokeWidth
          ..color = accent.withValues(alpha: MicFieldRings.alphas[i]),
      );
    }
  }

  @override
  bool shouldRepaint(_MicFieldRingsPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
