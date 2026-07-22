import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';

/// Bottom sheet that lets the user pick inclusive calendar days. Returns
/// `null` if dismissed, otherwise a half-open [OrderDateRange] whose exclusive
/// upper bound is midnight after the picked end day. An "all dates" state is
/// represented by an empty range (both ends null).
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
  late DateTime? _to = widget.initial.inclusiveToDay;

  bool get _isEmpty => _from == null && _to == null;

  OrderDateRange get _selectedRange =>
      OrderDateRange.forInclusiveDays(from: _from, to: _to);

  bool get _hasChanges => _selectedRange != widget.initial;

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.orderHistoryFilterTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.medium),
            _DateField(
              key: const Key('order-history-filter-from'),
              fieldId: 'order_history_sheet_from',
              label: l10n.orderHistoryFilterFrom,
              value: _from,
              placeholder: l10n.orderHistoryFilterAnyDate,
              clearTooltip: l10n.orderHistoryFilterClearDate(
                l10n.orderHistoryFilterFrom,
              ),
              dateFormat: formatter.pattern ?? 'yMMMd',
              firstDate: earliest,
              lastDate: _to ?? now,
              onDateSelected: (picked) => setState(() => _from = picked),
              onClear: _from == null
                  ? null
                  : () => setState(() => _from = null),
            ),
            const SizedBox(height: Spacing.small),
            _DateField(
              key: const Key('order-history-filter-to'),
              fieldId: 'order_history_sheet_to',
              label: l10n.orderHistoryFilterTo,
              value: _to,
              placeholder: l10n.orderHistoryFilterAnyDate,
              clearTooltip: l10n.orderHistoryFilterClearDate(
                l10n.orderHistoryFilterTo,
              ),
              dateFormat: formatter.pattern ?? 'yMMMd',
              firstDate: _from ?? earliest,
              lastDate: now,
              onDateSelected: (picked) => setState(() => _to = picked),
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
                    enabled: !_isEmpty,
                    child: OMDSOutlinedButton(
                      key: const Key('order-history-filter-clear'),
                      text: l10n.orderHistoryFilterClear,
                      enabled: !_isEmpty,
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
                    enabled: _hasChanges,
                    child: OmdsPrimaryButton(
                      key: const Key('order-history-filter-apply'),
                      text: l10n.orderHistoryFilterApply,
                      isEnabled: _hasChanges,
                      onTap: () {
                        Navigator.of(context).pop(_selectedRange);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.fieldId,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.clearTooltip,
    required this.dateFormat,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
    required this.onClear,
  });

  /// Semantics id prefix for this row's date-picker button (`${fieldId}_cta`)
  /// and its clear affordance (`${fieldId}_clear_cta`).
  final String fieldId;
  final String label;
  final DateTime? value;
  final String placeholder;
  final String clearTooltip;
  final String dateFormat;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: OmdsDatePicker(
            key: ValueKey<DateTime?>(value),
            identifier: '${fieldId}_cta',
            labelText: label,
            hintText: placeholder,
            dateFormat: dateFormat,
            initialDate: value,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateSelected: (picked) {
              if (picked != null) onDateSelected(picked);
            },
          ),
        ),
        Semantics(
          identifier: '${fieldId}_clear_cta',
          container: true,
          button: true,
          enabled: onClear != null,
          child: IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: onClear == null ? null : clearTooltip,
          ),
        ),
      ],
    );
  }
}
