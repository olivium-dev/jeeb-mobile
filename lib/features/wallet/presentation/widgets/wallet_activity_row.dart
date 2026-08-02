import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/wallet_ledger_repository.dart';
import '../wallet_activity_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/wallet/wallet_activity_row_preview_test.dart
// ===========================================================================
//
// Widget previews for [WalletActivityRow] — run with
// `flutter widget-preview start`.
//
// The row is a dumb widget (40_GUARDRAILS_ARCH §1): one [WalletLedgerEntry]
// value, one [WalletActivityL10n] resolver read off the ambient
// [Localizations], one inert `onTap`. No cubit, no repository, no
// [WalletLedgerRepository] anywhere below this banner — every state is a
// literal `const WalletLedgerEntry`, so these previews are network-free by
// construction rather than by the guard in [jeebPreviewHost].
//
// `now` is PINNED on every preview. The relative timestamp is the one thing on
// this row that would otherwise drift with the wall clock, and a card that
// reads "2h ago" on Monday and "3d ago" on Thursday is not a state anyone can
// review. The fixture instant and the `2026-06-18T10:00:00Z` timestamp are the
// ones `test/features/wallet/wallet_activity_list_screen_test.dart` already
// seeds, so the canvas and the regression suite look at the same rows.
//
// ## What to look for, and what the states are chosen for
//
// * **The sign comes from `sign`, never from `type`.** JM-055's AC is "amount +
//   sign + icon + ref", and `build` tints on `entry.sign >= 0` while the glyph
//   comes from `entry.type`. The two CAN disagree — a corrected backend row is
//   supposed to render its own sign — so read the icon and the tinted amount of
//   each card as a pair. A credit is `colors.primary`; a debit is a plain
//   `colors.onSurface`, i.e. the SAME color as the type label above it.
//
// * **RTL: the box mirrors, the amount STRING does not.** The padding is
//   [EdgeInsetsDirectional], so in Arabic the typed icon does move to the
//   trailing edge and the amount to the leading edge. But
//   [WalletActivityL10n.signedAmount] builds `'+5.00 USD'` by concatenation,
//   and in an RTL paragraph the leading `+`/`-` is a neutral that resolves to
//   the paragraph direction: it is laid out at the RIGHT end of the run, with
//   the currency at the left. Read the AR card's amount character by character
//   — the sign is the only thing besides a tint that separates a credit from a
//   debit, and it is not where a reader expects it.
//
// * **Only the ref line clamps, and the amount is not flexible.** `ref` is
//   `maxLines: 1` + ellipsis; the type label, the timestamp and the amount are
//   all unclamped. The amount is also the one child of the [Row] that is NOT
//   inside the [Expanded], so it takes its intrinsic width first and a wide
//   amount starves the text column instead of wrapping — see
//   [walletActivityRowLongRef], which is where that ends in an overflow.
//
// * **The floor.** `refLabel('')` and `relativeTime('')` both return `''` and
//   both sub-lines are guarded by `isNotEmpty`, so a row can legitimately
//   shrink to one label and one number — see [walletActivityRowNoRefNoTime].

/// Fixed clock for the relative timestamps, so a card's age never depends on
/// the day it is opened. Same instant the screen test's fixtures are read at.
final DateTime _walletActivityRowNow = DateTime.utc(2026, 6, 18, 12);

/// Canvas box for a full row: phone width, and tall enough for the deepest
/// three-line stack (type label + ref + relative time) plus the separator the
/// production list draws under it. Measured at 390 pt: 85 pt.
const Size _walletActivityRowBox = Size(390, 104);

/// Canvas box for the degenerate row — type label and amount, nothing else.
/// 81 pt measured, which is the FLOOR this widget can shrink to: the 56 pt
/// leading icon, not the text, is what sets the height.
const Size _walletActivityRowShortBox = Size(390, 96);

