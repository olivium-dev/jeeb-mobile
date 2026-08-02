import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_vehicle.dart';
import '../../domain/offer.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

  final int index;

  final VoidCallback onAccept;

  final VoidCallback onTapName;

  final bool isAccepting;

  final bool acceptDisabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feeFormatted = MoneyFormat.format(
      offer.fee,
      currency: offer.currency,
    );
    final vehicleLabel = _vehicleLabel(l10n, offer.vehicle);

    final note = offer.note?.trim();
    final hasNote = note != null && note.isNotEmpty;

    final displayName =
        displayNameOrNull(offer.jeeberName) ?? l10n.offersCardJeeberFallback;
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
    final semanticLabel = hasNote
        ? '$baseSemanticLabel. $note'
        : baseSemanticLabel;

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
              _OfferCardHeader(
                displayName: displayName,
                avatarUrl: offer.avatarUrl,
                averageRating: offer.rating,
                ratingCount: offer.ratingCount,
                hasRatings: hasRatings,
                noRatingsLabel: l10n.offersCardNoRatingsYet,
                feeFormatted: feeFormatted,
                nameIndexId: 'offer_card_${index}_name',
                namePatternId: 'offer_card_${offer.jeeberId}_name',
                priceIndexId: 'offer_card_${index}_price',
                pricePatternId: 'offer_card_${offer.jeeberId}_price',
                onTapName: onTapName,
              ),
              const SizedBox(height: Spacing.small),
              Wrap(
                spacing: Spacing.xSmall,
                runSpacing: Spacing.xSmall,
                children: [
                  _IdWrap(
                    indexId: 'offer_card_${index}_eta',
                    patternId: 'offer_card_${offer.jeeberId}_eta',
                    child: _MetaChip(
                      icon: Icons.access_time,
                      label: l10n.offersCardEtaMinutes(offer.etaMinutes),
                    ),
                  ),
                  _MetaChip(
                    icon: _vehicleIcon(offer.vehicle),
                    label: vehicleLabel,
                  ),
                ],
              ),
              if (hasNote) ...[
                const SizedBox(height: Spacing.small),
                _IdWrap(
                  indexId: 'offer_card_${index}_note',
                  patternId: 'offer_card_${offer.jeeberId}_note',
                  child: _OfferNoteLine(note: note),
                ),
              ],
              const SizedBox(height: Spacing.small),
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

