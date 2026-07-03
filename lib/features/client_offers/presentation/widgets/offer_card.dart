import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_vehicle.dart';
import '../../domain/offer.dart';

/// One offer card in the client offer-review list (JM-028).
///
/// Renders the Jeeber's identity, the price + ETA + vehicle facts, the rating,
/// the "Pay $X cash on delivery" line (D11), and the Accept CTA. The card is
/// intentionally dumb — it takes the offer payload + two flags from the cubit
/// and emits two callbacks ([onAccept], [onTapName]); no cubit / `sl` /
/// navigation here so it stays golden-testable with fixture data
/// (40_GUARDRAILS_ARCH §1).
///
/// Semantics identifiers exposed (EXACT, 63_W1_TEST_PLAN §2.8). [index] keys the
/// position-based ids the Maestro flow asserts (`offer_card_0…`) while the
/// per-Jeeber pattern (`offer_card_<jeeberId>…`) is also exposed on every card
/// so the full `offer_card_<id>` AC pattern resolves:
///   - `offer_card_<index>`                        / `offer_card_<jeeberId>`
///   - `offer_card_<index>_price`                  / `…_<jeeberId>_price`
///   - `offer_card_<index>_eta`                    / `…_<jeeberId>_eta`
///   - `offer_card_<index>_cash_on_delivery_label` / `…_<jeeberId>_cash_on_delivery_label`
///   - `offer_card_<index>_name`                   / `…_<jeeberId>_name`  (→ jeeber-profile-reviews)
///   - `offer_card_<index>_accept_cta`             / `…_<jeeberId>_accept_cta` (→ offer-accept-confirm)
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.index,
    required this.onAccept,
    required this.onTapName,
    this.isAccepting = false,
    this.acceptDisabled = false,
  });

  final Offer offer;

  /// Zero-based position in the sorted list. Drives the `offer_card_<index>…`
  /// identifiers the Maestro flow keys on (it asserts the index-0 card).
  final int index;

  /// Fired when the Accept CTA is tapped — the host opens the JM-029
  /// `offer-accept-confirm` sheet (NOT an inline accept, D11/D71).
  final VoidCallback onAccept;

  /// Fired when the Jeeber name is tapped — the host routes to
  /// `jeeber-profile-reviews` (JM-067).
  final VoidCallback onTapName;

  /// True while the cubit's accept call is in-flight on this offer.
  final bool isAccepting;

  /// True when another offer is mid-accept, or the window has expired, or the
  /// request is closed — the CTA stays visible but inert so the layout
  /// doesn't jump.
  final bool acceptDisabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Lane item 3 (currency unification): one formatter across receipt,
    // offers, tiers — "$12.00" for USD, "LBP 15,000.00" otherwise. No more
    // mixed "17.50 / USD" pill vs "$12.00" receipt.
    final feeFormatted =
        MoneyFormat.format(offer.fee, currency: offer.currency);
    final vehicleLabel = _vehicleLabel(l10n, offer.vehicle);

    // Optional Jeeber note (offer.note). Trim so a whitespace-only note from the
    // gateway renders nothing.
    final note = offer.note?.trim();
    final hasNote = note != null && note.isNotEmpty;

    final baseSemanticLabel = l10n.offersCardSemanticLabel(
      name: offer.jeeberName,
      rating: offer.rating.toStringAsFixed(1),
      vehicle: vehicleLabel,
      fee: feeFormatted,
      currency: offer.currency,
      minutes: offer.etaMinutes,
    );
    // Append the note to the screen-reader label so it is announced with the
    // rest of the card facts (the visible node is also independently addressable
    // by `offer_card_<index>_note`).
    final semanticLabel = hasNote ? '$baseSemanticLabel. $note' : baseSemanticLabel;

    // The card is addressable both by index (the asserted Maestro id) and by
    // Jeeber id (the full `offer_card_<id>` AC pattern). The merged root node
    // carries the index id; the per-id alias is layered on the inner content.
    return _DualId(
      indexId: 'offer_card_$index',
      patternId: 'offer_card_${offer.jeeberId}',
      label: semanticLabel,
      child: Card(
        key: Key('offer-card-${offer.id}'),
        margin: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
        elevation: UIConstants.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: OmdsBorderRadius.medium,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OmdsProfileAvatar(
                    initial: _initial(offer.jeeberName),
                    profilePicUrl: offer.avatarUrl,
                    size: Sizes.fourXLarge,
                  ),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Jeeber name — tap target → jeeber-profile-reviews.
                        _NameTapTarget(
                          indexId: 'offer_card_${index}_name',
                          patternId: 'offer_card_${offer.jeeberId}_name',
                          name: offer.jeeberName,
                          onTap: onTapName,
                        ),
                        const SizedBox(height: Spacing.twoXSmall),
                        OmdsStarRatingDisplay(
                          averageRating: offer.rating,
                          totalReviews: offer.ratingCount,
                          starSize: Sizes.medium,
                          reviewsLabelBuilder: (count) => '$count',
                        ),
                      ],
                    ),
                  ),
                  // Price pill.
                  _IdWrap(
                    indexId: 'offer_card_${index}_price',
                    patternId: 'offer_card_${offer.jeeberId}_price',
                    child: _FeePill(amount: feeFormatted),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.small),
              Row(
                children: [
                  // ETA chip.
                  _IdWrap(
                    indexId: 'offer_card_${index}_eta',
                    patternId: 'offer_card_${offer.jeeberId}_eta',
                    child: _MetaChip(
                      icon: Icons.access_time,
                      label: l10n.offersCardEtaMinutes(offer.etaMinutes),
                    ),
                  ),
                  const SizedBox(width: Spacing.xSmall),
                  _MetaChip(
                    icon: _vehicleIcon(offer.vehicle),
                    label: vehicleLabel,
                  ),
                ],
              ),
              // Optional Jeeber note — rendered below the ETA/vehicle chips
              // when present, hidden entirely otherwise.
              if (hasNote) ...[
                const SizedBox(height: Spacing.small),
                _IdWrap(
                  indexId: 'offer_card_${index}_note',
                  patternId: 'offer_card_${offer.jeeberId}_note',
                  child: _OfferNoteLine(note: note),
                ),
              ],
              const SizedBox(height: Spacing.small),
              // "Pay $X cash on delivery" (D11) — the load-bearing comprehension
              // line: payment is cash to the Jeeber on delivery, not in-app.
              _IdWrap(
                indexId: 'offer_card_${index}_cash_on_delivery_label',
                patternId:
                    'offer_card_${offer.jeeberId}_cash_on_delivery_label',
                child: Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: Sizes.medium,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.xSmall),
                    Expanded(
                      child: Text(
                        l10n.offerCardCashOnDelivery(
                          feeFormatted,
                          offer.currency,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.medium),
              // Accept CTA → opens the JM-029 offer-accept-confirm sheet.
              _AcceptCta(
                indexId: 'offer_card_${index}_accept_cta',
                patternId: 'offer_card_${offer.jeeberId}_accept_cta',
                label: isAccepting
                    ? l10n.offersCardAccepting
                    : l10n.offersCardAccept,
                offerId: offer.id,
                enabled: !acceptDisabled && !isAccepting,
                loading: isAccepting,
                onTap: onAccept,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static IconData _vehicleIcon(JeeberVehicle vehicle) {
    switch (vehicle) {
      case JeeberVehicle.car:
        return Icons.directions_car_outlined;
      case JeeberVehicle.motorcycle:
        return Icons.two_wheeler_outlined;
      case JeeberVehicle.bicycle:
        return Icons.pedal_bike_outlined;
      case JeeberVehicle.scooter:
        return Icons.electric_scooter_outlined;
      case JeeberVehicle.walker:
        return Icons.directions_walk_outlined;
      case JeeberVehicle.van:
        return Icons.local_shipping_outlined;
    }
  }

  static String _vehicleLabel(AppLocalizations l10n, JeeberVehicle vehicle) {
    switch (vehicle) {
      case JeeberVehicle.car:
        return l10n.offersCardVehicleCar;
      case JeeberVehicle.motorcycle:
        return l10n.offersCardVehicleMotorcycle;
      case JeeberVehicle.bicycle:
        return l10n.offersCardVehicleBicycle;
      case JeeberVehicle.scooter:
        return l10n.offersCardVehicleScooter;
      case JeeberVehicle.walker:
        return l10n.offersCardVehicleWalker;
      case JeeberVehicle.van:
        return l10n.offersCardVehicleVan;
    }
  }
}

/// Max visible lines for the optional Jeeber note before it ellipsizes.
const int _kOfferNoteMaxLines = 3;

/// Optional free-text note the Jeeber attached to the bid (`offer.note`).
/// Rendered as an icon + up-to-3-line ellipsized secondary line below the
/// ETA/vehicle chips. Only mounted when the offer carries a non-blank note.
class _OfferNoteLine extends StatelessWidget {
  const _OfferNoteLine({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: Sizes.medium,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            note,
            maxLines: _kOfferNoteMaxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Wraps [child] so both an index-based id and a per-Jeeber-id id resolve to
/// the same subtree. Maestro matches either; the index id is the asserted one.
class _IdWrap extends StatelessWidget {
  const _IdWrap({
    required this.indexId,
    required this.patternId,
    required this.child,
  });

  final String indexId;
  final String patternId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: indexId,
      child: Semantics(
        identifier: patternId,
        child: child,
      ),
    );
  }
}

/// The card root — exposes the index id and the per-Jeeber id as a container,
/// plus the rich screen-reader [label]. Children stay independently
/// addressable so Maestro can tap the name / accept CTA.
class _DualId extends StatelessWidget {
  const _DualId({
    required this.indexId,
    required this.patternId,
    required this.label,
    required this.child,
  });

  final String indexId;
  final String patternId;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: indexId,
      container: true,
      label: label,
      explicitChildNodes: true,
      child: Semantics(
        identifier: patternId,
        explicitChildNodes: true,
        child: child,
      ),
    );
  }
}

/// Tappable Jeeber name → jeeber-profile-reviews (JM-067).
class _NameTapTarget extends StatelessWidget {
  const _NameTapTarget({
    required this.indexId,
    required this.patternId,
    required this.name,
    required this.onTap,
  });

  final String indexId;
  final String patternId;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: indexId,
      button: true,
      label: name,
      onTap: onTap,
      child: Semantics(
        identifier: patternId,
        child: ExcludeSemantics(
          child: InkWell(
            key: Key('offer-card-name-$name'),
            onTap: onTap,
            child: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width Accept CTA → offer-accept-confirm sheet.
class _AcceptCta extends StatelessWidget {
  const _AcceptCta({
    required this.indexId,
    required this.patternId,
    required this.label,
    required this.offerId,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String indexId;
  final String patternId;
  final String label;
  final String offerId;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: indexId,
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onTap : null,
      child: Semantics(
        identifier: patternId,
        child: ExcludeSemantics(
          child: SizedBox(
            width: double.infinity,
            child: OmdsPrimaryButton(
              key: Key('offer-card-accept-$offerId'),
              text: label,
              isEnabled: enabled,
              onTap: onTap,
              icon: loading ? const OmdsButtonLoading() : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeePill extends StatelessWidget {
  const _FeePill({required this.amount});

  /// The fully-formatted money string (currency included — lane item 3:
  /// `MoneyFormat` output like `$12.00`), so the pill never renders a second
  /// bare currency-code line.
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Text(
        amount,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: colors.onSurfaceVariant),
          const SizedBox(width: Spacing.xSmall),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
