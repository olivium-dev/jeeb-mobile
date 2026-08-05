import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../features/kyc/domain/cdn_asset_gateway.dart';
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
/// [proofPhotoUrl] is null the same box renders an explicit unavailable state
/// and the zoom pill is not built at all (there is nothing to zoom).
///
/// Semantics: `receipt_proof_photo` wraps the image **and** the placeholder —
/// Maestro `jm-033` asserts it on the seeded journey, so the identifier must
/// exist in both states. `receipt_proof_zoom_cta` exists only when there is a
/// photo.
class ProofPhotoHero extends StatefulWidget {
  const ProofPhotoHero({
    super.key,
    required this.proofPhotoUrl,
    required this.proofPhotoObjectRef,
    required this.cdnAssetGateway,
    required this.photoSemanticLabel,
    required this.unavailableText,
    required this.badgeText,
    required this.zoomCtaText,
    this.onZoom,
    this.onZoomBytes,
  });

  /// URL of the proof photo, or null when the gateway surfaced none.
  final String? proofPhotoUrl;

  /// Authenticated CDN object_ref, or null when evidence is URL/absent.
  final String? proofPhotoObjectRef;

  /// Existing authenticated CDN gateway used to resolve [proofPhotoObjectRef].
  final CdnAssetGateway? cdnAssetGateway;

  /// a11y label on the photo / placeholder (`receipt_proof_photo`).
  final String photoSemanticLabel;

  /// Copy shown and announced when proof evidence cannot be rendered.
  final String unavailableText;

  /// Overlay badge copy — `receiptProofBadge`, or `receiptProofBadgeAt` once a
  /// capture time is on the wire. The `· ` separator lives inside that string.
  final String badgeText;

  /// Zoom pill copy — "Tap to zoom".
  final String zoomCtaText;

  /// Opens the full-screen viewer. Null when there is no photo, which also
  /// makes the whole-hero gesture inert.
  final VoidCallback? onZoom;

  /// Opens the full-screen viewer for resolved object_ref bytes.
  final ValueChanged<Uint8List>? onZoomBytes;

  /// Board height of the hero frame (`tpl 834`). A one-screen dimension, so it
  /// is named here rather than promoted to a shared spacing token.
  static const double _kProofHeroHeight = 230;

  /// The tag darkens the photo under it so the time reads on any exposure.
  /// Measured black @ 45% over the frame.
  static const double _kTagScrimAlpha = 0.45;

  @override
  State<ProofPhotoHero> createState() => _ProofPhotoHeroState();
}

class _ProofPhotoHeroState extends State<ProofPhotoHero> {
  bool _loadFailed = false;
  Future<Uint8List>? _assetFuture;
  Uint8List? _resolvedBytes;

  @override
  void didUpdateWidget(ProofPhotoHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proofPhotoUrl != widget.proofPhotoUrl ||
        oldWidget.proofPhotoObjectRef != widget.proofPhotoObjectRef ||
        oldWidget.cdnAssetGateway != widget.cdnAssetGateway) {
      _loadFailed = false;
      _assetFuture = null;
      _resolvedBytes = null;
    }
  }

  Widget _errorWidget(BuildContext context, String url, Object error) {
    _markLoadFailed(url: url);
    return _ProofPhotoUnavailable(label: widget.unavailableText);
  }

  Widget _memoryErrorWidget(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    _markLoadFailed();
    return _ProofPhotoUnavailable(label: widget.unavailableText);
  }

  void _markLoadFailed({String? url}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final staleUrl = url != null && widget.proofPhotoUrl != url;
      if (mounted && !_loadFailed && !staleUrl) {
        setState(() => _loadFailed = true);
      }
    });
  }

  Future<Uint8List> _ensureAssetFuture(String objectRef) {
    return _assetFuture ??= widget.cdnAssetGateway!.fetchAsset(objectRef);
  }

  VoidCallback? _heroTap(String? url, bool showUnavailable) {
    if (showUnavailable) return null;
    final bytes = _resolvedBytes;
    if (bytes != null) {
      final onZoomBytes = widget.onZoomBytes;
      return onZoomBytes == null ? null : () => onZoomBytes(bytes);
    }
    if (url != null) return widget.onZoom;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final JeebSemanticColors glass =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final String? url = widget.proofPhotoUrl;
    final String? objectRef = widget.proofPhotoObjectRef;
    final bool hasResolvableObjectRef =
        objectRef != null && widget.cdnAssetGateway != null;
    final bool showUnavailable =
        _loadFailed || (url == null && !hasResolvableObjectRef);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        onTap: _heroTap(url, showUnavailable),
        child: SizedBox(
          height: ProofPhotoHero._kProofHeroHeight,
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
                      Positioned.fill(
                        child: ColoredBox(color: glass.glassFill),
                      ),
                      Positioned.fill(
                        child: Semantics(
                          identifier: 'receipt_proof_photo',
                          image: !showUnavailable,
                          label: showUnavailable
                              ? widget.unavailableText
                              : widget.photoSemanticLabel,
                          child: _proofContent(
                            url: url,
                            objectRef: objectRef,
                            showUnavailable: showUnavailable,
                          ),
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
                  fill: colorScheme.scrim.withValues(
                    alpha: ProofPhotoHero._kTagScrimAlpha,
                  ),
                  blurSigma: JeebGlassCapsule.softBlur,
                  child: Text(
                    widget.badgeText,
                    style: context.jeebText.caption.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (!showUnavailable &&
                  (url != null || _resolvedBytes != null) &&
                  (widget.onZoom != null || widget.onZoomBytes != null))
                PositionedDirectional(
                  end: Spacing.small,
                  bottom: Spacing.small,
                  child: Semantics(
                    identifier: 'receipt_proof_zoom_cta',
                    button: true,
                    label: widget.zoomCtaText,
                    onTap: _heroTap(url, showUnavailable),
                    // Same idiom as the two CTAs: the identifier lives on one
                    // explicit node and the inked pill contributes none.
                    child: ExcludeSemantics(
                      child: _Pill(
                        fill: glass.glassFillPressed,
                        borderColor: glass.glassBorderVivid,
                        shadow: JeebShadows.overlay,
                        onTap: _heroTap(url, showUnavailable),
                        child: Text(
                          widget.zoomCtaText,
                          style: context.jeebText.caption.copyWith(
                            color: colorScheme.onSurface,
                          ),
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

  Widget _proofContent({
    required String? url,
    required String? objectRef,
    required bool showUnavailable,
  }) {
    if (showUnavailable) {
      return _ProofPhotoUnavailable(label: widget.unavailableText);
    }
    if (url != null) {
      return OmdsCachedImage(
        url: url,
        fit: BoxFit.cover,
        errorWidget: _errorWidget,
      );
    }
    return FutureBuilder<Uint8List>(
      future: _ensureAssetFuture(objectRef!),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_loadFailed) {
              setState(() => _loadFailed = true);
            }
          });
          return _ProofPhotoUnavailable(label: widget.unavailableText);
        }
        if (bytes != null && bytes.isNotEmpty) {
          if (!identical(_resolvedBytes, bytes)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && widget.proofPhotoObjectRef == objectRef) {
                setState(() => _resolvedBytes = bytes);
              }
            });
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: _memoryErrorWidget,
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          _markLoadFailed();
          return _ProofPhotoUnavailable(label: widget.unavailableText);
        }
        return const SizedBox.expand();
      },
    );
  }
}

class _ProofPhotoUnavailable extends StatelessWidget {
  const _ProofPhotoUnavailable({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: Sizes.twoXLarge,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.jeebText.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
