import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';

/// Status pill rendered inside [OrderHistoryCard]. Colour and label are
/// derived from the request's terminal-vs-in-flight category so a future
/// state added on the backend still renders sensibly.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _paletteFor(status, colorScheme);
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
    ColorScheme scheme,
  ) {
    switch (status.tab) {
      case OrderHistoryTab.completed:
        return _ChipPalette(
          background: scheme.tertiaryContainer,
          foreground: scheme.onTertiaryContainer,
        );
      case OrderHistoryTab.cancelled:
        return _ChipPalette(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        );
      case OrderHistoryTab.active:
        return _ChipPalette(
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
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
