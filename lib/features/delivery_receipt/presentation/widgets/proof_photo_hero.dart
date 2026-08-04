import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';

/// The proof-of-delivery hero on `delivered-receipt-confirm` (JM-033, R14
/// `tpl 834–837`): the photo the Jeeber uploaded (D3) framed in glass, with a
/// blurred dark timestamp tag at the leading top corner and a glass
/// "Tap to zoom" pill at the trailing bottom corner.
///
/// The tag is this screen's ONE real `BackdropFilter` (token sheet §4 budget:
/// ≤2); every other translucent surface here is pre-baked.
///
/// Presentation-only — every string and the zoom callback arrive by
/// constructor. The frame keeps its geometry in both states so the layout does
/// not jump between a receipt with a photo and one without: when
/// [proofPhotoUrl] is null the same box renders a neutral placeholder glyph and
/// the zoom pill is not built at all (there is nothing to zoom).
///
/// Semantics: `receipt_proof_photo` wraps the image **and** the placeholder —
/// Maestro `jm-033` asserts it on the seeded journey, so the identifier must
/// exist in both states. `receipt_proof_zoom_cta` exists only when there is a
/// photo.
class ProofPhotoHero extends StatelessWidget {
  const ProofPhotoHero({
    super.key,
    required this.proofPhotoUrl,
    required this.photoSemanticLabel,
    required this.badgeText,
    required this.zoomCtaText,
    this.onZoom,
  });

  /// URL of the proof photo, or null when the gateway surfaced none.
  final String? proofPhotoUrl;

  /// a11y label on the photo / placeholder (`receipt_proof_photo`).
  final String photoSemanticLabel;

  /// Overlay badge copy — `receiptProofBadge`, or `receiptProofBadgeAt` once a
  /// capture time is on the wire. The `· ` separator lives inside that string.
  final String badgeText;

  /// Zoom pill copy — "Tap to zoom".
  final String zoomCtaText;

  /// Opens the full-screen viewer. Null when there is no photo, which also
  /// makes the whole-hero gesture inert.
  final VoidCallback? onZoom;

  /// Board height of the hero frame (`tpl 834`). A one-screen dimension, so it
  /// is named here rather than promoted to a shared spacing token.
  static const double _kProofHeroHeight = 230;

  /// The tag darkens the photo under it so the time reads on any exposure.
  /// Measured black @ 45% over the frame.
  static const double _kTagScrimAlpha = 0.45;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final JeebSemanticColors glass =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final String? url = proofPhotoUrl;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        onTap: onZoom,
        child: SizedBox(
          height: _kProofHeroHeight,
          width: double.infinity,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(JeebRadii.xl),
                  child: Stack(
                    children: <Widget>[
                      // The glass ground: what a portrait photo letterboxes
                      // against, and the placeholder's own surface.
                      Positioned.fill(child: ColoredBox(color: glass.glassFill)),
                      Positioned.fill(
                        child: Semantics(
                          identifier: 'receipt_proof_photo',
                          image: true,
                          label: photoSemanticLabel,
                          child: url == null
                              ? Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: Sizes.twoXLarge,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : OmdsCachedImage(url: url, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Drawn OVER the photo: a frame behind a full-bleed image is no
              // frame at all.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(JeebRadii.xl),
                      border: Border.all(color: glass.glassBorder),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: Spacing.small,
                top: Spacing.small,
                child: _Pill(
                  fill: colorScheme.scrim.withValues(alpha: _kTagScrimAlpha),
                  blurSigma: JeebGlassCapsule.softBlur,
                  child: Text(
                    badgeText,
                    style: context.jeebText.caption
                        .copyWith(color: colorScheme.onSurface),
                  ),
                ),
              ),
              if (url != null)
                PositionedDirectional(
                  end: Spacing.small,
                  bottom: Spacing.small,
                  child: Semantics(
                    identifier: 'receipt_proof_zoom_cta',
                    button: true,
                    label: zoomCtaText,
                    onTap: onZoom,
                    // Same idiom as the two CTAs: the identifier lives on one
                    // explicit node and the inked pill contributes none.
                    child: ExcludeSemantics(
                      child: _Pill(
                        fill: glass.glassFillPressed,
                        borderColor: glass.glassBorderVivid,
                        shadow: JeebShadows.overlay,
                        onTap: onZoom,
                        child: Text(
                          zoomCtaText,
                          style: context.jeebText.caption
                              .copyWith(color: colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two overlay chips share one geometry (`tpl 836/837`: pill, 12/4 pad) and
/// differ only in fill, border, blur and whether they float.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.fill,
    required this.child,
    this.borderColor,
    this.shadow,
    this.blurSigma = 0,
    this.onTap,
  });

  final Color fill;
  final Widget child;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final double blurSigma;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(JeebRadii.pill);
    Widget pill = Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: shadow,
      ),
      child: child,
    );
    if (blurSigma > 0) {
      pill = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: pill,
        ),
      );
    }
    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: pill),
    );
  }
}
