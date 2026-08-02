import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';

/// "New Location" row on the Client Location screen (Figma 56539:1444): a
/// start-aligned label and a trailing circular navy add button. The whole row
/// is the tap target (mirrors the card behaviour); the circular button is a
/// navy filled circle with a peach-tinted "+" in Figma — here the glyph is
/// `onPrimary` on the navy circle (token-driven, see comparison.md).
class ClientLocationAddRow extends StatelessWidget {
  const ClientLocationAddRow({
    super.key,
    required this.label,
    required this.addSemanticLabel,
    required this.onTap,
    this.identifier = 'client_location_add_new',
  });

  final String label;
  final String addSemanticLabel;
  final VoidCallback onTap;

  /// Semantics identifier for the row. Defaults to the legacy
  /// `client_location_add_new` (kept for the existing delivery-create tests);
  /// the JM-024 location-select screen passes `location_select_new_location_cta`
  /// (63_W1_TEST_PLAN §2.3).
  final String identifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      label: addSemanticLabel,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: OmdsBorderRadius.uiMedium,
          onTap: onTap,
          child: _RowContent(label: label, onTap: onTap),
        ),
      ),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.primary);
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(vertical: Spacing.xSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: Spacing.medium),
          _AddButton(onTap: onTap),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: Sizes.fourXLarge,
      child: Center(
        child: Container(
          width: Sizes.threeXLarge,
          height: Sizes.threeXLarge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
          ),
          child: Icon(
            Icons.add,
            size: Sizes.xLarge,
            color: scheme.onPrimary,
          ),
        ),
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
// Render tests: test/previews/location/client_location_add_row_preview_test.dart
// ===========================================================================
// Widget previews for [ClientLocationAddRow] — run with
// `flutter widget-preview start`.
//
// The row takes no state: a `label`, an `addSemanticLabel`, a semantics
// `identifier` and a tap callback. There is no cubit and no repository to
// stub, so every state below is network-free by construction — the only input
// that can change what it renders is the string it is handed.
//
// That is exactly why the states worth reviewing are string-shaped. The live
// caller (`ClientLocationScreen`, JM-024 §2.3) passes
// `l10n.clientLocationNewOption` / `l10n.clientLocationAddSemantic`, so the
// default preview resolves both from the ambient [AppLocalizations] rather
// than hardcoding English: the AR RTL rendering then exercises the real
// "موقع جديد", not a placeholder, and the whole row has to mirror around a
// 48dp trailing button.
//
// Two things these previews surface, both in the widget and neither fixed
// here:
//
// * The label is **single-line by construction, and truncates rather than
//   wraps**. `Text(..., overflow: TextOverflow.ellipsis)` is passed without
//   `maxLines`, which does not mean "wrap, then ellipsize": an ellipsis with
//   no line limit truncates the paragraph at the first line. Measured at phone
//   width the label gets 326dp and clips there, so a long label loses its tail
//   instead of growing the row — see [clientLocationAddRowLongLabel]. Combined
//   with the fixed 64dp trailing button that is worst at 200% text on a 320dp
//   phone, where the row's only affordance text is what gets cut
//   ([clientLocationAddRowNarrowPhone]).
// * The `+` circle is `Sizes.threeXLarge` (40dp) centred in a
//   `Sizes.fourXLarge` (48dp) box, so the glyph meets the tap-target minimum
//   only because the whole row — not the circle — is the [InkWell].

/// The canvas box for one nav row on a phone: full width, one row tall.
const Size _clientLocationAddRowRowBox = Size(390, 96);

/// A taller box for the states that stack something under the row (the locked
/// specimen's caption), which is what actually needs the extra height — the row
/// itself stays 64dp even at 200% text, because the label never wraps.
const Size _clientLocationAddRowTallRowBox = Size(390, 160);

/// A small-phone box (320dp class device), where the label loses the most
/// width to the fixed 48dp button.
const Size _clientLocationAddRowNarrowBox = Size(320, 120);

/// The contract id the live location-select screen passes (63_W1_TEST_PLAN
/// §2.3). The widget's own default is the legacy `client_location_add_new`.
const String _clientLocationAddRowSelectId = 'location_select_new_location_cta';

/// One row, wired the way the screen wires it.
///
/// [label] is a callback over [AppLocalizations] so a state can either take the
/// real translated string (which changes per rendering) or pin a literal it
/// wants to stress-test. The accessibility label always comes from the ARB —
/// it is the only string a screen-reader user hears here, because the visible
/// label sits under an [ExcludeSemantics].
Widget _clientLocationAddRowHosted({
  required String Function(AppLocalizations l10n) label,
  double? width,
}) {
  return Builder(
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      final Widget row = ClientLocationAddRow(
        identifier: _clientLocationAddRowSelectId,
        label: label(l10n),
        addSemanticLabel: l10n.clientLocationAddSemantic,
        onTap: () {},
      );
      if (width == null) return row;
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: width, child: row),
      );
    },
  );
}

