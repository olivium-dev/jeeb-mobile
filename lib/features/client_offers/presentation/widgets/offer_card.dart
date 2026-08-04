import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_vehicle.dart';
import '../../domain/offer.dart';

/// One offer card in the client offer-review list (JM-028).
///
/// MIDNIGHT · R10. Two rows inside a [JeebOutlinedCard]:
///   1. Ø42 identity disc · name (+ optional `Fastest` pill) · rating meta ·
///      end-aligned price over ETA;
///   2. the "Pay $X cash on delivery" line (D11) and the Accept pill.
///
/// The top-ranked card ([isBestValue]) is the tile's *lit* card — the caption's
/// "orange rim + glow + solid orange Accept": a 2px accent frame over the same
/// glass fill, [JeebShadows.accentSelected], an overhanging orange `Best value`
/// badge and the screen's one orange CTA. **Every other card keeps a full
/// action row** — plan §7.2-C4: every offer must stay acceptable, so
/// [JeebCardState.dormant] (the tile's dimmed third card) is never used here.
///
/// The card is intentionally dumb — it takes the offer payload plus four flags
/// from the cubit and emits two callbacks ([onAccept], [onTapName]); no cubit /
/// `sl` / navigation here so it stays golden-testable with fixture data
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
///   - `offer_card_<index>_best_value_badge`       / `…_<jeeberId>_best_value_badge`
///   - `offer_card_<index>_fastest_badge`          / `…_<jeeberId>_fastest_badge`
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.index,
    required this.onAccept,
    required this.onTapName,
    this.isAccepting = false,
    this.acceptDisabled = false,
    this.isBestValue = false,
    this.isFastest = false,
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

  /// This offer tops the composite ranking (`offer_ranking.dart`): the lit
  /// card, orange badge, orange Accept. Never set for a single-offer list.
  final bool isBestValue;

  /// This offer has the unique lowest ETA and is not the best-value card.
  final bool isFastest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = context.jeebText;
    final semantics = _semanticsOf(theme);
    // Lane item 3 (currency unification): one formatter across receipt,
    // offers, tiers — "$12.00" for USD, "LBP 15,000.00" otherwise. No more
    // mixed "17.50 / USD" pill vs "$12.00" receipt.
    final feeFormatted = MoneyFormat.format(
      offer.fee,
      currency: offer.currency,
    );
    final vehicleLabel = _vehicleLabel(l10n, offer.vehicle);

    // Optional Jeeber note (offer.note). Trim so a whitespace-only note from the
    // gateway renders nothing.
    final note = offer.note?.trim();
    final hasNote = note != null && note.isNotEmpty;

    // W6 "People, not UUIDs" (sprint-009 SW-08): the offer-list row is NOT
    // enriched with a display name by the gateway (O-list-enrich gap in
    // DioOffersRepository), so `jeeberName` is frequently the raw jeeberId UUID
    // or a synthetic `jeeb-<hash>` handle. Suppress those via [displayNameOrNull]
    // and fall back to an honest generic ("New Jeeber") — the card must never
    // headline an identifier as a person's name at the accept-ONE decision
    // moment. Real names populate once accounts set them (profile-name
    // onboarding); until then every unnamed Jeeber reads as "New Jeeber".
    final displayName =
        displayNameOrNull(offer.jeeberName) ?? l10n.offersCardJeeberFallback;
    // Ratings are shown honestly: real stars + count only when the Jeeber has
    // been rated; otherwise "No ratings yet" — never a fabricated "4.5 (0)".
    final hasRatings = offer.ratingCount > 0;

    final baseSemanticLabel = hasRatings
        ? l10n.offersCardSemanticLabel(
            name: displayName,
            rating: offer.rating.toStringAsFixed(1),
            vehicle: vehicleLabel,
            fee: feeFormatted,
            currency: offer.currency,
            minutes: offer.etaMinutes,
          )
        : l10n.offersCardSemanticLabelUnrated(
            name: displayName,
            vehicle: vehicleLabel,
            fee: feeFormatted,
            currency: offer.currency,
            minutes: offer.etaMinutes,
          );
    // Append the note and the ranking badges to the screen-reader label so they
    // are announced with the rest of the card facts (each visible node is also
    // independently addressable by its own identifier).
    final labelParts = <String>[
      baseSemanticLabel,
      if (isBestValue) l10n.offersCardBestValueBadge,
      if (isFastest) l10n.offersCardFastestBadge,
      if (hasNote) note,
    ];
    final semanticLabel = labelParts.join('. ');

    final card = JeebOutlinedCard(
      key: Key('offer-card-${offer.id}'),
      // The caption spells the lit card out as "orange rim + glow + solid
      // orange Accept" — a frame, NOT R9's `accentSelected` orange fill.
      borderColor: isBestValue ? context.jeebRoles.accent : null,
      borderWidth: isBestValue ? _kLitBorderWidth : 1,
      padding: _kCardPadding,
      actionsSpacing: Spacing.small,
      actions: Row(
        children: [
          // "Pay $X cash on delivery" (D11) — the load-bearing comprehension
          // line: payment is cash to the Jeeber on delivery, not in-app.
          Expanded(
            child: _IdWrap(
              indexId: 'offer_card_${index}_cash_on_delivery_label',
              patternId:
                  'offer_card_${offer.jeeberId}_cash_on_delivery_label',
              child: Text(
                l10n.offerCardCashOnDelivery(feeFormatted, offer.currency),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.caption.copyWith(color: semantics.mutedText),
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          // Accept → JM-029 offer-accept-confirm sheet (not inline).
          _AcceptCta(
            indexId: 'offer_card_${index}_accept_cta',
            patternId: 'offer_card_${offer.jeeberId}_accept_cta',
            label: isAccepting
                ? l10n.offersCardAccepting
                : l10n.offersCardAccept,
            offerId: offer.id,
            enabled: !acceptDisabled && !isAccepting,
            loading: isAccepting,
            // Only the lit card draws the tile's orange act; the siblings
            // recede onto glass so comparison reads by brightness.
            variant: isBestValue
                ? JeebCtaVariant.accent
                : JeebCtaVariant.outline,
            onTap: onAccept,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Row(
            children: [
              JeebAvatar.thread(
                initial: displayName,
                imageUrl: offer.avatarUrl,
                // The "unknown" disc is bound to a FACT the app holds (no
                // ratings), never to a guess about the person.
                fill: hasRatings
                    ? JeebAvatarFill.primary
                    : JeebAvatarFill.dormant,
              ),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: _NameTapTarget(
                            indexId: 'offer_card_${index}_name',
                            patternId: 'offer_card_${offer.jeeberId}_name',
                            name: displayName,
                            onTap: onTapName,
                          ),
                        ),
                        if (isFastest) ...[
                          const SizedBox(width: Spacing.xSmall),
                          _IdWrap(
                            indexId: 'offer_card_${index}_fastest_badge',
                            patternId:
                                'offer_card_${offer.jeeberId}_fastest_badge',
                            child: _FastestPill(
                              label: l10n.offersCardFastestBadge,
                            ),
                          ),
                        ],
                      ],
                    ),
                    _MetaLine(
                      hasRatings: hasRatings,
                      averageRating: offer.rating,
                      ratingCount: offer.ratingCount,
                      noRatingsLabel: l10n.offersCardNoRatingsYet,
                      vehicleLabel: vehicleLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.small),
              // Doc-13 P1: the money column HUGS its content (a `Flexible`
              // twin of the name's `Expanded` split the row 50/50 and
              // ellipsized names at the board's own canvas). The cap is what
              // keeps a 200%-text LBP figure from overflowing the row.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * _kPriceColumnMaxFraction,
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IdWrap(
                    indexId: 'offer_card_${index}_price',
                    patternId: 'offer_card_${offer.jeeberId}_price',
                    child: Text(
                      feeFormatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: text.price.copyWith(color: colors.onSurface),
                    ),
                  ),
                  _IdWrap(
                    indexId: 'offer_card_${index}_eta',
                    patternId: 'offer_card_${offer.jeeberId}_eta',
                    child: Text(
                      l10n.offersCardEtaIn(offer.etaMinutes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: text.caption.copyWith(color: semantics.mutedText),
                    ),
                  ),
                ],
                ),
              ),
            ],
            ),
          ),
          // Optional Jeeber note — rendered below the identity row when
          // present, hidden entirely otherwise.
          if (hasNote) ...[
            const SizedBox(height: Spacing.xSmall),
            _IdWrap(
              indexId: 'offer_card_${index}_note',
              patternId: 'offer_card_${offer.jeeberId}_note',
              child: _OfferNoteLine(note: note),
            ),
          ],
        ],
      ),
    );

    // The card is addressable both by index (the asserted Maestro id) and by
    // Jeeber id (the full `offer_card_<id>` AC pattern). The merged root node
    // carries the index id; the per-id alias is layered on the inner content.
    return _DualId(
      indexId: 'offer_card_$index',
      patternId: 'offer_card_${offer.jeeberId}',
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: _kCardGap),
        child: isBestValue
            ? Stack(
                // The badge straddles the card's top edge (board `top: -9`), so
                // the stack must not clip it — and the host list carries the
                // matching top padding.
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(JeebRadii.lg),
                      boxShadow: JeebShadows.accentSelected,
                    ),
                    child: card,
                  ),
                  PositionedDirectional(
                    end: Spacing.medium,
                    top: -_kBestValueBadgeOverhang,
                    child: _IdWrap(
                      indexId: 'offer_card_${index}_best_value_badge',
                      patternId:
                          'offer_card_${offer.jeeberId}_best_value_badge',
                      child: _BestValuePill(
                        label: l10n.offersCardBestValueBadge,
                      ),
                    ),
                  ),
                ],
              )
            : card,
      ),
    );
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

