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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/kyc/kyc_id_alignment_guide_preview_test.dart
// ===========================================================================
//
// The guide is the framing hint above the two ID capture tiles in
// `KycIdentityStep`. It has no cubit, no repository and no state: its entire
// output is a function of two `String`s (`title`, `caption`) and the width its
// parent offers it. Every preview below is therefore network-free by
// construction, not by the guard in `jeebPreviewHost`.
//
// Both strings are resolved from the real ARB through `AppLocalizations`
// rather than restated in English, so the **AR RTL dark** rendering shows the
// Arabic copy the app actually ships (`ضع الهوية داخل الإطار` /
// `ضع البطاقة مسطحة، واملأ الإطار، وتجنّب الانعكاسات.`) — the same strings
// `test/kyc_id_alignment_guide_test.dart` asserts.
//
// Each state also pins its own HOST WIDTH with a real `SizedBox`, because the
// only caller sets it: `KycIdentityStep` wraps the step in
// `EdgeInsets.all(Spacing.large)` (20), so the guide gets `deviceWidth - 40`.
// A preview that left the width to the canvas would silently stop being the
// state under review in the render tests, which pump onto an 800 pt surface.
//
// What these previews exposed, all of it in the widget rather than in the
// previews — read the **AR RTL dark** rendering of any state first:
//
//  * **The corner brackets do not mirror.** The four ticks are placed with
//    `PositionedDirectional`, so in Arabic the boxes swap sides correctly —
//    but each tick is painted by a `CustomPainter` that takes `isStart` as a
//    synonym for "left" and never sees a `TextDirection`. A canvas is not
//    flipped for RTL, so in Arabic every bracket is drawn anchored to its
//    INNER edge: the four elbows point into the frame instead of hugging its
//    corners. `test/previews/kyc/kyc_id_alignment_guide_preview_test.dart`
//    pins the painted geometry in both directions.
//
//  * **`title` is never painted.** It is passed to `Semantics` only, so the
//    visible guide has no heading at any width, and `kycIdAlignmentGuideTitle`
//    is copy no sighted user ever reads. Worse for the users who do: the
//    container's `Semantics` is not an explicit-child boundary, so the caption
//    is folded into that node's label AND repeated as its hint — a screen
//    reader announces the caption twice.
//
//  * **The frame does not scale with text.** It is locked to
//    `KycIdAlignmentGuide.maxFrameWidth` (240) at the ISO ID-1 aspect ratio,
//    so at 200% text the caption grows to 4–8 lines under an unchanged
//    240 x 151 rectangle. Compare the `EN light` and `EN 200% text`
//    renderings of `kycIdAlignmentGuideLongestCaptionCompact`.
//
//  * **The frame is card-shaped even when the document is not.**
//    `KycIdType` also admits `passport` and `residency`, and
//    `KycIdentityStep` hands this guide the same national-ID copy and the same
//    ID-1 rectangle for all three. There is no passport wording in the ARB to
//    preview, which is the point.

/// A 390 pt phone minus the step's `Spacing.large` (20) padding on both sides —
/// the width the guide really gets today.
const double _kycIdAlignmentGuidePhoneContentWidth = 350;

/// The same arithmetic on the narrowest device the app still supports (320 pt).
const double _kycIdAlignmentGuideCompactContentWidth = 280;

/// A 834 pt tablet body. `KycIdentityStep` does NOT wrap itself in
/// `ResponsiveBody`, so nothing clamps the step to a readable column: the guide
/// is offered the whole width minus the same 40 pt of padding.
const double _kycIdAlignmentGuideTabletContentWidth = 794;

/// Canvas boxes. Each is tall enough for its own state at 200% text, so an
/// overflow stripe in the canvas means the widget changed, not that the box was
/// too small.
const Size _kycIdAlignmentGuidePhoneBox = Size(390, 320);
const Size _kycIdAlignmentGuideCompactBox = Size(390, 500);
const Size _kycIdAlignmentGuideRejectionBox = Size(390, 400);
const Size _kycIdAlignmentGuideEmptyBox = Size(390, 240);
const Size _kycIdAlignmentGuideTabletBox = Size(834, 300);

/// The production title. Only the accessibility tree ever sees it.
String _kycIdAlignmentGuideDefaultTitle(AppLocalizations l10n) =>
    l10n.kycIdAlignmentGuideTitle;

