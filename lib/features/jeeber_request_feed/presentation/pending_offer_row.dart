import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

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
class PendingOfferRow extends StatelessWidget {
  const PendingOfferRow({
    super.key,
    required this.index,
    required this.offer,
    required this.isWithdrawing,
    this.onWithdraw,
  });

  final int index;
  final SubmittedOffer offer;
  final bool isWithdrawing;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'pending_offer_$index',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PriceEtaRow(index: index, offer: offer),
            const SizedBox(height: Spacing.twoXSmall),
            // sprint-009: a terminal offer (accepted / lost) shows an outcome
            // badge and NO withdraw control; a still-open offer keeps the
            // "awaiting" label + Withdraw (unchanged contract).
            if (offer.status.isTerminal)
              _StatusBadge(index: index, status: offer.status)
            else ...[
              _AwaitingLabel(),
              const SizedBox(height: Spacing.small),
              _WithdrawAction(
                index: index,
                isWithdrawing: isWithdrawing,
                onWithdraw: onWithdraw,
              ),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Spacing.small),
              child: Divider(height: 1, color: colorScheme.outlineVariant),
            ),
          ],
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
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.secondaryContainer,
          fontWeight: FontWeight.w600,
        ),
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
        style: theme.textTheme.labelMedium?.copyWith(
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
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.index, required this.status});

  final int index;
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isAccepted = status == OfferStatus.accepted;
    final label = isAccepted
        ? l10n.requestStatusAccepted
        : l10n.requestFeedActionDeclinedSnack;
    final fg = isAccepted
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final bg = isAccepted
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Semantics(
      identifier: 'pending_offer_${index}_status',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.twoXSmall,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: OmdsBorderRadius.pill,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class _AwaitingLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'pending_offer_awaiting_label',
      child: Text(
        // No dedicated "Awaiting customer decision" key exists yet (JM-047
        // owns it; ARB is integrator-owned, 50_ROUTE_REQUESTS). Reuse the
        // closest existing localized string — the asserted contract is the
        // Semantics id, not the visible text (i18n-safe, CTO brief §6.6).
        AppLocalizations.of(context).jeeberFeedStatusPending,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontStyle: FontStyle.italic,
        ),
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
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: IntrinsicWidth(
        child: Semantics(
          identifier: 'pending_offer_${index}_withdraw_cta',
          button: true,
          // OmdsLoadingButton (not OmdsPrimaryButton) so the row shows a busy
          // spinner while `DELETE /offer-service/v1/offers/:id` is in flight
          // (the primary button has no loading state). Destructive tint via
          // textColor=error + a tinted surface keeps it visually an outline
          // withdraw control without a magic-pixel border (design-tokens rule).
          child: OmdsLoadingButton(
            key: Key('pending-offer-withdraw-$index'),
            text: AppLocalizations.of(context).offerSubmissionWithdrawButton,
            isLoading: isWithdrawing,
            backgroundColor: theme.colorScheme.errorContainer,
            textColor: theme.colorScheme.onErrorContainer,
            loadingColor: theme.colorScheme.onErrorContainer,
            borderRadius: OmdsBorderRadius.pill,
            onTap: onWithdraw ?? () {},
          ),
        ),
      ),
    );
  }
}
