import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/saved_location.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Result returned by [AddEditLocationSheet.show].
class LocationFormResult {
  const LocationFormResult({
    required this.label,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String label;
  final SavedLocationCategory category;
  final double latitude;
  final double longitude;
  final String? address;
}

/// Bottom sheet for adding or editing a saved location (T-MOB-025).
///
/// When [existing] is null, the sheet is in Add mode.
/// When [existing] is non-null, the sheet pre-fills the form and is in
/// Edit mode.
///
/// EXEMPT: OmdsBottomSheet does not expose the form-field layout pattern
/// required here (label text field + category chips + coordinate fields).
/// This sheet uses Flutter's `showModalBottomSheet` with OMDS design tokens
/// throughout (T-MOB-025).
class AddEditLocationSheet extends StatefulWidget {
  const AddEditLocationSheet({super.key, this.existing});

  final SavedLocation? existing;

  static Future<LocationFormResult?> show({
    required BuildContext context,
    required SavedLocation? existing,
  }) {
    return showModalBottomSheet<LocationFormResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      builder: (_) => AddEditLocationSheet(existing: existing),
    );
  }

  @override
  State<AddEditLocationSheet> createState() => _AddEditLocationSheetState();
}

class _AddEditLocationSheetState extends State<AddEditLocationSheet> {
  late SavedLocationCategory _category;
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;

