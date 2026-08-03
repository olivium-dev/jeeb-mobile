import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/submitted_offer.dart';

/// A single submitted-offer row in the feed's Pending-Response sub-tab
/// (JM-047/048): the price the jeeber quoted + ETA + an "Awaiting customer
/// decision" status + a Withdraw control (D15).
///
/// The QA flow (`jm-048` AC3, `jm-047`) keys off the ROW INDEX, not the offer
/// id, so the row carries an index-based `pending_offer_<index>` root plus the
/// `pending_offer_<index>_price` / `_eta` / `_withdraw_cta` children and the
/// shared `pending_offer_awaiting_label` (65_W2_TEST_PLAN §2 JM-047/048).
/// `explicitChildNodes` keeps each child queryable as its own native node
/// rather than folding into the row.
///
/// redesign-2026-08 (w5, from `wiring/w4-jeeber-pending-offers.md` R1): the
/// bare strip became a [JeebOutlinedCard] — white fill, 1.5px
/// `colorScheme.outline`, r16, **no shadow** (outline-over-shadow) — so the row
/// no longer paints its own trailing `Divider`: the outline *is* the
/// separation, and a hairline between two outlined cards draws a third line
/// nobody asked for. Type comes from `context.jeebText` (`price` for the money,
/// `caption` for its ETA qualifier); the status line is the board's
/// [JeebSystemChip] instead of periwinkle italics on white (§4.1 forbids
/// periwinkle body ink on white); Withdraw is a [JeebCtaButton] outline pill.
///
/// **The gutter lives here, not in the consumers.** Three surfaces mount this
/// row — the standalone `/jeeber/pending-offers` route, the jeeber-home feed's
/// Pending-Response sub-tab, and the shell dashboard tab's copy of that feed —
/// and only one of them is inside the migrating lane's directory. Owning
/// [rowPadding] here gives all three the board's 24px page margin and the same
/// 16px inter-card rhythm with zero consumer edits, which is also why the
/// existing zero-horizontal-gutter list paddings at every call site stay
/// correct.
///
/// Wording is untouched: a jeeber sends ONE private offer per request, so
/// nothing here implies a plural.
class PendingOfferRow extends StatelessWidget {
  const PendingOfferRow({
    super.key,
    required this.index,
    required this.offer,
    required this.isWithdrawing,
    this.onWithdraw,
  });

  /// Row gutter — the board's 24px page margin with an 8px half-gap, byte-for-
  /// byte the `rowPadding` of the two already-migrated siblings in this
  /// directory (`RequestCard`, `JeeberFeedCard`) so a jeeber scrolling from
  /// Requests to Pending-Response sees one rhythm, not two.
  static const EdgeInsetsGeometry rowPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.xLarge,
    vertical: Spacing.xSmall,
  );

  final int index;
  final SubmittedOffer offer;
  final bool isWithdrawing;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    // sprint-009: a terminal offer (accepted / lost) shows an outcome badge and
    // NO withdraw control; a still-open offer keeps the "awaiting" label +
    // Withdraw (unchanged contract).
    final bool isTerminal = offer.status.isTerminal;
    return Semantics(
      identifier: 'pending_offer_$index',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: rowPadding,
        child: JeebOutlinedCard(
          // The decision rides the card's own action slot, so the kit owns the
          // gap between the body and the control (same idiom as `RequestCard`).
          actions: isTerminal
              ? null
              : _WithdrawAction(
                  index: index,
                  isWithdrawing: isWithdrawing,
                  onWithdraw: onWithdraw,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PriceEtaRow(index: index, offer: offer),
              const SizedBox(height: Spacing.small),
              if (isTerminal)
                _StatusBadge(index: index, status: offer.status)
              else
                const _AwaitingLabel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceEtaRow extends StatelessWidget {
  const _PriceEtaRow({required this.index, required this.offer});

  final int index;
  final SubmittedOffer offer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _PriceText(index: index, offer: offer)),
        if (offer.etaMinutes != null) ...[
          const SizedBox(width: Spacing.small),
          _EtaText(index: index, etaMinutes: offer.etaMinutes!),
        ],
      ],
    );
  }
}

class _PriceText extends StatelessWidget {
  const _PriceText({required this.index, required this.offer});

