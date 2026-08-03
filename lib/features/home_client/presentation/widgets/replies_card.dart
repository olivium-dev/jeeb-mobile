import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/money_format.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar_stack.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';
import 'client_home_tier_chip.dart';

/// Replies-tab row (JM-027 `my-orders` Replies sub-tab), rebuilt to the
/// redesign board's second card (`04-client-home.html` tpl 202-213).
///
/// Layout: title + tier chip, the request summary, the offerer avatar stack
/// beside the "N offers · from $X" floor, then the CTA row carrying two
/// actions per JM-027:
///   * `replies_check_offers_cta` → routes to the `offer-review` list
///     (`/requests/:id/offers`, JM-028), NOT `/chat/:id` (the old divergent
///     behavior the gap map flagged for `my-orders`).
///   * `replies_accept_cta` → opens the `offer-accept-confirm` sheet
///     (`offer_accept_sheet`, JM-029) [D11/D71].
/// Both are dumb callbacks (`onCheckOffers`/`onAccept`); the tab supplies the
/// navigation so the widget stays golden-testable.
///
/// The board draws ONE `View offers` pill; we keep BOTH buttons and their
/// copy — `replies_accept_cta` is load-bearing for jm-027 and the double-accept
/// regression suite. The card is one row taller than the board as a result.
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
    return Padding(
      key: Key('replies-card-${request.id}'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      // `explicitChildNodes` makes the card a Semantics *boundary*: without it
      // the column auto-merges the avatar-stack node
      // (`orders_replies_avatar_stack_<id>`) and the CTA button nodes
      // (`replies_check_offers_cta` / `replies_accept_cta`) into one, so only
      // the avatar-stack id survives. The boundary keeps every id as its own
      // queryable node for Maestro and screen readers.
      child: Semantics(
        explicitChildNodes: true,
        child: JeebOutlinedCard(
          padding: const EdgeInsetsDirectional.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RepliesHeader(request: request),
              const SizedBox(height: Spacing.twoXSmall),
              _RepliesSummary(text: request.summaryLine),
              const SizedBox(height: Spacing.small),
              _RepliesOffersLine(request: request),
              const SizedBox(height: Spacing.small),
              _RepliesActions(
                request: request,
                onCheckOffers: onCheckOffers,
                onAccept: onAccept,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Order id on the start, the tier chip on the end (board `tpl 203-205`).
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
            // Role fix: `secondaryContainer` is a CONTAINER (fill) role, not an
            // ink role — the same defect class the color gate's fourth regex
            // bans. Titles on surface read in `onSurface`.
            style: context.jeebText.cardTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierChip(tier: request.tier),
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
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Board row 2 (`tpl 206-211`): the offerer stack beside "N offers · from $X".
class _RepliesOffersLine extends StatelessWidget {
  const _RepliesOffersLine({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _OfferAvatarStack(
          requestId: request.id,
          avatarUrls: request.offerAvatarUrls,
          totalCount: request.offerCount,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            _offersLabel(AppLocalizations.of(context)),
            // UX-AUDIT §T3: on the white card this reads `onSurfaceVariant`,
            // NOT the board's periwinkle (which fails contrast off navy).
            style: context.jeebText.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// "3 offers · from $8.00" when the probe found a fee floor, otherwise the
  /// plain pluralized count. The floor is genuinely absent on payload-count
  /// rows (they are never probed), so the fallback is the common case — never
  /// a fabricated price. `MoneyFormat` owns the LTR isolate, so no
  /// `Directionality` wrapping happens here.
  String _offersLabel(AppLocalizations l10n) {
    final offers = l10n.pendingCardOffersBadge(request.offerCount);
    final floor = request.lowestOfferFee;
    if (floor == null) return offers;
    return l10n.homeRepliesOffersFloor(
      offers,
      MoneyFormat.format(floor, currency: request.offerCurrency ?? 'USD'),
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
        const SizedBox(width: Spacing.small),
        IntrinsicWidth(
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
      ],
    );
  }
}

/// Overlapping offerer avatars followed by a navy "+N" overflow count. The
/// discs, the 2px ring and the −9 directional overlap are kit-owned
/// ([JeebAvatarStack]); only the "+N" stays local, because `+2`/`+6` are
/// pinned against [_OfferOverflowCount].
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
    return JeebAvatarStack(
      identifier: 'orders_replies_avatar_stack_$requestId',
      semanticLabel: '$totalCount',
      // No offerer NAME reaches this surface, so every entry is the kit's
      // dormant "unknown person" disc unless a photo URL exists. The board's
      // `K N R` initials are mock data and must not be fabricated.
      avatars: [
        for (final url in inline) JeebAvatarEntry(imageUrl: url),
      ],
      trailing: extra > 0 ? _OfferOverflowCount(extra: extra) : null,
      trailingSpacing: Spacing.twoXSmall,
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
