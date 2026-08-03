import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../domain/wallet_ledger_repository.dart';
import '../wallet_activity_l10n.dart';

/// Row radius/padding — 24's order-row numbers (`24-order-history.html`
/// tpl 1427/1437), which the notifications inbox row already adopted. This list
/// hangs directly off the redesigned 23 hub, so its rows have to read as the
/// same product as its neighbours.
const double _rowRadius = 18;
const EdgeInsetsGeometry _rowPadding = EdgeInsetsDirectional.symmetric(
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
/// Redesign-2026-08: a re-skin onto the kit, not a rewrite. The hand-rolled
/// `InkWell` + Ø56 grey icon tile + hairline `Divider` became a
/// [JeebOutlinedCard] (outline over shadow, r18, 14/16) carrying two bands in
/// 24's rhythm — a headline row (glyph · type label · signed amount) over a meta
/// row (reference · relative time). Nothing was added or removed.
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
    final bool isCredit = entry.sign >= 0;
    final String ref = copy.refLabel(entry.ref);
    final String time = copy.relativeTime(entry.timestamp, now: now);
    // Periwinkle meta ink — 24's date/status line, 23's row subtitles.
    final TextStyle metaStyle = context.jeebText.bodySmall.copyWith(
      color: scheme.onSecondaryContainer,
    );

    return JeebOutlinedCard(
      // FROZEN: `wallet_activity_row_<id>` re-homed onto the kit card, which
      // emits one `Semantics(identifier:, button:, container:,
      // explicitChildNodes:)` node — the same shape as the hand-rolled wrapper
      // it replaces (the `NotificationRow` precedent).
      identifier: 'wallet_activity_row_${entry.id}',
      onTap: onTap,
      radius: _rowRadius,
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Filled glyph inline at 16 (R10) — the Ø56 `surfaceContainerHighest`
              // tile is gone: an outlined card does not need a second box.
              Icon(
                _iconFor(entry.type),
                size: Sizes.medium,
                color: scheme.primary,
              ),
              const SizedBox(width: Spacing.xSmall),
              Expanded(
                child: Text(
                  copy.typeLabel(entry.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.jeebText.cardTitle.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.xSmall),
              // Signed amount — `+` credit (released / refund / top up / gift),
              // `-` debit (reserve / fee-won / penalty). The sign comes from the
              // W2m `sign`, not the type, so a corrected backend row renders
              // correctly without an enum table here. The credit ink is the
              // contrast-gated `success` role: navy-vs-ink (the pre-redesign
              // pair) are the same colour to the eye, so the tint carried no
              // information at all.
              Text(
                copy.signedAmount(entry.amount, entry.sign, entry.currency),
                // The `+`/`-` is the load-bearing half of this token and the
                // copy layer builds the string by hand (no `MoneyFormat`
                // isolate), so an Arabic paragraph would reorder it to
                // `USD 0.90-`. Resolve the run LTR instead.
                textDirection: TextDirection.ltr,
                style: context.jeebText.cardTitle.copyWith(
                  fontWeight: FontWeight.w800,
                  color:
                      isCredit ? context.jeebRoles.success : scheme.primary,
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
