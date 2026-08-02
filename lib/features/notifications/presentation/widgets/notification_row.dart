import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/notifications_repository.dart';
import '../notifications_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
  });

  final NotificationItem item;
  final NotificationsL10n copy;
  final VoidCallback onTap;

  /// Injectable clock for the relative timestamp (deterministic in tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final unread = !item.read;
    // G3: a locally-persisted new_request from a data-only push may carry no
    // title/body — fall back to localized copy so the row is never blank. Server
    // rows (which always carry a title) are unaffected.
    final isNewRequest = item.kind == NotificationKind.newRequest;
    final title = item.title.isNotEmpty
        ? item.title
        : (isNewRequest ? copy.newRequestFallbackTitle : '');
    final body = item.body.isNotEmpty
        ? item.body
        : (isNewRequest ? copy.newRequestFallbackBody : '');

    return Semantics(
      // Dynamic per-row id — QA asserts the seeded fixture id (e.g.
      // notif_row_notif-001). 41_GUARDRAILS_TESTING §1.1.
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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/notifications/notification_row_preview_test.dart
// ===========================================================================
//
// Widget previews for [NotificationRow] — run with
// `flutter widget-preview start`.
//
// The row is a dumb widget (40_GUARDRAILS_ARCH §1): one [NotificationItem]
// value, one [NotificationsL10n] resolver read off the ambient [Localizations],
// one inert `onTap`. There is no cubit and no repository behind it, so these
// previews are network-free by construction rather than by the guard in
// [jeebPreviewHost] — each state is a literal `const NotificationItem`.
//
// `now` is PINNED on every preview. The relative timestamp is the one thing on
// this row that would otherwise drift with the wall clock, and a card that
// reads "2h ago" on Monday and "3d ago" on Thursday is not a state anyone can
// review. The fixture instant and the `2026-06-18T10:00:00Z` timestamp are the
// ones `test/features/notifications/notifications_list_screen_test.dart`
// already seeds, so the canvas and the regression suite look at the same rows.
//
// ## What to look for, and what the states are chosen for
//
// * **The eyebrow is not the title (P0-X08).** Every row paints the per-kind
//   category label above the payload headline. The regression these guard is a
//   fixture that rendered the same string twice and collapsed the hierarchy —
//   so read the two top lines of each card as a pair.
//
// * **RTL mirroring (AC-16 FM1).** The leading icon must sit at the trailing
//   edge in Arabic and the unread dot at the leading edge. The padding is
//   [EdgeInsetsDirectional] and the dot's margin is `EdgeInsetsDirectional.only`
//   so this should hold — the AR RTL rendering of the matrix is where it would
//   show if it stopped holding.
//
// * **Nothing on this row clamps.** Neither the title nor the body sets
//   `maxLines` or `overflow`, so long copy wraps and the row simply GROWS.
//   Measured at 390 pt: the shortest row this widget can produce is 80 pt and
//   a full four-line one is 168 pt, but the long-payload fixture below is
//   328 pt at 1.0× and **1252 pt at 200 % text** — a single notification
//   taller than three phone screens. It never overflows (the list scrolls),
//   it just buries every row under it.
//
// * **The blank-row floor.** The G3 fallback fills an empty payload for
//   `new_request` ONLY; every other kind renders whatever the push carried. See
//   [notificationRowBarePayload] for what is left when that is nothing.

/// Fixed clock for the relative timestamps, so a card's age never depends on
/// the day it is opened. Same instant the screen test's fixtures are read at.
final DateTime _notificationRowNow = DateTime.utc(2026, 6, 18, 12);

/// Canvas box for a normal row: phone width, and tall enough for the deepest
/// four-line stack (eyebrow + title + wrapped body + timestamp) this widget
/// produces at 1.0× text. Measured at 390 pt: 128 pt for a one-line body, 168
/// pt when the body wraps.
const Size _notificationRowBox = Size(390, 190);

/// Canvas box for the degenerate row — category label and nothing else. 80 pt
/// measured, which is the FLOOR this widget can shrink to.
const Size _notificationRowShortBox = Size(390, 96);

/// Canvas box for the wrapping state: 328 pt measured at 1.0× text. The 200%
/// rendering of the matrix does not fit in any sane box (1252 pt) and is meant
/// to be scrolled — see [notificationRowLongContent].
const Size _notificationRowTallBox = Size(390, 360);

/// Hosts one row the way `_LoadedList` does: full phone width, inside a
/// scrollable, and followed by the same `Divider(height: 1)` that
/// `ListView.separated` puts between rows.
///
/// The scrollable is not decoration. A `Scaffold` body hands its child TIGHT
/// constraints, so a bare row would stretch to the full height of the canvas
/// box and every card would report the same (wrong) height. Worse, this row has
/// no `maxLines` anywhere, so at 200% text it grows past any fixed box and
/// would paint overflow stripes over the state under review. Production hosts
/// it in a `ListView.separated`, which is exactly this: unbounded height, and
/// growth turns into scroll rather than into an error.
///
/// [NotificationsL10n.of] needs a [BuildContext] under the preview's
/// [Localizations], which is what the [Builder] is for — the resolver picks EN
/// or AR off the ambient locale exactly as the production screen does.
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
///
/// This is the shape every other state is a degradation of — typed icon,
/// category eyebrow, payload title in semibold, body, age, unread dot. The
/// fixture is the one the RTL screen test seeds (`AC-16 FM1`), which is why
/// this is the state carrying the matrix: it is a [Row] of icon + text + dot,
/// and the AR RTL rendering is the only place the mirroring is visible.
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
///
/// Worth a card of its own precisely because that difference is so small. Read
/// unread and read side by side in the canvas: if the two are hard to tell
/// apart here, they are impossible to tell apart in a list of twenty, and the
/// unread affordance has stopped doing its job. (The dot is the only
/// non-typographic signal, and it is announced to screen readers by label
/// only — `copy.unreadLabel` on a decoration-less [Container].)
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
/// and no body at all.
///
/// The isolate cannot localize, so the render layer supplies the copy. If this
/// card ever shows a bare "New request" eyebrow over empty space, the fallback
/// in `build` has broken and a jeeber who dismissed the push again has no
/// readable trail back to the request — which is the exact device gap G3 was
/// opened for.
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
///
/// An unrecognized `type` from the notification service maps to
/// [NotificationKind.unknown], and `_str` in the Dio projection turns a missing
/// title, body or `ts` into `''` — so a row like this is not hypothetical, it
/// is what any wire shape the mobile enum does not know about degrades to. All
/// three `if (…isNotEmpty)` guards fail and what is left is a generic
/// "Notification" eyebrow, a bell icon and an unread dot: a 56 pt tap target
/// that says nothing about what it will do, and that on tap only marks itself
/// read (`unknown` has no deep-link, by design — no fabricated nav).
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
///
/// Neither the title nor the body clamps, so this row does not ellipsize — it
/// GROWS, and the question the canvas answers is how far. Measured at 390 pt:
/// 328 pt at 1.0× text and 1252 pt at 200%, which is why this state carries the
/// matrix and why its 200% card has to be SCROLLED to be read. One unread
/// notification at the accessibility ceiling is taller than three phone
/// screens; nothing above it is broken, but nothing below it is reachable
/// either.
///
/// Look also at the unread dot. It is a fixed 12 pt square nudged down by
/// `Spacing.xSmall`, tuned against a 16 pt eyebrow — at 200% that eyebrow line
/// is 64 pt tall and the dot no longer reads as sitting beside it. It is the
/// one element on the row that does not scale with text.
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
///
/// `relativeTime` falls back to the input string whenever [DateTime.tryParse]
/// returns null, and the Dio projection accepts `ts` / `timestamp` /
/// `createdAt` as whatever string the service put there — so one service that
/// formats dates for humans is all it takes to leak a raw field into the row.
/// It is a deliberately quiet failure (a garbled date is better than a crash or
/// a fabricated "just now"), but it is invisible in every test that asserts on
/// semantics identifiers, and this card is the only place it is ever seen.
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
