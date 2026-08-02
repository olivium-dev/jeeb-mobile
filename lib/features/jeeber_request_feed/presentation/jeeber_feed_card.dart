import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_tier_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/request_feed_models.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

class JeeberFeedCard extends StatelessWidget {
  const JeeberFeedCard({
    super.key,
    required this.request,
    this.onTap,
    this.onIgnore,
    this.onOffer,
    this.onAdvanceStatus,
    this.isActionBusy = false,
    this.isExpired = false,
    this.exposeMakeOfferId = false,
  });

  final DeliveryRequest request;

  final VoidCallback? onTap;

  final VoidCallback? onIgnore;

  final VoidCallback? onOffer;

  final VoidCallback? onAdvanceStatus;

  final bool isActionBusy;

  final bool isExpired;

  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      identifier: 'jeeber_feed_request_card_${request.id}',
      button: !isExpired && onTap != null,
      explicitChildNodes: true,
      child: AnimatedOpacity(
        opacity: isExpired ? UIConstants.opacityDisabled : 1.0,
        duration: UIConstants.animationFast,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.xSmall,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: OmdsBorderRadius.medium,
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: UIConstants.dividerWidth,
              ),
            ),
            child: GestureDetector(
              key: Key('jeeber-feed-card-${request.id}'),
              behavior: HitTestBehavior.opaque,

              onTap: isExpired ? null : onTap,
              child: _CardColumn(
                request: request,
                onIgnore: onIgnore,
                onOffer: onOffer,
                onAdvanceStatus: onAdvanceStatus,
                isActionBusy: isActionBusy,
                isExpired: isExpired,
                exposeMakeOfferId: exposeMakeOfferId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardColumn extends StatelessWidget {
  const _CardColumn({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.isExpired,
    required this.exposeMakeOfferId,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool isExpired;
  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: _CardRow(
        request: request,
        onIgnore: onIgnore,
        onOffer: onOffer,
        onAdvanceStatus: onAdvanceStatus,
        isActionBusy: isActionBusy,
        isExpired: isExpired,
        exposeMakeOfferId: exposeMakeOfferId,
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.isExpired,
    required this.exposeMakeOfferId,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool isExpired;
  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ClientAvatar(request: request),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _CardInfo(
            request: request,
            onIgnore: onIgnore,
            onOffer: onOffer,
            onAdvanceStatus: onAdvanceStatus,
            isActionBusy: isActionBusy,
            isExpired: isExpired,
            exposeMakeOfferId: exposeMakeOfferId,
          ),
        ),
      ],
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = _clientDisplayName(context, request);
    return OmdsProfileAvatar(
      key: const Key('jeeber-feed-card-avatar'),
      initial: displayName[0].toUpperCase(),
      profilePicUrl: request.senderAvatarUrl,
      size: Sizes.fourXLarge,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }
}

class _CardInfo extends StatelessWidget {
  const _CardInfo({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.isExpired,
    required this.exposeMakeOfferId,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool isExpired;
  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('jeeber-feed-card-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IdentityBlock(request: request),
        const SizedBox(height: Spacing.xSmall),
        if (request.itemsSummary != null)
          _SummaryLine(text: request.itemsSummary!),
        if (request.distanceFromYouKm != null) ...[
          const SizedBox(height: Spacing.xSmall),
          _DistanceLine(distanceKm: request.distanceFromYouKm!),
        ],
        const SizedBox(height: Spacing.small),
        _CardFooter(
          request: request,
          onIgnore: onIgnore,
          onOffer: onOffer,
          onAdvanceStatus: onAdvanceStatus,
          isActionBusy: isActionBusy,
          isExpired: isExpired,
          exposeMakeOfferId: exposeMakeOfferId,
        ),
      ],
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('jeeber-feed-card-identity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _ClientName(request: request)),
            const SizedBox(width: Spacing.xSmall),
            _Timestamp(receivedAt: request.receivedAt),
          ],
        ),
        if (request.senderRating != null) ...[
          const SizedBox(height: Spacing.twoXSmall),
          _RatingCluster(rating: request.senderRating!),
        ],
      ],
    );
  }
}

class _ClientName extends StatelessWidget {
  const _ClientName({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _clientDisplayName(context, request),
      key: const Key('jeeber-feed-card-client-name'),
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RatingCluster extends StatelessWidget {
  const _RatingCluster({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: l10n.jeeberFeedRatingSemantic(rating.toStringAsFixed(0)),
      child: OmdsStarRatingDisplay(
        averageRating: rating,
        starSize: Sizes.medium,
        spacing: Spacing.twoXSmall,
        showRatingValue: false,
        showReviewCount: false,

        activeColor: colorScheme.tertiary,
        inactiveColor: colorScheme.outlineVariant,
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final JeeberRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<JeebTierColors>();
    final color = _color(tokens, theme.colorScheme);
    return OmdsChip(
      label: _label(AppLocalizations.of(context)),
      unselectedColor: color.withValues(alpha: UIConstants.opacityPrimaryLight),
      unselectedTextColor: color,
      borderColor: color.withValues(alpha: UIConstants.opacityOverlay),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xSmall,
        vertical: Spacing.twoXSmall,
      ),
      textStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  String _label(AppLocalizations l10n) => switch (tier) {
    JeeberRequestTier.flash => l10n.requestFeedTierFlash,
    JeeberRequestTier.light => l10n.requestFeedTierLight,
    JeeberRequestTier.standard => l10n.requestFeedTierStandard,
    JeeberRequestTier.bulk => l10n.requestFeedTierBulk,
  };

  Color _color(JeebTierColors? tokens, ColorScheme scheme) => switch (tier) {
    JeeberRequestTier.flash => tokens?.flash ?? scheme.tertiary,
    JeeberRequestTier.light => tokens?.eco ?? scheme.tertiary,
    JeeberRequestTier.standard => tokens?.standard ?? scheme.secondaryContainer,
    JeeberRequestTier.bulk => tokens?.express ?? scheme.tertiary,
  };
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      key: const Key('jeeber-feed-card-summary'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DistanceLine extends StatelessWidget {
  const _DistanceLine({required this.distanceKm});

  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.jeeberFeedDistanceAway(_formatDistance(context, distanceKm)),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDistance(BuildContext context, double km) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatted = NumberFormat.decimalPattern(locale).format(km);
    return '${formatted}km';
  }
}

String _clientDisplayName(BuildContext context, DeliveryRequest request) {
  final name = request.senderName?.trim() ?? '';
  return name.isNotEmpty
      ? name
      : AppLocalizations.of(context).jeeberFeedAnonymousClient;
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.isExpired,
    required this.exposeMakeOfferId,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool isExpired;
  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('jeeber-feed-card-footer'),
      width: double.infinity,
      child: Wrap(
        alignment: request.tier == null
            ? WrapAlignment.end
            : WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Spacing.xSmall,
        runSpacing: Spacing.xSmall,
        children: [
          if (request.tier case final tier?) _TierChip(tier: tier),
          if (isExpired)
            _ExpiredStatus(requestId: request.id)
          else
            _ActionArea(
              request: request,
              onIgnore: onIgnore,
              onOffer: onOffer,
              onAdvanceStatus: onAdvanceStatus,
              isActionBusy: isActionBusy,
              exposeMakeOfferId: exposeMakeOfferId,
            ),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.exposeMakeOfferId,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    return switch (request.feedStatus) {
      JeeberFeedItemStatus.incoming => _IncomingActions(
        requestId: request.id,
        onIgnore: onIgnore,
        onOffer: onOffer,
        exposeMakeOfferId: exposeMakeOfferId,
      ),
      JeeberFeedItemStatus.pendingResponse => const _PendingStatus(),
      JeeberFeedItemStatus.accepted => _AcceptedAction(
        requestId: request.id,
        action: request.nextDeliveryAction,
        onTap: onAdvanceStatus,
        isBusy: isActionBusy,
      ),
    };
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({
    required this.requestId,
    required this.onIgnore,
    required this.onOffer,
    required this.exposeMakeOfferId,
  });

  final String requestId;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IgnoreButton(requestId: requestId, onTap: onIgnore),
        const SizedBox(width: Spacing.xSmall),
        _OfferButton(
          requestId: requestId,
          onTap: onOffer,
          exposeMakeOfferId: exposeMakeOfferId,
        ),
      ],
    );
  }
}

class _IgnoreButton extends StatelessWidget {
  const _IgnoreButton({required this.requestId, required this.onTap});

  final String requestId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'jeeber_feed_request_ignore_$requestId',
      button: true,
      child: OmdsPrimaryButton(
        key: Key('jeeber-feed-ignore-$requestId'),
        text: AppLocalizations.of(context).jeeberFeedIgnoreAction,
        variant: OmdsButtonVariant.text,
        textColor: theme.colorScheme.error,
        onTap: onTap ?? () {},
      ),
    );
  }
}

class _OfferButton extends StatelessWidget {
  const _OfferButton({
    required this.requestId,
    required this.onTap,
    this.exposeMakeOfferId = false,
  });

  final String requestId;
  final VoidCallback? onTap;

  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      identifier: 'jeeber_feed_request_offer_$requestId',
      button: true,
      child: OmdsPrimaryButton(
        key: Key('jeeber-feed-offer-$requestId'),
        text: AppLocalizations.of(context).jeeberFeedOfferAction,
        borderRadius: OmdsBorderRadius.pill,
        onTap: onTap ?? () {},
      ),
    );
    if (!exposeMakeOfferId) return button;
    return Semantics(
      identifier: 'feed_make_offer_cta',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: button,
    );
  }
}

class _ExpiredStatus extends StatelessWidget {
  const _ExpiredStatus({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      identifier: 'jeeber_feed_request_expired_$requestId',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_disabled_outlined,
            size: Sizes.medium,
            color: color,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Text(
            AppLocalizations.of(context).jeeberFeedStatusExpired,
            key: Key('jeeber-feed-expired-status-$requestId'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingStatus extends StatelessWidget {
  const _PendingStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context).jeeberFeedStatusPending,
      key: const Key('jeeber-feed-pending-status'),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _AcceptedAction extends StatelessWidget {
  const _AcceptedAction({
    required this.requestId,
    required this.action,
    required this.onTap,
    required this.isBusy,
  });

  final String requestId;
  final JeeberDeliveryAction? action;
  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {

    return IntrinsicWidth(
      child: Semantics(
        identifier: 'jeeber_feed_request_action_$requestId',
        button: true,
        child: OmdsLoadingButton(
          key: Key('jeeber-feed-action-$requestId'),
          text: _label(AppLocalizations.of(context)),
          isLoading: isBusy,
          borderRadius: OmdsBorderRadius.pill,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n) => switch (action) {
    JeeberDeliveryAction.headingToDropOff =>
      l10n.jeeberFeedActionHeadingToDropOff,
    JeeberDeliveryAction.orderPicked || null => l10n.chatDmOrderPickedAction,
  };
}

class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.receivedAt});

  final DateTime? receivedAt;

  @override
  Widget build(BuildContext context) {
    if (receivedAt == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Text(

      DateFormat.Hm(locale).format(receivedAt!.toLocal()),
      key: const Key('jeeber-feed-card-timestamp'),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
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
// Render tests: test/previews/jeeber_request_feed/jeeber_feed_card_preview_test.dart
// ===========================================================================

// Widget previews for [JeeberFeedCard] — run with
// `flutter widget-preview start`.
//
// [JeeberFeedCard] is a pure function of ONE argument — the [DeliveryRequest]
// it is handed — plus two display flags ([JeeberFeedCard.isExpired],
// [JeeberFeedCard.exposeMakeOfferId]) and four callbacks. It reads no cubit and
// owns no state, so every preview below is just a hand-built request record.
// Nothing here can touch the network: no repository is constructed, and the
// only URL in the file is an avatar the guard in [jeebPreviewHost] would refuse
// to mutate anyway.
//
// What counts as a "state" here is therefore **which fields the gateway
// actually supplied** (identity, rating, tier and distance are all nullable on
// the wire) crossed with the card's lifecycle bucket
// ([DeliveryRequest.feedStatus] + the G3 expiry flag). Those two axes decide
// the whole layout: the identity block collapses without a rating, the footer
// changes shape without a tier, and the action area swaps between a two-button
// row, an italic status word and a single pill.
//
// The fixture values are the ones `test/jeeber_feed_card_test.dart` already
// uses (`Sami Fawaz`, the potato/water/coffee summary, 3 km, Flash) so a
// reviewer comparing the canvas against the test suite sees the same card.
//
// ## Read the AR RTL rendering first
//
// This card is **narrower than its own content in Arabic**. `_IncomingActions`
// is a `Row(mainAxisSize: min)` holding Ignore + Offer, and that Row does not
// wrap; the Arabic labels ("تجاهل" / "تقديم عرض") are wider than the English
// ones, so on the 266 pt content column of a 390 pt phone the row overflows by
// 2 pt — and on a **360 pt phone (the Galaxy S22 this project tests on) by
// 32 pt, at DEFAULT text size**. English is clean at 360 and 390 and overflows
// by 31 pt at 320. The `EN 200% text` rendering of the matrix is worse again:
// 115 pt (EN) / 198 pt (AR) at 390. Every incoming-state preview below shows
// it; `jeeber_feed_card_preview_test.dart` pins the numbers.
//
// ## Two more things the canvas shows that the test suite does not
//
// * **The footer is two stacked rows, not one.** `_CardFooter` is a [Wrap] with
//   `WrapAlignment.spaceBetween`, which reads as "tier chip at the start,
//   action at the end" — but the tier chip child measures the FULL content
//   width (266 of 266 at 390 pt), so it takes a run to itself and the action
//   area always lands on a second run underneath, with the chip's visible pill
//   centred rather than start-aligned. Figma 56560:1523 draws one row.
// * **The accepted-action pill is not content-hugging on a phone.** The
//   [IntrinsicWidth] in `_AcceptedAction` clamps to the incoming constraint, and
//   "Heading to drop off" has an intrinsic width of ~268 pt — wider than the
//   266 pt column at 390 pt and the 236 pt column at 360 pt. The pill therefore
//   renders gutter-to-gutter, which is exactly what that `IntrinsicWidth` is
//   commented as preventing. It hugs only on the 800 pt surface
//   `test/jeeber_feed_card_test.dart` measures it on, and only with the shorter
//   "Order picked" label.
//
// Genuinely clean, recorded so nobody re-checks it: directionality. Every inset
// is symmetric or `EdgeInsetsDirectional`, so AR mirrors the avatar (310→358
// instead of 32→80) and the whole content column with no hand-written
// direction logic. The timestamp is also honest — [_jeeberFeedCardReceivedAtUtc]
// is a UTC instant, as the gateway sends, and the card converts to device-local
// before formatting (SW-03), so the canvas shows your wall clock rather than
// "09:41".

/// A phone-width feed row.
///
/// 380 pt of height for a card that is 204–280 pt tall at default text size is
/// deliberate: the `EN 200% text` rendering of the same states is 284–360 pt,
/// and the thing worth seeing at 200% is the footer — clipping the box to the
/// default-size card would cut off the exact row that breaks.
const Size _jeeberFeedCardBox = Size(390, 380);

/// The Galaxy S22 width — the device this project runs its final on-device
/// check on, and the narrowest mainstream Android. 30 pt narrower than
/// [_jeeberFeedCardBox] is the difference between a 2 pt Arabic overflow and a
/// 32 pt one.
const Size _jeeberFeedCardNarrowBox = Size(360, 380);

/// The instant the gateway reports, as a UTC instant — see the SW-03 note in
/// the preview prose above. A constant so the canvas never re-renders on a tick.
final DateTime _jeeberFeedCardReceivedAtUtc = DateTime.utc(2026, 6, 11, 9, 41);

/// Far enough out that nothing here expires by accident; the G3 state is driven
/// by the explicit flag, not by the clock.
final DateTime _jeeberFeedCardExpiresAt = DateTime.utc(2030);

/// The avatar the dev-seam feed host passes today.
const String _jeeberFeedCardAvatarUrl = 'https://i.pravatar.cc/150?img=12';

/// One feed row, framed the way the production list frames it.
///
/// The card's content column is `MainAxisSize.max`, so under the bounded height
/// of a preview box it would stretch and drag its border to the bottom of the
/// canvas. Production mounts it in a `ListView.builder` — an unbounded main-axis
/// constraint — and this shrink-wrapping [Column] reproduces exactly that, so
/// the previewed card is the height a jeeber actually sees.
///
/// All four callbacks are supplied because the real host
/// (`jeeber_feed_tab_view.dart`) supplies all four; a null `onTap` would also
/// silently drop the card's `button: true` semantics.
Widget _jeeberFeedCardHosted(
  DeliveryRequest request, {
  bool isExpired = false,
  bool exposeMakeOfferId = false,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      JeeberFeedCard(
        request: request,
        isExpired: isExpired,
        exposeMakeOfferId: exposeMakeOfferId,
        onTap: () {},
        onIgnore: () {},
        onOffer: () {},
        onAdvanceStatus: () {},
      ),
    ],
  );
}

/// One request record. Defaults match the happy path in
/// `test/jeeber_feed_card_test.dart`; each preview overrides only the fields
/// that define its state.
DeliveryRequest _jeeberFeedCardRequest({
  required String id,
  JeeberFeedItemStatus status = JeeberFeedItemStatus.incoming,
  JeeberDeliveryAction? action,
  String? senderName = 'Sami Fawaz',
  String? senderAvatarUrl = _jeeberFeedCardAvatarUrl,
  double? senderRating = 4,
  JeeberRequestTier? tier = JeeberRequestTier.flash,
  String? itemsSummary = '1 kilo potato, water gallon, coffee blend',
  double? distanceFromYouKm = 3,
}) {
  return DeliveryRequest(
    id: id,
    pickup: const RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
    dropoff: const RequestLocation(label: 'Verdun', latitude: 0, longitude: 0),
    tier: tier,
    estimatedDistanceKm: 3,
    potentialEarnings: 4,
    currency: 'USD',
    expiresAt: _jeeberFeedCardExpiresAt,
    senderName: senderName,
    senderAvatarUrl: senderAvatarUrl,
    senderRating: senderRating,
    itemsSummary: itemsSummary,
    distanceFromYouKm: distanceFromYouKm,
    receivedAt: _jeeberFeedCardReceivedAtUtc,
    feedStatus: status,
    nextDeliveryAction: action,
  );
}

/// The happy path: a fresh request carrying everything the gateway can send.
///
/// Screen 24 — name, avatar, star rating, description, distance, tier chip and
/// the Ignore / Offer pair. This is the densest the card ever gets at default
/// text size and the baseline every other state should be read against.
///
/// It is also the state that breaks first. Compare the three renderings: EN
/// light fits, `AR RTL dark` overflows the action row by 2 pt at this width, and
/// `EN 200% text` overflows it by 115 pt.
///
/// `exposeMakeOfferId` is true because the feed sets it on the FIRST incoming
/// card (JM-048); it adds a wrapping Semantics node and no pixels, so this
/// preview doubles as the check that it stays invisible.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Incoming · full metadata',
  size: _jeeberFeedCardBox,
)
Widget jeeberFeedCardIncoming() => _jeeberFeedCardHosted(
      _jeeberFeedCardRequest(id: 'req-1'),
      exposeMakeOfferId: true,
    );

/// The gateway told us almost nothing: no name, no avatar, no rating, no tier.
///
/// This is the closest thing this card has to an empty state, and every one of
/// those omissions is a supported wire shape. Three fallbacks have to hold at
/// once:
///
/// * the name degrades to the localized "Customer", never a blank line;
/// * the avatar shows that word's initial ("C"), never the "?" glyph;
/// * the rating cluster disappears entirely rather than rendering zero stars —
///   an unrated client must not look like a one-star client.
///
/// A fabricated "Standard" chip would be worse than no chip: the jeeber prices
/// off the tier. Dropping it is also the only configuration in which the footer
/// is a single row, because the tier chip is what forces the second one.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Identity + tier omitted',
  size: _jeeberFeedCardBox,
)
Widget jeeberFeedCardAnonymous() => _jeeberFeedCardHosted(
      _jeeberFeedCardRequest(
        id: 'req-anon',
        senderName: null,
        senderAvatarUrl: null,
        senderRating: null,
        tier: null,
        itemsSummary: 'Envelope from the notary on Bliss Street',
        distanceFromYouKm: 0.4,
      ),
    );

/// Screen 25: the jeeber has offered and is waiting on the client.
///
/// The whole action row collapses to one italic word, which makes this the only
/// state that cannot overflow — and the one where the card is doing the least to
/// explain itself. Worth a look in the canvas because "Pending" is a *status*,
/// not a button, and it is painted in `onSecondaryContainer` on a
/// `surfaceContainerLow` card: a foreground/background pair that is not defined
/// against each other in either theme.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Offer pending',
  size: _jeeberFeedCardBox,
)
Widget jeeberFeedCardPending() => _jeeberFeedCardHosted(
      _jeeberFeedCardRequest(
        id: 'req-pending',
        status: JeeberFeedItemStatus.pendingResponse,
        senderName: 'Layla Hamdan',
        tier: JeeberRequestTier.standard,
      ),
    );

/// Screen 26: the client accepted, so the card becomes a state-machine control.
///
/// Uses the LONGER of the two action labels ("Heading to drop off", not "Order
/// picked") on purpose. `_AcceptedAction` wraps the button in [IntrinsicWidth]
/// specifically so the pill hugs its label instead of expanding to
/// `double.infinity` — and at this width it does not: the label's intrinsic
/// width (~268 pt) is wider than the 266 pt content column, so `IntrinsicWidth`
/// clamps to the constraint and the pill renders gutter-to-gutter. The
/// content-hugging pill Figma 56560:1523 asks for only survives on a surface
/// wider than any phone.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Accepted · advance action',
  size: _jeeberFeedCardBox,
)
Widget jeeberFeedCardAccepted() => _jeeberFeedCardHosted(
      _jeeberFeedCardRequest(
        id: 'req-accepted',
        status: JeeberFeedItemStatus.accepted,
        action: JeeberDeliveryAction.headingToDropOff,
        senderName: 'Rami Haddad',
        tier: JeeberRequestTier.bulk,
      ),
    );

/// G3 graceful exit: the offer window closed while the jeeber was looking at it.
///
/// The card must not vanish mid-glance. It fades to
/// `UIConstants.opacityDisabled`, swaps its action row for an "Expired" status,
/// and goes inert — the tap-through and both buttons are gone, so there is no
/// way to act on a request that no longer exists. The feed removes the row once
/// the linger elapses.
///
/// The fade is the state's whole visual signal, which makes `AR RTL dark` the
/// rendering to check: a dimmed `onSurfaceVariant` label on a dark surface is
/// where this state has the least contrast left to give. At 200% the Arabic
/// "منتهي الصلاحية" plus its hourglass glyph overflows that row too (90 pt),
/// which the English rendering never shows.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Expired · G3 linger',
  size: _jeeberFeedCardBox,
)
Widget jeeberFeedCardExpired() => _jeeberFeedCardHosted(
      _jeeberFeedCardRequest(id: 'req-expired', senderName: 'Nadia Chami'),
      isExpired: true,
    );

/// The layout ceiling: the longest plausible content on the narrowest real
/// device.
///
/// A client name that cannot fit on one line, a real-world food order as the
/// description, a two-digit distance and a five-star cluster, still incoming so
/// both buttons compete for the same footer — all on the 360 pt Galaxy S22.
///
/// Two text contracts are on review, and both hold: the name is `maxLines: 1` +
/// ellipsis inside an [Expanded], so it clips rather than shoving the timestamp
/// off the trailing edge, and the description (G1, sprint-009 P0) gets a
/// deliberate TWO-line preview in the on-surface body role — the full text lives
/// on the request detail — so it ellipsises on line two instead of growing the
/// card without bound.
///
/// What does NOT hold is the action row underneath them. At 360 pt the Ignore +
/// Offer row overflows by 32 pt in Arabic at default text size, and by 145 pt
/// (EN) / 228 pt (AR) at 200%. This is the state, and the width, where a jeeber
/// loses the "Offer" button off the edge of the screen.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Longest content · 360 pt device',
  size: _jeeberFeedCardNarrowBox,
)
Widget jeeberFeedCardLongContent() => _jeeberFeedCardHosted(
      _jeeberFeedCardRequest(
        id: 'req-long',
        senderName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        senderRating: 5,
        tier: JeeberRequestTier.standard,
        itemsSummary:
            '2 shawarma + cola from Barbar, extra garlic, no pickles, and a '
            'large fries — call me when you arrive at the building entrance, '
            'third floor, ring twice',
        distanceFromYouKm: 12.5,
      ),
    );
