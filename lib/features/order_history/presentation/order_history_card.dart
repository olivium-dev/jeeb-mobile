import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';
import 'order_status_chip.dart';

/// Board radius for a 24 row (`24-order-history.html` tpl 1427 / 1437).
const double _cardRadius = 18;

/// Single row in the order-history list (redesign-2026-08 §24).
///
/// Two bands inside one kit card: an identity row (state glyph · where-from ·
/// amount) and a meta row (tier · date · status · action pill). The shell is
/// **status-driven, never index-driven** — a row that is physically moving
/// (`pickedUp` / `enRoute`) is the board's one orange element and renders as a
/// [JeebAccentFrameCard]; everything else is a plain [JeebOutlinedCard]. In
/// practice at most one row is live, which is exactly the board.
///
/// The card stays self-contained — it takes an [order] plus callbacks and
/// renders. No BLoC subscription, so it is trivial to embed in goldens.
class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onTrack,
    this.onReorder,
  });

  /// `14/16` — the board's row padding (`24-order-history.html` tpl 1427). The
  /// kit folds the stroke width in itself, so this is not hand-corrected.
  static const EdgeInsetsGeometry cardPadding =
      EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: 14);

  /// Ø18 in the board is the *glyph* box; the live dot itself is Ø9 (tpl 1429).
  static const double liveDotSize = 9;

  /// The Ø3 separator between the date and the status (tpl 1443). A shape, not
  /// a `'·'` string: no l10n key and no bidi hazard under RTL.
  static const double metaDotSize = 3;

  /// Above this text scale the meta line sheds its tier chip. Same 1.5 the
  /// screen header uses to stop sharing a line between its two bands.
  static const double largeTextScaleThreshold = 1.5;

  final OrderSummary order;
  final VoidCallback onTap;

  /// Navy `Track` pill — rendered only while the order is physically moving.
  final VoidCallback? onTrack;

  /// Outlined `Jeeb it again` pill — rendered on terminal rows.
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final String dateLabel =
        DateFormat.MMMd(locale).format(order.createdAt.toLocal());
    // R5: orange marks what is moving *now*. `matched` is assigned-not-moving.
    final bool isLive = order.status == OrderRequestStatus.pickedUp ||
        order.status == OrderRequestStatus.enRoute;

    // T11 / SW-02: show the real amount through the one MoneyFormat rule when
    // it is known; a missing price degrades to an em-dash (with an explicit
    // "amount unavailable" a11y label), NEVER a fabricated `$0.00`.
    final bool amountKnown = order.hasKnownAmount;
    final String amountLabel = amountKnown
        ? MoneyFormat.format(order.amountMinor! / 100, currency: order.currency)
        : '—';
    final String amountSemantics =
        amountKnown ? amountLabel : l10n.orderHistoryAmountUnavailable;

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _IdentityRow(
          order: order,
          isLive: isLive,
          amountLabel: amountLabel,
          amountKnown: amountKnown,
          amountSemantics: amountSemantics,
        ),
        const SizedBox(height: Spacing.small),
        _MetaRow(
          order: order,
          isLive: isLive,
          dateLabel: dateLabel,
          onTrack: onTrack,
          onReorder: onReorder,
        ),
      ],
    );

    // FROZEN: key, identifier and semanticLabel are re-homed onto the kit card,
    // which emits one `Semantics(identifier:, label:, button:, container:,
    // explicitChildNodes:)` node — value-identical to the hand-rolled wrapper
    // it replaces, plus the child-id protection the nested pills need.
    final Key cardKey = Key('order-history-card-${order.id}');
    final String identifier = 'order_history_card_${order.id}';
    final String semanticLabel = l10n.orderHistoryCardSemanticLabel(order.id);

    if (isLive) {
      return JeebAccentFrameCard(
        key: cardKey,
        identifier: identifier,
        semanticLabel: semanticLabel,
        onTap: onTap,
        radius: _cardRadius,
        padding: cardPadding,
        child: body,
      );
    }
    return JeebOutlinedCard(
      key: cardKey,
      identifier: identifier,
      semanticLabel: semanticLabel,
      onTap: onTap,
      radius: _cardRadius,
      padding: cardPadding,
      // Never `state: dormant` — a cancelled row keeps full opacity so its
      // periwinkle meta line stays above AA (§2, R9).
      child: body,
    );
  }
}

