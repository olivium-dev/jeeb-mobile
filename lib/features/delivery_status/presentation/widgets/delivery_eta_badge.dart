import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Compact ETA pill rendered at the top of the screen while the parcel is
/// in transit. Hidden by the screen layer in every other lifecycle state.
class DeliveryEtaBadge extends StatelessWidget {
  const DeliveryEtaBadge({super.key, required this.minutes});

  static const Key rootKey = Key('delivery-status-eta-badge');

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isArriving = minutes <= 1;
    return Container(
      key: rootKey,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: OmdsBorderRadius.large,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            l10n.deliveryEtaLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            isArriving
                ? l10n.deliveryEtaArriving
                : l10n.deliveryEtaMinutes(minutes),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [DeliveryEtaBadge] — run with

/// The width the status header row really gets on a 390pt phone: `_Body`'s
/// `SingleChildScrollView` padding is `Spacing.large` (20) on both sides.
const double _deliveryEtaBadgeRowWidth = 350;

/// The same row on the narrowest phone the app still lays out for (320pt):
/// `320 - 20 - 20 = 280`.
const double _deliveryEtaBadgeNarrowRowWidth = 280;

/// Canvas box for the header row. Tall enough for the 200% rendering, where the
/// caption wraps beside a 64pt pill instead of ellipsizing.
const Size _deliveryEtaBadgeRowBox = Size(390, 220);

/// Puts [child] at the width its production row really has, centred in the
/// canvas.
Widget _deliveryEtaBadgeHosted(Widget child, {double width = _deliveryEtaBadgeRowWidth}) => Center(
      child: SizedBox(width: width, child: child),
    );

/// Reproduces the status header row from `_Body` in
/// `delivery_status_screen.dart`: an [Expanded] "Delivery #id" caption in
/// `bodySmall` / `onSurfaceVariant`, spread apart from the badge and vertically
class _DeliveryEtaBadgeStatusHeaderRow extends StatelessWidget {
  const _DeliveryEtaBadgeStatusHeaderRow({required this.deliveryId, required this.minutes});

  final String deliveryId;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            l10n.deliveryStatusIdSubtitle(deliveryId),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DeliveryEtaBadge(minutes: minutes),
      ],
    );
  }
}

/// The state that ships: a courier a few minutes out, in the row the screen
/// really gives it.
@JeebPreview(group: 'delivery_status', name: 'In transit · 7 min', size: _deliveryEtaBadgeRowBox)
Widget deliveryEtaBadgeTypical() => _deliveryEtaBadgeHosted(
      const _DeliveryEtaBadgeStatusHeaderRow(deliveryId: 'd-1', minutes: 7),
    );

/// The other branch, and the reason this widget takes `minutes` rather than a
/// pre-formatted string: at one minute the number is replaced by words.
@JeebPreview(group: 'delivery_status', name: 'Arriving now · 1 min', size: _deliveryEtaBadgeRowBox)
Widget deliveryEtaBadgeArriving() => _deliveryEtaBadgeHosted(
      const _DeliveryEtaBadgeStatusHeaderRow(deliveryId: 'd-2', minutes: 1),
    );

/// The off-by-one guard: two minutes is the first value that is NOT "arriving".
/// `minutes <= 1` is the whole of the branch — written once, easy to widen by
@JeebPreview(group: 'delivery_status', name: 'Threshold · 2 min', size: _deliveryEtaBadgeRowBox)
Widget deliveryEtaBadgeThreshold() => _deliveryEtaBadgeHosted(
      const _DeliveryEtaBadgeStatusHeaderRow(deliveryId: 'd-3', minutes: 2),
    );

/// Longest plausible numeric content: the ceiling of the ETA a courier was
/// allowed to promise.
@JeebPreview(group: 'delivery_status', name: 'Ceiling · 120 min', size: _deliveryEtaBadgeRowBox)
Widget deliveryEtaBadgeCeiling() => _deliveryEtaBadgeHosted(
      const _DeliveryEtaBadgeStatusHeaderRow(deliveryId: 'd-4', minutes: 120),
    );

/// The bad-data state, and the second reason the `<= 1` branch exists.
/// `DeliverySnapshot.etaMinutes` is an unvalidated `int?`. The gateway contract
@JeebPreview(group: 'delivery_status', name: 'Past due · negative ETA', size: _deliveryEtaBadgeRowBox)
Widget deliveryEtaBadgePastDue() => _deliveryEtaBadgeHosted(
      const _DeliveryEtaBadgeStatusHeaderRow(deliveryId: 'PAST-DUE-9', minutes: -6),
    );

/// The worst case a real device can produce: the ceiling ETA, on the narrowest
/// phone the app lays out for, at the 200% text ceiling.
@JeebPreview(group: 'delivery_status', name: 'Narrow phone · 120 min', size: _deliveryEtaBadgeRowBox)
Widget deliveryEtaBadgeNarrowCeiling() => _deliveryEtaBadgeHosted(
      const _DeliveryEtaBadgeStatusHeaderRow(deliveryId: 'NARROW-320', minutes: 120),
      width: _deliveryEtaBadgeNarrowRowWidth,
    );
