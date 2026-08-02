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

// Widget previews for [JeeberFeedCard] — run with

/// A phone-width feed row.
/// 380 pt of height for a card that is 204–280 pt tall at default text size is
const Size _jeeberFeedCardBox = Size(390, 380);

/// The Galaxy S22 width — the device this project runs its final on-device
/// check on, and the narrowest mainstream Android. 30 pt narrower than
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
/// The card's content column is `MainAxisSize.max`, so under the bounded height
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
/// Screen 24 — name, avatar, star rating, description, distance, tier chip and
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
/// This is the closest thing this card has to an empty state, and every one of
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
/// The whole action row collapses to one italic word, which makes this the only
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
/// Uses the LONGER of the two action labels ("Heading to drop off", not "Order
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
/// The card must not vanish mid-glance. It fades to
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
