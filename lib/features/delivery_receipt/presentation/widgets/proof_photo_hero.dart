import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';

/// The proof-of-delivery hero on `delivered-receipt-confirm` (JM-033, dc-tpl
/// 834–837): an r20 neutral frame holding the photo the Jeeber uploaded (D3),
/// a navy "Proof of delivery" badge pinned to the leading top corner and a
/// white "Tap to zoom" pill pinned to the trailing bottom corner.
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

  /// Overlay badge copy — "Proof of delivery".
  final String badgeText;

  /// Zoom pill copy — "Tap to zoom".
  final String zoomCtaText;

  /// Opens the full-screen viewer. Null when there is no photo, which also
  /// makes the whole-hero gesture inert.
  final VoidCallback? onZoom;

  /// Board height of the hero frame (dc-tpl 834). A one-screen dimension, so
  /// it is named here rather than promoted to a shared spacing token.
  static const double _kProofHeroHeight = 230;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final url = proofPhotoUrl;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        onTap: onZoom,
        child: ClipRRect(
          // dc-tpl 834: 20px frame radius.
          borderRadius: OmdsBorderRadius.large,
          child: SizedBox(
            height: _kProofHeroHeight,
            width: double.infinity,
            child: Stack(
              children: [
                // The board's neutral ground behind the photo (#EAE7EB).
                Positioned.fill(
                  child: ColoredBox(color: colorScheme.surfaceContainerHigh),
                ),
                Positioned.fill(
                  child: Semantics(
                    identifier: 'receipt_proof_photo',
                    image: true,
                    label: photoSemanticLabel,
                    child: url == null
                        ? Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: Sizes.twoXLarge,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : OmdsCachedImage(url: url, fit: BoxFit.cover),
                  ),
                ),
                // dc-tpl 836. TODO(redesign-24): the board reads
                // "Proof of delivery · 9:38" — the gateway carries no
                // proof-capture time, so the timestamp is omitted, not faked.
                PositionedDirectional(
                  start: Spacing.small,
                  top: Spacing.small,
                  child: _Pill(
                    color: colorScheme.primary.withValues(alpha: 0.85),
                    child: Text(
                      badgeText,
                      style: context.jeebText.label
                          .copyWith(color: colorScheme.onPrimary),
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
                          color: colorScheme.surface,
                          shadow: JeebShadows.floatPill,
                          onTap: onZoom,
                          child: Text(
                            zoomCtaText,
                            style: context.jeebText.label
                                .copyWith(color: colorScheme.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two overlay chips share one geometry (dc-tpl 836/837: r999, 5/11 pad)
/// and differ only in fill, ink and whether they float.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.color,
    required this.child,
    this.shadow,
    this.onTap,
  });

  final Color color;
  final Widget child;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: OmdsBorderRadius.pill,
        boxShadow: shadow,
      ),
      child: child,
    );
    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.pill,
        child: pill,
      ),
    );
  }
}
