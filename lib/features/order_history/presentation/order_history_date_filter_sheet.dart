import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';

/// The sheet's own gutter — R21's 24 band, mirrored for RTL.
const EdgeInsetsGeometry _kSheetBand = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.xSmall,
  Spacing.xLarge,
  0,
);

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

/// R21's date-range filter, on the Midnight kit.
///
/// The `sheet` field variant (navy base + one top glow) sits behind the theme's
/// own navy sheet surface, so the glow is the only thing it adds.
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
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat.yMMMd(locale);
    final now = DateTime.now();
    final earliest = DateTime(now.year - 5);

    return JeebMidnightField(
      variant: JeebFieldVariant.sheet,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: _kSheetBand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.orderHistoryFilterTitle,
                    style: context.jeebText.h2.copyWith(
                      color: scheme.onSurface,
                    ),
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
                    formatter: formatter,
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
                    formatter: formatter,
                    firstDate: _from ?? earliest,
                    lastDate: now,
                    onDateSelected: (picked) => setState(() => _to = picked),
                    onClear: _to == null
                        ? null
                        : () => setState(() => _to = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xLarge),
            JeebCtaFooter.split(
              expandLeading: true,
              padding: EdgeInsetsDirectional.fromSTEB(
                Spacing.xLarge,
                0,
                Spacing.xLarge,
                context.sheetBottomInset + Spacing.xLarge,
              ),
              leading: Semantics(
                identifier: 'order_history_sheet_clear_cta',
                container: true,
                button: true,
                enabled: !_isEmpty,
                child: JeebCtaButton.outline(
                  key: const Key('order-history-filter-clear'),
                  label: l10n.orderHistoryFilterClear,
                  isEnabled: !_isEmpty,
                  onTap: () {
                    Navigator.of(context).pop(const OrderDateRange());
                  },
                ),
              ),
              trailing: Semantics(
                identifier: 'order_history_sheet_apply_cta',
                container: true,
                button: true,
                enabled: _hasChanges,
                child: JeebCtaButton.primary(
                  key: const Key('order-history-filter-apply'),
                  label: l10n.orderHistoryFilterApply,
                  isEnabled: _hasChanges,
                  onTap: () {
                    Navigator.of(context).pop(_selectedRange);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One glass row: label over value, calendar glyph, and the clear affordance
/// outside the card so it stays its own semantics node.
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.fieldId,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.clearTooltip,
    required this.formatter,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
    required this.onClear,
  });

  /// `12/16` — one rung tighter than the card default; this row is a control,
  /// not a card.
  static const EdgeInsetsGeometry rowPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.medium,
    vertical: 12,
  );

  final String fieldId;
  final String label;
  final DateTime? value;
  final String placeholder;
  final String clearTooltip;
  final DateFormat formatter;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasValue = value != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          // FROZEN id — the kit card carries it, so the tap target and the
          // node the tests address are the same widget.
          child: JeebOutlinedCard(
            identifier: '${fieldId}_cta',
            radius: JeebRadii.md,
            padding: rowPadding,
            onTap: () => _open(context),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JeebSectionLabel(label, small: true),
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        hasValue ? formatter.format(value!) : placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.jeebText.body.copyWith(
                          color: hasValue
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xSmall),
                Icon(
                  Icons.calendar_today_outlined,
                  size: Sizes.medium,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
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
            color: scheme.onSurfaceVariant,
            tooltip: onClear == null ? null : clearTooltip,
          ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: value ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onDateSelected(picked);
  }
}
