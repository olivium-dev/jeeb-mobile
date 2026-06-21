import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/notifications_repository.dart';
import '../notifications_l10n.dart';

/// A single inbox row for notifications-list (JM-057). Dumb widget
/// (40_GUARDRAILS_ARCH §1 layer rules): data in via constructor, the tap out
/// via [onTap] — it never reaches `sl` or `context.go`.
///
/// Carries the dynamic Maestro id `notif_row_<id>` (41_GUARDRAILS_TESTING §1.1
/// per-item row form; JM-057 AC). Renders the typed leading icon (one per D84
/// class), the category label + payload title/body, a relative timestamp, and
/// an unread dot. The whole row is the tap target — on tap the screen marks the
/// row read and dispatches the D84 deep-link.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.item,
    required this.copy,
    required this.onTap,
    this.now,
    this.onConfirmReceipt,
    this.isConfirmingReceipt = false,
    this.isReceiptConfirmed = false,
  });

  final NotificationItem item;
  final NotificationsL10n copy;
  final VoidCallback onTap;

  /// Injectable clock for the relative timestamp (deterministic in tests).
  final DateTime? now;

  /// notif-inline-confirm-receipt: fired by the per-row "Confirm receipt"
  /// button (rendered only for `confirm_receipt` rows with a `ref`). `null`
  /// hides the inline action (the whole-row tap → delivered-receipt still works).
  final VoidCallback? onConfirmReceipt;

  /// True while this row's inline confirm-receipt is in flight (spinner).
  final bool isConfirmingReceipt;

  /// True once this row's inline confirm-receipt succeeded (shows "Confirmed").
  final bool isReceiptConfirmed;

  /// Render the inline confirm-receipt action only for a `confirm_receipt` row
  /// that has a deliveryId (`ref`) AND a handler wired (notif-inline-confirm-
  /// receipt). Other kinds keep their whole-row tap dispatch unchanged.
  bool get _showConfirmReceipt =>
      item.kind == NotificationKind.confirmReceipt &&
      (item.ref?.isNotEmpty ?? false) &&
      onConfirmReceipt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final unread = !item.read;

    return Semantics(
      // Dynamic per-row id — QA asserts the seeded fixture id (e.g.
      // notif_row_notif-001). 41_GUARDRAILS_TESTING §1.1.
      identifier: 'notif_row_${item.id}',
      button: true,
      container: true,
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
                    if (item.title.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        item.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        item.body,
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
                    if (_showConfirmReceipt) ...[
                      const SizedBox(height: Spacing.small),
                      _ConfirmReceiptAction(
                        notificationId: item.id,
                        copy: copy,
                        onConfirm: onConfirmReceipt!,
                        isConfirming: isConfirmingReceipt,
                        isConfirmed: isReceiptConfirmed,
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

/// Inline confirm-receipt action (notif-inline-confirm-receipt, D70). Renders
/// the per-row "Confirm receipt" button, an in-flight spinner, or — once
/// confirmed — a static "Confirmed" affordance. Carries the dynamic
/// `notif_row_<id>_confirm_receipt` id so a flow can tap it without leaving the
/// inbox.
class _ConfirmReceiptAction extends StatelessWidget {
  const _ConfirmReceiptAction({
    required this.notificationId,
    required this.copy,
    required this.onConfirm,
    required this.isConfirming,
    required this.isConfirmed,
  });

  final String notificationId;
  final NotificationsL10n copy;
  final VoidCallback onConfirm;
  final bool isConfirming;
  final bool isConfirmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (isConfirmed) {
      return Semantics(
        identifier: 'notif_row_${notificationId}_confirm_receipt_done',
        label: copy.confirmReceiptDone,
        container: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: Sizes.medium, color: colors.primary),
            const SizedBox(width: Spacing.twoXSmall),
            Text(
              copy.confirmReceiptDone,
              style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
            ),
          ],
        ),
      );
    }

    return Semantics(
      identifier: 'notif_row_${notificationId}_confirm_receipt',
      button: true,
      enabled: !isConfirming,
      label: copy.confirmReceiptAction,
      onTap: isConfirming ? null : onConfirm,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 180,
          child: OmdsLoadingButton(
            text: copy.confirmReceiptAction,
            isLoading: isConfirming,
            isEnabled: !isConfirming,
            height: Sizes.fourXLarge,
            onTap: onConfirm,
          ),
        ),
      ),
    );
  }
}

/// Typed leading icon — one glyph per D84 dispatch class so the row reads at a
/// glance (cosmetic; flows key on the row id, not the icon).
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
      case NotificationKind.confirmReceipt:
        return Icons.inventory_2_outlined;
      case NotificationKind.marketing:
        return Icons.campaign_outlined;
      case NotificationKind.unknown:
        return Icons.notifications_none_outlined;
    }
  }
}