  final int index;
  final SubmittedOffer offer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatted = NumberFormat.simpleCurrency(
      locale: locale,
      name: offer.currency,
    ).format(offer.price);
    return Semantics(
      identifier: 'pending_offer_${index}_price',
      child: Text(
        formatted,
        // `jeebText.price` is the ramp's declared "offer prices" style, and the
        // ink is NAVY: what the jeeber quoted is the card's most-read number,
        // but the accent stays rationed for a do-it-now moment, which a list of
        // already-sent offers does not have. (It was `secondaryContainer` — a
        // container fill used as text ink, i.e. periwinkle on white.)
        style: context.jeebText.price.copyWith(color: theme.colorScheme.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EtaText extends StatelessWidget {
  const _EtaText({required this.index, required this.etaMinutes});

  final int index;
  final int etaMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'pending_offer_${index}_eta',
      child: Text(
        '$etaMinutes ${l10n.offerSubmissionEtaSuffix}',
        // The price's qualifier — `caption` is the ramp's "ETA and cash lines"
        // style, matching `RequestCard`'s countdown.
        style: context.jeebText.caption.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// sprint-009 offer-lifecycle outcome badge for a TERMINAL offer. Carries the
/// stable `pending_offer_<index>_status` id so a Maestro flow can assert the
/// customer's decision. Reuses the closest existing localized strings
/// (`requestStatusAccepted` / `requestFeedActionDeclinedSnack`) — the asserted
/// contract is the Semantics id, not the visible text (i18n-safe, integrator
/// owns the dedicated ARB keys).
///
/// redesign-2026-08: the hand-rolled pill became [JeebSystemChip.filled], the
/// board's settled-fact chip — which is exactly what screen 21 uses for its own
/// `Offer accepted` / `Offer rejected` rows, so the two surfaces that report the
/// same fact now report it the same way. One tone for both outcomes is the
/// board's answer; the copy carries the decision.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.index, required this.status});

  final int index;
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAccepted = status == OfferStatus.accepted;
    final label = isAccepted
        ? l10n.requestStatusAccepted
        : l10n.requestFeedActionDeclinedSnack;
    return Semantics(
      identifier: 'pending_offer_${index}_status',
      // `center: false` — the enclosing Column already aligns to the start
      // edge, and the chip must not stretch across the card.
      child: JeebSystemChip.filled(label: label, center: false),
    );
  }
}

class _AwaitingLabel extends StatelessWidget {
  const _AwaitingLabel();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'pending_offer_awaiting_label',
      // A system state, not italic body copy: the same settled-fact chip the
      // outcome uses, so "waiting" and "answered" are one visual family.
      // Periwinkle ink now sits on `surfaceContainerHigh` rather than on white
      // (§4.1 — a contrast test asserts periwinkle is never body ink on white).
      child: JeebSystemChip.filled(
        // No dedicated "Awaiting customer decision" key exists yet (JM-047
        // owns it; ARB is integrator-owned, 50_ROUTE_REQUESTS). Reuse the
        // closest existing localized string — the asserted contract is the
        // Semantics id, not the visible text (i18n-safe, CTO brief §6.6).
        label: AppLocalizations.of(context).jeeberFeedStatusPending,
        center: false,
      ),
    );
  }
}

class _WithdrawAction extends StatelessWidget {
  const _WithdrawAction({
    required this.index,
    required this.isWithdrawing,
    required this.onWithdraw,
  });

  final int index;
  final bool isWithdrawing;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      // The Semantics node stays INSIDE the Align so its rect is the pill and
      // not the full card width — a Maestro/`tester.tap` on
      // `pending_offer_<i>_withdraw_cta` hits the button, as it does today.
      child: Semantics(
        identifier: 'pending_offer_${index}_withdraw_cta',
        button: true,
        // JeebCtaButton.outline keeps the in-flight spinner OmdsPrimaryButton
        // lacks, so nothing is lost by leaving OmdsLoadingButton behind. No
        // `identifier:` is passed to the kit — this explicit wrapper is the
        // frozen node, and a second one inside it would nest two buttons.
        //
        // Deliberate: the pill drops its `errorContainer` tint. The board has
        // no destructive-fill affordance — 12's "Report no-show", the closest
        // destructive action on it, is a plain outline pill — and the error
        // family is reserved for actual error surfaces.
        child: JeebCtaButton.outline(
          key: Key('pending-offer-withdraw-$index'),
          label: AppLocalizations.of(context).offerSubmissionWithdrawButton,
          isLoading: isWithdrawing,
          expand: false,
          // Unchanged contract: the control stays tappable when a host omits
          // the callback, exactly as `onWithdraw ?? () {}` did before.
          onTap: onWithdraw ?? () {},
        ),
      ),
    );
  }
}
