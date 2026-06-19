import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/wallet_ledger_repository.dart';
import '../wallet_activity_l10n.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isCredit = entry.sign >= 0;
    final ref = copy.refLabel(entry.ref);
    final time = copy.relativeTime(entry.timestamp, now: now);

    return Semantics(
      // Dynamic per-row id — QA asserts the seeded fixture id (e.g.
      // wallet_activity_row_led-seed-fee_won). 41_GUARDRAILS_TESTING §1.1.
      identifier: 'wallet_activity_row_${entry.id}',
      button: true,
      container: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.small,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _LeadingIcon(type: entry.type),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.typeLabel(entry.type),
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ref.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        ref,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        time,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Spacing.small),
              // Signed amount — `+` credit (released / refund / top up / gift),
              // `-` debit (reserve / fee-won / penalty). The sign comes from the
              // W2m `sign`, not the type, so a corrected backend row renders
              // correctly without an enum table here.
              Text(
                copy.signedAmount(entry.amount, entry.sign, entry.currency),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCredit ? colors.primary : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Typed leading icon — one glyph per W2m ledger `type` so the row reads at a
/// glance (cosmetic; flows key on the row id, not the icon).
class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.type});

  final WalletLedgerType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.fiveXLarge,
      height: Sizes.fiveXLarge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Icon(_iconFor(type), color: colors.onSurfaceVariant),
    );
  }

  IconData _iconFor(WalletLedgerType type) {
    switch (type) {
      case WalletLedgerType.reserve:
        return Icons.lock_clock_outlined;
      case WalletLedgerType.feeWon:
        return Icons.percent_outlined;
      case WalletLedgerType.released:
        return Icons.lock_open_outlined;
      case WalletLedgerType.refund:
        return Icons.undo_outlined;
      case WalletLedgerType.penalty:
        return Icons.gavel_outlined;
      case WalletLedgerType.topup:
        return Icons.add_card_outlined;
      case WalletLedgerType.gift:
        return Icons.card_giftcard_outlined;
      case WalletLedgerType.unknown:
        return Icons.receipt_long_outlined;
    }
  }
}
