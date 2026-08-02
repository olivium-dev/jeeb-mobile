import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../l10n/app_localizations.dart';
import '../../../../core/previews/jeeb_preview.dart';

class KycIdAlignmentGuide extends StatelessWidget {
  const KycIdAlignmentGuide({
    super.key,
    required this.title,
    required this.caption,
  });

  static const Key rootKey = Key('kyc-id-alignment-guide');
  static const Key frameKey = Key('kyc-id-alignment-guide-frame');

  static const double idCardAspectRatio = 85.6 / 54.0;

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A 390 pt phone minus the step's `Spacing.large` (20) padding on both sides —
/// the width the guide really gets today.
const double _kycIdAlignmentGuidePhoneContentWidth = 350;

/// The same arithmetic on the narrowest device the app still supports (320 pt).
const double _kycIdAlignmentGuideCompactContentWidth = 280;

/// A 834 pt tablet body. `KycIdentityStep` does NOT wrap itself in
/// `ResponsiveBody`, so nothing clamps the step to a readable column: the guide
const double _kycIdAlignmentGuideTabletContentWidth = 794;

/// Canvas boxes. Each is tall enough for its own state at 200% text, so an
/// overflow stripe in the canvas means the widget changed, not that the box was
const Size _kycIdAlignmentGuidePhoneBox = Size(390, 320);
const Size _kycIdAlignmentGuideCompactBox = Size(390, 500);
const Size _kycIdAlignmentGuideRejectionBox = Size(390, 400);
const Size _kycIdAlignmentGuideEmptyBox = Size(390, 240);
const Size _kycIdAlignmentGuideTabletBox = Size(834, 300);

/// The production title. Only the accessibility tree ever sees it.
String _kycIdAlignmentGuideDefaultTitle(AppLocalizations l10n) =>
    l10n.kycIdAlignmentGuideTitle;

/// The guide at a pinned width, with both strings resolved from the real ARB.
/// [Align] + [SizedBox] rather than a bare [SizedBox]: `jeebPreviewHost`'s
Widget _kycIdAlignmentGuideHosted(
  String Function(AppLocalizations) caption, {
  double width = _kycIdAlignmentGuidePhoneContentWidth,
  String Function(AppLocalizations) title = _kycIdAlignmentGuideDefaultTitle,
}) {
  return Align(
    alignment: AlignmentDirectional.topCenter,
    child: SizedBox(
      width: width,
      child: Builder(
        builder: (BuildContext context) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          return KycIdAlignmentGuide(
            title: title(l10n),
            caption: caption(l10n),
          );
        },
      ),
    ),
  );
}

/// What ships today: `kycIdAlignmentGuideTitle` + `kycIdAlignmentGuideCaption`
/// on a 390 pt phone, exactly as `KycIdentityStep` builds it.
@JeebPreview(
  group: 'kyc',
  name: 'National ID · production copy',
  size: _kycIdAlignmentGuidePhoneBox,
)
Widget kycIdAlignmentGuideProduction() => _kycIdAlignmentGuideHosted(
      (AppLocalizations l10n) => l10n.kycIdAlignmentGuideCaption,
    );

/// The layout ceiling, built from real copy rather than an invented string.
/// `kycIdStepSubtitle` ("We need a clear photo of both sides…") is the longest
@JeebPreview(
  group: 'kyc',
  name: 'Longest caption · 320 pt phone',
  size: _kycIdAlignmentGuideCompactBox,
)
Widget kycIdAlignmentGuideLongestCaptionCompact() => _kycIdAlignmentGuideHosted(
      (AppLocalizations l10n) => l10n.kycIdStepSubtitle,
      width: _kycIdAlignmentGuideCompactContentWidth,
    );

/// The return trip: a jeeber sent back here by an `id_unreadable` rejection
/// (`KycResubmitStep.idFront` / `.idBack`).
@JeebPreview(
  group: 'kyc',
  name: 'Resubmit · rejection reason',
  size: _kycIdAlignmentGuideRejectionBox,
)
Widget kycIdAlignmentGuideRejectionReason() => _kycIdAlignmentGuideHosted(
      (AppLocalizations l10n) => l10n.kycRejectionReasonIdUnreadable,
    );

/// The degenerate input: a caption that is present but empty.
/// `caption` is `required`, which only means "supplied" — nothing asserts it is
@JeebPreview(
  group: 'kyc',
  name: 'Empty caption',
  size: _kycIdAlignmentGuideEmptyBox,
)
Widget kycIdAlignmentGuideEmptyCaption() =>
    _kycIdAlignmentGuideHosted((AppLocalizations _) => '');

/// The same production copy on a tablet-width step body (794 pt of content).
/// `KycIdentityStep` never wraps itself in `ResponsiveBody`, the widget whose
@JeebPreview(
  group: 'kyc',
  name: 'Tablet · full-width step body',
  size: _kycIdAlignmentGuideTabletBox,
)
Widget kycIdAlignmentGuideTabletWidth() => _kycIdAlignmentGuideHosted(
      (AppLocalizations l10n) => l10n.kycIdAlignmentGuideCaption,
      width: _kycIdAlignmentGuideTabletContentWidth,
    );