JeebSemanticColors _semanticsOf(ThemeData theme) =>
    theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();

/// Card padding — the board's dominant `13/16` card inset.
const EdgeInsetsGeometry _kCardPadding = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.medium,
  vertical: 13,
);

/// R12 — lists breathe at 9–12px between cards, not above AND below.
const double _kCardGap = 10;

/// How far the `Best value` badge stands proud of the card's top edge
/// (board `top: -9px`).
const double _kBestValueBadgeOverhang = Spacing.twoXSmall + 5;

/// Hit height for the tappable name. WCAG 2.5.8's 24dp floor, NOT 48 — a 48dp
/// layout minimum here is the doc-13 Pattern-E defect that splits name from meta.
const double _kNameTapMinHeight = 24;

/// Inline pill height inside a card row (board's Accept pill).
const double _kInlinePillHeight = 38;

/// Widest the money column may grow before it ellipsizes.
const double _kPriceColumnMaxFraction = 0.4;

/// The lit card's rim — the one 2px stroke in the card system.
const double _kLitBorderWidth = 2;

/// The `★ 4.9 (127) · Motorcycle` line under the name.
///
/// A `Wrap`, not a `Row`: at 200% text the rating and the vehicle have to be
/// able to split across runs instead of overflowing (`offer_card_overflow_test`
/// pins 411dp). The vehicle stays its OWN `Text` so `find.text('Motorcycle')`
/// keeps resolving.
///
/// TODO(midnight): the board's third fact in this line is "3 km away". No
/// distance field exists on `Offer`, on the offers wire row, or on the request
/// row — omitted, not faked. Restore it when the gateway sends `distanceKm`.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.hasRatings,
    required this.averageRating,
    required this.ratingCount,
    required this.noRatingsLabel,
    required this.vehicleLabel,
  });

  final bool hasRatings;
  final double averageRating;
  final int ratingCount;
  final String noRatingsLabel;
  final String vehicleLabel;

  @override
  Widget build(BuildContext context) {
    final semantics = _semanticsOf(Theme.of(context));
    final metaStyle = context.jeebText.bodySmall.copyWith(
      color: semantics.mutedText,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Spacing.twoXSmall,
      children: [
        if (hasRatings) ...[
          OmdsStarRatingDisplay(
            averageRating: averageRating,
            // The board draws ONE star followed by the score — a five-star
            // strip would out-weigh the price at this size.
            starCount: 1,
            starSize: Sizes.small,
            spacing: Spacing.twoXSmall,
            // Board stars are amber `#FFC107`, never the OMDS default gold.
            activeColor: semantics.amber,
            // The count is rendered as its OWN Wrap child rather than through
            // `totalReviews` + `reviewsLabelBuilder`: OMDS lays the count
            // inside its own unbreakable `Row`, and a seven-figure review count
            // at 200% text overflows that Row by ~230px
            // (`offer_card_overflow_test` pins 411dp). As a sibling it can
            // ellipsize and wrap.
            showReviewCount: false,
            ratingTextStyle: metaStyle,
          ),
          Text(
            '($ratingCount)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metaStyle,
          ),
        ] else
          _NoRatingsYet(label: noRatingsLabel),
        Text('·', style: metaStyle),
        Text(
          vehicleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metaStyle,
        ),
      ],
    );
  }
}

