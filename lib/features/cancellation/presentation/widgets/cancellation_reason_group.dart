import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';

/// Radio-group of cancellation reasons (keyboard-navigable, announced to screen readers).
class CancellationReasonGroup extends StatelessWidget {
  const CancellationReasonGroup({
    super.key,
    required this.reasons,
    required this.selectedReason,
    required this.labelOf,
    required this.onChanged,
  });

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
          _ReasonTile(
            reason: reason,
            label: labelOf(reason),
            isSelected: selectedReason == reason,
            onTap: () => onChanged(reason),
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
    final colorScheme = Theme.of(context).colorScheme;
    // Backend reason code for stable identifier across i18n/reorder.
    return Semantics(
      identifier: 'cancellation_reason_$reason',
      container: true,
      label: label,
      selected: isSelected,
      button: true,
      child: OmdsSettingsRow(
        title: label,
        leadingIcon: isSelected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        leadingIconColor: isSelected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
        trailing: const SizedBox.shrink(),
        onTap: onTap,
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// One `ListTile` with a leading icon and a single-line title is 56 dp, so each
/// box below is `56 × rows` plus a little air. The group has no intrinsic
const Size _cancellationReasonGroupClientBox = Size(390, 240);
const Size _cancellationReasonGroupJeeberBox = Size(390, 300);
const Size _cancellationReasonGroupLongLabelBox = Size(390, 280);
const Size _cancellationReasonGroupEmptyBox = Size(390, 120);

/// The client's reason codes, in the order `CancellationScreen._reasons`
/// returns them for `isJeeber: false`.
const List<String> _cancellationReasonGroupClientReasons = <String>[
  'changed_mind',
  'wait_too_long',
  'wrong_address',
  'other',
];

/// The Jeeber's reason codes — a different, longer list for the same widget.
const List<String> _cancellationReasonGroupJeeberReasons = <String>[
  'cannot_complete',
  'vehicle_issue',
  'emergency',
  'prohibited_item',
  'other',
];

/// The screen's own code→copy mapping, duplicated because
/// `_CancellationViewState._label` is private to `cancellation_screen.dart`.
String _cancellationReasonGroupLabel(String reason, AppLocalizations l10n) {
  switch (reason) {
    case 'changed_mind':
      return l10n.cancellationReasonChangedMind;
    case 'wait_too_long':
      return l10n.cancellationReasonWaitTooLong;
    case 'wrong_address':
      return l10n.cancellationReasonWrongAddress;
    case 'cannot_complete':
      return l10n.cancellationReasonCantComplete;
    case 'vehicle_issue':
      return l10n.cancellationReasonVehicleIssue;
    case 'emergency':
      return l10n.cancellationReasonEmergency;
    case 'prohibited_item':
      return l10n.cancellationReasonProhibitedItem;
    default:
      return l10n.cancellationReasonOther;
  }
}

/// Mounts the group the way `CancellationScreen._Body` does: inside a
/// `SingleChildScrollView`, so the tiles grow instead of overflowing.
Widget _cancellationReasonGroupHosted({
  required List<String> reasons,
  String? seeded,
  Map<String, String>? labels,
}) {
  return Builder(
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      String? selected = seeded;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: CancellationReasonGroup(
              reasons: reasons,
              selectedReason: selected,
              labelOf: (String reason) =>
                  labels?[reason] ??
                  _cancellationReasonGroupLabel(reason, l10n),
              onChanged: (String? reason) =>
                  setState(() => selected = reason),
            ),
          );
        },
      );
    },
  );
}

/// The state every client sees on open: four reasons, NOTHING selected.
/// This is the widget's real default — `CancellationScreen` starts with
@JeebPreview(
  group: 'cancellation',
  name: 'Client · nothing selected',
  size: _cancellationReasonGroupClientBox,
)
Widget cancellationReasonGroupClientUnselected() =>
    _cancellationReasonGroupHosted(
      reasons: _cancellationReasonGroupClientReasons,
    );

/// "Other" selected — the one choice that changes the screen around it.
/// `_Body` reveals the free-text `cancellation_other_field` only while
@JeebPreview(
  group: 'cancellation',
  name: 'Client · "Other" selected',
  size: _cancellationReasonGroupClientBox,
  matrix: true,
)
Widget cancellationReasonGroupOtherSelected() => _cancellationReasonGroupHosted(
      reasons: _cancellationReasonGroupClientReasons,
      seeded: 'other',
    );

/// The Jeeber's list: five codes, none shared with the client's four except
/// `other`.
@JeebPreview(
  group: 'cancellation',
  name: 'Jeeber · prohibited item selected',
  size: _cancellationReasonGroupJeeberBox,
)
Widget cancellationReasonGroupJeeber() => _cancellationReasonGroupHosted(
      reasons: _cancellationReasonGroupJeeberReasons,
      seeded: 'prohibited_item',
    );

/// The wrapping ceiling: a label long enough to take several lines.
/// `OmdsSettingsRow` renders its title as a bare `Text` with no `maxLines` and
@JeebPreview(
  group: 'cancellation',
  name: 'Long label · wraps to several lines',
  size: _cancellationReasonGroupLongLabelBox,
  matrix: true,
)
Widget cancellationReasonGroupLongLabel() => _cancellationReasonGroupHosted(
      reasons: const <String>['prohibited_item', 'other'],
      seeded: 'prohibited_item',
      labels: const <String, String>{
        'prohibited_item':
            'The package contains items I am not allowed to carry, such as '
                'flammable liquids, medication or anything the courier terms '
                'list as prohibited',
        'other': 'Something else, described below',
      },
    );

/// No reasons at all — the shape the type permits and nothing forbids.
/// `reasons` is a plain `List<String>` with no `assert` and no non-empty
@JeebPreview(
  group: 'cancellation',
  name: 'No reasons · renders nothing',
  size: _cancellationReasonGroupEmptyBox,
)
Widget cancellationReasonGroupEmpty() =>
    _cancellationReasonGroupHosted(reasons: const <String>[]);