  // Placeholder coordinates — in production a map picker (ofl_geo_capture)
  // would provide these. For this milestone we use a text input as a
  // lightweight stand-in, same pattern as T-MOB-012.
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? SavedLocationCategory.home;
    _labelController = TextEditingController(text: e?.label ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _latController = TextEditingController(
      text: e != null ? e.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: e != null ? e.longitude.toString() : '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _labelController.text.trim().isNotEmpty &&
        double.tryParse(_latController.text.trim()) != null &&
        double.tryParse(_lngController.text.trim()) != null;
  }

  void _onSave(AppLocalizations l10n) {
    if (!_isValid) return;
    final lat = double.parse(_latController.text.trim());
    final lng = double.parse(_lngController.text.trim());
    final address = _addressController.text.trim();
    Navigator.of(context).pop(
      LocationFormResult(
        label: _labelController.text.trim(),
        category: _category,
        latitude: lat,
        longitude: lng,
        address: address.isEmpty ? null : address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHandle(),
              const SizedBox(height: Spacing.medium),
              _SheetTitle(
                text: isEdit
                    ? l10n.savedLocationsEdit
                    : l10n.savedLocationsAddNew,
              ),
              const SizedBox(height: Spacing.medium),
              _CategoryRow(
                selected: _category,
                onSelected: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: Spacing.medium),
              OmdsTextField(
                controller: _labelController,
                labelText: l10n.savedAddressLabelLabel,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.small),
              OmdsTextField(
                controller: _addressController,
                labelText: l10n.savedAddressLineLabel,
              ),
              const SizedBox(height: Spacing.small),
              _CoordinateRow(
                latController: _latController,
                lngController: _lngController,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: Spacing.large),
              _FormActions(
                isSaveEnabled: _isValid,
                onSave: () => _onSave(l10n),
                onCancel: () => Navigator.of(context).pop(),
                saveLabel: isEdit
                    ? l10n.savedLocationsEdit
                    : l10n.savedLocationsAddNew,
                cancelLabel: l10n.actionCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: OmdsBorderRadius.twoXLarge,
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.selected, required this.onSelected});

  final SavedLocationCategory selected;
  final ValueChanged<SavedLocationCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: SavedLocationCategory.values
          .map((cat) => _CategoryChip(
                category: cat,
                label: _label(cat, l10n),
                icon: _icon(cat),
                isSelected: selected == cat,
                onTap: () => onSelected(cat),
              ))
          .toList(growable: false),
    );
  }

  String _label(SavedLocationCategory cat, AppLocalizations l10n) {
    switch (cat) {
      case SavedLocationCategory.home:
        return l10n.savedLocationsChipHome;
      case SavedLocationCategory.work:
        return l10n.savedLocationsChipWork;
      case SavedLocationCategory.other:
        return l10n.savedLocationsChipOther;
    }
  }

  IconData _icon(SavedLocationCategory cat) {
    switch (cat) {
      case SavedLocationCategory.home:
        return Icons.home_rounded;
      case SavedLocationCategory.work:
        return Icons.work_rounded;
      case SavedLocationCategory.other:
        return Icons.place_rounded;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final SavedLocationCategory category;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Spacing.xSmall),
      child: OmdsChip(
        label: label,
        onTap: onTap,
        isSelected: isSelected,
        icon: Icon(icon, size: Sizes.small),
      ),
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({
    required this.latController,
    required this.lngController,
    required this.onChanged,
  });

  final TextEditingController latController;
  final TextEditingController lngController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: OmdsTextField(
            controller: latController,
            labelText: l10n.savedAddressLatitudeLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: OmdsTextField(
            controller: lngController,
            labelText: l10n.savedAddressLongitudeLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.isSaveEnabled,
    required this.onSave,
    required this.onCancel,
    required this.saveLabel,
    required this.cancelLabel,
  });

  final bool isSaveEnabled;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String saveLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OMDSOutlinedButton(
            text: cancelLabel,
            onTap: onCancel,
          ),
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: OmdsPrimaryButton(
            text: saveLabel,
            isEnabled: isSaveEnabled,
            onTap: onSave,
          ),
        ),
      ],
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
// Render tests: test/previews/location/add_edit_location_sheet_preview_test.dart
// ===========================================================================
// Widget previews for [AddEditLocationSheet] — run with
// `flutter widget-preview start`.
//
// The sheet takes exactly one input, [AddEditLocationSheet.existing], and
// derives everything else from it: null means Add mode, non-null means Edit
// mode with the four controllers pre-filled from the [SavedLocation]. There is
// no cubit, no repository and no image, so these previews are network-free by
// construction rather than because [jeebPreviewHost] guards them — the widget
// has nothing to fetch.
//
// Fixtures are the `has_saved_addresses` seam seed already pinned by
// `test/saved_locations_screen_test.dart` (Home / Sassine Square, Ashrafieh —
// Office / Downtown Beirut), so preview and widget test describe the same
// account.
//
// Four things vary, and each preview below exists for one of them:
//
// * **Mode.** Add vs Edit swaps the title and the CTA label, and Add starts
//   with a disabled Save because [_isValid] needs a label plus two parseable
//   doubles.
// * **The category chips.** `_CategoryRow` is a bare [Row] of three
//   [OmdsChip]s with no [Wrap] and no scroll, so its width is fixed copy
//   against a fixed box — see the layout note below.
// * **Field content.** Optional address, a label long enough to fill the
//   field, and the raw `double.toString()` the coordinate fields are seeded
//   with.
// * **The frame.** Production never shows this widget the way the bare
//   previews do; it shows it inside `showModalBottomSheet` with
//   `isScrollControlled: true` and 20 pt top corners. `Modal presentation`
//   renders that real framing through [AddEditLocationSheet.show].
//
// **What the matrix exposes and this file cannot fix** (production code is out
// of scope for a preview). All three are measured at 390 pt wide; the numbers
// come from `flutter test`, whose substitute font is ~1.5x wider per glyph
// than the production face, so read the magnitudes as upper bounds and the
// failures themselves as real:
//
// 1. **The category row overflows before the ceiling.** `_CategoryRow` is a
//    bare `Row` (`add_edit_location_sheet.dart:214`) of three chips with no
//    `Wrap`, no scroll and no `Flexible`, so its width is fixed copy against a
//    350 pt box: it overflows by **39 px at 1.5x** text and **117 px at 2.0x**
//    in English, **158 px at 2.0x** in Arabic. 1.5x is an ordinary Android
//    font-size setting, not the accessibility ceiling.
// 2. **…and RTL hides a different chip than LTR.** Once the row overflows,
//    the run is packed from the left in both directions, so English loses the
//    trailing "Other" chip while Arabic loses the *leading* one — المنزل, the
//    chip that is selected by default. The state the user is currently in is
//    the state Arabic clips first.
// 3. **The CTA label is clipped by its own pill.** `OmdsPrimaryButton` pins
//    `height: Sizes.fourXLarge` (48) while the label wraps freely, so at 2.0x
//    the "Add new location" paragraph asks for **160 pt** of height inside a
//    48 pt box and is cut to its first line (90 pt at 1.5x). The title above
//    it wraps to three lines correctly — only the fixed-height button clips.
//
// One copy problem shows up in every rendering: **the CTA repeats the title
// verbatim.** `_SheetTitle` and the primary button are both fed
// `l10n.savedLocationsAddNew` / `l10n.savedLocationsEdit`, so the sheet says
// "Add new location" twice and a screen reader announces the heading and the
// button identically. The ARB already ships `actionSave` for that slot.

/// Phone width, and tall enough for the whole form at 1.0 text scale.
///
/// The content stack measures 400 pt at 390 pt wide (measured; the production
/// face is a little shorter than the test font), so the box has ~60 pt of
/// headroom and the canvas shows the sheet's own edge rather than a scroll
/// clip. At 200% the same form is 554 pt and the sheet's
/// [SingleChildScrollView] takes over — vertical scrolling is the correct
/// behaviour to review there, not a yellow overflow bar.
const Size _addEditLocationSheetBox = Size(390, 460);

/// Room for the scrim, the backdrop and the sheet's full height.
const Size _addEditLocationSheetModalBox = Size(390, 700);

Widget _addEditLocationSheetHosted(SavedLocation? existing) =>
    AddEditLocationSheet(existing: existing);

/// The `has_saved_addresses` seam's default address, verbatim.
const SavedLocation _addEditLocationSheetSeedHome = SavedLocation(
  id: 'addr-client-001-home',
  label: 'Home',
  latitude: 33.8869,
  longitude: 35.5131,
  category: SavedLocationCategory.home,
  address: 'Sassine Square, Ashrafieh',
  isDefault: true,
);

/// The seam's second address with [SavedLocation.address] dropped — the field
/// is optional on the model and nullable on the wire.
const SavedLocation _addEditLocationSheetOfficeNoAddress = SavedLocation(
  id: 'addr-client-001-office',
  label: 'Office',
  latitude: 33.8938,
  longitude: 35.5018,
  category: SavedLocationCategory.work,
);

/// Longest plausible content: a label a real user types when "Home" and "Work"
/// are already taken, plus a full postal line.
const SavedLocation _addEditLocationSheetLongLabelFixture = SavedLocation(
  id: 'addr-client-001-long',
  label: 'Grandmother building, third entrance behind the pharmacy',
  latitude: 33.8959,
  longitude: 35.4796,
  category: SavedLocationCategory.other,
  address: 'Rue Hamra, Ras Beirut, Beirut Governorate, Lebanon',
);

/// Coordinates as a map picker actually hands them over: full double precision.
const SavedLocation _addEditLocationSheetRawGpsFixture = SavedLocation(
  id: 'addr-client-001-pin',
  label: 'Dropped pin',
  latitude: 33.88691234567891,
  longitude: 35.5130987654321,
  category: SavedLocationCategory.other,
);

/// An Arabic label typed into the English UI — the common case for this app's
/// users, and the one that mixes scripts inside a single LTR field.
const SavedLocation _addEditLocationSheetArabicLabelFixture = SavedLocation(
  id: 'addr-client-001-teta',
  label: 'بيت تيتا',
  latitude: 33.8892,
  longitude: 35.5012,
  category: SavedLocationCategory.other,
  address: 'شارع الحمرا، بيروت',
);

/// Add mode: the sheet as it opens from the "+" on Saved locations.
///
/// Every controller is empty, so this is the only state where `_isValid` is
/// false and the primary CTA is disabled — the sole guard against saving a
/// location with no label or unparseable coordinates. Two things to check that
/// no widget test does: the disabled pill is still legible (it paints
/// `primary` at 45% under a label at 90%, not the washed-out Material default),
/// and the "Home" chip is pre-selected even though the user has chosen nothing.
///
/// This state also shows the duplicated CTA copy at its most confusing: the
/// heading and the disabled button both read "Add new location".
@JeebPreview(group: 'location', name: 'Add · empty', size: _addEditLocationSheetBox)
Widget addEditLocationSheetAddEmpty() => _addEditLocationSheetHosted(null);

/// Edit mode on the seeded default address.
///
/// The happy path, and the reference for everything below: title flips to
/// "Edit location", the Home chip is selected from [SavedLocation.category]
/// rather than the default, and all four fields carry wire values. If the
/// address ever renders in the label field (or vice versa) the controller
/// wiring in `initState` has crossed.
@JeebPreview(group: 'location', name: 'Edit · seeded home', size: _addEditLocationSheetBox)
Widget addEditLocationSheetEditHome() => _addEditLocationSheetHosted(_addEditLocationSheetSeedHome);

/// Edit mode with no address on file.
///
/// `address` is nullable end to end and `_onSave` maps an empty box back to
/// null, so a saved location can round-trip without one. The field must render
/// as a normal empty input with its label resting inside it — not as an error,
/// and not with the literal string "null", which is what a `'${e.address}'`
/// interpolation would produce.
@JeebPreview(group: 'location', name: 'Edit · no address', size: _addEditLocationSheetBox)
Widget addEditLocationSheetNoAddress() => _addEditLocationSheetHosted(_addEditLocationSheetOfficeNoAddress);

/// Layout ceiling: a label longer than the field and a full postal address.
///
/// Both fields are `maxLines: 1`, so the text scrolls inside the box instead of
/// wrapping — check that the box height does not change and that the floating
/// label stays readable above it. It also selects the third chip ("Other"),
/// the one the EN 200% rendering pushes off the end of the category row; the
/// AR 200% rendering keeps "أخرى" and drops the leading chip instead. Neither
/// clip is visible at 1.0, which is exactly why the matrix renders all three.
@JeebPreview(group: 'location', name: 'Edit · long label', size: _addEditLocationSheetBox)
Widget addEditLocationSheetLongLabel() => _addEditLocationSheetHosted(_addEditLocationSheetLongLabelFixture);

/// The coordinate row fed the precision a map picker really produces.
///
/// `initState` seeds these boxes with `e.latitude.toString()`, unformatted, so
/// a pin dropped at 33.88691234567891 puts seventeen characters into a field
/// that is half the sheet wide. The two fields are equal-width [Expanded]s, so
/// this is where the row is tightest — the number must not visually merge with
/// the "Longitude" field beside it, and at 200% text it must not clip the
/// leading digits, which are the only ones that identify the city.
@JeebPreview(group: 'location', name: 'Edit · raw GPS precision', size: _addEditLocationSheetBox)
Widget addEditLocationSheetRawGpsPrecision() => _addEditLocationSheetHosted(_addEditLocationSheetRawGpsFixture);

/// The sheet as the client actually meets it: pushed by
/// [AddEditLocationSheet.show] over the dimmed Saved-locations list.
///
/// The only preview that exercises the production entry point — the scrim, the
/// `Spacing.large` top corners, the bottom anchoring, and `isScrollControlled`,
/// which is what lets the form grow past half the screen instead of being
/// capped at it. Everything above renders a shape production never ships: the
/// bare widget top-aligned on an opaque surface.
///
/// Its fixture carries an Arabic label inside the English UI, the normal case
/// for this app: the field's own text direction should follow the text, while
/// the form around it stays LTR. Tapping Cancel dismisses the sheet — hot
/// restart to bring it back.
@JeebPreview(group: 'location', name: 'Modal presentation · Arabic label', size: _addEditLocationSheetModalBox)
Widget addEditLocationSheetInModalRoute() => Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const _AddEditLocationSheetOverSavedLocations(existing: _addEditLocationSheetArabicLabelFixture),
      ),
    );

