import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

/// Replies-tab row (JM-027 `my-orders` Replies sub-tab) matching the Figma
/// `+6 offers` panel.
///
/// Layout: title + tier badge, destination, stacked avatars of the offerers
/// (`OmdsAvatarStack`-equivalent — built inline because no OMDS primitive yet
/// exposes exactly the overlap-with-counter behavior the Figma wants), and a
/// CTA row carrying two actions per JM-027:
///   * `replies_check_offers_cta` → routes to the `offer-review` list
///     (`/requests/:id/offers`, JM-028), NOT `/chat/:id` (the old divergent
///     behavior the gap map flagged for `my-orders`).
///   * `replies_accept_cta` → opens the `offer-accept-confirm` sheet
///     (`offer_accept_sheet`, JM-029) [D11/D71].
/// Both are dumb callbacks (`onCheckOffers`/`onAccept`); the tab supplies the
/// navigation so the widget stays golden-testable.
class RepliesCard extends StatelessWidget {
  const RepliesCard({
    super.key,
    required this.request,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeRequest request;

  /// Tapped on `replies_check_offers_cta` → offer-review-list (JM-028).
  final VoidCallback onCheckOffers;

  /// Tapped on `replies_accept_cta` → offer-accept-confirm sheet (JM-029).
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
      // `explicitChildNodes` makes the card a Semantics *boundary*: without it
      // the column auto-merges the avatar-stack node
      // (`orders_replies_avatar_stack_<id>`, nested in the header) and the CTA
      // button nodes (`replies_check_offers_cta` / `replies_accept_cta`) into
      // one, so only the avatar-stack id survives. The boundary keeps every id
      // as its own queryable node for Maestro and screen readers.
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

/// The two JM-027 reply-card CTAs, pinned to the END of the row (Figma
/// 56535:2251): an outlined secondary "Accept" (`replies_accept_cta` →
/// offer-accept-confirm sheet, JM-029) and the primary "Check Offers"
/// (`replies_check_offers_cta` → offer-review-list, JM-028).
///
/// `OmdsPrimaryButton` / `OmdsOutlinedButton` are width-filling containers, so
/// each is wrapped in `IntrinsicWidth` to hug its label, and the `Row` is
/// end-aligned (`MainAxisAlignment.end`). Stays 100% OMDS (no raw Material
/// button); a hardcoded `width:` would violate the design-tokens rule.
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
          child: SizedBox(
            height: Sizes.twoXLarge,
            child: Semantics(
              // JM-027 AC: Accept → offer-accept-confirm sheet (JM-029).
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
        ),
        const SizedBox(width: Spacing.small),
        IntrinsicWidth(
          child: SizedBox(
            height: Sizes.twoXLarge,
            child: Semantics(
              // JM-027 AC: Check Offers → offer-review-list (JM-028), NOT chat.
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
        ),
      ],
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
