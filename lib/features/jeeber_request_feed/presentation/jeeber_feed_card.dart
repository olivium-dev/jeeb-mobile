import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_tier_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/request_feed_models.dart';

/// Deliveryman feed card matching the Figma `deliveryman-requests` flow
/// (file ZOi3kKtw7sd42ssSVX3Kn4, screens 24 `56560:997`, 25 `56560:1403`,
/// 26 `56560:1523`).
///
/// One card renders a single [DeliveryRequest] as the Jeeber sees it: client
/// identity + time, an items summary, tier/distance metadata, and a
/// status-driven action affordance. All of those elements share one bordered
/// surface and one content column, so a missing gateway identity cannot split
/// the row into visually unrelated fragments.
///
/// * [JeeberFeedItemStatus.incoming] — Ignore (text) + Offer (filled pill).
/// * [JeeberFeedItemStatus.pendingResponse] — italic "Pending" status.
/// * [JeeberFeedItemStatus.accepted] — a delivery state-machine action pill.
///
/// G3 graceful exit: when [isExpired] is true (a supplied server `expiresAt`
/// has passed and the card is in its brief linger window), the
/// card fades and the action row is replaced by an "Expired" status — the
/// request never silently vanishes mid-glance.
///
/// Composed entirely from OMDS primitives ([OmdsProfileAvatar],
/// [OmdsStarRatingDisplay], [OmdsPrimaryButton]) + tokenized text/dividers;
/// no raw Material buttons, no hardcoded colors or dimensions.
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

  /// Tap-through to the request detail / chat. `null` makes the card inert.
  final VoidCallback? onTap;

  /// Dismiss the incoming request from the feed.
  final VoidCallback? onIgnore;

  /// Open the offer-submission flow for this request.
  final VoidCallback? onOffer;

  /// Advance the delivery state machine for an accepted request.
  final VoidCallback? onAdvanceStatus;

  /// Whether the accepted-status action button is mid-flight (shows a loader).
  final bool isActionBusy;

  /// G3: a supplied server `expiresAt` has passed and the card is in its linger
  /// window — faded, actions replaced by the "Expired" status, taps inert. The
  /// feed cubit removes it after the linger elapses.
  final bool isExpired;

  /// JM-048: when true, this card's "Offer" button additionally carries the
  /// screen-level `feed_make_offer_cta` coined id (in addition to its per-row
  /// `jeeber_feed_request_offer_<id>`). The feed sets it on the FIRST incoming
  /// card only so the QA flow taps an unambiguous make-offer CTA — tapping it
  /// routes through the KYC gate (unapproved) or to the composer (approved),
  /// JM-044/048. Non-incoming cards (pending/accepted) never offer, so the id
  /// is inert for them.
  final bool exposeMakeOfferId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // `explicitChildNodes: true` keeps the card identifier a non-merging
    // boundary so the nested `jeeber_feed_request_action_<id>` (and ignore/
    // offer) button ids stay independently queryable as their own native
    // nodes rather than risk being folded into this actionable card node.
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
              // An expired card is display-only for its linger window.
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
        // Accent PAINT (filled stars), not a container fill — same #D73B00.
        activeColor: colorScheme.tertiary,
        inactiveColor: colorScheme.outlineVariant,
      ),
    );
  }
}

/// Delivery tier chip, colored from [JeebTierColors] so the same theme
/// extension drives the visual treatment everywhere. Using [OmdsChip] makes
/// the tier read as metadata attached to this card instead of a floating word.
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

/// G1 (sprint-009 P0): the request CONTENT line — the customer's own
/// "What do you need?" text (gateway feed `description`). This is what the
/// jeeber prices, so it reads as body copy in the on-surface role and gets a
/// TWO-line preview (the full text lives on the request detail), not the old
/// single muted caption line.
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

/// Status-driven action affordance. Branches on [DeliveryRequest.feedStatus]
/// so screens 24/25/26 all render through one card with different action
/// rows, never a phantom gap.
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

  /// JM-048: expose the screen-level `feed_make_offer_cta` coined id on this
  /// row's offer button (the FIRST incoming card only). The per-row
  /// `jeeber_feed_request_offer_<id>` stays as the inner explicit-child node so
  /// existing T-MOB flows that key off it keep working; the QA JM-048 flow taps
  /// the unambiguous screen-level id (65_W2_TEST_PLAN §2 JM-044/048).
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

/// G3 graceful exit: the status line an expired card renders in place of its
/// action row during the linger window ("Expired", hourglass glyph). Carries
/// a per-request Semantics id so QA can assert the state before the sweep
/// collapses the card.
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
    // Figma 56560:1523 pins a content-hugging navy pill to the END of the
    // accepted-card action row ("Order picked" / "Heading to drop off").
    // `OmdsLoadingButton` is an `AnimatedContainer` with `width: width ??
    // double.infinity`, so with no explicit width it expands to fill the
    // bounded incoming constraint — `Align(centerEnd)` alone is a no-op and the
    // pill renders gutter-to-gutter. `IntrinsicWidth` feeds the button a tight
    // content-width constraint so it hugs the label; the `Align` then pins the
    // hugged pill to the end (mirrors correctly in AR). Same proven mechanism as
    // the home-client Check Offers / Track CTAs (screens 14/15, commit 9e0ed57).
    // Stays 100% OMDS; the `width:` param is the alternative but it would
    // hardcode a magic pixel value, which the design-tokens rule forbids.
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
      // SW-03: `receivedAt` arrives as a UTC instant from the gateway —
      // convert to DEVICE-LOCAL time before formatting. Pre-fix the card
      // formatted the raw UTC fields ("12:31" under a 14:31 status bar),
      // making every fresh request look hours stale.
      DateFormat.Hm(locale).format(receivedAt!.toLocal()),
      key: const Key('jeeber-feed-card-timestamp'),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
