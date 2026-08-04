import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../domain/wallet_ledger_repository.dart';
import '../wallet_activity_l10n.dart';

/// Row geometry — R21's own box (`border-radius:20px; padding:14px 16px`), which
/// snaps to `JeebRadii.lg` (18) under the §5 ±2 rule and is the rung
/// `notification_row.dart` already ships.
const EdgeInsetsGeometry kWalletActivityRowPadding =
    EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.medium,
  vertical: 14,
);

/// A single typed ledger row for wallet-activity-list (JM-055). Dumb widget
/// (40_GUARDRAILS_ARCH §1 layer rules): data in via constructor, the tap out via
/// [onTap] — it never reaches `sl` or `context.go`.
///
/// Carries the dynamic Maestro id `wallet_activity_row_<id>`
/// (41_GUARDRAILS_TESTING §1.1 per-item row form; JM-055 AC). Renders the typed
/// leading icon (one per W2m `type`: Reserve / Fee-won / Released / Refund /
/// Penalty / Top up / Gift, D41), the type label + reference sub-line + relative
/// time, and the SIGNED amount (`+`/`-`, JM-055 AC "amount + sign + icon + ref")
/// tinted credit/debit. The whole row is the tap target — on tap the screen
/// pushes `transaction-detail` (JM-056).
///
/// MIDNIGHT (M3-11), derived from R4 (`04-r4-wallet.png`) whose hub this list
/// hangs off, with R19 (earnings) as the secondary pattern for row facts:
///   * rest-glass [JeebOutlinedCard] at `JeebRadii.lg`, 14/16 — R21's rung.
///   * type label = `onSurface` (§1 "board primary ink"; the wave-B ruling that
///     `onSurface` is the heading ink app-wide). It was `colorScheme.primary`,
///     which under Midnight IS `#D73B00` — a read-only label spending the
///     orange budget.
///   * typed glyph = `onSurfaceVariant`, §1's muted ink role: the icon is
///     cosmetic (flows key on the row id), so it must not read as an action.
///   * amount = `price` (22/w800/−0.5, §6 "money emphasis"), credit inked
///     `onSuccessContainer` `#7BD9A4` (R19's own cash-row ink) and debit
///     `onErrorContainer` `#FF7B7B` — the danger-SOFT half, per the R22 ruling
///     the kit's `JeebCtaVariant.danger` records: never full-strength `#FF5252`.
class WalletActivityRow extends StatelessWidget {
  const WalletActivityRow({
    super.key,
    required this.entry,
    required this.copy,
    required this.onTap,
    this.now,
  });

  final WalletLedgerEntry entry;
  final WalletActivityL10n copy;
  final VoidCallback onTap;

  /// Injectable clock for the relative timestamp (deterministic in tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebRoles roles = context.jeebRoles;
    final bool isCredit = entry.sign >= 0;
    final String ref = copy.refLabel(entry.ref);
    final String time = copy.relativeTime(entry.timestamp, now: now);
    final TextStyle metaStyle = context.jeebText.bodySmall.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return JeebOutlinedCard(
      // FROZEN: `wallet_activity_row_<id>` re-homed onto the kit card, which
      // emits one `Semantics(identifier:, button:, container:,
      // explicitChildNodes:)` node — the same shape as the hand-rolled wrapper
      // it replaces (the `NotificationRow` precedent).
      identifier: 'wallet_activity_row_${entry.id}',
      onTap: onTap,
      radius: JeebRadii.lg,
      padding: kWalletActivityRowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _iconFor(entry.type),
                size: Sizes.medium,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xSmall),
              Expanded(
                child: Text(
                  copy.typeLabel(entry.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.jeebText.cardTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.xSmall),
              // Signed amount — `+` credit (released / refund / top up / gift),
              // `-` debit (reserve / fee-won / penalty). The sign comes from the
              // W2m `sign`, not the type, so a corrected backend row renders
              // correctly without an enum table here.
              Text(
                copy.signedAmount(entry.amount, entry.sign, entry.currency),
                // The `+`/`-` is the load-bearing half of this token and the
                // copy layer builds the string by hand (no `MoneyFormat`
                // isolate), so an Arabic paragraph would reorder it to
                // `USD 0.90-`. Resolve the run LTR instead.
                textDirection: TextDirection.ltr,
                style: context.jeebText.price.copyWith(
                  color: isCredit
                      ? roles.onSuccessContainer
                      : roles.onErrorContainer,
                ),
              ),
            ],
          ),
          if (ref.isNotEmpty || time.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.twoXSmall),
            Row(
              children: <Widget>[
                if (ref.isNotEmpty)
                  Expanded(
                    child: Text(
                      ref,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle,
                    ),
                  )
                else
                  const Spacer(),
                if (time.isNotEmpty) ...<Widget>[
                  const SizedBox(width: Spacing.xSmall),
                  Text(time, maxLines: 1, style: metaStyle),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Typed leading glyph — one per W2m ledger `type` so the row reads at a glance
/// (cosmetic; flows key on the row id, not the icon). Filled variants (R10),
/// matching the hub's own `Icons.lock` / `Icons.article` set.
IconData _iconFor(WalletLedgerType type) {
  switch (type) {
    case WalletLedgerType.reserve:
      return Icons.lock_clock;
    case WalletLedgerType.feeWon:
      return Icons.percent;
    case WalletLedgerType.released:
      return Icons.lock_open;
    case WalletLedgerType.refund:
      return Icons.undo;
    case WalletLedgerType.penalty:
      return Icons.gavel;
    case WalletLedgerType.topup:
      return Icons.add_card;
    case WalletLedgerType.gift:
      return Icons.card_giftcard;
    case WalletLedgerType.unknown:
      return Icons.receipt_long;
  }
}
