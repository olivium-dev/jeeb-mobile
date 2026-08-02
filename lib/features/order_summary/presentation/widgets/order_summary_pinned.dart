import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/order_summary.dart';
import '../order_summary_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class OrderSummaryPinned extends StatelessWidget {
  const OrderSummaryPinned({
    super.key,
    required this.summary,
    this.onOpenChat,
    this.onTrack,
    this.dense = false,
  });

  final OrderSummary summary;

  final VoidCallback? onOpenChat;

  final VoidCallback? onTrack;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = OrderSummaryL10n.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final priceText = summary.price.toStringAsFixed(2);

    return Semantics(
      identifier: 'order_summary_pinned',
      container: true,
      explicitChildNodes: true,
      child: Container(
        margin: EdgeInsetsDirectional.all(dense ? Spacing.small : Spacing.medium),
        padding: const EdgeInsetsDirectional.all(Spacing.medium),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.medium,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OmdsProfileAvatar(
                  initial: _initial(summary.jeeberName),
                  profilePicUrl: summary.jeeberAvatarUrl,
                  size: Sizes.fourXLarge,
                ),
                const SizedBox(width: Spacing.small),
                Expanded(child: _JeeberBlock(summary: summary)),
                const SizedBox(width: Spacing.small),
                _PriceBlock(
                  label: l10n.priceLabel,
                  amount: priceText,
                  currency: summary.currency,
                ),
              ],
            ),
            const SizedBox(height: Spacing.small),
            Row(
              children: [
                Expanded(
                  child: _Fact(
                    identifier: 'order_summary_eta',
                    icon: Icons.access_time,
                    label: l10n.etaLabel,
                    value: summary.etaMinutes != null
                        ? l10n.etaMinutes(summary.etaMinutes!)
                        : l10n.etaPending,
                  ),
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: _Fact(
                    identifier: 'order_summary_tier',
                    icon: Icons.bolt_outlined,
                    label: l10n.tierLabel,
                    value: summary.tier.trim().isEmpty
                        ? l10n.tierPending
                        : l10n.tierName(summary.tier),
                  ),
                ),
              ],
            ),
            if (summary.itemSummary != null) ...[
              const SizedBox(height: Spacing.small),
              _Fact(
                identifier: 'order_summary_item',
                icon: Icons.inventory_2_outlined,
                label: l10n.itemLabel,
                value: summary.itemSummary!,
              ),
            ],
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'order_summary_cash_label',
              container: true,
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: Sizes.medium,
                    color: colors.primary,
                  ),
                  const SizedBox(width: Spacing.xSmall),
                  Expanded(
                    child: Text(
                      l10n.cashLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onOpenChat != null || onTrack != null) ...[
              const SizedBox(height: Spacing.medium),
              Row(
                children: [
                  if (onOpenChat != null)
                    Expanded(
                      child: Semantics(
                        identifier: 'order_summary_open_chat',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.openChat,
                          variant: OmdsButtonVariant.outlined,
                          onTap: onOpenChat!,
                        ),
                      ),
                    ),
                  if (onOpenChat != null && onTrack != null)
                    const SizedBox(width: Spacing.small),
                  if (onTrack != null)
                    Expanded(
                      child: Semantics(
                        identifier: 'order_summary_track',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.track,
                          onTap: onTrack!,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _JeeberBlock extends StatelessWidget {
  const _JeeberBlock({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'order_summary_jeeber_name',
          container: true,
          child: Text(
            summary.jeeberName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (summary.hasRating) ...[
          const SizedBox(height: Spacing.twoXSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: OmdsStarRatingDisplay(
              averageRating: summary.jeeberRating!,
              totalReviews: summary.jeeberRatingCount,
              starSize: Sizes.medium,
              reviewsLabelBuilder: (count) => '($count)',
            ),
          ),
        ],
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String label;
  final String amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      identifier: 'order_summary_price',
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.small,
          vertical: Spacing.xSmall,
        ),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onPrimaryContainer.withValues(
                  alpha: UIConstants.opacityHigh,
                ),
              ),
            ),
            Text(
              '$amount $currency',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.identifier,
    required this.icon,
    required this.label,
    required this.value,
  });

  final String identifier;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      identifier: identifier,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: colors.onSurfaceVariant),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

/// Phone width, and tall enough for the roomy (non-dense) card with an item
/// line and CTAs. Measured at 314 dp on a 390 dp canvas at 1x, in both locales.
const Size _orderSummaryPinnedCardBox = Size(390, 336);

/// The dense chat/tracking injection: one CTA, no item line — 266 dp at 1x.
/// Note how little `dense` actually buys. It swaps `Spacing.medium` for
const Size _orderSummaryPinnedDenseBox = Size(390, 288);

/// The box for the two `matrix: true` states, sized to the TALLEST of their
/// three cells rather than the first one.
const Size _orderSummaryPinnedMatrixBox = Size(390, 560);

/// An accepted-order snapshot with every field overridable.
/// Each state passes its own [deliveryId] so no two fixtures are
OrderSummary _orderSummaryPinnedSummary({
  required String deliveryId,
  String jeeberName = 'Kamal Hajj',
  double price = 9.0,
  String currency = 'USD',
  String tier = 'express',
  double? rating = 4.9,
  int? ratingCount = 312,
  int? etaMinutes = 20,
  String? itemSummary = 'Groceries from Spinneys',
}) =>
    OrderSummary(
      deliveryId: deliveryId,
      requestId: 'req-client-001-accepted',
      conversationId: 'conv-journey-accepted',
      price: price,
      currency: currency,
      jeeberName: jeeberName,
      tier: tier,
      jeeberRating: rating,
      jeeberRatingCount: ratingCount,
      etaMinutes: etaMinutes,
      itemSummary: itemSummary,
    );

/// Mounts the widget the way a host route does: data in, callbacks out.
/// A null callback is not a disabled button — it removes the CTA entirely, so
Widget _orderSummaryPinnedHosted(
  OrderSummary summary, {
  bool chat = true,
  bool track = true,
  bool dense = false,
}) =>
    OrderSummaryPinned(
      summary: summary,
      onOpenChat: chat ? () {} : null,
      onTrack: track ? () {} : null,
      dense: dense,
    );

/// The standalone deep-link rendering (JM-056) — the ONLY host that mounts both
/// CTAs, and therefore the only one where the button row has to share a line.
@JeebPreview(
  group: 'order_summary',
  name: 'Deep link · both CTAs',
  size: _orderSummaryPinnedMatrixBox,
  matrix: true,
)
Widget orderSummaryPinnedDeepLink() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(deliveryId: 'del-31-deeplink'),
    );

/// The chat-host injection (JM-025): `dense: true`, chat CTA suppressed because
/// the customer is already on that screen, and a cold-start jeeber.
@JeebPreview(
  group: 'order_summary',
  name: 'Chat host · dense, no rating',
  size: _orderSummaryPinnedDenseBox,
)
Widget orderSummaryPinnedChatHostDense() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-chat',
        jeeberName: 'Yasmine Haddad',
        rating: null,
        ratingCount: 0,
        itemSummary: null,
      ),
      chat: false,
    );

/// The tier-wire regression (`tier_wire_key_test.dart`), made visible.
/// The gateway serialises `tierId`, never `tier`, on `GET /v1/deliveries/{id}`
@JeebPreview(
  group: 'order_summary',
  name: 'ETA + tier pending',
  size: _orderSummaryPinnedCardBox,
)
Widget orderSummaryPinnedPendingFields() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-pending',
        tier: '',
        etaMinutes: null,
        itemSummary: 'Medicine from Mazen Pharmacy',
      ),
      chat: false,
    );

/// The header row's ceiling, and where the price-pill problem stops being an
/// accessibility edge case and becomes the DEFAULT rendering for a whole market.
@JeebPreview(
  group: 'order_summary',
  name: 'Long name + huge price',
  size: _orderSummaryPinnedMatrixBox,
  matrix: true,
)
Widget orderSummaryPinnedLongNameHugePrice() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-price',
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        price: 1234567.89,
        currency: 'SYP',
        itemSummary: 'Two crates of bottled water',
      ),
    );

/// Bidi: an Arabic item summary rendered inside an English UI.
/// `itemSummary` is the only free text on this card — the one place the UI
@JeebPreview(
  group: 'order_summary',
  name: 'Arabic item in EN UI',
  size: _orderSummaryPinnedCardBox,
)
Widget orderSummaryPinnedArabicItem() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-bidi',
        itemSummary: '٢ كيلو تفاح من سبينيس',
      ),
      chat: false,
    );
