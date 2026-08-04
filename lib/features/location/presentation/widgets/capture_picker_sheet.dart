import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../l10n/app_localizations.dart';
import 'map_capture_controller.dart';

/// The frosted sheet docked over the capture map (MIDNIGHT R11): a grab handle,
/// the pinned-point card, and the confirm CTA. R11's caption — "the whole
/// picker lives on one frosted bottom sheet".
///
/// What the board draws here and this sheet deliberately does NOT build:
/// the "Pickup set / 2 · Drop-off" step chips, the search field and the
/// saved-place pills. All three are refused in
/// `per-screen-revised/09-location-picker.md` §3 — the create flow's location
/// leg is a SINGLE point, there is no geocoding source in the app, and drawing
/// either would fabricate state the backend does not have. (Two-leg vs
/// one-coordinate remains owner question Q2.)
class CapturePickerSheet extends StatelessWidget {
  const CapturePickerSheet({
    super.key,
    required this.onPin,
    required this.isConfirming,
    this.controller,
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
  /// = top pad 12 + handle 5 + gap 16 + card ~60 + gap 16 + CTA 56 + pad 28.
  static const double dockedClearance = 193;

  /// Fires the "Pin Location" confirm.
  final VoidCallback onPin;

  /// Disables the CTA while the pin is being handed back.
  final bool isConfirming;

  /// The live map centre. Null when the caller mounts the screen without a map
  /// (dev seam / tests), which is exactly why the pinned-point card is
  /// conditional: with no map there is no coordinate to show, and inventing one
  /// is the bug JEBV4-176 removed.
  final MapCaptureController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(JeebRadii.pill),
                      // A disabled CTA drops its lift (kit §1.6).
                      boxShadow: isConfirming ? null : JeebShadows.ctaOrange,
                    ),
                    child: OmdsPrimaryButton(
                      // TODO(midnight): l10n-queued — tile literal is
                      // "Confirm drop-off".
                      text: l10n.captureLocationPinCta,
                      isEnabled: !isConfirming,
                      height: ctaHeight,
                      borderRadius: OmdsBorderRadius.pill,
                      textStyle: context.jeebText.button
                          .copyWith(fontWeight: FontWeight.w700),
                      onTap: onPin,
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

/// The pinned-point card: a red pin, the live coordinate, and the accuracy
/// meta line the board draws under the address.
///
/// The board draws a street address ("Rue Monot 42, Achrafieh"). We show the
/// coordinate instead, because the app has no reverse-geocode source — the only
/// implementation in the tree snaps to a hardcoded five-entry Beirut catalogue,
/// and rendering that as "the address" is the JEBV4-176 class of fabrication.
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
    return Semantics(
      identifier: 'capture_location_address_card',
      container: true,
      explicitChildNodes: true,
      child: ListenableBuilder(
        listenable: controller,
        // TODO(redesign-24): needs gateway reverse-geocode — omitted, not faked.
        builder: (context, _) {
          final centre = controller.center;
          final label = '${centre.latitude.toStringAsFixed(_fractionDigits)}, '
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
                  // A latitude/longitude pair reorders inside an RTL paragraph
                  // (the comma flips the two numbers), so the whole run is
                  // pinned to LTR.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      label,
                      style: context.jeebText.cardTitle
                          .copyWith(color: scheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // TODO(midnight): omitted — the board's "GPS · accurate to 8 m"
                // meta line has no wire value on this leg (no reverse-geocode).
              ],
            ),
          );
        },
      ),
    );
  }
}
