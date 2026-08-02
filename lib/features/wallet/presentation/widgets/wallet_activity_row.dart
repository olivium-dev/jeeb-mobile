import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/wallet_ledger_repository.dart';
import '../wallet_activity_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Fixed clock for the relative timestamps, so a card's age never depends on
/// the day it is opened. Same instant the screen test's fixtures are read at.
final DateTime _walletActivityRowNow = DateTime.utc(2026, 6, 18, 12);

/// Canvas box for a full row: phone width, and tall enough for the deepest
/// three-line stack (type label + ref + relative time) plus the separator the
const Size _walletActivityRowBox = Size(390, 104);

/// Canvas box for the degenerate row — type label and amount, nothing else.
/// 81 pt measured, which is the FLOOR this widget can shrink to: the 56 pt
const Size _walletActivityRowShortBox = Size(390, 96);

/// Hosts one row the way `_LoadedList` does: full phone width, inside a
/// scrollable, and followed by the same indented `Divider(height: 1)` that
Widget _walletActivityRowHosted(WalletLedgerEntry entry) =>
    SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Builder(
            builder: (BuildContext context) => WalletActivityRow(
              entry: entry,
              copy: WalletActivityL10n.of(context),
              onTap: () {},
              now: _walletActivityRowNow,
            ),
          ),
          const Divider(
            height: 1,
            indent: Spacing.medium,
            endIndent: Spacing.medium,
          ),
        ],
      ),
    );

/// The canonical row, and the one the JM-055 AC is written against: the
/// platform fee debited when a jeeber wins an offer.
@JeebPreview(
  group: 'wallet',
  name: 'Fee · debit',
  size: _walletActivityRowBox,
  matrix: true,
)
Widget walletActivityRowFeeDebit() => _walletActivityRowHosted(
      const WalletLedgerEntry(
        id: 'led-seed-fee_won',
        type: WalletLedgerType.feeWon,
        amount: 0.9,
        sign: -1,
        ref: 'off-led-b',
        timestamp: '2026-06-18T10:00:00Z',
        currency: 'USD',
      ),
    );

/// The credit half of the contrast, on the one type a brand-new jeeber sees
/// first: the starter credit granted at approval.
@JeebPreview(
  group: 'wallet',
  name: 'Starter credit · credit',
  size: _walletActivityRowBox,
)
Widget walletActivityRowGiftCredit() => _walletActivityRowHosted(
      const WalletLedgerEntry(
        id: 'led-seed-gift',
        type: WalletLedgerType.gift,
        amount: 5,
        sign: 1,
        ref: 'welcome-2026',
        timestamp: '2026-06-17T12:00:00Z',
        currency: 'USD',
      ),
    );

/// The floor: a release with no reference and no timestamp on the wire.
/// Both sub-lines are behind `if (…isNotEmpty)` guards, and both resolvers
@JeebPreview(
  group: 'wallet',
  name: 'Released · no ref, no timestamp',
  size: _walletActivityRowShortBox,
)
Widget walletActivityRowNoRefNoTime() => _walletActivityRowHosted(
      const WalletLedgerEntry(
        id: 'led-seed-released',
        type: WalletLedgerType.released,
        amount: 12.5,
        sign: 1,
        ref: '',
        timestamp: '',
        currency: 'USD',
      ),
    );

/// Wire drift, made visible: a `type` the mobile enum does not know about, on a
/// row that also carries no `currency`.
@JeebPreview(
  group: 'wallet',
  name: 'Unknown type · no currency',
  size: _walletActivityRowBox,
)
Widget walletActivityRowUnknownType() => _walletActivityRowHosted(
      const WalletLedgerEntry(
        id: 'led-seed-unknown',
        type: WalletLedgerType.unknown,
        amount: 1.75,
        sign: -1,
        ref: 'chg-9f2',
        timestamp: '2026-06-18T09:00:00Z',
      ),
    );

/// Layout ceiling: the longest reference a payment gateway plausibly returns,
/// beside the largest amount a top-up plausibly carries.
@JeebPreview(
  group: 'wallet',
  name: 'Top up · long ref, wide amount',
  size: _walletActivityRowBox,
  matrix: true,
)
Widget walletActivityRowLongRef() => _walletActivityRowHosted(
      const WalletLedgerEntry(
        id: 'led-seed-topup',
        type: WalletLedgerType.topup,
        amount: 1250,
        sign: 1,
        ref: 'off-2026-06-18-beirut-hamra-b42-3f-abdulrahman-almuhandis-0091',
        timestamp: '2026-06-16T12:00:00Z',
        currency: 'USD',
      ),
    );

/// The timestamp the row cannot read, printed raw.
/// `relativeTime` falls back to the input string whenever [DateTime.tryParse]
@JeebPreview(
  group: 'wallet',
  name: 'Refund · unparseable timestamp',
  size: _walletActivityRowBox,
)
Widget walletActivityRowUnparsedTimestamp() => _walletActivityRowHosted(
      const WalletLedgerEntry(
        id: 'led-seed-refund',
        type: WalletLedgerType.refund,
        amount: 7.4,
        sign: 1,
        ref: 'dis-441',
        timestamp: '15/06/2026 09:30 AM',
        currency: 'USD',
      ),
    );