/// Hosts one row the way `_LoadedList` does: full phone width, inside a
/// scrollable, and followed by the same indented `Divider(height: 1)` that
/// `ListView.separated` puts between rows.
///
/// The scrollable is not decoration. A `Scaffold` body hands its child TIGHT
/// constraints, so a bare row would stretch to the full height of the canvas
/// box and every card would report the same (wrong) height. And nothing on this
/// row clamps its height, so at 200% text it grows past any fixed box and would
/// paint overflow stripes over the state under review. Production hosts it in a
/// `ListView.separated`, which is exactly this: unbounded height, and growth
/// turns into scroll rather than into an error.
///
/// [WalletActivityL10n.of] needs a [BuildContext] under the preview's
/// [Localizations], which is what the [Builder] is for — the resolver picks EN
/// or AR off the ambient locale exactly as the production screen does.
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
///
/// This is the shape every other state is a degradation of — typed icon, type
/// label, `Ref:` sub-line, relative age, signed amount. It is the fixture the
/// screen test seeds (`wallet_activity_row_led-seed-fee_won`), and it carries
/// the matrix because it is a [Row] of icon + text + number at its most
/// ordinary: the AR RTL card is where the mirroring — and the misplaced `-` in
/// `-0.90 USD` — is visible, and the 200% card shows what the row costs
/// vertically (84 pt → 344 pt) even on an amount narrow enough not to break the
/// layout the way [walletActivityRowLongRef] does.
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
///
/// Read this card directly against [walletActivityRowFeeDebit]. The ONLY
/// signals that this is money in rather than money out are a one-character `+`
/// and `colors.primary` on the amount — the icon changes too, but a gift box
/// and a percent sign do not read as opposite directions. If the tint is hard
/// to tell from the debit's `onSurface` in either brightness, the sign is
/// carrying the whole distinction on its own.
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
///
/// Both sub-lines are behind `if (…isNotEmpty)` guards, and both resolvers
/// return `''` for empty input — `refLabel('')` short-circuits, and
/// `relativeTime('')` falls through `ServerTime.parse` returning null to hand
/// back the empty string it was given. So this is not hypothetical: any W2m row
/// that omits `ref` or `ts` collapses to a type label and a number.
///
/// What the card is for is the height. The row does not shrink to fit its text
/// — the 56 pt `_LeadingIcon` sets the floor at 81 pt, barely shorter than the
/// full three-line row above. A list of these is mostly empty space, and the
/// tap target says nothing about what tapping it will open.
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
///
/// The Dio projection maps any unrecognized W2m `type` to
/// [WalletLedgerType.unknown], which renders the generic "Activity" label and a
/// receipt glyph — deliberately quiet, because a fabricated label would be
/// worse than a vague one. `currency` is nullable in [WalletLedgerEntry] and
/// `signedAmount` simply drops the suffix when it is missing, so the amount
/// here reads `-1.75` with no unit at all. In a ledger where a jeeber is
/// reconciling money that is a real ambiguity, and this is the only place it is
/// ever seen — every screen test asserts on semantics identifiers, which are
/// unaffected.
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
///
/// This is where the [Row]'s asymmetry shows. The ref is the ONLY clamped line
/// (`maxLines: 1`, ellipsis) and it lives inside the [Expanded]; the amount is
/// unclamped and NOT flexible, so it takes its intrinsic width first and the
/// ref ellipsizes into whatever is left. The type label and the timestamp are
/// unclamped too — they just happen to be short in both locales.
///
/// It carries the matrix because the 200% card is a genuine break, not a tight
/// fit. Measured at 390 pt: at 1.0× the amount already takes 169 pt and the ref
/// is ellipsized down to 109 pt. At 200% the amount wants **337 pt** of the
/// 342 pt of content width, while the 56 pt icon and the 12/16 pt gaps do not
/// scale at all — so the [Expanded] collapses to **zero width** (the type label
/// and the ref disappear entirely, the label reflowing into a 200 pt-tall
/// column of nothing) and the [Row] still overflows by 59 px off the trailing
/// edge. The EN 1.0× card is fine, which is exactly why this needs a card that
/// is not.
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
///
/// `relativeTime` falls back to the input string whenever [DateTime.tryParse]
/// returns null, and the Dio projection accepts whatever string W2m put in
/// `ts` — so one service that formats dates for humans is all it takes to leak
/// a raw field onto the row. It is a deliberately quiet failure (a garbled date
/// beats a crash or a fabricated "Just now"), but it is invisible to every test
/// that asserts on semantics identifiers, and unlike the type label it does not
/// localize: the AR card shows the same Latin-digit English string.
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
