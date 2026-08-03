import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

/// The three quick-add pills under the transcript (tpl 332-335).
///
/// Each appends a labelled scaffold (`Quantity: `) to the request and opens the
/// editor with the caret after it — the app has no structured quantity/brand/
/// budget fields, so this stays plain text the user finishes themselves.
/// A chip leaves the row once used, which is also what makes a double-tap
/// unable to duplicate its fragment.
class TranscriptionQuickAddRow extends StatelessWidget {
  const TranscriptionQuickAddRow({super.key, required this.state});

  /// Stable ids for [TranscriptionState.appliedQuickAdds] — never the localized
  /// label, which changes with the locale.
  static const String quantityId = 'quantity';
  static const String brandId = 'brand';
  static const String budgetId = 'budget';

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = <_QuickAdd>[
      _QuickAdd(
        id: quantityId,
        identifier: TranscriptionKeys.quickAddQuantity,
        label: l10n.transcriptionQuickAddQuantity,
        fragment: l10n.transcriptionQuickAddFragmentQuantity,
      ),
      _QuickAdd(
        id: brandId,
        identifier: TranscriptionKeys.quickAddBrand,
        label: l10n.transcriptionQuickAddBrand,
        fragment: l10n.transcriptionQuickAddFragmentBrand,
      ),
      _QuickAdd(
        id: budgetId,
        identifier: TranscriptionKeys.quickAddBudget,
        label: l10n.transcriptionQuickAddBudget,
        fragment: l10n.transcriptionQuickAddFragmentBudget,
      ),
    ];
    final remaining = entries
        .where((entry) => !state.appliedQuickAdds.contains(entry.id))
        .toList(growable: false);
    if (remaining.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: Spacing.xSmall,
      runSpacing: Spacing.xSmall,
      children: [
        for (final entry in remaining) _QuickAddChip(entry: entry),
      ],
    );
  }
}

@immutable
class _QuickAdd {
  const _QuickAdd({
    required this.id,
    required this.identifier,
    required this.label,
    required this.fragment,
  });

  final String id;
  final String identifier;
  final String label;
  final String fragment;
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({required this.entry});

  final _QuickAdd entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    void apply() => context
        .read<TranscriptionCubit>()
        .applyQuickAdd(entry.id, entry.fragment);
    return Semantics(
      identifier: entry.identifier,
      button: true,
      container: true,
      label: entry.label,
      onTap: apply,
      child: ExcludeSemantics(
        // The kit chip deliberately stays under 48dp; the tap target is the
        // consumer's job (the idiom 09/11/16 already use).
        child: MinTapTarget(
          onTap: apply,
          child: JeebSelectChip(
            role: JeebChipRole.inlineAction,
            label: entry.label,
            // A leading glyph rather than a baked-in '+' so the prefix mirrors
            // to the correct side under RTL for free.
            leading: Icon(
              Icons.add,
              size: Sizes.small,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
