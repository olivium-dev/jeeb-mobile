import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

/// Status pill rendered inside [OrderHistoryCard]. Colour and label are
/// derived from the request's terminal-vs-in-flight category so a future
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(status, context.jeebRoles);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Text(
        _labelFor(status, AppLocalizations.of(context)),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  static _ChipPalette _paletteFor(
    OrderRequestStatus status,
    JeebRoles roles,
  ) {
    switch (status.tab) {
      case OrderHistoryTab.completed:
        return _ChipPalette(
          background: roles.successContainer,
          foreground: roles.onSuccessContainer,
        );
      case OrderHistoryTab.cancelled:
        return _ChipPalette(
          background: roles.errorContainer,
          foreground: roles.onErrorContainer,
        );
      case OrderHistoryTab.active:
        return _ChipPalette(
          background: roles.primaryContainer,
          foreground: roles.onPrimaryContainer,
        );
    }
  }

  static String _labelFor(OrderRequestStatus s, AppLocalizations l10n) {
    switch (s) {
      case OrderRequestStatus.pending:
        return l10n.orderHistoryStatusPending;
      case OrderRequestStatus.matched:
        return l10n.orderHistoryStatusMatched;
      case OrderRequestStatus.pickedUp:
        return l10n.orderHistoryStatusPickedUp;
      case OrderRequestStatus.enRoute:
        return l10n.orderHistoryStatusEnRoute;
      case OrderRequestStatus.delivered:
        return l10n.orderHistoryStatusDelivered;
      case OrderRequestStatus.cancelled:
        return l10n.orderHistoryStatusCancelled;
      case OrderRequestStatus.disputed:
        return l10n.orderHistoryStatusDisputed;
      case OrderRequestStatus.unknown:
        return l10n.orderHistoryStatusUnknown;
    }
  }
}

class _ChipPalette {
  const _ChipPalette({required this.background, required this.foreground});
  final Color background;
  final Color foreground;
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/order_history/order_status_chip_preview_test.dart
// ===========================================================================
//
// Widget previews for [OrderStatusChip] — run with
// `flutter widget-preview start`.
//
// The chip takes one enum and nothing else: no cubit, no repository, nothing
// async. "Loading" and "error" therefore do not exist for it, and these
// previews are network-free because there is nothing to fetch, not merely
// because [jeebPreviewHost] guards the wire. Its real states are the eight
// values of [OrderRequestStatus] — which the widget collapses into THREE
// paint jobs, and that collapse is the first thing to look at:
//
//  * the fill comes from `status.tab`, not from `status`. All five in-flight
//    values (pending / matched / pickedUp / enRoute / unknown) render the same
//    `primaryContainer` pill, and `cancelled` and `disputed` render the same
//    `errorContainer` one. Only the LABEL separates them, so a label that
//    fails to localize or fails to fit is not a cosmetic problem here — it is
//    the entire content of the chip. That is why every state below is a
//    different label rather than a different colour;
//  * `_labelFor` is exhaustive over the enum with no `default:`, so nothing can
//    reach this widget unlabelled: `OrderRequestStatus.parse` funnels every
//    status it does not recognise into `unknown`. [orderStatusChipUnknown] is
//    that contract made visible, not a curiosity — a `Done` order once fell
//    into `unknown` for a whole release (run-22 P1-B) and this chip is where a
//    customer would have seen it;
//  * the `Text` sets no `maxLines` and no `overflow`, and its one call site —
//    `_Header` in `order_history_card.dart` — makes the chip the NON-flexible
//    trailing child of a `Row` beside an `Expanded` date. A non-flexible child
//    is measured against unbounded width, so the chip always takes what it
//    wants and the date always pays. See [orderStatusChipHeaderRow].
//
// Five states are lone pills and the last is the host row. The row is reproduced
// here because the production `_Header` is private to another library — the
// same trade `delivery_eta_badge.dart` makes, with the same caveat: if
// `_Header` changes its geometry this preview is quietly wrong. One deliberate
// substitution inside it: the real card formats `DateFormat.yMMMd(locale)
// .add_jm()`, and `intl` is not imported above the banner (nothing preview-only
// may change the shipping import block beyond the harness). The fixture uses
// [MaterialLocalizations] instead, which localizes into Arabic the same way and
// produces a string of comparable length, so the squeeze is representative
// without being byte-identical.
//
// The status values used below are the ones
// `test/features/order_history/orders_stale_status_chip_test.dart` drives the
// real screen with during the live COD run it reproduces.

/// Canvas box for a lone pill: narrow, but tall enough that the 200% rendering
/// of the matrix is not clipped by the canvas itself.
const Size _orderStatusChipPillBox = Size(240, 110);

/// Canvas box for the card header row — phone width, and tall enough for the
/// 200% rendering where the date wraps beside the pill.
const Size _orderStatusChipHeaderBox = Size(390, 200);

/// The width the header row really gets: [OrderHistoryCard] pads
/// `Spacing.medium` (16) on each side, and the list around it adds vertical
/// padding only. `390 - 16 - 16 = 358`.
///
/// Pinned in the fixture rather than left to the canvas [Size] on purpose: the
/// render tests pump onto a fixed 800 × 600 surface, so a row left to fill its
/// host would be squeezed on the phone and not squeezed under test — the state
/// that breaks would only break in one of the two places it is looked at.
const double _orderStatusChipHeaderWidth = 358;

/// `createdAt` of the order the stale-chip regression test uses.
final DateTime _orderStatusChipCreatedAt = DateTime(2026, 7, 31, 19, 40);

/// A lone pill, start-aligned so RTL mirroring is visible: the chip sits on the
/// left of the canvas in English and on the right in Arabic. Centred content
/// would hide that, and mirroring is most of what the AR rendering is for.
Widget _orderStatusChipHosted(OrderRequestStatus status) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: OrderStatusChip(status: status),
      ),
    );