/// Glyph · where-from · amount.
class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.order,
    required this.isLive,
    required this.amountLabel,
    required this.amountKnown,
    required this.amountSemantics,
  });

  final OrderSummary order;
  final bool isLive;
  final String amountLabel;
  final bool amountKnown;
  final String amountSemantics;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // No item/description field on the list DTO — pickup is the real
    // "where from" the board's `Medicine — Pharmacie du Musée` is naming.
    final String title = order.pickupAddress.isEmpty
        ? l10n.orderHistoryAddressMissing
        : order.pickupAddress;

    return Row(
      children: <Widget>[
        _StatusGlyph(status: order.status, isLive: isLive),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.jeebText.cardTitle.copyWith(color: scheme.primary),
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        Text(
          amountLabel,
          semanticsLabel: amountSemantics,
          maxLines: 1,
          style: context.jeebText.body.copyWith(
            fontWeight: FontWeight.w800,
            // A missing price is muted, not shouted like a real amount.
            color: amountKnown ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The one mark that carries lifecycle state on a row.
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.status, required this.isLive});

  final OrderRequestStatus status;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (status) {
      case OrderRequestStatus.pending:
      case OrderRequestStatus.matched:
      case OrderRequestStatus.pickedUp:
      case OrderRequestStatus.enRoute:
      case OrderRequestStatus.unknown:
        return Container(
          width: OrderHistoryCard.liveDotSize,
          height: OrderHistoryCard.liveDotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: roles.accent,
            // The halo belongs to motion only — a queued row is a plain dot.
            boxShadow: isLive ? JeebShadows.stepGlow : null,
          ),
        );
      case OrderRequestStatus.delivered:
        return Icon(
          Icons.check_circle,
          size: Sizes.medium,
          color: roles.success,
        );
      case OrderRequestStatus.cancelled:
        return Icon(
          Icons.cancel,
          size: Sizes.medium,
          color: scheme.onSecondaryContainer,
        );
      case OrderRequestStatus.disputed:
        return Icon(Icons.error, size: Sizes.medium, color: scheme.error);
    }
  }
}

/// Tier · date · status · action pill.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.order,
    required this.isLive,
    required this.dateLabel,
    required this.onTrack,
    required this.onReorder,
  });

  final OrderSummary order;
  final bool isLive;
  final String dateLabel;
  final VoidCallback? onTrack;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle metaStyle = context.jeebText.bodySmall;
    // The board only carries a tier chip on the in-motion row; terminal rows
    // trade it for the retention pill. Tier stays available on `/orders/:id`.
    //
    // It is also dropped above 1.5× text — the same threshold the header uses
    // to stack its two bands. Past that scale the chip alone is wider than the
    // whole meta group, and the date, status and action pill are all load-
    // bearing where the tier is redundant with the row's own accent framing.
    final bool showTier =
        order.status.tab == OrderHistoryTab.active &&
        MediaQuery.textScalerOf(context).scale(1) <=
            OrderHistoryCard.largeTextScaleThreshold;
    final Widget? pill = _pill(context, l10n);

    return Row(
      children: <Widget>[
        // One `Expanded` group rather than a `Spacer`: a `Spacer` shares the
        // free space with the loose meta texts, so the pill would stop short of
        // the trailing edge instead of hugging it.
        Expanded(
          child: Row(
            children: <Widget>[
              if (showTier) ...<Widget>[
                // NOT `Flexible`: the kit chip's inner row is min-sized and its
                // label does not ellipsize, so any max width below its intrinsic
                // width overflows it (AR labels and 2× text both hit this).
                // Shrinkage is absorbed by the two ellipsizing meta texts below.
                JeebTierChip.custom(
                  emoji: JeebTierChip.emojiFor(order.tier.name),
                  label: _tierLabel(order.tier, l10n),
                ),
                const SizedBox(width: Spacing.xSmall),
              ],
              Flexible(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.twoXSmall),
              Container(
                width: OrderHistoryCard.metaDotSize,
                height: OrderHistoryCard.metaDotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: Spacing.twoXSmall),
              // Date and status stay two separate `Text`s: the stale-status
              // regression suite pins `find.text('Pending'/'Picked up'/…)`.
              Flexible(
                child: Text(
                  orderStatusLabel(order.status, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle.copyWith(
                    color: isLive
                        ? context.jeebRoles.accent
                        : scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (pill != null) ...<Widget>[
          const SizedBox(width: Spacing.xSmall),
          pill,
        ],
      ],
    );
  }

  /// `Track` while moving, `Jeeb it again` once terminal, nothing in between —
  /// a queued or just-matched row has no honest action of its own here.
  Widget? _pill(BuildContext context, AppLocalizations l10n) {
    if (isLive && onTrack != null) {
      return JeebSelectChip(
        role: JeebChipRole.inlineAction,
        label: l10n.orderHistoryTrackCta,
        selected: true,
        onTap: onTrack,
        identifier: 'order_history_track_cta_${order.id}',
      );
    }
    final bool isTerminal = order.status == OrderRequestStatus.delivered ||
        order.status == OrderRequestStatus.cancelled ||
        order.status == OrderRequestStatus.disputed;
    if (isTerminal && onReorder != null) {
      return JeebSelectChip(
        role: JeebChipRole.inlineAction,
        label: l10n.orderHistoryReorderCta,
        onTap: onReorder,
        identifier: 'order_history_reorder_cta_${order.id}',
      );
    }
    return null;
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
