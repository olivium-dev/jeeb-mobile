import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

class RepliesCard extends StatelessWidget {
  const RepliesCard({
    super.key,
    required this.request,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeRequest request;

  final VoidCallback onCheckOffers;

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: Key('replies-card-${request.id}'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      child: Semantics(
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RepliesHeader(request: request),
            const SizedBox(height: Spacing.twoXSmall),
            _RepliesSummary(text: request.summaryLine),
            const SizedBox(height: Spacing.small),
            _RepliesActions(
              request: request,
              onCheckOffers: onCheckOffers,
              onAccept: onAccept,
            ),
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

class _RepliesHeader extends StatelessWidget {
  const _RepliesHeader({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            request.displayId ?? request.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.secondaryContainer,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        _OfferAvatarStack(
          requestId: request.id,
          avatarUrls: request.offerAvatarUrls,
          totalCount: request.offerCount,
        ),
      ],
    );
  }
}

class _RepliesSummary extends StatelessWidget {
  const _RepliesSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RepliesActions extends StatelessWidget {
  const _RepliesActions({
    required this.request,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeRequest request;
  final VoidCallback onCheckOffers;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IntrinsicWidth(
          child: Semantics(
            identifier: 'replies_accept_cta',
            button: true,
            child: OMDSOutlinedButton(
              key: Key('replies-accept-${request.id}'),
              text: l10n.offersCardAccept,
              onTap: onAccept,
              borderRadius: OMDSBorderRadius.pill,
            ),
          ),
        ),
        const SizedBox(width: Spacing.small),
        IntrinsicWidth(
          child: Semantics(
            identifier: 'replies_check_offers_cta',
            button: true,
            child: OmdsPrimaryButton(
              key: Key('replies-check-offers-${request.id}'),
              text: l10n.homeRepliesCheckOffersCta,
              onTap: onCheckOffers,
              borderRadius: OmdsBorderRadius.pill,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferAvatarStack extends StatelessWidget {
  const _OfferAvatarStack({
    required this.requestId,
    required this.avatarUrls,
    required this.totalCount,
  });

  static const int _maxInline = 3;

  final String requestId;
  final List<String> avatarUrls;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) return const SizedBox.shrink();
    final inline = avatarUrls.take(_maxInline).toList(growable: false);
    final extra = totalCount - inline.length;
    return Semantics(
      identifier: 'orders_replies_avatar_stack_$requestId',
      label: '$totalCount',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverlappingAvatars(urls: inline),
          if (extra > 0) ...[
            const SizedBox(width: Spacing.twoXSmall),
            _OfferOverflowCount(extra: extra),
          ],
        ],
      ),
    );
  }
}

class _OverlappingAvatars extends StatelessWidget {
  const _OverlappingAvatars({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    const overlap = Sizes.medium;
    final width = urls.isEmpty
        ? 0.0
        : Sizes.large + (urls.length - 1) * (Sizes.large - overlap);
    return SizedBox(
      width: width,
      height: Sizes.large,
      child: Stack(
        children: [
          for (var i = 0; i < urls.length; i++)
            PositionedDirectional(
              start: i * (Sizes.large - overlap),
              child: _OfferAvatar(url: urls[i]),
            ),
        ],
      ),
    );
  }
}

class _OfferOverflowCount extends StatelessWidget {
  const _OfferOverflowCount({required this.extra});

  final int extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '+$extra',
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _OfferAvatar extends StatelessWidget {
  const _OfferAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: 'J',
      profilePicUrl: url,
      size: Sizes.large,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }
}
