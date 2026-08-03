import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_surface_tone.dart';

/// A radio-group of cancellation reasons.
///
/// Each option is keyboard-navigable and announces its selection state to
/// screen readers (AC4: reason group is keyboard-navigable; selected reason
/// announced).
///
/// redesign-2026-08: the options are the board's single-select row — a white
/// [JeebOutlinedCard] with the 1.5px outline that swaps to a solid navy fill
/// when picked (`JeebCardState.selected`), never a thicker border. Behaviour,
/// order and identifiers are unchanged.
class CancellationReasonGroup extends StatelessWidget {
  const CancellationReasonGroup({
    super.key,
    required this.reasons,
    required this.selectedReason,
    required this.labelOf,
    required this.onChanged,
  });

  /// Gap between two option cards (peer rhythm, not a block break).
  static const double optionSpacing = Spacing.xSmall;

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
            // Cards, unlike the old flush rows, need air between them; the
            // last one carries none so the caller owns the block gap.
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
    // Screen-scoped to the cancellation reason picker; `reason` is the stable
    // backend reason code (e.g. `changed_mind`, `other`), so the id survives
    // i18n/reorder (dynamic-list-item form, mirrors `dispute_reason_<name>`).
    return Semantics(
      identifier: 'cancellation_reason_$reason',
      container: true,
      label: label,
      selected: isSelected,
      button: true,
      child: JeebOutlinedCard(
        state: isSelected ? JeebCardState.selected : JeebCardState.normal,
        onTap: onTap,
        child: _ReasonBody(label: label, isSelected: isSelected),
      ),
    );
  }
}

/// The card's content — a separate widget so it reads the CARD's
/// [JeebSurfaceTone] (navy when selected) rather than the ambient one.
class _ReasonBody extends StatelessWidget {
  const _ReasonBody({required this.label, required this.isSelected});

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
        _ReasonMark(isSelected: isSelected),
      ],
    );
  }
}

/// The Ø22 trailing radio mark, matching the tier row's indicator (07): an
/// empty ring while unpicked, an accent disc with a white check once picked.
/// The kit's own indicator is private to `JeebTierRow`, which takes tier-shaped
/// arguments this screen has none of — hence the local mirror, same geometry.
class _ReasonMark extends StatelessWidget {
  const _ReasonMark({required this.isSelected});

  static const double _size = 22;
  static const double _ringWidth = 2;
  static const double _checkSize = 13;

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!isSelected) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.surfaceContainerHighest,
            width: _ringWidth,
          ),
        ),
      );
    }
    final roles = context.jeebRoles;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(color: roles.accent, shape: BoxShape.circle),
      child: Center(
        child: Icon(Icons.check, size: _checkSize, color: roles.onAccent),
      ),
    );
  }
}
