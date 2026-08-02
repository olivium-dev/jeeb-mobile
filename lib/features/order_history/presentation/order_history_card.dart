import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';
import 'order_status_chip.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.yMMMd(locale).add_jm().format(
          order.createdAt.toLocal(),
        );
    final amountKnown = order.hasKnownAmount;
    final amountLabel = amountKnown
        ? MoneyFormat.format(order.amountMinor! / 100, currency: order.currency)
        : '—';
    final amountSemantics =
        amountKnown ? amountLabel : l10n.orderHistoryAmountUnavailable;

    return Semantics(
      identifier: 'order_history_card_${order.id}',
      button: true,
      container: true,
      label: l10n.orderHistoryCardSemanticLabel(order.id),
      child: InkWell(
        key: Key('order-history-card-${order.id}'),
        onTap: onTap,
        borderRadius: OmdsBorderRadius.medium,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                dateLabel: dateLabel,
                status: order.status,
              ),
              const SizedBox(height: Spacing.xSmall),
              _AddressLine(
                icon: Icons.trip_origin,
                iconColor: scheme.primary,
                label: order.pickupAddress.isEmpty
                    ? l10n.orderHistoryAddressMissing
                    : order.pickupAddress,
              ),
              const SizedBox(height: Spacing.twoXSmall),
              _AddressLine(
                icon: Icons.location_on_outlined,
                iconColor: scheme.error,
                label: order.dropoffAddress.isEmpty
                    ? l10n.orderHistoryAddressMissing
                    : order.dropoffAddress,
              ),
              const SizedBox(height: Spacing.xSmall),
              _Footer(
                tier: order.tier,
                amountLabel: amountLabel,
                amountKnown: amountKnown,
                amountSemantics: amountSemantics,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dateLabel, required this.status});

  final String dateLabel;
  final OrderRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            dateLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        OrderStatusChip(status: status),
      ],
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Sizes.medium, color: iconColor),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.tier,
    required this.amountLabel,
    required this.amountKnown,
    required this.amountSemantics,
  });

  final OrderTier tier;
  final String amountLabel;
  final bool amountKnown;
  final String amountSemantics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        _TierBadge(tier: tier),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            _tierLabel(tier, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          amountLabel,
          semanticsLabel: amountSemantics,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: amountKnown ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _tierLabel(OrderTier tier, AppLocalizations l10n) {
    switch (tier) {
      case OrderTier.flash:
        return l10n.tierSelectionTierFlash;
      case OrderTier.express:
        return l10n.tierSelectionTierExpress;
      case OrderTier.standard:
        return l10n.tierSelectionTierStandard;
      case OrderTier.onTheWay:
        return l10n.tierSelectionTierOnTheWay;
      case OrderTier.eco:
        return l10n.tierSelectionTierEco;
    }
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final OrderTier tier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.twoXLarge,
      height: Sizes.twoXLarge,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: OmdsBorderRadius.xSmall,
      ),
      child: Icon(
        _iconFor(tier),
        size: Sizes.medium,
        color: scheme.onSecondaryContainer,
      ),
    );
  }

  static IconData _iconFor(OrderTier tier) {
    switch (tier) {
      case OrderTier.flash:
        return Icons.flash_on;
      case OrderTier.express:
        return Icons.rocket_launch_outlined;
      case OrderTier.standard:
        return Icons.local_shipping_outlined;
      case OrderTier.onTheWay:
        return Icons.alt_route;
      case OrderTier.eco:
        return Icons.eco_outlined;
    }
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width; height fits the measured 100%-text card in BOTH locales
/// (156 pt EN and AR). The 200%-text card measures 440–530 pt, which no honest
const Size _orderHistoryCardBox = Size(390, 170);

/// Taller box for the two-line-address ceiling (measured 196 pt EN and AR;
/// 724 pt EN / 812 pt AR at 200% text).
const Size _orderHistoryCardTallBox = Size(390, 210);

/// The anchor timestamp from `order_history_card_test.dart`, so a preview and a
/// widget test never disagree about when the order was placed. Rendered through
final DateTime _orderHistoryCardCreatedAt = DateTime.utc(2026, 5, 17, 10, 30);

/// Builds the card the way `order_history_screen.dart` builds it — the only
/// production caller — so a preview cannot show a row the app never ships.
Widget _orderHistoryCardHosted({
  required String id,
  required OrderRequestStatus status,
  OrderTier tier = OrderTier.express,
  String pickupAddress = 'Hamra Street, Beirut',
  String dropoffAddress = 'Gemmayzeh, Beirut',
  int? amountMinor = 1234_00,
  String currency = 'USD',
}) {
  return OrderHistoryCard(
    order: OrderSummary(
      id: id,
      createdAt: _orderHistoryCardCreatedAt,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      status: status,
      tier: tier,
      amountMinor: amountMinor,
      currency: currency,
    ),
    onTap: () {},
  );
}

/// The reference rendering: a completed, priced order.
/// Every other state is read against this one. Three contracts are visible at
@JeebPreview(
  group: 'order_history',
  name: 'Delivered · priced',
  size: _orderHistoryCardBox,
  matrix: true,
)
Widget orderHistoryCardDelivered() => _orderHistoryCardHosted(
      id: 'ord-1',
      status: OrderRequestStatus.delivered,
    );

/// T11 / SW-02 made visible: a MISSING amount renders as an em-dash.
/// The regression this guards is the one that shipped: every history row read
@JeebPreview(
  group: 'order_history',
  name: 'Amount unknown (em-dash)',
  size: _orderHistoryCardBox,
)
Widget orderHistoryCardAmountUnknown() => _orderHistoryCardHosted(
      id: 'ord-2',
      status: OrderRequestStatus.enRoute,
      tier: OrderTier.flash,
      pickupAddress: 'Mar Mikhael, Beirut',
      dropoffAddress: 'Verdun, Beirut',
      amountMinor: null,
    );

/// A **zero** on the wire is also unknown, not free.
/// `hasKnownAmount` treats `0` exactly like `null` (same rule as the receipt):
@JeebPreview(
  group: 'order_history',
  name: 'Cancelled · zero wire amount',
  size: _orderHistoryCardBox,
)
Widget orderHistoryCardCancelledZeroAmount() => _orderHistoryCardHosted(
      id: 'ord-3',
      status: OrderRequestStatus.cancelled,
      tier: OrderTier.standard,
      pickupAddress: 'Achrafieh, Beirut',
      dropoffAddress: 'Badaro, Beirut',
      amountMinor: 0,
    );

/// Partial enrichment: the gateway returned the order but not the pickup label.
/// One address missing is far more common than both — geocoding fails per leg —
@JeebPreview(
  group: 'order_history',
  name: 'Pickup address missing',
  size: _orderHistoryCardBox,
)
Widget orderHistoryCardAddressMissing() => _orderHistoryCardHosted(
      id: 'ord-4',
      status: OrderRequestStatus.matched,
      tier: OrderTier.standard,
      pickupAddress: '',
      dropoffAddress: 'Sodeco Square, Beirut',
      amountMinor: 850,
    );

/// Forward compatibility: a status this build has never heard of.
/// `OrderRequestStatus.parse` maps anything outside its vocabulary to
@JeebPreview(
  group: 'order_history',
  name: 'Unknown backend status',
  size: _orderHistoryCardBox,
)
Widget orderHistoryCardUnknownStatus() => _orderHistoryCardHosted(
      id: 'ord-5',
      status: OrderRequestStatus.unknown,
      tier: OrderTier.eco,
      pickupAddress: 'Jounieh Old Souk',
      dropoffAddress: 'Antelias Highway',
      amountMinor: 2400,
    );

/// The layout ceiling: two full-length addresses and a realistic LBP price.
/// `LBP 1,335,000.00` is a $15 delivery at the 2026 peg — not a synthetic
@JeebPreview(
  group: 'order_history',
  name: 'Long addresses · LBP ceiling',
  size: _orderHistoryCardTallBox,
  matrix: true,
)
Widget orderHistoryCardLongContent() => _orderHistoryCardHosted(
      id: 'ord-6',
      status: OrderRequestStatus.pickedUp,
      tier: OrderTier.onTheWay,
      pickupAddress: 'Building 42, Rue Abdel Aziz, beside the American '
          'University of Beirut main gate, Hamra, Beirut, Lebanon',
      dropoffAddress: 'Apartment 8B, Sursock Street, third floor, the blue '
          'door beside the bakery, Achrafieh, Beirut, Lebanon',
      amountMinor: 133500000,
      currency: 'LBP',
    );
