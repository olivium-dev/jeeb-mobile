import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../domain/notifications_repository.dart';
import '../notifications_l10n.dart';

/// R21's own row box (`21-r21-order-history` tpl: `border-radius:20px;
/// padding:14px 16px`) — 20 snaps to `JeebRadii.lg` under the §5 ±2 rule.
const EdgeInsetsGeometry _rowPadding = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.medium,
  vertical: 14,
);

/// Ø9 — R21's live dot, reused as the unread mark and the ONLY orange here.
/// FLAT: R21 glows its in-motion row only, and an unread row is queued.
const double _unreadDotSize = 9;

/// A read row is R21's faded row, at R21's SHIPPED value so the two surfaces
/// move together. TODO(midnight): inherits owner Q-006 — the blanket fade puts
/// this row's `#8A93D8` meta run at 3.25:1 on `#0B1351`, under AA.
const double _readOpacity = 0.65;

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
/// MIDNIGHT (M3-08): the board never drew this screen, so the row is derived
/// from R21 (order history), its neighbour in the shell and the nearest drawn
/// list surface. Carried over verbatim: the rest-glass rung (`glassFill` 7% +
/// 1px `glassBorder`, `JeebRadii.lg`, 14/16 padding), the white `cardTitle` /
/// periwinkle `bodySmall` ink split, the Ø9 accent state dot, and the faded
/// treatment for the row that no longer wants anything. Zero motion, like R21.
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
    // R21's meta run is measured `#8A93D8` — `onSurfaceVariant`, not the
    // brighter `#B9C0F0` this row used to paint on its eyebrow.
    final TextStyle metaStyle = context.jeebText.bodySmall.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final Widget card = JeebOutlinedCard(
      // FROZEN: `notif_row_<id>` re-homed onto the kit card, which emits one
      // `Semantics(identifier:, button:, container:, explicitChildNodes:)` node
      // — the same shape as the hand-rolled wrapper it replaces, so the nested
      // timestamp and unread-badge ids still surface.
      identifier: 'notif_row_${item.id}',
      onTap: onTap,
      radius: JeebRadii.lg,
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
                // The glyph carries read-state too, so the dot confirms
                // rather than being the only signal.
                color: unread
                    ? context.jeebRoles.accent
                    : scheme.onSurfaceVariant,
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
            // R21's own band gap (`margin-top:11px`) — the 4px scale's 12.
            const SizedBox(height: Spacing.small),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // R21's `#fff` 15/w700. Was `scheme.primary`, which under
              // Midnight IS the accent — every row title rendered orange.
              style: context.jeebText.cardTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ],
          if (body.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.twoXSmall),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              // `inkSoft` #B9C0F0 (§3): the rung between R21's white title
              // and its periwinkle meta run, AA-clear on all navies (§9).
              style: context.jeebText.body.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );

    if (unread) return card;
    return Opacity(opacity: _readOpacity, child: card);
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
    case NotificationKind.dispute:
      return Icons.report_problem_outlined;
    case NotificationKind.support:
      return Icons.support_agent;
    case NotificationKind.unknown:
      return Icons.notifications_none_outlined;
  }
}
