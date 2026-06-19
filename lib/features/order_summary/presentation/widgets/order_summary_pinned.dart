import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/order_summary.dart';
import '../order_summary_l10n.dart';

/// JM-031 — the pinned order-summary header WIDGET (CTO-D3 primary rendering).
///
/// A reusable, self-contained strip that hosts inject into BOTH `order-chat`
/// (JM-025) and `order-tracking` (JM-032) so the customer always sees the
/// authoritative, locked snapshot of their accepted order (D71): accepted COD
/// price, Jeeber name + rating (D6), ETA, tier, item summary, and the
/// "Pay cash on delivery" reminder (D11 — NO commission/finance line on this
/// customer-facing surface).
///
/// Dumb widget (guardrail §1): data in via [summary], events out via
/// [onOpenChat] / [onTrack]. It NEVER touches `sl` or `context.go` — the host
/// route owns navigation. Hosts pass:
///   * chat host (JM-025): `onTrack` → `/orders/:id/tracking`, `onOpenChat` null
///     (already on chat) or a no-op/scroll.
///   * tracking host (JM-032): `onOpenChat` → `/chat/:id`, `onTrack` null
///     (already on tracking).
///   * standalone deep-link screen (JM-056 target): both wired.
/// A null callback hides the corresponding CTA so it is never a dead end.
///
/// Every interactive/asserted element carries the EXACT `Semantics(identifier:)`
/// from `63_W1_TEST_PLAN §2.11`.
class OrderSummaryPinned extends StatelessWidget {
  const OrderSummaryPinned({
    super.key,
    required this.summary,
    this.onOpenChat,
    this.onTrack,
    this.dense = false,
  });

  /// The locked accepted-order snapshot to render.
  final OrderSummary summary;

  /// Tapped on `order_summary_open_chat`. Null hides the chat CTA (e.g. when the
  /// widget is already hosted inside the chat screen).
  final VoidCallback? onOpenChat;

  /// Tapped on `order_summary_track`. Null hides the track CTA (e.g. when the
  /// widget is already hosted inside the tracking screen).
  final VoidCallback? onTrack;

  /// When true, renders as a compact pinned strip (for the chat/tracking header
  /// injection) rather than the roomier standalone-screen card.
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
            // ── Jeeber identity + accepted price ──────────────────────────
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
            // ── Facts row: ETA + tier ─────────────────────────────────────
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
                    value: l10n.tierName(summary.tier),
                  ),
                ),
              ],
            ),
            // ── Item summary ──────────────────────────────────────────────
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
            // ── Pay-cash-on-delivery reminder (D11) ───────────────────────
            Semantics(
              identifier: 'order_summary_cash_label',
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
            // ── CTAs (each hidden when its callback is null) ──────────────
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

/// Jeeber name (`order_summary_jeeber_name`) + rating chip (D6: only when a
/// real score exists — cold-start jeebers show the name alone).
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
          OmdsStarRatingDisplay(
            averageRating: summary.jeeberRating!,
            totalReviews: summary.jeeberRatingCount,
            starSize: Sizes.medium,
            reviewsLabelBuilder: (count) => '($count)',
          ),
        ],
      ],
    );
  }
}

/// Accepted COD price (`order_summary_price`) pill.
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

/// A labelled fact chip (icon + label + value) used for ETA / tier / item. The
/// [identifier] is applied to the value-bearing container so Maestro can assert
/// the field is present regardless of its visible (localized) copy.
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