/// Reproduces the header `Row` of `OrderHistoryCard`: an [Expanded] date label
/// in `bodyMedium` / `onSurfaceVariant`, then the chip.
///
/// The date is not decoration. It is the only thing in the app that competes
/// with the chip for width, and — like the chip — it carries no `maxLines` and
/// no `overflow`, so pressure from the chip makes it WRAP and the card grow
/// taller rather than ellipsize.
class _OrderStatusChipCardHeaderRow extends StatelessWidget {
  const _OrderStatusChipCardHeaderRow({required this.status});

  final OrderRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String dateLabel =
        '${material.formatMediumDate(_orderStatusChipCreatedAt)} '
        '${material.formatTimeOfDay(
      TimeOfDay.fromDateTime(_orderStatusChipCreatedAt),
    )}';
    return Center(
      child: SizedBox(
        width: _orderStatusChipHeaderWidth,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                dateLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            OrderStatusChip(status: status),
          ],
        ),
      ),
    );
  }
}

/// The ordinary in-flight reading, and the state a customer stares at longest:
/// their jeeber is on the road.
///
/// `enRoute` is the `active` bucket, so this is the `primaryContainer` pill —
/// and that role is not one colour across the two schemes. `AppTheme.light()`
/// pins it to the brand ORANGE container (#FFDBD1 under #3A0B01 ink, 13.3:1);
/// `AppTheme.dark()` derives it from the NAVY seed (#3C4279 under #DFE0FF,
/// 7.2:1). The same "in progress" chip is warm in light and cool in dark.
/// Contrast is comfortable at both ends — it is the hue that jumps, and only a
/// side-by-side rendering shows it.
@JeebPreview(
  group: 'order_history',
  name: 'In flight · En route',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipInFlight() =>
    _orderStatusChipHosted(OrderRequestStatus.enRoute);

/// The terminal success state, and the one whose palette was deliberately
/// changed: `completed` now resolves to the semantic `successContainer` role
/// rather than to brand tertiary doing state duty (see `_paletteFor`).
///
/// Worth looking at beside [orderStatusChipInFlight] in both brightnesses: this
/// is the only chip in the widget that reads from [JeebColorRoles] instead of
/// from [ColorScheme], so it is the one that will drift if the two layers are
/// ever tuned apart. It is also the best-behaved of the three — a genuine tonal
/// pair in both schemes (#DCFCE7/#14532D at 8.3:1 light, inverted to
/// #14532D/#BBF7D0 at 7.5:1 dark) — which makes it the reference the
/// `errorContainer` pill below should be compared against.
@JeebPreview(
  group: 'order_history',
  name: 'Completed · Delivered',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipDelivered() =>
    _orderStatusChipHosted(OrderRequestStatus.delivered);

/// The other terminal state.
///
/// `cancelled` maps to `errorContainer`, and this is where the light scheme
/// and the dark scheme stop agreeing about what that role is.
///
/// `AppTheme.light()` builds its scheme with `ColorScheme.light(...)` and does
/// not pass an `errorContainer`; Flutter's getter then falls back to `error`
/// itself (#B00020) with `onError` (white) for the ink. `AppTheme.dark()` uses
/// `ColorScheme.fromSeed`, which generates the real tonal pair
/// (#93000A/#FFDAD6). So in LIGHT this pill is a saturated tone-40 FILL sitting
/// beside two pale tints, and in DARK it is a container like its neighbours —
/// exactly the tone-pair mistake `AppTheme`'s own `_jeebOrangeContainer` note
/// documents fixing for the brand orange, still live on the error role.
/// Contrast passes either way (7.3:1 and 7.2:1); it is the weight that is
/// wrong. Compare the three pills in one scroll of the canvas.
@JeebPreview(
  group: 'order_history',
  name: 'Terminal · Cancelled',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipCancelled() =>
    _orderStatusChipHosted(OrderRequestStatus.cancelled);

/// The collision, and the reason a colour-only reading of this chip is not
/// enough: `disputed` buckets to `OrderHistoryTab.cancelled`, so it paints the
/// SAME pill as [orderStatusChipCancelled].
///
/// A dispute is open and needs the customer to act; a cancellation is closed
/// and needs nothing. Side by side these are one pixel-identical pill with a
/// different word in it — and the app already ships a `warning` role
/// ([JeebColorRoles.warning]) that nothing here uses.
@JeebPreview(
  group: 'order_history',
  name: 'Terminal · Disputed',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipDisputed() =>
    _orderStatusChipHosted(OrderRequestStatus.disputed);

/// The forward-compatibility contract: a status the client has never heard of.
///
/// `OrderRequestStatus.parse` maps anything unrecognised to `unknown`, `unknown`
/// buckets to `active`, and the label is the localized "In progress" — never a
/// blank pill and never a raw wire string like `AtDoor`. This is the state a
/// gateway that ships a new status ahead of the app produces, and it is
/// deliberately reassuring rather than alarming.
///
/// It also carries the LONGEST English label of the eight — "In progress"
/// measures 89pt against 72pt for "En route" in Inter — which is why the matrix
/// is on here: this is where the pill's missing `maxLines` / `overflow` would
/// first show. It does not show. With nothing constraining the pill's width the
/// text cannot be clipped, and at the 200% ceiling the chip simply grows to
/// 149 × 40 and stays legible. The Arabic twin ("قيد التنفيذ") is the same 11
/// characters, so unusually for this app the RTL rendering is under the same
/// pressure rather than less.
@JeebPreview(
  group: 'order_history',
  name: 'Unknown status · In progress',
  size: _orderStatusChipPillBox,
  matrix: true,
)
Widget orderStatusChipUnknown() =>
    _orderStatusChipHosted(OrderRequestStatus.unknown);

/// The layout ceiling: the chip where it actually lives, in the header row of
/// `OrderHistoryCard`, at the width a 390pt phone gives it.
///
/// Reviewed on its own a pill always looks fine. Reviewed here you can see what
/// it costs the date beside it, and the three renderings fail differently:
///
///  * **EN light** — comfortable: the chip takes 81 of the 358pt and the date
///    fits on one line, so the header is 24pt tall.
///  * **AR RTL dark** — the row mirrors unaided (the chip's padding is
///    `EdgeInsetsDirectional.symmetric`, and horizontal-symmetric padding has
///    no side to get wrong), and the date moves to the far side of the chip.
///    The Arabic date is the LONGER string of the two (23 characters against
///    19), so this rendering squeezes harder than the English one — the one
///    place in this widget where AR is under more pressure than EN.
///  * **EN 200% text** — the chip is non-flexible, so it is measured first
///    against unbounded width and grows to 133pt; the `Expanded` date takes
///    what is left. With no `maxLines` on either, the date WRAPS to two lines
///    rather than ellipsizing and the header goes from 24pt to 80pt tall.
///    Nothing overflows — the cost is paid in card height, not in clipped text.
///
/// `pickedUp` is the status here because it is the mid-delivery value the
/// stale-chip regression test advances to on a push, and "Picked up" is the
/// widest of the four labels a real in-flight request can carry.
@JeebPreview(
  group: 'order_history',
  name: 'Card header row · layout ceiling',
  size: _orderStatusChipHeaderBox,
  matrix: true,
)
Widget orderStatusChipHeaderRow() => const _OrderStatusChipCardHeaderRow(
      status: OrderRequestStatus.pickedUp,
    );
