import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Visual framing guide rendered above the ID capture tiles in [KycIdStep].
///
/// The frame is proportioned to the ISO/IEC 7810 ID-1 aspect ratio
/// (85.6 × 54 mm ≈ 1.586). It tells the user how to align their national ID
/// inside the camera viewport *before* the system camera launches, which
/// reduces "id unreadable" rejections coming back from the reviewer pool.
class KycIdAlignmentGuide extends StatelessWidget {
  const KycIdAlignmentGuide({
    super.key,
    required this.title,
    required this.caption,
  });

  static const Key rootKey = Key('kyc-id-alignment-guide');
  static const Key frameKey = Key('kyc-id-alignment-guide-frame');

  /// ISO/IEC 7810 ID-1 aspect ratio (the dimension of a national ID card).
  static const double idCardAspectRatio = 85.6 / 54.0;

  /// Max width of the framing rectangle. Keeps the guide a visual hint rather
  /// than the dominant element of the step, so the capture tiles below stay
  /// in the first viewport.
  static const double maxFrameWidth = 240;

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: rootKey,
      container: true,
      label: title,
      hint: caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxFrameWidth),
            child: _AlignmentFrame(scheme: theme.colorScheme),
          ),
          const SizedBox(height: Spacing.small),
          _GuideCaption(text: caption, textTheme: theme.textTheme),
        ],
      ),
    );
  }
}

class _AlignmentFrame extends StatelessWidget {
  const _AlignmentFrame({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: KycIdAlignmentGuide.idCardAspectRatio,
      child: Container(
        key: KycIdAlignmentGuide.frameKey,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: OmdsBorderRadius.small,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final corner in _Corner.values)
              _CornerTick(corner: corner, color: scheme.primary),
            Center(child: _CenterHint(scheme: scheme)),
          ],
        ),
      ),
    );
  }
}

enum _Corner { topStart, topEnd, bottomStart, bottomEnd }

class _CornerTick extends StatelessWidget {
  const _CornerTick({required this.corner, required this.color});

  static const double _length = 24;
  static const double _thickness = 3;
  static const double _inset = Spacing.small;

  final _Corner corner;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isTop = corner == _Corner.topStart || corner == _Corner.topEnd;
    final isStart = corner == _Corner.topStart || corner == _Corner.bottomStart;
    return PositionedDirectional(
      top: isTop ? _inset : null,
      bottom: isTop ? null : _inset,
      start: isStart ? _inset : null,
      end: isStart ? null : _inset,
      child: SizedBox(
        width: _length,
        height: _length,
        child: CustomPaint(
          painter: _CornerPainter(
            color: color,
            thickness: _thickness,
            isTop: isTop,
            isStart: isStart,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.isTop,
    required this.isStart,
  });

  final Color color;
  final double thickness;
  final bool isTop;
  final bool isStart;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final hx = isStart ? 0.0 : size.width;
    final hy = isTop ? 0.0 : size.height;
    final hxEnd = isStart ? size.width : 0.0;
    final vyEnd = isTop ? size.height : 0.0;
    canvas.drawLine(Offset(hx, hy), Offset(hxEnd, hy), paint);
    canvas.drawLine(Offset(hx, hy), Offset(hx, vyEnd), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.color != color ||
      old.thickness != thickness ||
      old.isTop != isTop ||
      old.isStart != isStart;
}

class _CenterHint extends StatelessWidget {
  const _CenterHint({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.credit_card_outlined,
      size: 36,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
  }
}

class _GuideCaption extends StatelessWidget {
  const _GuideCaption({required this.text, required this.textTheme});

  final String text;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
