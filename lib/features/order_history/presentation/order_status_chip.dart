import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';

import '../../../core/previews/jeeb_preview.dart';

/// Status pill rendered inside [OrderHistoryCard]. Colour and label are
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
const Size _orderStatusChipPillBox = Size(240, 110);

/// Canvas box for the card header row — phone width, and tall enough for the
const Size _orderStatusChipHeaderBox = Size(390, 200);

/// The width the header row really gets: [OrderHistoryCard] pads
const double _orderStatusChipHeaderWidth = 358;

/// `createdAt` of the order the stale-chip regression test uses.
final DateTime _orderStatusChipCreatedAt = DateTime(2026, 7, 31, 19, 40);

/// A lone pill, start-aligned so RTL mirroring is visible: the chip sits on the
Widget _orderStatusChipHosted(OrderRequestStatus status) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: OrderStatusChip(status: status),
      ),
    );

/// Reproduces the header `Row` of `OrderHistoryCard`: an [Expanded] date label
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
@JeebPreview(
  group: 'order_history',
  name: 'In flight · En route',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipInFlight() =>
    _orderStatusChipHosted(OrderRequestStatus.enRoute);

/// The terminal success state, and the one whose palette was deliberately
@JeebPreview(
  group: 'order_history',
  name: 'Completed · Delivered',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipDelivered() =>
    _orderStatusChipHosted(OrderRequestStatus.delivered);

/// The other terminal state.
@JeebPreview(
  group: 'order_history',
  name: 'Terminal · Cancelled',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipCancelled() =>
    _orderStatusChipHosted(OrderRequestStatus.cancelled);

/// The collision, and the reason a colour-only reading of this chip is not
@JeebPreview(
  group: 'order_history',
  name: 'Terminal · Disputed',
  size: _orderStatusChipPillBox,
)
Widget orderStatusChipDisputed() =>
    _orderStatusChipHosted(OrderRequestStatus.disputed);

/// The forward-compatibility contract: a status the client has never heard of.
@JeebPreview(
  group: 'order_history',
  name: 'Unknown status · In progress',
  size: _orderStatusChipPillBox,
  matrix: true,
)
Widget orderStatusChipUnknown() =>
    _orderStatusChipHosted(OrderRequestStatus.unknown);

/// The layout ceiling: the chip where it actually lives, in the header row of
@JeebPreview(
  group: 'order_history',
  name: 'Card header row · layout ceiling',
  size: _orderStatusChipHeaderBox,
  matrix: true,
)
Widget orderStatusChipHeaderRow() => const _OrderStatusChipCardHeaderRow(
      status: OrderRequestStatus.pickedUp,
    );
