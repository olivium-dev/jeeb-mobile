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
/// avatar + name + rating + tier badge, an items summary, the distance line,
/// and a status-driven action affordance:
///
/// * [JeeberFeedItemStatus.incoming] — Ignore (text) + Offer (filled pill).
/// * [JeeberFeedItemStatus.pendingResponse] — italic "Pending" status.
/// * [JeeberFeedItemStatus.accepted] — a delivery state-machine action pill.
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

  @override
  Widget build(BuildContext context) {
    // `explicitChildNodes: true` keeps the card identifier a non-merging
    // boundary so the nested `jeeber_feed_request_action_<id>` (and ignore/
    // offer) button ids stay independently queryable as their own native
    // nodes rather than risk being folded into this actionable card node.
    return Semantics(
      identifier: 'jeeber_feed_request_card_${request.id}',
      button: onTap != null,
      explicitChildNodes: true,
      child: InkWell(
        key: Key('jeeber-feed-card-${request.id}'),
        onTap: onTap,
        child: _CardColumn(
          request: request,
          onIgnore: onIgnore,
          onOffer: onOffer,
          onAdvanceStatus: onAdvanceStatus,
          isActionBusy: isActionBusy,
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
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardRow(request: request),
          _ActionArea(
            request: request,
            onIgnore: onIgnore,
            onOffer: onOffer,
            onAdvanceStatus: onAdvanceStatus,
            isActionBusy: isActionBusy,
          ),
          _Timestamp(receivedAt: request.receivedAt),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Spacing.small),
            child: Divider(height: 1, color: colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ClientAvatar(request: request),
        const SizedBox(width: Spacing.small),
        Expanded(child: _CardInfo(request: request)),
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
    return OmdsProfileAvatar(
      initial: _initial(request.senderName),
      profilePicUrl: request.senderAvatarUrl,
      size: Sizes.fourXLarge,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }

  static String _initial(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}

class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NameRow(request: request),
        const SizedBox(height: Spacing.twoXSmall),
        if (request.itemsSummary != null)
          _SummaryLine(text: request.itemsSummary!),
        if (request.distanceFromYouKm != null) ...[
          const SizedBox(height: Spacing.twoXSmall),
          _DistanceLine(distanceKm: request.distanceFromYouKm!),
        ],
      ],
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: _ClientName(name: request.senderName)),
        if (request.senderRating != null) ...[
          const SizedBox(width: Spacing.small),
          _RatingCluster(rating: request.senderRating!),
        ],
        const Spacer(),
        _TierLabel(tier: request.tier),
      ],
    );
  }
}

class _ClientName extends StatelessWidget {
  const _ClientName({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      name ?? '',
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.secondaryContainer,
        fontWeight: FontWeight.w400,
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
        activeColor: colorScheme.primaryContainer,
        inactiveColor: colorScheme.outlineVariant,
      ),
    );
  }
}

/// Delivery tier badge (Figma "Flash"), colored from [JeebTierColors] so the
/// same theme extension drives the visual treatment everywhere.
class _TierLabel extends StatelessWidget {
  const _TierLabel({required this.tier});

  final JeeberRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<JeebTierColors>();
    return Text(
      _label(AppLocalizations.of(context)),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: _color(tokens, theme.colorScheme),
        letterSpacing: 0.5,
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
        JeeberRequestTier.flash =>
          tokens?.flash ?? scheme.primaryContainer,
        JeeberRequestTier.light => tokens?.eco ?? scheme.tertiary,
        JeeberRequestTier.standard =>
          tokens?.standard ?? scheme.secondaryContainer,
        JeeberRequestTier.bulk =>
          tokens?.express ?? scheme.primaryContainer,
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
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
        letterSpacing: 0.4,
      ),
      maxLines: 1,
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
        letterSpacing: 0.5,
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
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.small),
      child: switch (request.feedStatus) {
        JeeberFeedItemStatus.incoming => _IncomingActions(
            requestId: request.id,
            onIgnore: onIgnore,
            onOffer: onOffer,
          ),
        JeeberFeedItemStatus.pendingResponse => const _PendingStatus(),
        JeeberFeedItemStatus.accepted => _AcceptedAction(
            requestId: request.id,
            action: request.nextDeliveryAction,
            onTap: onAdvanceStatus,
            isBusy: isActionBusy,
          ),
      },
    );
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({
    required this.requestId,
    required this.onIgnore,
    required this.onOffer,
  });

  final String requestId;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IgnoreButton(requestId: requestId, onTap: onIgnore),
        const SizedBox(width: Spacing.medium),
        _OfferButton(requestId: requestId, onTap: onOffer),
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
  const _OfferButton({required this.requestId, required this.onTap});

  final String requestId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'jeeber_feed_request_offer_$requestId',
      button: true,
      child: OmdsPrimaryButton(
        key: Key('jeeber-feed-offer-$requestId'),
        text: AppLocalizations.of(context).jeeberFeedOfferAction,
        borderRadius: OmdsBorderRadius.pill,
        onTap: onTap ?? () {},
      ),
    );
  }
}

class _PendingStatus extends StatelessWidget {
  const _PendingStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        AppLocalizations.of(context).jeeberFeedStatusPending,
        key: const Key('jeeber-feed-pending-status'),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontStyle: FontStyle.italic,
        ),
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
    return Align(
      alignment: AlignmentDirectional.centerEnd,
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
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        DateFormat.Hm(locale).format(receivedAt!),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
