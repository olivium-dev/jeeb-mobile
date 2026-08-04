import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_surface_tone.dart';

/// A radio-group of cancellation reasons: keyboard-navigable rows that announce
/// their selection state (AC4).
///
/// MIDNIGHT · M3-04 — R9's stacked single-select rows, minus its orange. The
/// picked row is the kit's neutral fill swap and the picked mark is the
/// destructive `onErrorContainer`, not R9's tile-drawn accent disc.
class CancellationReasonGroup extends StatelessWidget {
  const CancellationReasonGroup({
    super.key,
    required this.reasons,
    required this.selectedReason,
    required this.labelOf,
    required this.onChanged,
  });

  /// Gap between two option cards — R9's board list gap is 9; 8 is the token.
  static const double optionSpacing = Spacing.xSmall;

  /// Ø22 trailing mark, matching `JeebTierRow.indicatorSize`.
  static const double markSize = 22;

  /// 2px ring on the unpicked mark, matching R9's indicator.
  static const double markRingWidth = 2;

  /// Glyph inside the picked disc.
  static const double markCheckSize = 13;

  /// Test handle for one row's trailing mark.
  static Key markKey(String reason) =>
      ValueKey<String>('cancellation-mark-$reason');

  final List<String> reasons;
  final String? selectedReason;
  final String Function(String reason) labelOf;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reason in reasons)
          Padding(
            padding: EdgeInsetsDirectional.only(
              bottom: reason == reasons.last ? 0 : optionSpacing,
            ),
            child: _ReasonTile(
              reason: reason,
              label: labelOf(reason),
              isSelected: selectedReason == reason,
              onTap: () => onChanged(reason),
            ),
          ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String reason;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Screen-scoped id; `reason` is the stable backend code, so it survives
    // i18n/reorder (dynamic-list-item form, mirrors `dispute_reason_<name>`).
    return Semantics(
      identifier: 'cancellation_reason_$reason',
      container: true,
      label: label,
      selected: isSelected,
      button: true,
      child: JeebOutlinedCard(
        // `selected`, never `accentSelected`: the lit orange form is R9's
        // tile-drawn affirmative and this screen has no tile to earn it.
        state: isSelected ? JeebCardState.selected : JeebCardState.normal,
        onTap: onTap,
        child: _ReasonBody(
          reason: reason,
          label: label,
          isSelected: isSelected,
        ),
      ),
    );
  }
}

/// The card's content — a separate widget so it reads the CARD's
/// [JeebSurfaceTone] (emphasis glass when selected) rather than the ambient one.
class _ReasonBody extends StatelessWidget {
  const _ReasonBody({
    required this.reason,
    required this.label,
    required this.isSelected,
  });

  final String reason;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final tone = JeebSurfaceTone.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.jeebText.cardTitle.copyWith(color: tone.titleInk),
          ),
        ),
        const SizedBox(width: Spacing.small),
        _ReasonMark(
          key: CancellationReasonGroup.markKey(reason),
          isSelected: isSelected,
        ),
      ],
    );
  }
}

/// The Ø22 trailing mark: a `glassBorderVivid` ring while unpicked, a
/// danger-soft disc with a navy check once picked. `JeebTierRow`'s own
/// indicator is private and takes tier-shaped arguments this screen has none of.
class _ReasonMark extends StatelessWidget {
  const _ReasonMark({super.key, required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!isSelected) {
      final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
          JeebSemanticColors.midnight();
      return Container(
        width: CancellationReasonGroup.markSize,
        height: CancellationReasonGroup.markSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: semantics.glassBorderVivid,
            width: CancellationReasonGroup.markRingWidth,
          ),
        ),
      );
    }
    return Container(
      width: CancellationReasonGroup.markSize,
      height: CancellationReasonGroup.markSize,
      decoration: BoxDecoration(
        color: scheme.onErrorContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.check,
          size: CancellationReasonGroup.markCheckSize,
          color: scheme.onError,
        ),
      ),
    );
  }
}