class _OfferCardHeader extends StatelessWidget {
  const _OfferCardHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.averageRating,
    required this.ratingCount,
    required this.hasRatings,
    required this.noRatingsLabel,
    required this.feeFormatted,
    required this.nameIndexId,
    required this.namePatternId,
    required this.priceIndexId,
    required this.pricePatternId,
    required this.onTapName,
  });

  final String displayName;
  final String? avatarUrl;
  final double averageRating;
  final int ratingCount;
  final bool hasRatings;
  final String noRatingsLabel;
  final String feeFormatted;
  final String nameIndexId;
  final String namePatternId;
  final String priceIndexId;
  final String pricePatternId;
  final VoidCallback onTapName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmdsProfileAvatar(
              initial: OfferCard._initial(displayName),
              profilePicUrl: avatarUrl,
              size: Sizes.fourXLarge,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: _NameTapTarget(
                indexId: nameIndexId,
                patternId: namePatternId,
                name: displayName,
                onTap: onTapName,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Wrap(
          spacing: Spacing.small,
          runSpacing: Spacing.twoXSmall,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (hasRatings)
              _RatingSummary(
                averageRating: averageRating,
                ratingCount: ratingCount,
              )
            else
              _NoRatingsYet(label: noRatingsLabel),
            _IdWrap(
              indexId: priceIndexId,
              patternId: pricePatternId,
              child: _FeePill(amount: feeFormatted),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({
    required this.averageRating,
    required this.ratingCount,
  });

  final double averageRating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OmdsStarRatingDisplay(
          averageRating: averageRating,
          starSize: Sizes.medium,
          showReviewCount: false,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Text(
            '($ratingCount)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

const int _kOfferNoteMaxLines = 3;

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

class _NoRatingsYet extends StatelessWidget {
  const _NoRatingsYet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      identifier: 'offer_card_no_ratings',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_border,
            size: Sizes.medium,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.fourXLarge),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1.0,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary,
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/client_offers/offer_card_preview_test.dart
// ===========================================================================

// Widget previews for [OfferCard] — run with `flutter widget-preview start`.
//
// [OfferCard] is deliberately dumb (40_GUARDRAILS_ARCH §1): it takes an [Offer]
// plus two booleans from `ClientOffersCubit` and emits two callbacks. There is
// no cubit, no `sl`, and no repository to fake, so every state below is a pure
// function of its fixture — these previews are network-free by construction,
// not merely by the guard in [jeebPreviewHost].
//
// One rule the fixtures follow that is easy to break: `avatarUrl` stays **null**
// everywhere. A non-null URL makes `OmdsProfileAvatar` build a `NetworkImage`,
// which is a real HTTP GET that the guard would happily allow (it only rejects
// mutating verbs). Null keeps the initial-letter placeholder — which is also
// what the SW-08 assertions below are about.
//
// Fixture values reuse `test/offer_card_test.dart` and
// `test/features/client_offers/offer_card_overflow_test.dart` (Hadi / $42.50 /
// 18 min / 4.7 (132); the UUID name; the LBP 1,234,567,890.99 ceiling) so the
// canvas and the widget suite describe the same card.
//
// ## Read the canvas knowing these three things
//
// **1. The widget tests never see phone width.** `offer_card_overflow_test.dart`
// pumps into an 800×600 viewport and asserts only "no exception thrown". No
// exception is ever thrown here — nothing in this card can overflow, because
// every text node is `maxLines` + `ellipsis` and both chip rows are `Wrap`s.
// It degrades by *silently dropping characters*, which a test that watches for
// `RenderFlex overflow` cannot see and the canvas shows immediately. Measured
// at 390 pt, the first thing each rendering loses:
//
// | rendering        | 100%          | 130%                 | 200%                        |
// |------------------|---------------|----------------------|-----------------------------|
// | EN, USD fee      | —             | —                    | name ("Nadine Khou…")       |
// | EN, LBP fee      | —             | **fee pill clipped** | fee pill + name             |
// | AR, USD fee      | —             | — (360 pt: ETA chip) | **ETA chip** + name         |
// | AR, LBP fee      | —             | **fee pill clipped** | fee pill + ETA chip + name  |
//
// **2. The card fills the preview box vertically.** Its inner `Column` is
// `mainAxisSize.max` and [jeebPreviewHost] hands the `Scaffold` body a tight
// height, so the border stretches to whatever `size:` says. In production the
// card is a `ListView` child (`client_offers_screen.dart`) and shrink-wraps.
// That is a canvas artifact, not a bug — the `size:` heights below are the
// measured intrinsic ones so it stays close to the real thing: 292 pt EN /
// 332 pt AR at 100% (Arabic line height makes every card ~40 pt taller), and
// ~500 pt at 200%, which no honest box height can contain.
//
// **3. `isAccepting` is unreachable in the shipped app.** See
// [offerCardAccepting].

/// Phone width; height fits the measured 100%-text card in BOTH locales
/// (EN 292 pt, AR 332 pt). The 200% rendering is ~500 pt and will clip.
const Size _offerCardBox = Size(390, 340);

/// Anchor timestamp shared with `test/support/offers_fixtures.dart` so a preview
/// and a widget test never disagree about "when" an offer arrived.
final DateTime _offerCardSubmittedAt = DateTime.utc(2026, 5, 17, 12);

/// Builds the card the way `client_offers_screen.dart` builds it — the only
/// production caller — so a preview cannot show a prop combination the app
/// never ships.
///
/// [isAccepting] and [acceptDisabled] are mutually exclusive: the cubit marks
/// the one offer whose accept is in flight, and disables every other card.
Widget _offerCardHosted({
  required String id,
  required String jeeberName,
  double fee = 30,
  String currency = 'USD',
  int etaMinutes = 12,
  JeeberVehicle vehicle = JeeberVehicle.scooter,
  double rating = 4.6,
  int ratingCount = 80,
  String? note,
  bool isAccepting = false,
  bool acceptDisabled = false,
}) {
  return OfferCard(
    offer: Offer(
      id: id,
      jeeberId: 'jeeber-$id',
      jeeberName: jeeberName,
      fee: fee,
      currency: currency,
      etaMinutes: etaMinutes,
      vehicle: vehicle,
      rating: rating,
      ratingCount: ratingCount,
      submittedAt: _offerCardSubmittedAt,
      // avatarUrl intentionally omitted — see the preview prose above.
      note: note,
    ),
    index: 0,
    isAccepting: isAccepting,
    acceptDisabled: acceptDisabled,
    onAccept: () {},
    onTapName: () {},
  );
}

/// The reference rendering: a named, rated Jeeber with an armed Accept CTA.
///
/// Every other state is read against this one. Three contracts are visible at
/// once — the name is an underlined tap target (→ JM-067 profile-reviews), the
/// fee is a single `MoneyFormat` token (`$42.50`, never a bare "42.50" beside a
/// separate "USD"), and the "Pay … cash on delivery" line (D11) repeats that
/// same token so the client cannot read this as an in-app charge.
@JeebPreview(group: 'client_offers', name: 'Rated jeeber', size: _offerCardBox)
Widget offerCardRated() => _offerCardHosted(
      id: 'preview-rated',
      jeeberName: 'Hadi',
      fee: 42.5,
      etaMinutes: 18,
      vehicle: JeeberVehicle.motorcycle,
      rating: 4.7,
      ratingCount: 132,
    );

/// A brand-new Jeeber: real name, zero ratings (SW-08).
///
/// `ratingCount == 0` drops `OmdsStarRatingDisplay` entirely in favour of the
/// honest "No ratings yet" line. The regression it guards is the fabricated
/// "4.5 (0)" the star widget draws for an unrated account — five empty stars
/// read as *rated zero*, a different and defamatory claim about a Jeeber who
/// has simply never been rated.
///
/// Check the AR rendering: the fallback must be the translated string
/// ("لا تقييمات بعد"), not English.
///
/// This is also the cheapest place to see the 200% name clip: "Nadine Khoury"
/// is thirteen characters and still ellipsizes at 390 pt.
@JeebPreview(
  group: 'client_offers',
  name: 'New jeeber, no ratings',
  size: _offerCardBox,
)
Widget offerCardNoRatings() => _offerCardHosted(
      id: 'preview-unrated',
      jeeberName: 'Nadine Khoury',
      fee: 18,
      etaMinutes: 25,
      vehicle: JeeberVehicle.bicycle,
      rating: 0,
      ratingCount: 0,
    );

/// W6 "People, not UUIDs" (sprint-009 SW-08) made visible.
///
/// The offer-list row is NOT enriched with a display name by the gateway (the
/// O-list-enrich gap in `DioOffersRepository`), so `jeeberName` arrives as a raw
/// UUID or a synthetic `jeeb-<hash>` handle far more often than as a person.
/// `displayNameOrNull` suppresses both and the card headlines the localized
/// generic instead.
///
/// Two things to look at, because both have regressed before: the raw
/// identifier must appear NOWHERE on the card, and the avatar initial must be
/// derived from the *resolved* name ("N" for New Jeeber) — taking it from the
/// raw value once put a "9" in the circle beside the words "New Jeeber".
@JeebPreview(
  group: 'client_offers',
  name: 'UUID name suppressed',
  size: _offerCardBox,
)
Widget offerCardIdentitySuppressed() => _offerCardHosted(
      id: 'preview-uuid-name',
      jeeberName: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
      fee: 24,
      etaMinutes: 15,
      vehicle: JeeberVehicle.car,
      rating: 4.8,
      ratingCount: 12,
    );

/// Accept tapped, `POST …/accept` in flight on THIS offer: "Accepting…" plus an
/// `OmdsButtonLoading` spinner, CTA locked.
///
/// **The shipped app never renders this.** `client_offers_screen.dart` passes
/// `isAccepting: false` unconditionally (B-01: the JM-029 confirm sheet owns the
/// in-flight spinner and the cards behind it merely go inert), so the whole
/// `isAccepting` branch is live API that only `test/offer_card_test.dart`
/// exercises. Keep it previewed rather than deleting it: it is what the card
/// would show the moment anyone wires an inline accept, and this comment is the
/// only place that says it is currently dead.
///
/// It is also the one state whose render test cannot use `pumpAndSettle` — the
/// spinner is an indefinite animation, so the harness's settle would time out.
/// See the dedicated pump-once test in
/// `test/previews/client_offers/offer_card_preview_test.dart`.
@JeebPreview(
  group: 'client_offers',
  name: 'Accept in flight',
  size: _offerCardBox,
)
Widget offerCardAccepting() => _offerCardHosted(
      id: 'preview-accepting',
      jeeberName: 'Rami Aoun',
      fee: 35,
      etaMinutes: 20,
      vehicle: JeeberVehicle.van,
      rating: 4.9,
      ratingCount: 54,
      isAccepting: true,
    );

/// A rival offer is mid-accept (or the window expired, or the request closed),
/// so this card's CTA is inert.
///
/// Put it beside `Rated jeeber` in the canvas — unlike the chat-bubble offer
/// card, this one tells the truth: `acceptDisabled` reaches
/// `OmdsPrimaryButton.isEnabled`, so the pill drops to the 45%-alpha disabled
/// fill and the semantics node reports `hasEnabledState` *without* `isEnabled`
/// and without a tap action. That is the visible half of the accept-race
/// (409 / 410 `offer-expired`) contract.
///
/// The CTA stays *mounted* rather than being removed: the card must not change
/// height while a rival accept resolves, because a list that reflows under the
/// finger is how a client taps the wrong Jeeber.
@JeebPreview(
  group: 'client_offers',
  name: 'Accept locked (rival winning)',
  size: _offerCardBox,
)
Widget offerCardAcceptLocked() => _offerCardHosted(
      id: 'preview-locked',
      jeeberName: 'Nour Haddad',
      fee: 41,
      etaMinutes: 35,
      vehicle: JeeberVehicle.walker,
      rating: 4.2,
      ratingCount: 9,
      acceptDisabled: true,
    );

/// The layout ceiling from `offer_card_overflow_test.dart`, plus a note:
/// longest plausible name, a non-USD nine-figure fee, a nine-figure rating
/// count, and a note past its three-line limit, all at once.
///
/// What each element must do under pressure: the name ellipsizes on one line
/// (in AR the ellipsis has to land on the *left*); the rating summary and the
/// fee pill share a `Wrap`, so they split across runs instead of overflowing;
/// the note ellipsizes after three lines. The `LBP …` token is wrapped in a
/// Unicode LTR isolate (JEBV4-98 / F10) so it does not scramble inside the
/// Arabic paragraph — the AR rendering is the only place that is checkable.
///
/// The fee pill is `maxLines: 1`, and this is where that bites: it clips the
/// amount rather than wrapping it, and it does so for realistic LBP prices too,
/// not just this synthetic ceiling (`LBP 1,335,000.00` — a $15 delivery at the
/// 2026 peg — is already clipped at 130% text on a 390 pt phone). The
/// cash-on-delivery line below has no `maxLines` and keeps the full amount, so
/// the card can show a truncated price above an untruncated one.
@JeebPreview(
  group: 'client_offers',
  name: 'Long name, note, LBP ceiling',
  size: Size(390, 430),
)
Widget offerCardLongContent() => _offerCardHosted(
      id: 'preview-long',
      jeeberName: 'Alexander Bartholomew Montgomery the Third',
      fee: 1234567890.99,
      currency: 'LBP',
      etaMinutes: 90,
      vehicle: JeeberVehicle.van,
      rating: 4.9,
      ratingCount: 1234567890,
      note: 'I am two streets away and can take the parcel right now, but the '
          'building has no lift so please meet me at the door on the ground '
          'floor.',
    );
