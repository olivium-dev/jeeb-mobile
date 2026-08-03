import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import 'map_capture_controller.dart';

/// The bottom sheet docked over the capture map (redesign-2026-08 screen 09,
/// HTML tpl 538-561): a grab handle, the pinned-point card, and the confirm
/// CTA.
///
/// What the board draws here and this sheet deliberately does NOT build:
/// the "Pickup set / 2 · Drop-off" step chips, the search field and the
/// saved-place pills. All three are refused in
/// `per-screen-revised/09-location-picker.md` §3 — the create flow's location
/// leg is a SINGLE point, there is no geocoding source in the app, and drawing
/// either would fabricate state the backend does not have.
class CapturePickerSheet extends StatelessWidget {
  const CapturePickerSheet({
    super.key,
    required this.onPin,
    required this.isConfirming,
    this.controller,
  });

  /// Grab-handle geometry (tpl 539).
  static const double _handleWidth = 44;
  static const double _handleHeight = 5;

  /// The board's CTA height (tpl 559). `OmdsPrimaryButton` defaults to 48.
  static const double ctaHeight = 56;

  /// How much of the screen bottom this sheet occupies, EXCLUDING the device
  /// safe-area inset. Published so the map underneath can lift its floating
  /// controls clear of the sheet instead of hiding them behind it — the sheet
  /// owns its own composition, so it is the only honest source for this.
  ///
  /// = top pad 12 + handle 5 + gap 16 + card ~48 + gap 16 + CTA 56 + pad 32.
  static const double dockedClearance = 185;

  /// Fires the "Pin Location" confirm.
  final VoidCallback onPin;

  /// Disables the CTA while the pin is being handed back.
  final bool isConfirming;

  /// The live map centre. Null on the placeholder route (no Maps key, B-23),
  /// which is exactly why the pinned-point card is conditional: with no map
  /// there is no coordinate to show, and inventing one is the bug JEBV4-176
  /// removed.
  final MapCaptureController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final live = controller;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmdsBorderRadius.topXLarge,
        boxShadow: JeebShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.small,
            Spacing.xLarge,
            Spacing.twoXLarge,
          ),
          // TODO(redesign-24): step chips omitted — single-point leg; owner decision D-09a.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: _handleWidth,
                  height: _handleHeight,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: OmdsBorderRadius.pill,
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
                      borderRadius: OmdsBorderRadius.pill,
                      // A disabled CTA drops its lift (kit §1.6).
                      boxShadow: isConfirming ? null : JeebShadows.ctaNavy,
                    ),
                    child: OmdsPrimaryButton(
                      text: l10n.captureLocationPinCta,
                      isEnabled: !isConfirming,
                      height: ctaHeight,
                      borderRadius: OmdsBorderRadius.pill,
                      textStyle: context.jeebText.button,
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

/// The pinned-point card (tpl 549): a red pin and the live coordinate under it.
///
/// The board draws a street address ("Rue Monot 42, Achrafieh"). We show the
/// coordinate instead, because the app has no reverse-geocode source — the only
/// implementation in the tree snaps to a hardcoded five-entry Beirut catalogue,
/// and rendering that as "the address" is the JEBV4-176 class of fabrication.
class _PinnedPointCard extends StatelessWidget {
  const _PinnedPointCard({required this.controller});

  /// tpl 550 — the pin glyph.
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
          return JeebOutlinedCard(
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
                          .copyWith(color: scheme.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
