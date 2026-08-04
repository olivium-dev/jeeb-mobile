import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';

/// The localized wire-status label rendered on an order-history row.
///
/// The redesign (redesign-2026-08 §24) removed the tinted status *pill*: the
/// board carries state in the row glyph (accent dot / check / ✕) and in the ink
/// of a plain meta line, so the only thing left of `OrderStatusChip` is its
/// status→string switch. It stays a top-level helper — and this file stays on
/// disk — because `orders_stale_status_chip_test.dart` is the regression guard
/// for the stale-status defect and asserts on these exact strings
/// (`find.text('Pending' / 'Picked up' / 'In transit')`).
///
/// Deriving the label from the wire status (never from the tab bucket) is what
/// keeps a future backend state rendering sensibly instead of blank.
String orderStatusLabel(OrderRequestStatus status, AppLocalizations l10n) {
  switch (status) {
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