/// Opens the sheet through its production entry point on the first frame.
class _AddEditLocationSheetOverSavedLocations extends StatefulWidget {
  const _AddEditLocationSheetOverSavedLocations({required this.existing});

  final SavedLocation? existing;

  @override
  State<_AddEditLocationSheetOverSavedLocations> createState() =>
      _AddEditLocationSheetOverSavedLocationsState();
}

class _AddEditLocationSheetOverSavedLocationsState extends State<_AddEditLocationSheetOverSavedLocations> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because `show()` needs a mounted route to push onto.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    // Returns a LocationFormResult the preview drops on the floor: nothing here
    // may persist, and the production caller is the one that calls the repo.
    await AddEditLocationSheet.show(
      context: context,
      existing: widget.existing,
    );
  }

  @override
  Widget build(BuildContext context) => const _AddEditLocationSheetBackdrop();
}

/// A neutral stand-in for the Saved-locations list behind the sheet — enough
/// shape to judge the scrim against.
///
/// Deliberately text-free, so every string a preview test pins can only have
/// come from the sheet itself.
class _AddEditLocationSheetBackdrop extends StatelessWidget {
  const _AddEditLocationSheetBackdrop();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _row(colors),
            _row(colors),
            _row(colors),
          ],
        ),
      ),
    );
  }

  /// One placeholder address tile.
  Widget _row(ColorScheme colors) => Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
      );
}
