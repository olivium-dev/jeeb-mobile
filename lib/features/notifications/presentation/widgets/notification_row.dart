import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../domain/notifications_repository.dart';
import '../notifications_l10n.dart';

/// Row radius/padding — the numbers screen 24 uses for an order row
/// (`24-order-history.html` tpl 1427 / 1437). The inbox sits next to that list
/// in the shell, so it reads as the same product.
const double _rowRadius = 18;
const EdgeInsetsGeometry _rowPadding = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.medium,
  vertical: 14,
);

/// Ø9 — 24's live dot, reused as the unread mark. Deliberately the ONLY orange
/// on this screen: an unread row is exactly the "do-it-now" moment the accent
/// is rationed for, and the mark stays small enough that a full inbox never
/// becomes an orange wall.
const double _unreadDotSize = 9;

/// A single inbox row for notifications-list (JM-057). Dumb widget
/// (40_GUARDRAILS_ARCH §1 layer rules): data in via constructor, the tap out
/// via [onTap] — it never reaches `sl` or `context.go`.
///
/// Carries the dynamic Maestro id `notif_row_<id>` (41_GUARDRAILS_TESTING §1.1
/// per-item row form; JM-057 AC). Renders the typed leading icon (one per D84
/// class), the category label + payload title/body, a relative timestamp, and
/// an unread dot. The whole row is the tap target — on tap the screen marks the
/// row read and dispatches the D84 deep-link.
///
/// Redesign-2026-08: a re-skin onto the kit, not a rewrite. The hand-rolled
/// `InkWell` + `Divider` list item became a [JeebOutlinedCard] (outline over
/// shadow, r18, 14/16) carrying two bands in 24's rhythm — a meta line (glyph ·
/// category · relative time · unread dot) over the payload headline and body.
/// The relative time moved to the trailing edge of the meta line, which is
/// where 24 puts a row's trailing value; nothing was added or removed.
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

  /// Injectable clock for the relative timestamp (deterministic in tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool unread = !item.read;
    // G3: a locally-persisted new_request from a data-only push may carry no
    // title/body — fall back to localized copy so the row is never blank. Server
    // rows (which always carry a title) are unaffected.
    final bool isNewRequest = item.kind == NotificationKind.newRequest;
    final String title = item.title.isNotEmpty
        ? item.title
        : (isNewRequest ? copy.newRequestFallbackTitle : '');
    final String body = item.body.isNotEmpty
        ? item.body
        : (isNewRequest ? copy.newRequestFallbackBody : '');
    // Periwinkle meta ink — 24's date/status line.
    final TextStyle metaStyle = context.jeebText.bodySmall.copyWith(
      color: scheme.onSecondaryContainer,
    );

    return JeebOutlinedCard(
      // FROZEN: `notif_row_<id>` re-homed onto the kit card, which emits one
      // `Semantics(identifier:, button:, container:, explicitChildNodes:)` node
      // — the same shape as the hand-rolled wrapper it replaces, so the nested
      // timestamp and unread-badge ids still surface.
      identifier: 'notif_row_${item.id}',
      onTap: onTap,
      radius: _rowRadius,
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _iconFor(item.kind),
                size: Sizes.medium,
                // The glyph carries read-state too, so the dot is a
                // confirmation rather than the only signal.
                color: unread ? scheme.primary : scheme.onSecondaryContainer,
              ),
              const SizedBox(width: Spacing.xSmall),
              Expanded(
                child: Text(
                  copy.categoryLabel(item.kind),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              ),
              if (item.timestamp.isNotEmpty) ...<Widget>[
                const SizedBox(width: Spacing.xSmall),
                Semantics(
                  identifier: 'notif_row_${item.id}_timestamp',
                  container: true,
                  child: Text(
                    copy.relativeTime(item.timestamp, now: now),
                    maxLines: 1,
                    style: metaStyle,
                  ),
                ),
              ],
              if (unread) ...<Widget>[
                const SizedBox(width: Spacing.xSmall),
                Semantics(
                  identifier: 'notif_row_${item.id}_unread_badge',
                  label: copy.unreadLabel,
                  container: true,
                  child: Container(
                    width: _unreadDotSize,
                    height: _unreadDotSize,
                    decoration: BoxDecoration(
                      color: context.jeebRoles.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (title.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.xSmall),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.jeebText.cardTitle.copyWith(
                color: scheme.primary,
                // Read rows step down one weight instead of changing size, so
                // no row shifts height when it is marked read.
                fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
          if (body.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.twoXSmall),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              // Ink, not the warm brown `onSurfaceVariant` this row used to
              // paint: the palette reserves brown for outlines and dividers,
              // and body copy is the near-navy ink (`_ds/readme.md` §Color).
              style: context.jeebText.body.copyWith(color: scheme.onSurface),
            ),
          ],
        ],
      ),
    );
  }
}

/// Typed leading glyph — one per D84 dispatch class so the row reads at a
/// glance (cosmetic; flows key on the row id, not the icon). The outlined set
/// is contract-pinned by the RTL mirroring test, so it survives the re-skin
/// unchanged; only its tile and ink moved.
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