/// The guide at a pinned width, with both strings resolved from the real ARB.
///
/// [Align] + [SizedBox] rather than a bare [SizedBox]: `jeebPreviewHost`'s
/// [Scaffold] passes loose constraints, and the guide's own [Column] is
/// `mainAxisSize.max`, so without the [Align] the state under review would be
/// vertically centred in whatever box the canvas happened to have.
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
///
/// This is the rendering a reviewer signs off, and the one to compare against
/// its own **AR RTL dark** variant: the copy translates and the tick boxes
/// swap sides, but the brackets they paint do not — see the section header.
@JeebPreview(
  group: 'kyc',
  name: 'National ID · production copy',
  size: _kycIdAlignmentGuidePhoneBox,
)
Widget kycIdAlignmentGuideProduction() => _kycIdAlignmentGuideHosted(
      (AppLocalizations l10n) => l10n.kycIdAlignmentGuideCaption,
    );

/// The layout ceiling, built from real copy rather than an invented string.
///
/// `kycIdStepSubtitle` ("We need a clear photo of both sides…") is the longest
/// string this step already owns and the obvious candidate for a caption that
/// says more; it is shown on the narrowest supported device, where the guide
/// has 280 pt.
///
/// The **EN 200% text** rendering is the one to read. The caption wraps to
/// eight lines (320 pt of text) under a frame that is still 240 x 151, because
/// the frame is a fixed `maxFrameWidth` at a fixed aspect ratio and scales with
/// nothing. It wraps rather than clipping only because [Text] here sets no
/// `maxLines` and no `overflow` — nothing in the widget enforces that.
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
///
/// The widget's own doc says it exists to reduce exactly those rejections, and
/// `kycRejectionReasonIdUnreadable` is the copy the status screen shows before
/// the user is bounced into this step — so it is the most plausible caption
/// this guide will be asked to carry after the first attempt fails. Two lines
/// at 100% text, six at 200%.
@JeebPreview(
  group: 'kyc',
  name: 'Resubmit · rejection reason',
  size: _kycIdAlignmentGuideRejectionBox,
)
Widget kycIdAlignmentGuideRejectionReason() => _kycIdAlignmentGuideHosted(
      (AppLocalizations l10n) => l10n.kycRejectionReasonIdUnreadable,
    );

/// The degenerate input: a caption that is present but empty.
///
/// `caption` is `required`, which only means "supplied" — nothing asserts it is
/// non-empty and nothing in the widget short-circuits on it. The result is 28 pt
/// of dead space under the frame (the 12 pt `Spacing.small` gap plus a blank
/// 16 pt line band), which reads as a layout bug rather than as missing copy,
/// and a [Semantics] hint that is an empty string.
///
/// Not reachable from today's single caller, and worth a picture precisely
/// because the next one — a key that fell out of the ARB during a merge, a
/// server-supplied instruction — would reach it silently.
@JeebPreview(
  group: 'kyc',
  name: 'Empty caption',
  size: _kycIdAlignmentGuideEmptyBox,
)
Widget kycIdAlignmentGuideEmptyCaption() =>
    _kycIdAlignmentGuideHosted((AppLocalizations _) => '');

/// The same production copy on a tablet-width step body (794 pt of content).
///
/// `KycIdentityStep` never wraps itself in `ResponsiveBody`, the widget whose
/// own doc says to "wrap it around any screen body that should respect
/// responsive constraints" and which would clamp this to a 600 pt column. So
/// the caption paragraph runs the full 794 pt — far past a readable line
/// length — while the frame it describes stays pinned at 240 pt, a sixth of the
/// width, marooned in the middle of the body.
///
/// Deliberately the same strings as [kycIdAlignmentGuideProduction]: this is a
/// WIDTH state, so the render test tells the two apart by geometry rather than
/// by copy.
@JeebPreview(
  group: 'kyc',
  name: 'Tablet · full-width step body',
  size: _kycIdAlignmentGuideTabletBox,
)
Widget kycIdAlignmentGuideTabletWidth() => _kycIdAlignmentGuideHosted(
      (AppLocalizations l10n) => l10n.kycIdAlignmentGuideCaption,
      width: _kycIdAlignmentGuideTabletContentWidth,
    );
