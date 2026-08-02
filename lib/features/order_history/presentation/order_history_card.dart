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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/order_history/order_history_card_preview_test.dart
// ===========================================================================
//
// Widget previews for [OrderHistoryCard] — `flutter widget-preview start`.
//
// The card is the dumbest widget in the feature: it takes one [OrderSummary]
// plus an `onTap` and renders. No cubit, no `sl`, no repository — so every
// state below is a pure function of its fixture and is network-free by
// construction, not merely by the guard in [jeebPreviewHost].
//
// Fixture values reuse `test/features/order_history/order_history_card_test.dart`
// (`ord-1`, 2026-05-17 10:30 UTC, `$1,234.00`, the null/0 amounts) so the canvas
// and the widget suite describe the same card. Addresses are Beirut streets
// because address LENGTH is the variable that breaks this layout, and the demo
// corpus is Lebanese.
//
// ## Two things the widget suite cannot see, and the canvas can
//
// **1. `_Footer` has no flex on the amount.** The footer Row is
// `[_TierBadge(32) · gap(8) · Expanded(tier label) · Text(amount)]`. The amount
// is NOT wrapped in `Flexible`, so it is laid out at its natural width first and
// `Expanded` gets whatever is left — possibly nothing. A wide money token
// therefore squeezes the tier label to zero and then overflows the Row. It is a
// hard `RenderFlex overflowed` (yellow stripes), not a silent ellipsis:
//
// | amount            | 100%           | 150%       | 200%       |
// |-------------------|----------------|------------|------------|
// | `$12.00`          | —              | —          | —          |
// | `$1,234.00`       | —              | —          | —          |
// | `LBP 1,335,000.00`| —              | **OVERFLOW** | **OVERFLOW** |
// | `LBP …,890.99`    | tier label wraps | OVERFLOW | OVERFLOW   |
//
// The exact trigger point is font-dependent (measured under the flutter_test
// font, which is wider than Roboto), but the shape is not: a non-USD ISO code
// plus grouped digits is the widest token this card ever renders, and LBP is a
// shipping currency. See [orderHistoryCardLongContent].
//
// **2. The tier label has no `maxLines`.** Squeezed, it wraps instead of
// ellipsizing, so the card silently grows taller — 156 pt → 188 pt for a
// nine-figure LBP amount at 100% text. In a list that is a reflow, not a clip.
//
// The address lines, by contrast, are honest: `maxLines: 2` + `ellipsis`.

/// Phone width; height fits the measured 100%-text card in BOTH locales
/// (156 pt EN and AR). The 200%-text card measures 440–530 pt, which no honest
/// box height can contain, so the matrix's third rendering clips.
const Size _orderHistoryCardBox = Size(390, 170);

/// Taller box for the two-line-address ceiling (measured 196 pt EN and AR;
/// 724 pt EN / 812 pt AR at 200% text).
const Size _orderHistoryCardTallBox = Size(390, 210);

/// The anchor timestamp from `order_history_card_test.dart`, so a preview and a
/// widget test never disagree about when the order was placed. Rendered through
/// `toLocal()` by the card (SW-03), so the visible time follows the reviewer's
/// machine — never assert on it.
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
///
/// Every other state is read against this one. Three contracts are visible at
/// once — the date is device-LOCAL (SW-03: the fixture is 10:30 **UTC**, so this
/// label moves with the reviewer's timezone and that is correct), the status
/// pill takes the success role from `OrderStatusChip`, and the amount is a
/// single `MoneyFormat` token wrapped in a Unicode LTR isolate (JEBV4-98 / F10).
///
/// Matrixed because the AR RTL card is the only place that isolate is checkable:
/// the `$` must stay left of the digits inside an Arabic paragraph, and the
/// whole card — chip, tier badge, both address icons — must mirror, which it can
/// only do because every inset here is `EdgeInsetsDirectional`.
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
///
/// The regression this guards is the one that shipped: every history row read
/// `$0.00`, including the completed $12 order, because a null `amountMinor` was
/// coerced to zero. An absent price is UNKNOWN, and a fabricated zero is a lie
/// about what the customer paid. The em-dash is muted (`onSurfaceVariant`)
/// rather than styled like a real amount, and carries an explicit
/// "Amount unavailable" screen-reader label — inspect the semantics, not just
/// the glyph.
///
/// In-flight is the realistic setting for it: the requests-list endpoint drops
/// the amount for rows that are not yet settled.
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
///
/// `hasKnownAmount` treats `0` exactly like `null` (same rule as the receipt):
/// a priced request is never actually worth zero, so a 0 means enrichment
/// broke upstream. Distinct from the null case because the two arrive by
/// different routes — null is a missing key, 0 is a present-but-broken value —
/// and only one of them used to be handled.
///
/// Also the cancelled palette: `OrderStatusChip` swings to the error role here,
/// which is the one chip colour a dark-mode contrast check has to look at.
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
///
/// One address missing is far more common than both — geocoding fails per leg —
/// and the failure has to stay legible: the pickup line falls back to the
/// localized "Address unavailable" while the dropoff still reads normally, so a
/// customer can tell which end is unknown. An empty string here must never
/// collapse the row or render a bare icon with nothing beside it.
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
///
/// `OrderRequestStatus.parse` maps anything outside its vocabulary to
/// [OrderRequestStatus.unknown] rather than crashing, and `unknown.tab` buckets
/// it into **active** so a new backend state is visible to the user and to QA
/// instead of being silently dropped. The pill must therefore read the localized
/// "In progress" — never the raw wire token, never an empty pill.
///
/// This is the state a gateway deploy produces on a mobile build that has not
/// shipped yet, so it is worth knowing what it looks like before it happens.
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
///
/// `LBP 1,335,000.00` is a $15 delivery at the 2026 peg — not a synthetic
/// number — and it is the widest token this card renders. Both addresses run
/// past their two-line limit so the ellipsis is visible on each, and in AR that
/// ellipsis has to land on the LEFT.
///
/// **Look at the 200% card in this matrix: it overflows.** The amount `Text` in
/// `_Footer` has no `Flexible`, so it claims its natural width, `Expanded`
/// hands the tier label nothing, and the Row runs off the trailing edge with
/// striped overflow. It starts around 150% text under the test font and it is
/// currency-shaped, not length-shaped: `$1,234.00` survives 200% comfortably
/// while any `LBP …` token does not. The AR RTL card is the same defect
/// mirrored — the amount runs off the LEADING edge there.
///
/// Nothing above the banner has been changed to fix this; the preview exists so
/// the fix has a before picture. See the table in the section prose.
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
