import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/capture_pin_purpose.dart';
import 'map_capture_controller.dart';

/// The frosted sheet docked over the capture map (MIDNIGHT R11): a grab handle,
/// the pinned-point card, and the confirm CTA. R11's caption — "the whole
/// picker lives on one frosted bottom sheet".
///
/// What the board draws here and this sheet deliberately does NOT build:
/// the "Pickup set / 2 · Drop-off" step chips, the search field and the
/// saved-place pills. All three are refused in
/// `per-screen-revised/09-location-picker.md` §3 — the create flow's location
/// leg is a SINGLE point, and drawing either would fabricate state the backend
/// does not have. Reverse-geocoding only labels that one captured coordinate.
/// (Two-leg vs one-coordinate remains owner question Q2.)
class CapturePickerSheet extends StatelessWidget {
  const CapturePickerSheet({
    super.key,
    required this.onPin,
    required this.isConfirming,
    this.controller,
    this.purpose = CapturePinPurpose.dropOff,
  });

  /// Grab-handle geometry (R11: 44 × 5, white 20%).
  static const double _handleWidth = 44;
  static const double _handleHeight = 5;

  /// The board's CTA height. `OmdsPrimaryButton` defaults to 48.
  static const double ctaHeight = 56;

  /// How much of the screen bottom this sheet occupies, EXCLUDING the device
  /// safe-area inset. Published so the map underneath can lift its floating
  /// controls clear of the sheet instead of hiding them behind it — the sheet
  /// owns its own composition, so it is the only honest source for this.
  ///
  /// = top pad 12 + handle 5 + gap 16 + card ~78 + gap 16 + CTA 56 + pad 28.
  /// The card grew by one caption line ("Selected point") above the coordinate.
  static const double dockedClearance = 211;

  /// Fires the "Pin Location" confirm.
  final VoidCallback onPin;

  /// Disables the CTA while the pin is being handed back.
  final bool isConfirming;

  /// The live map centre. Null when the caller mounts the screen without a map
  /// (dev seam / tests), which is exactly why the pinned-point card is
  /// conditional: with no map there is no coordinate to show, and inventing one
  /// is the bug JEBV4-176 removed.
  final MapCaptureController? controller;

  /// What the picked point is for — drives the CTA copy so the button does not
  /// claim "Confirm drop-off" on the pickup leg.
  final CapturePinPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final live = controller;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadiusDirectional.vertical(
          top: Radius.circular(JeebRadii.sheet),
        ),
        border: BorderDirectional(
          top: BorderSide(color: scheme.outline),
        ),
        boxShadow: JeebShadows.floatNav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.small,
            Spacing.xLarge,
            Spacing.large,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: _handleWidth,
                  height: _handleHeight,
                  decoration: BoxDecoration(
                    color: glass.glassBorderVivid,
                    borderRadius: BorderRadius.circular(JeebRadii.pill),
                  ),
                ),
              ),
              if (live != null) ...[
                const SizedBox(height: Spacing.medium),
                _PinnedPointCard(controller: live),
              ],
              const SizedBox(height: Spacing.medium),
              JeebCtaFooter.single(
                // The sheet already owns the gutters and the bottom inset.
                padding: EdgeInsetsDirectional.zero,
                child: Semantics(
                  identifier: 'capture_location_pin_cta',
                  button: true,
                  child: live == null
                      ? _ConfirmCta(
                          enabled: !isConfirming,
                          onPin: onPin,
                          purpose: purpose,
                        )
                      : ListenableBuilder(
                          listenable: live,
                          builder: (context, _) => _ConfirmCta(
                            enabled: !isConfirming && live.isReady,
                            onPin: onPin,
                            purpose: purpose,
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

/// The "Confirm drop-off" CTA button, factored out so its enabled state can
/// be driven either statically ([CapturePickerSheet.isConfirming] alone, no
/// map) or reactively (also gated on [MapCaptureController.isReady]).
class _ConfirmCta extends StatelessWidget {
  const _ConfirmCta({
    required this.enabled,
    required this.onPin,
    required this.purpose,
  });

  final bool enabled;
  final VoidCallback onPin;
  final CapturePinPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(JeebRadii.pill),
        // A disabled CTA drops its lift (kit §1.6).
        boxShadow: enabled ? JeebShadows.ctaOrange : null,
      ),
      child: OmdsPrimaryButton(
        text: purpose.confirmCta(l10n),
        isEnabled: enabled,
        height: CapturePickerSheet.ctaHeight,
        borderRadius: OmdsBorderRadius.pill,
        textStyle:
            context.jeebText.button.copyWith(fontWeight: FontWeight.w700),
        onTap: onPin,
      ),
    );
  }
}

/// The pinned-point card: a red pin, the selected point, and the accuracy
/// meta line the board draws under the address.
///
/// The value is a best-effort address from the device's OS geocoder. Until that
/// lookup succeeds — or whenever it fails — the exact coordinate remains the
/// honest fallback.
class _PinnedPointCard extends StatelessWidget {
  const _PinnedPointCard({required this.controller});

  /// The board's pin glyph inside the card.
  static const double _pinSize = 19;

  /// Coordinate precision, matching the create draft's own label.
  static const int _fractionDigits = 4;

  final MapCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'capture_location_address_card',
      container: true,
      explicitChildNodes: true,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final centre = controller.center;
          final candidate = centre.address?.trim();
          final address = candidate == null || candidate.isEmpty
              ? null
              : candidate;
          final label = address ??
              '${centre.latitude.toStringAsFixed(_fractionDigits)}, '
                  '${centre.longitude.toStringAsFixed(_fractionDigits)}';
          return JeebGlassCard(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.small,
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: _pinSize, color: scheme.error),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.captureLocationSelectedPoint,
                        style: context.jeebText.bodySmall
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                      // A lat/long pair reorders under RTL; a resolved address
                      // keeps the ambient locale's own direction instead.
                      Directionality(
                        textDirection: address == null
                            ? TextDirection.ltr
                            : Directionality.of(context),
                        child: Text(
                          label,
                          style: context.jeebText.cardTitle
                              .copyWith(color: scheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // TODO(midnight): omitted — the board's "GPS · accurate to 8 m"
                // meta line has no accuracy wire value on this leg.
              ],
            ),
          );
        },
      ),
    );
  }
}