/// Max visible lines for the optional Jeeber note before it ellipsizes.
const int _kOfferNoteMaxLines = 3;

/// Optional free-text note the Jeeber attached to the bid (`offer.note`).
/// Rendered as an icon + up-to-3-line ellipsized secondary line. Only mounted
/// when the offer carries a non-blank note.
class _OfferNoteLine extends StatelessWidget {
  const _OfferNoteLine({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final semantics = _semanticsOf(Theme.of(context));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: Sizes.small,
          color: semantics.mutedText,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Expanded(
          child: Text(
            note,
            maxLines: _kOfferNoteMaxLines,
            overflow: TextOverflow.ellipsis,
            style: context.jeebText.caption.copyWith(
              color: semantics.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}

/// Honest zero-rating line (SW-08): shown in place of [OmdsStarRatingDisplay]
/// when the Jeeber has no ratings yet (`ratingCount == 0`). Replaces the
/// fabricated "4.5 (0)" the star display would otherwise render for a brand-new
/// Jeeber. A muted outline-star glyph + "No ratings yet" reads as an honest
/// cold-start signal, not a real score.
class _NoRatingsYet extends StatelessWidget {
  const _NoRatingsYet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final semantics = _semanticsOf(Theme.of(context));
    return Semantics(
      identifier: 'offer_card_no_ratings',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_border,
            size: Sizes.small,
            color: semantics.mutedText,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.jeebText.bodySmall.copyWith(
                color: semantics.mutedText,
              ),
            ),
          ),
        ],
      ),
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
      child: Semantics(identifier: patternId, child: child),
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
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      identifier: indexId,
      button: true,
      label: name,
      onTap: onTap,
      child: Semantics(
        identifier: patternId,
        child: ExcludeSemantics(
          // The glass card is a DecoratedBox, not a Material — the ripple needs
          // its own transparent one.
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: Key('offer-card-name-$name'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _kNameTapMinHeight,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1.0,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // No underline: the board's names are plain white w700 and
                    // the hit target already advertises the affordance.
                    style: context.jeebText.cardTitle.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Accept CTA → offer-accept-confirm sheet. Hugs its label (the board's inline
/// pill), so it must not be stretched to the card width.
class _AcceptCta extends StatelessWidget {
  const _AcceptCta({
    required this.indexId,
    required this.patternId,
    required this.label,
    required this.offerId,
    required this.enabled,
    required this.loading,
    required this.variant,
    required this.onTap,
  });

  final String indexId;
  final String patternId;
  final String label;
  final String offerId;
  final bool enabled;
  final bool loading;
  final JeebCtaVariant variant;
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
          child: JeebCtaButton(
            key: Key('offer-card-accept-$offerId'),
            label: label,
            variant: variant,
            isEnabled: enabled,
            isLoading: loading,
            expand: false,
            height: _kInlinePillHeight,
            labelStyle: context.jeebText.body.copyWith(
              fontWeight: FontWeight.w700,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Solid-orange `Best value` badge overhanging the lit card's top edge.
/// The ONE orange fill on a card — §4.1 rations it to exactly this.
class _BestValuePill extends StatelessWidget {
  const _BestValuePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.accent,
        borderRadius: BorderRadius.circular(JeebRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xSmall,
          vertical: Sizes.threeXSmall,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.jeebText.badge.copyWith(color: roles.onAccent),
        ),
      ),
    );
  }
}

/// Raised-navy `Fastest` pill sitting inline after the Jeeber's name.
class _FastestPill extends StatelessWidget {
  const _FastestPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(JeebRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xSmall,
          vertical: Sizes.threeXSmall,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.jeebText.badge.copyWith(color: colors.onSurface),
        ),
      ),
    );
  }
}
