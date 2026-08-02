import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/notifications_repository.dart';
import '../notifications_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Fixed clock for the relative timestamps, so a card's age never depends on
/// the day it is opened. Same instant the screen test's fixtures are read at.
final DateTime _notificationRowNow = DateTime.utc(2026, 6, 18, 12);

/// Canvas box for a normal row: phone width, and tall enough for the deepest
/// four-line stack (eyebrow + title + wrapped body + timestamp) this widget
const Size _notificationRowBox = Size(390, 190);

/// Canvas box for the degenerate row — category label and nothing else. 80 pt
/// measured, which is the FLOOR this widget can shrink to.
const Size _notificationRowShortBox = Size(390, 96);

/// Canvas box for the wrapping state: 328 pt measured at 1.0× text. The 200%
/// rendering of the matrix does not fit in any sane box (1252 pt) and is meant
const Size _notificationRowTallBox = Size(390, 360);

/// Hosts one row the way `_LoadedList` does: full phone width, inside a
/// scrollable, and followed by the same `Divider(height: 1)` that
Widget _notificationRowHosted(NotificationItem item) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Builder(
            builder: (BuildContext context) => NotificationRow(
              item: item,
              copy: NotificationsL10n.of(context),
              onTap: () {},
              now: _notificationRowNow,
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );

/// The canonical row: an unread server notification with a full payload.
/// This is the shape every other state is a degradation of — typed icon,
@JeebPreview(
  group: 'notifications',
  name: 'Unread · offer',
  size: _notificationRowBox,
  matrix: true,
)
Widget notificationRowUnreadOffer() => _notificationRowHosted(
      const NotificationItem(
        id: 'notif-001',
        kind: NotificationKind.offer,
        title: 'New offer on your request',
        body: 'Tap to review.',
        timestamp: '2026-06-18T10:00:00Z',
        read: false,
        ref: 'req-rtl',
      ),
    );

/// The same row after it has been tapped — and the only difference is a font
/// weight and a missing 12 pt dot.
@JeebPreview(
  group: 'notifications',
  name: 'Read · order update',
  size: _notificationRowBox,
)
Widget notificationRowRead() => _notificationRowHosted(
      const NotificationItem(
        id: 'notif-005',
        kind: NotificationKind.status,
        title: 'Your order is on the way',
        body: 'Sami picked it up from the store.',
        timestamp: '2026-06-15T09:30:00Z',
        read: true,
        ref: 'ord-88',
      ),
    );

/// G3 regression guard, made visible: a `new_request` persisted by the FCM
/// background isolate from a DATA-ONLY push, so the payload carries no title
@JeebPreview(
  group: 'notifications',
  name: 'New request · data-only push (G3)',
  size: _notificationRowBox,
)
Widget notificationRowNewRequestFallback() => _notificationRowHosted(
      const NotificationItem(
        id: 'bg-1',
        kind: NotificationKind.newRequest,
        title: '',
        body: '',
        timestamp: '2026-06-18T11:52:00Z',
        read: false,
        ref: 'req-42',
      ),
    );

/// The floor, and the blind spot of the fix above: the G3 fallback fires for
/// `new_request` ONLY.
@JeebPreview(
  group: 'notifications',
  name: 'Unknown kind · nothing to render',
  size: _notificationRowShortBox,
)
Widget notificationRowBarePayload() => _notificationRowHosted(
      const NotificationItem(
        id: 'notif-unknown',
        kind: NotificationKind.unknown,
        title: '',
        body: '',
        timestamp: '',
        read: false,
      ),
    );

/// Layout ceiling: the longest payload the notification service plausibly
/// sends, on the kind whose copy carries a name and an address.
@JeebPreview(
  group: 'notifications',
  name: 'Long payload · wraps, never clamps',
  size: _notificationRowTallBox,
  matrix: true,
)
Widget notificationRowLongContent() => _notificationRowHosted(
      const NotificationItem(
        id: 'notif-long',
        kind: NotificationKind.offerAccepted,
        title:
            'Abdulrahman Al-Muhandis accepted your offer and is on the way to '
            'the pickup point',
        body:
            'He will call when he reaches Hamra Street, Beirut — building 42, '
            'third floor. Please have the package sealed and ready to hand '
            'over.',
        timestamp: '2026-06-17T12:00:00Z',
        read: false,
        ref: 'ord-91',
      ),
    );

/// The timestamp the row cannot read, printed raw.
/// `relativeTime` falls back to the input string whenever [DateTime.tryParse]
@JeebPreview(
  group: 'notifications',
  name: 'Unparseable timestamp · raw passthrough',
  size: _notificationRowBox,
)
Widget notificationRowUnparsedTimestamp() => _notificationRowHosted(
      const NotificationItem(
        id: 'notif-badts',
        kind: NotificationKind.lowBalance,
        title: 'Your wallet balance is low',
        body: 'Top up to keep receiving requests.',
        timestamp: '18/06/2026 10:00 AM',
        read: false,
      ),
    );
