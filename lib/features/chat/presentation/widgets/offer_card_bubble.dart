import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';

/// Card shown in the broadcasting phase for each Jeeber's offer.
///
/// Mirrors the Figma broadcast chat panel: avatar + name, rating + price +
/// ETA, optional free-text note, and a primary "Accept" CTA. The screen
/// hands [onAccept] to the cubit which drives the accept saga.
class OfferCardBubble extends StatelessWidget {
  const OfferCardBubble({
    super.key,
    required this.message,
    required this.onAccept,
    this.isAccepting = false,
    this.acceptDisabled = false,
  });

  final DeliveryChatMessage message;
  final ValueChanged<String> onAccept;
  final bool isAccepting;
  final bool acceptDisabled;

  @override
  Widget build(BuildContext context) {
    final payload = message.offerPayload;
    if (payload == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: Key('chat-offer-card-${payload.offerId}'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.twoXSmall,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: OmdsBorderRadius.small,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OfferHeader(payload: payload),
            const SizedBox(height: Spacing.small),
            _OfferStats(payload: payload),
            if (payload.note.isNotEmpty) ...[
              const SizedBox(height: Spacing.small),
              Text(
                payload.note,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: Spacing.medium),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(
                height: Sizes.twoXLarge,
                child: OmdsPrimaryButton(
                  key: Key('chat-offer-accept-${payload.offerId}'),
                  text: isAccepting
                      ? l10n.chatOfferAccepting
                      : l10n.chatOfferAccept,
                  onTap: () {
                    if (acceptDisabled || isAccepting) return;
                    onAccept(payload.offerId);
                  },
                  borderRadius: OmdsBorderRadius.pill,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferHeader extends StatelessWidget {
  const _OfferHeader({required this.payload});

  final OfferCardPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        OmdsProfileAvatar(
          initial: payload.jeeberName.isEmpty ? 'J' : payload.jeeberName[0],
          profilePicUrl: payload.jeeberAvatarUrl,
          size: Sizes.threeXLarge,
          backgroundColor: theme.colorScheme.surfaceContainer,
          initialColor: theme.colorScheme.primary,
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payload.jeeberName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (payload.ratingCount > 0)
                _RatingRow(
                  rating: payload.rating,
                  ratingCount: payload.ratingCount,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.ratingCount});

  final double rating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.twoXSmall),
      child: Row(
        children: [
          Icon(
            Icons.star_rounded,
            size: Sizes.medium,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Text(
            '${rating.toStringAsFixed(1)} ($ratingCount)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferStats extends StatelessWidget {
  const _OfferStats({required this.payload});

  final OfferCardPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _OfferStatTile(
            icon: Icons.attach_money_rounded,
            label: '${payload.fee.toStringAsFixed(2)} ${payload.currency}',
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _OfferStatTile(
            icon: Icons.schedule_rounded,
            label: AppLocalizations.of(context)
                .chatOfferEtaMinutes(payload.etaMinutes),
            iconColor: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _OfferStatTile extends StatelessWidget {
  const _OfferStatTile({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: OmdsBorderRadius.twoXSmall,
      ),
      child: Row(
        children: [
          Icon(icon, size: Sizes.medium, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