/// The live state: the label and the a11y label both resolved from the ARB.
///
/// This is the only preview whose text changes between the EN and AR
/// renderings ("New Location" / "موقع جديد"), which makes it the one that would
/// catch a caller regressing to a hardcoded English literal. The AR rendering
/// is also the mirroring check: the label must sit at the start edge (the right
/// in Arabic) with the navy `+` circle at the far left.
@JeebPreview(group: 'location', name: 'Localized default', size: _clientLocationAddRowRowBox)
Widget clientLocationAddRowDefault() =>
    _clientLocationAddRowHosted(label: (AppLocalizations l10n) => l10n.clientLocationNewOption);

/// The overflow ceiling for English: a label wider than the row.
///
/// The row does NOT grow — it truncates. `TextOverflow.ellipsis` with no
/// `maxLines` caps the paragraph at one line, so the label is clipped to the
/// 326dp it is given and the tail is replaced by "…". Whether that is
/// acceptable is a product call (it is a nav row, and the `+` is the real
/// affordance), but it means any translation of `clientLocationNewOption` wider
/// than that 326dp silently loses its end rather than reflowing — and the
/// budget shrinks with screen width and grows with text scale.
///
/// Pinned to phone width for the same reason as the narrow state: a widget test
/// pumps an 800dp surface, where this label fits outright and the truncation
/// disappears.
@JeebPreview(group: 'location', name: 'Long label truncates', size: _clientLocationAddRowRowBox)
Widget clientLocationAddRowLongLabel() => _clientLocationAddRowHosted(
      label: (AppLocalizations _) => clientLocationAddRowLongLabelText,
      width: 390,
    );

/// The English label used by [clientLocationAddRowLongLabel]. Exported so the
/// render test can pin the exact string it truncates.
const String clientLocationAddRowLongLabelText =
    'Add a new pickup or drop-off location to your saved places';

/// The same overflow ceiling, but in Arabic script.
///
/// A long English literal rendered in the AR canvas proves nothing about
/// Arabic — the glyphs, the shaping and the truncation point are all different,
/// and an RTL string clips at its own start-side end. This state hands the row
/// a verbose Arabic label so the AR RTL rendering truncates *Arabic*, and so
/// the EN light rendering shows what an RTL string does inside an LTR row (it
/// must still hug the left edge and leave the `+` at the right).
@JeebPreview(group: 'location', name: 'Long Arabic label truncates', size: _clientLocationAddRowRowBox)
Widget clientLocationAddRowLongArabicLabel() => _clientLocationAddRowHosted(
      label: (AppLocalizations _) => clientLocationAddRowLongArabicLabelText,
      width: 390,
    );

/// The Arabic label used by [clientLocationAddRowLongArabicLabel] — a verbose
/// translation of [clientLocationAddRowLongLabelText].
const String clientLocationAddRowLongArabicLabelText =
    'إضافة موقع استلام أو تسليم جديد إلى قائمة أماكنك المحفوظة';

/// A 320dp-class phone, at the screen's real gutters (16dp each side → 288dp
/// of row).
///
/// The `+` button is a fixed 48dp box plus a 16dp gap regardless of text scale,
/// so the label keeps whatever is left — 224dp here versus 326dp on a 390dp
/// phone. This is the state where the **EN 200% text** rendering matters most:
/// the label cannot reflow, so at 2x on this width it is the row's only
/// affordance text that gets cut. Pinned with an explicit [SizedBox] so the
/// state reproduces in a widget test (which pumps an 800dp surface) and not
/// just on the canvas.
@JeebPreview(group: 'location', name: 'Narrow phone · 320dp', size: _clientLocationAddRowNarrowBox)
Widget clientLocationAddRowNarrowPhone() => _clientLocationAddRowHosted(
      label: (AppLocalizations _) => 'Add another delivery location',
      width: 288,
    );

/// B-02b: the row while an order create is in flight.
///
/// `ClientLocationScreen` wraps this row in a private `_SubmitLock` that
/// applies `IgnorePointer` + `Opacity(UIConstants.opacityDisabled)` while the
/// create is submitting — a real, reachable, user-visible state of this row
/// that the widget itself has no parameter for. Reproduced here with the same
/// token so the dimmed navy circle can be reviewed for contrast, which is where
/// it is worst: 50% opacity navy on the dark surface of the AR RTL rendering.
///
/// The caption is what distinguishes this preview from the default one in the
/// render test — dimmed or not, the row still says "New Location".
@JeebPreview(group: 'location', name: 'Locked · create in flight', size: _clientLocationAddRowTallRowBox)
Widget clientLocationAddRowLocked() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const IgnorePointer(
          child: Opacity(
            opacity: UIConstants.opacityDisabled,
            child: _ClientLocationAddRowLockedRow(),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Builder(
          builder: (BuildContext context) => Text(
            'Locked · create in flight',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );

/// The row as [clientLocationAddRowLocked] dims it. A widget rather than a call
/// to `_clientLocationAddRowHosted` so the `Opacity` above it can stay `const`.
class _ClientLocationAddRowLockedRow extends StatelessWidget {
  const _ClientLocationAddRowLockedRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ClientLocationAddRow(
      identifier: _clientLocationAddRowSelectId,
      label: l10n.clientLocationNewOption,
      addSemanticLabel: l10n.clientLocationAddSemantic,
      onTap: () {},
    );
  }
}
