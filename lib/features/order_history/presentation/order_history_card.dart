import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';
import 'order_status_chip.dart';

/// Board radius for an R21 row (`JeebRadii.lg`, tile-measured 18).
const double _cardRadius = 18;

/// Single row in the order-history list (MIDNIGHT R21).
///
/// Two bands inside one kit card: an identity row (state glyph · where-from ·
/// amount) and a meta row (tier · date · status · action pill). The shell is
/// **status-driven, never index-driven** — a row that is physically moving
/// (`pickedUp` / `enRoute`) is the board's one orange element and renders as a
/// [JeebAccentFrameCard]; everything else is a plain [JeebOutlinedCard]. In
/// practice at most one row is live, which is exactly the board.
///
/// R21 is a ZERO-MOTION tile (03-MOTION-NOTES): nothing on this row animates.
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
  static const EdgeInsetsGeometry cardPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.medium,
    vertical: 14,
  );

  /// Ø18 in the board is the *glyph* box; the live dot itself is Ø9 (tpl 1429).
  static const double liveDotSize = 9;

  /// The Ø3 separator between the date and the status (tpl 1443). A shape, not
  /// a `'·'` string: no l10n key and no bidi hazard under RTL.
  static const double metaDotSize = 3;

  /// Above this text scale the meta line sheds its tier chip. Same 1.5 the
  /// screen header uses to stop sharing a line between its two bands.
  static const double largeTextScaleThreshold = 1.5;

  /// R21's expired row "fades but keeps its orange Re-broadcast spark".
  /// TODO(midnight): Q6 — the tile is NOT a uniform fade (measured: fill ≈.41,
  /// title ≈.62, meta ≈.80) and .65 on #8A93D8 lands under AA. Owner call open.
  static const double expiredOpacity = 0.65;

  /// Inline meta affordance height (`Re-broadcast`). Sub-48 like R15's tag
  /// chips — routed to the M6 a11y sweep, not solved per screen.
  static const double metaActionHeight = 28;

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
    final String dateLabel = DateFormat.MMMd(
      locale,
    ).format(order.createdAt.toLocal());
    // R5: orange marks what is moving *now*. `matched` is assigned-not-moving.
    final bool isLive =
        order.status == OrderRequestStatus.pickedUp ||
        order.status == OrderRequestStatus.enRoute;

    // T11 / SW-02: show the real amount through the one MoneyFormat rule when
    // it is known; a missing price degrades to an em-dash (with an explicit
    // "amount unavailable" a11y label), NEVER a fabricated `$0.00`.
    final bool amountKnown = order.hasKnownAmount;
    final String amountLabel = amountKnown
        ? MoneyFormat.format(order.amountMinor! / 100, currency: order.currency)
        : '—';
    final String amountSemantics = amountKnown
        ? amountLabel
        : l10n.orderHistoryAmountUnavailable;

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
    final Widget card = JeebOutlinedCard(
      key: cardKey,
      identifier: identifier,
      semanticLabel: semanticLabel,
      onTap: onTap,
      radius: _cardRadius,
      padding: cardPadding,
      // NOT `state: dormant` — that rung is 0.75 AND drops the actions row,
      // and R21's faded row still draws its Re-broadcast affordance.
      child: body,
    );
    if (!_isExpired(order.status)) return card;
    return Opacity(opacity: expiredOpacity, child: card);
  }

  /// Cancelled and disputed are the tile's faded "expired" row.
  static bool _isExpired(OrderRequestStatus status) =>
      status == OrderRequestStatus.cancelled ||
      status == OrderRequestStatus.disputed;
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
    // TODO(midnight): the board's `Medicine — Pharmacie du Musée` needs an item
    // title on GET /v1/requests; pickup is the honest slot — omitted, not faked.
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
            style: context.jeebText.cardTitle.copyWith(color: scheme.onSurface),
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        Text(
          amountLabel,
          semanticsLabel: amountSemantics,
          maxLines: 1,
          // `body` not `cardTitle`: the tile's price reads a step larger, but
          // at 2× text the extra px overflows the identity row.
          style: context.jeebText.body.copyWith(
            fontWeight: FontWeight.w800,
            // A missing price is muted, not shouted like a real amount.
            color: amountKnown ? scheme.onSurface : scheme.onSurfaceVariant,
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
            // Tile-drawn glow on the live row only; a queued row is a flat dot.
            boxShadow: isLive ? JeebShadows.glowDot : null,
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
    // Tile-measured #8A93D8 on the completed row's `Jun 26 · …` run; the lit
    // row carries no periwinkle at all on the tile, so it steps up to inkSoft.
    final Color metaInk = isLive
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final Widget? pill = _pill(context, l10n);
    final Widget? rebroadcast = _rebroadcast(context, l10n);

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
                  // R21 measures white ~12% inside the accent frame, not the
                  // opaque navy pill R1 draws.
                  glass: true,
                ),
                const SizedBox(width: Spacing.xSmall),
              ],
              Flexible(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle.copyWith(color: metaInk),
                ),
              ),
              _MetaDot(ink: metaInk),
              // Date and status stay two separate `Text`s: the stale-status
              // regression suite pins `find.text('Pending'/'Picked up'/…)`.
              Flexible(
                child: Text(
                  orderStatusLabel(order.status, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle.copyWith(
                    // #FFB499, tile-measured: solid accent is unreadable on
                    // the frame's own orange-lit fill.
                    color: isLive
                        ? context.jeebRoles.onAccentContainer
                        : metaInk,
                  ),
                ),
              ),
              // TODO(midnight): the board's `· Karim · ★ 4` (completed) and
              // `· ETA 20 min` (live) need a jeeber name, rating and ETA on
              // GET /v1/requests — omitted, not faked.
              if (rebroadcast != null) ...<Widget>[
                _MetaDot(ink: metaInk),
                rebroadcast,
              ],
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

  /// `Track` while moving (white slab), `Jeeb it again` once delivered (glass).
  /// A queued or just-matched row has no honest action of its own here, and the
  /// expired row's affordance is the inline [_rebroadcast] spark instead.
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
    if (order.status == OrderRequestStatus.delivered && onReorder != null) {
      return JeebSelectChip(
        role: JeebChipRole.inlineAction,
        label: l10n.orderHistoryReorderCta,
        onTap: onReorder,
        identifier: 'order_history_reorder_cta_${order.id}',
      );
    }
    return null;
  }

  /// The expired row's orange text spark. FROZEN id re-homed off the pill: the
  /// board draws no pill here, and `order_history_reorder_cta_<id>` is pinned.
  Widget? _rebroadcast(BuildContext context, AppLocalizations l10n) {
    final bool isExpired =
        order.status == OrderRequestStatus.cancelled ||
        order.status == OrderRequestStatus.disputed;
    if (!isExpired || onReorder == null) return null;
    return JeebCtaButton.accentText(
      // TODO(midnight): l10n-queued `orderHistoryRebroadcastCta` = Re-broadcast.
      label: l10n.orderHistoryReorderCta,
      onTap: onReorder,
      height: OrderHistoryCard.metaActionHeight,
      labelStyle: context.jeebText.bodySmall,
      contentPadding: EdgeInsetsDirectional.zero,
      identifier: 'order_history_reorder_cta_${order.id}',
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

/// The Ø3 meta separator with its own breathing room on both sides.
class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.twoXSmall,
      ),
      child: Container(
        width: OrderHistoryCard.metaDotSize,
        height: OrderHistoryCard.metaDotSize,
        decoration: BoxDecoration(shape: BoxShape.circle, color: ink),
      ),
    );
  }
}
