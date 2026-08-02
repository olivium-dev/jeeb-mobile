import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_tier_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/request_feed_models.dart';























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
