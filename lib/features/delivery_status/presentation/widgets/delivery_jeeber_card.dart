import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_summary.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Shows the matched Jeeber's avatar, display name, vehicle, and rating.
/// Renders a `looking for…` placeholder while [jeeber] is null. The card
/// intentionally does not embed the Contact CTA — that's owned by the
class DeliveryJeeberCard extends StatelessWidget {
  const DeliveryJeeberCard({super.key, required this.jeeber});

  static const Key rootKey = Key('delivery-status-jeeber-card');

  final JeeberSummary? jeeber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      key: rootKey,
      title: l10n.deliveryJeeberCardTitle,
      content: jeeber == null ? _Waiting() : _JeeberRow(jeeber: jeeber!),
    );
  }
}

class _Waiting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const OmdsLoadingState(
          size: Sizes.xLarge,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Text(
            AppLocalizations.of(context).deliveryJeeberWaiting,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _JeeberRow extends StatelessWidget {
  const _JeeberRow({required this.jeeber});

  final JeeberSummary jeeber;

  String _initial() {
    final trimmed = jeeber.displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OmdsProfileAvatar(
          initial: _initial(),
          profilePicUrl: jeeber.avatarUrl,
          size: Sizes.threeXLarge,
          backgroundColor: colorScheme.primaryContainer,
          initialColor: colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                jeeber.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Sizes.threeXSmall),
              Text(
                jeeber.vehicleLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (jeeber.rating != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.small,
              vertical: Spacing.twoXSmall,
            ),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: OmdsBorderRadius.small,
            ),
            child: Text(
              l10n.deliveryJeeberRating(jeeber.rating!.toStringAsFixed(1)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [DeliveryJeeberCard] — run with

/// Phone width by the tallest 200%-text rendering of the five single-row
/// states (278 dp, 'Matched · rating shown'). Sizing the box to the EN-light
const Size _deliveryJeeberCardBox = Size(390, 300);

/// The wrapping ceiling: 742 dp at 200% text, and that number is the finding
/// rather than a canvas detail.
const Size _deliveryJeeberCardTallCardBox = Size(390, 780);

/// A jeeber's name as the gateway sends it when the account carries a full
/// legal name instead of the privacy-preserving "first name + initial" form.
const String _deliveryJeeberCardLongDisplayName = 'Abdulrahman Al-Muhandis Al-Trabulsi';

/// `vehicleLabel` is free text off the jeeber's KYC record, not an enum — this
/// is the longest plausible one, and it lands in the same column as the name.
const String _deliveryJeeberCardLongVehicleLabel =
    'Pickup truck with refrigerated cargo box (large)';

/// [DeliveryJeeberCard] takes one nullable prop, so a preview is a constructor
/// call; the [TickerMode] is the only scaffolding, and it is inert for every
Widget _deliveryJeeberCardHosted(JeeberSummary? jeeber) => TickerMode(
      enabled: false,
      child: DeliveryJeeberCard(jeeber: jeeber),
    );

/// The happy path, and the fixture `test/delivery_status_screen_test.dart`
/// already pins: a matched jeeber with the short privacy-preserving name, a
@JeebPreview(
  group: 'delivery_status',
  name: 'Matched · rating shown',
  size: _deliveryJeeberCardBox,
  matrix: true,
)
Widget deliveryJeeberCardMatched() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: 'Karim H.',
        vehicleLabel: 'Scooter',
        phoneE164: '+96171000000',
        rating: 4.8,
      ),
    );

/// Pre-match: `jeeber == null`, so the card swaps its entire content for the
/// spinner + "Looking for a Jeeber…" placeholder.
@JeebPreview(
  group: 'delivery_status',
  name: 'Waiting for a match',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardWaiting() => _deliveryJeeberCardHosted(null);

/// A matched jeeber with **no** rating: the chip is dropped entirely
/// (`if (jeeber.rating != null)`) rather than rendered as "—" or "0.0".
@JeebPreview(
  group: 'delivery_status',
  name: 'No rating yet',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardNoRating() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: 'Kamal Hajj',
        vehicleLabel: 'Motorbike',
      ),
    );

/// Degraded data: the gateway returned an empty `displayName`.
/// `_initial()` guards this and paints '?' in the avatar disc — and that guard
@JeebPreview(
  group: 'delivery_status',
  name: 'Blank display name',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardBlankName() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: '',
        vehicleLabel: 'Pickup truck',
        rating: 3.0,
      ),
    );

/// The layout ceiling: longest plausible name AND longest plausible vehicle
/// label, with the rating chip present to squeeze them.
@JeebPreview(
  group: 'delivery_status',
  name: 'Longest content',
  size: _deliveryJeeberCardTallCardBox,
  matrix: true,
)
Widget deliveryJeeberCardLongContent() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: _deliveryJeeberCardLongDisplayName,
        vehicleLabel: _deliveryJeeberCardLongVehicleLabel,
        rating: 5.0,
      ),
    );

/// Bidi: an Arabic name and vehicle label inside the English UI.
/// The name and the vehicle label are the only free text on this card, so they
@JeebPreview(
  group: 'delivery_status',
  name: 'Arabic name in EN UI',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardArabicName() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: 'كريم حجازي',
        vehicleLabel: 'دراجة نارية',
        rating: 4.5,
      ),
    );
