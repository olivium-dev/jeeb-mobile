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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/cancellation/cancellation_reason_group_preview_test.dart
// ===========================================================================
//
// Widget previews for [CancellationReasonGroup] — run with
// `flutter widget-preview start`.
//
// The group is the radio list on the cancel-a-delivery screen (T-MOB-024). It
// is pure presentation: a `List<String>` of backend reason CODES, the currently
// selected code, a `labelOf` that turns a code into copy, and an `onChanged`.
// It owns no state, no cubit and no repository — **there is nothing to seed and
// no network by construction**, so the guard in [jeebPreviewHost] never has
// anything to reject.
//
// **Every state here is a list, a selection, or a label length.** That is the
// whole contract, and it is exactly where this widget can break:
//
// * the reason list is role-dependent — 4 codes for a client, 5 for a Jeeber —
//   and comes from a `switch` in `CancellationScreen`, not from the widget;
// * selection is drawn ONLY by swapping `Icons.radio_button_unchecked` for
//   `Icons.radio_button_checked` and recolouring that one glyph, so "which
//   option is chosen" lives entirely in a 24 dp icon;
// * `labelOf` is unbounded, and the tile's title `Text` sets no `maxLines` and
//   no `overflow`, so a long label wraps and grows the row.
//
// **Where the copy comes from.** The role states call the same code→ARB
// mapping `_CancellationViewState._label` uses (duplicated below, since it is
// private to the screen), so their AR rendering reviews the shipping Arabic
// rather than English in an RTL box. The long-label state uses fixture copy —
// no ARB reason is long enough to make a tile wrap.
//
// **Taps are live in the canvas.** Each preview seeds its selection and then
// owns it in a [StatefulBuilder], so clicking a row in the canvas moves the
// radio the way the screen's `setState` does. Pumped fresh in a test, each
// preview is deterministically its seeded state.
//
// **What to look at.** The unchecked glyph is `onSurfaceVariant` and the
// checked one is `primary`, so the two readings differ in shape AND colour —
// but the glyph is a raw 24 dp `Icon` that does not grow with the text, so the
// 200% rendering is where the selection indicator shrinks relative to what it
// marks. In AR the tile mirrors (`ListTile` handles that itself), which is what
// the AR/dark card of the matrix states is for.

/// One `ListTile` with a leading icon and a single-line title is 56 dp, so each
/// box below is `56 × rows` plus a little air. The group has no intrinsic
/// height — only the one its row count and its wrapping produce.
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
///
/// Kept exact on purpose: a preview that invented its own labels would review
/// copy the app never shows, and would not notice an ARB key going missing.
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
///
/// That wrapper is not decoration. The group is a bare `Column` with no
/// `mainAxisSize` and no scrolling of its own; dropped straight into the preview
/// host's `Scaffold` it would be laid out against a bounded height and a tall
/// list (or a 200% text scale) would render a red overflow stripe that the real
/// screen never shows. Production scrolls it, so the preview scrolls it.
///
/// [seeded] is the initially selected code; the host then owns the selection so
/// the canvas is clickable. Pass `labels` to override the ARB mapping for the
/// states whose point is a length the ARB has no string for.
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
///
/// This is the widget's real default — `CancellationScreen` starts with
/// `_selectedReason == null` — and it is the state that gates the screen, since
/// the submit button stays disabled until one of these rows is tapped. Every
/// glyph must be `radio_button_unchecked`; a single checked ring here would mean
/// the user is one tap from cancelling a delivery they never chose a reason for.
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
///
/// `_Body` reveals the free-text `cancellation_other_field` only while
/// `selectedReason == 'other'`, so this row is a disclosure control as well as a
/// radio, and it is the LAST row: the field it reveals appears below the fold on
/// a short phone.
///
/// Matrix, because this is where selection has to survive translation and dark
/// mode: the checked ring is `colorScheme.primary` against a plain surface, the
/// tile mirrors in Arabic, and the difference between "chosen" and "not chosen"
/// has to stay legible in all three readings.
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
///
/// Same widget, different role — worth its own preview because the row count and
/// the copy both change, and because `prohibited_item` carries the longest
/// shipping label ("Prohibited item detected"). The selection is seeded on it so
/// the longest real label is also the one drawn in the selected colour.
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
///
/// `OmdsSettingsRow` renders its title as a bare `Text` with no `maxLines` and
/// no `overflow`, so nothing here truncates — the row simply grows, which is
/// safe inside the screen's scroll view and is what this preview confirms. What
/// it is really for is the radio: `ListTile` centres its leading slot, so the
/// 24 dp glyph floats in the middle of a multi-line paragraph rather than
/// aligning with the first line the reader starts on.
///
/// Matrix, because label length is the variable: this is the one state where the
/// EN 200% card and the AR card say something the EN light card cannot.
///
/// Fixture copy — the longest shipping reason is 24 characters, so no ARB string
/// can produce this shape today. A reviewer-authored reason, or a longer
/// translation, can.
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
///
/// `reasons` is a plain `List<String>` with no `assert` and no non-empty
/// precondition, and the screen builds it from a `switch` that a future role (or
/// a server-driven reason list) could leave empty. The group has no empty state
/// of its own: the `for` emits nothing and the `Column` collapses to zero
/// height, so the screen degrades to a prompt asking "Why are you cancelling?"
/// above a blank gap and a permanently disabled submit button.
///
/// It renders no text, so the render suite pins it by absence instead — see the
/// note in the test.
@JeebPreview(
  group: 'cancellation',
  name: 'No reasons · renders nothing',
  size: _cancellationReasonGroupEmptyBox,
)
Widget cancellationReasonGroupEmpty() =>
    _cancellationReasonGroupHosted(reasons: const <String>[]);
