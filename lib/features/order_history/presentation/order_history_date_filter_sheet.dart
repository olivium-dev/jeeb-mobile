import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';

/// Bottom sheet that lets the user pick an inclusive date range. Returns
/// `null` if dismissed, an [OrderDateRange] otherwise. An "all dates"
/// state is represented by an empty range (both ends null).
Future<OrderDateRange?> showOrderHistoryDateFilterSheet({
  required BuildContext context,
  required OrderDateRange initial,
}) {
  return showModalBottomSheet<OrderDateRange>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OrderHistoryDateFilterSheet(initial: initial),
  );
}

class _OrderHistoryDateFilterSheet extends StatefulWidget {
  const _OrderHistoryDateFilterSheet({required this.initial});

  final OrderDateRange initial;

  @override
  State<_OrderHistoryDateFilterSheet> createState() =>
      _OrderHistoryDateFilterSheetState();
}

class _OrderHistoryDateFilterSheetState
    extends State<_OrderHistoryDateFilterSheet> {
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat.yMMMd(locale);
    final now = DateTime.now();
    final earliest = DateTime(now.year - 5);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: Spacing.medium,
        end: Spacing.medium,
        top: Spacing.xSmall,
        // Keyboard + system nav-bar inset (was keyboard-only) so the
        // Apply/Clear buttons clear the soft-button nav bar under edge-to-edge.
        bottom: context.sheetBottomInset + Spacing.xLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.orderHistoryFilterTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.medium),
          _DateRow(
            key: const Key('order-history-filter-from'),
            fieldId: 'order_history_sheet_from',
            label: l10n.orderHistoryFilterFrom,
            value: _from,
            placeholder: l10n.orderHistoryFilterAnyDate,
            formatter: formatter,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _from ?? now,
                firstDate: earliest,
                lastDate: _to ?? now,
              );
              if (picked != null) setState(() => _from = picked);
            },
            onClear: _from == null ? null : () => setState(() => _from = null),
          ),
          const SizedBox(height: Spacing.xSmall),
          _DateRow(
            key: const Key('order-history-filter-to'),
            fieldId: 'order_history_sheet_to',
            label: l10n.orderHistoryFilterTo,
            value: _to,
            placeholder: l10n.orderHistoryFilterAnyDate,
            formatter: formatter,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _to ?? now,
                firstDate: _from ?? earliest,
                lastDate: now,
              );
              if (picked != null) setState(() => _to = picked);
            },
            onClear: _to == null ? null : () => setState(() => _to = null),
          ),
          const SizedBox(height: Spacing.xLarge),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  identifier: 'order_history_sheet_clear_cta',
                  container: true,
                  button: true,
                  child: OMDSOutlinedButton(
                    key: const Key('order-history-filter-clear'),
                    text: l10n.orderHistoryFilterClear,
                    onTap: () {
                      Navigator.of(context).pop(const OrderDateRange());
                    },
                  ),
                ),
              ),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Semantics(
                  identifier: 'order_history_sheet_apply_cta',
                  container: true,
                  button: true,
                  child: OmdsPrimaryButton(
                    key: const Key('order-history-filter-apply'),
                    text: l10n.orderHistoryFilterApply,
                    onTap: () {
                      Navigator.of(context).pop(
                        OrderDateRange(from: _from, to: _to),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    super.key,
    required this.fieldId,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.formatter,
    required this.onTap,
    required this.onClear,
  });

  /// Semantics id prefix for this row's date-picker button (`${fieldId}_cta`)
  /// and its clear affordance (`${fieldId}_clear_cta`).
  final String fieldId;
  final String label;
  final DateTime? value;
  final String placeholder;
  final DateFormat formatter;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: Sizes.sixXLarge,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Semantics(
            identifier: '${fieldId}_cta',
            container: true,
            button: true,
            child: OMDSOutlinedButton(
              text: value == null ? placeholder : formatter.format(value!),
              onTap: onTap,
            ),
          ),
        ),
        Semantics(
          identifier: '${fieldId}_clear_cta',
          container: true,
          button: true,
          child: IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: onClear == null ? null : placeholder,
          ),
        ),
      ],
    );
  }
}
