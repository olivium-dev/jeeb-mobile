import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';
import 'active_request_card.dart';

/// Replies-tab row matching the Figma `+6 offers` panel.
///
/// Layout: avatar | title + tier badge, destination, stacked avatars of the
/// offerers (`OmdsAvatarStack`-equivalent — built inline because no OMDS
/// primitive yet exposes exactly the overlap-with-counter behavior the
/// Figma wants), and a primary "Check Offers" CTA that pushes the
/// broadcasting chat for this request.
class RepliesCard extends StatelessWidget {
  const RepliesCard({
    super.key,
    required this.request,
    required this.onCheckOffers,
  });

  final ClientHomeRequest request;
  final VoidCallback onCheckOffers;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: Key('replies-card-${request.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      child: Column(
        children: [
          _RepliesRow(request: request, onCheckOffers: onCheckOffers),
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xSmall),
            child: Divider(height: 1, color: colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

class _RepliesRow extends StatelessWidget {
  const _RepliesRow({required this.request, required this.onCheckOffers});

  final ClientHomeRequest request;
  final VoidCallback onCheckOffers;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RepliesAvatar(initial: _initialFor(request.title)),
        const SizedBox(width: Spacing.twoXSmall),
        Expanded(
          child: _RepliesBody(request: request, onCheckOffers: onCheckOffers),
        ),
      ],
    );
  }

  static String _initialFor(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ? '?' : trimmed[0];
  }
}

class _RepliesAvatar extends StatelessWidget {
  const _RepliesAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: initial,
      size: Sizes.threeXLarge,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }
}

class _RepliesBody extends StatelessWidget {
  const _RepliesBody({required this.request, required this.onCheckOffers});

  final ClientHomeRequest request;
  final VoidCallback onCheckOffers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                request.displayId ?? request.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Spacing.xSmall),
            ClientHomeTierBadge(tier: request.tier),
          ],
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          request.destinationLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            letterSpacing: 0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Spacing.small),
        _OfferAvatarStack(
          avatarUrls: request.offerAvatarUrls,
          totalCount: request.offerCount,
        ),
        const SizedBox(height: Spacing.small),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            height: Sizes.twoXLarge,
            child: OmdsPrimaryButton(
              key: Key('replies-check-offers-${request.id}'),
              text: AppLocalizations.of(context).homeRepliesCheckOffersCta,
              onTap: onCheckOffers,
              borderRadius: OmdsBorderRadius.pill,
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontally-overlapped avatars with a "+N" pill once the count exceeds
/// what we render inline. Used by the Replies card to surface the offerers
/// without a separate screen.
class _OfferAvatarStack extends StatelessWidget {
  const _OfferAvatarStack({
    required this.avatarUrls,
    required this.totalCount,
  });

  static const int _maxInline = 3;

  final List<String> avatarUrls;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final inline = avatarUrls.take(_maxInline).toList(growable: false);
    final extra = totalCount - inline.length;
    return Row(
      children: [
        for (var i = 0; i < inline.length; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : Spacing.twoXSmall),
            child: _OfferAvatar(url: inline[i]),
          ),
        if (extra > 0) ...[
          const SizedBox(width: Spacing.xSmall),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.small,
              vertical: Spacing.twoXSmall,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: OmdsBorderRadius.pill,
            ),
            child: Text(
              '+$extra',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ],
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
