import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      // `explicitChildNodes` makes the card a Semantics *boundary*: without it
      // the column auto-merges the avatar-stack node
      // (`orders_replies_avatar_stack_<id>`, nested in the header) and the
      // Check-Offers button node (`orders_replies_check_offers_<id>`) into one,
      // so only the avatar-stack id survives. The boundary keeps BOTH ids as
      // their own queryable nodes for Maestro and screen readers.
      child: Semantics(
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RepliesHeader(request: request),
            const SizedBox(height: Spacing.twoXSmall),
            _RepliesSummary(text: request.summaryLine),
            const SizedBox(height: Spacing.small),
            _RepliesCheckOffersButton(request: request, onTap: onCheckOffers),
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

/// Order id on the start, the offerer avatar stack + "+N" count on the end.
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
        color: theme.colorScheme.onSecondaryContainer,
        letterSpacing: 0.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RepliesCheckOffersButton extends StatelessWidget {
  const _RepliesCheckOffersButton({required this.request, required this.onTap});

  final ClientHomeRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Figma 56535:2251 pins a content-hugging navy pill to the END of the row.
    // `OmdsPrimaryButton` is an `AnimatedContainer` with `width: null`, which
    // expands to fill the bounded incoming width — so `Align(centerEnd)` alone
    // renders it gutter-to-gutter (measured 768/800 px). `IntrinsicWidth` feeds
    // the button a tight content-width constraint so it hugs the label, and the
    // `Align` then pins the hugged pill to the end. Stays 100% OMDS (no raw
    // Material button); the `width:` param is the alternative but it would
    // hardcode a magic pixel value, which the design-tokens rule forbids.
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: IntrinsicWidth(
        child: SizedBox(
          height: Sizes.twoXLarge,
          child: Semantics(
            identifier: 'orders_replies_check_offers_${request.id}',
            button: true,
            child: OmdsPrimaryButton(
              key: Key('replies-check-offers-${request.id}'),
              text: AppLocalizations.of(context).homeRepliesCheckOffersCta,
              onTap: onTap,
              borderRadius: OmdsBorderRadius.pill,
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlapping offerer avatars followed by a navy "+N" overflow count,
/// matching the Figma `+6` cluster on the end of the Replies card header. No
/// OMDS avatar-stack primitive exists yet — flagged as an extraction candidate
/// for `omds-flutter` (`flutter-component-extraction-aggressive`).
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
        color: theme.colorScheme.onSecondaryContainer,
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
