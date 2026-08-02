import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/notifications_repository.dart';
import '../notifications_l10n.dart';

class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.item,
    required this.copy,
    required this.onTap,
    this.now,
  });

  final NotificationItem item;
  final NotificationsL10n copy;
  final VoidCallback onTap;

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final unread = !item.read;
    final isNewRequest = item.kind == NotificationKind.newRequest;
    final title = item.title.isNotEmpty
        ? item.title
        : (isNewRequest ? copy.newRequestFallbackTitle : '');
    final body = item.body.isNotEmpty
        ? item.body
        : (isNewRequest ? copy.newRequestFallbackBody : '');

    return Semantics(
      identifier: 'notif_row_${item.id}',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.small,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadingIcon(kind: item.kind),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.categoryLabel(item.kind),
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        body,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (item.timestamp.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Semantics(
                        identifier: 'notif_row_${item.id}_timestamp',
                        container: true,
                        child: Text(
                          copy.relativeTime(item.timestamp, now: now),
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: Spacing.small),
                Semantics(
                  identifier: 'notif_row_${item.id}_unread_badge',
                  label: copy.unreadLabel,
                  container: true,
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(top: Spacing.xSmall),
                    width: Spacing.small,
                    height: Spacing.small,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.kind});

  final NotificationKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.fiveXLarge,
      height: Sizes.fiveXLarge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Icon(_iconFor(kind), color: colors.onSurfaceVariant),
    );
  }

  IconData _iconFor(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.offer:
        return Icons.local_offer_outlined;
      case NotificationKind.offerAccepted:
        return Icons.handshake_outlined;
      case NotificationKind.status:
        return Icons.local_shipping_outlined;
      case NotificationKind.lowBalance:
        return Icons.account_balance_wallet_outlined;
      case NotificationKind.feeWon:
        return Icons.percent_outlined;
      case NotificationKind.refundPenalty:
        return Icons.gavel_outlined;
      case NotificationKind.topup:
        return Icons.add_card_outlined;
      case NotificationKind.kycApproved:
        return Icons.verified_user_outlined;
      case NotificationKind.kycRejected:
        return Icons.report_gmailerrorred_outlined;
      case NotificationKind.requestExpired:
        return Icons.hourglass_disabled_outlined;
      case NotificationKind.newRequest:
        return Icons.move_to_inbox_outlined;
      case NotificationKind.confirmReceipt:
        return Icons.inventory_2_outlined;
      case NotificationKind.marketing:
        return Icons.campaign_outlined;
      case NotificationKind.unknown:
        return Icons.notifications_none_outlined;
    }
  }
}
