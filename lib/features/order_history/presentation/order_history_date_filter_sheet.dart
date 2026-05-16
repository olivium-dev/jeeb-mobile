import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.orderHistoryFilterTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _DateRow(
            key: const Key('order-history-filter-from'),
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
          const SizedBox(height: 8),
          _DateRow(
            key: const Key('order-history-filter-to'),
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('order-history-filter-clear'),
                  onPressed: () {
                    Navigator.of(context).pop(const OrderDateRange());
                  },
                  child: Text(l10n.orderHistoryFilterClear),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('order-history-filter-apply'),
                  onPressed: () {
                    Navigator.of(context).pop(
                      OrderDateRange(from: _from, to: _to),
                    );
                  },
                  child: Text(l10n.orderHistoryFilterApply),
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
    required this.label,
    required this.value,
    required this.placeholder,
    required this.formatter,
    required this.onTap,
    required this.onClear,
  });

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
          width: 64,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: onTap,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value == null ? placeholder : formatter.format(value!),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close),
          tooltip: onClear == null ? null : placeholder,
        ),
      ],
    );
  }
}
