import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';

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
const Size _clientLocationAddRowRowBox = Size(390, 96);

/// A taller box for the states that stack something under the row (the locked
/// specimen's caption), which is what actually needs the extra height — the row
const Size _clientLocationAddRowTallRowBox = Size(390, 160);

/// A small-phone box (320dp class device), where the label loses the most
/// width to the fixed 48dp button.
const Size _clientLocationAddRowNarrowBox = Size(320, 120);

/// The contract id the live location-select screen passes (63_W1_TEST_PLAN
/// §2.3). The widget's own default is the legacy `client_location_add_new`.
const String _clientLocationAddRowSelectId = 'location_select_new_location_cta';

/// One row, wired the way the screen wires it.
/// [label] is a callback over [AppLocalizations] so a state can either take the
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

@JeebPreview(group: 'location', name: 'Localized default', size: _clientLocationAddRowRowBox)
Widget clientLocationAddRowDefault() =>
    _clientLocationAddRowHosted(label: (AppLocalizations l10n) => l10n.clientLocationNewOption);

@JeebPreview(group: 'location', name: 'Long label truncates', size: _clientLocationAddRowRowBox)
Widget clientLocationAddRowLongLabel() => _clientLocationAddRowHosted(
      label: (AppLocalizations _) => clientLocationAddRowLongLabelText,
      width: 390,
    );

/// The English label used by [clientLocationAddRowLongLabel]. Exported so the
/// render test can pin the exact string it truncates.
const String clientLocationAddRowLongLabelText =
    'Add a new pickup or drop-off location to your saved places';

@JeebPreview(group: 'location', name: 'Long Arabic label truncates', size: _clientLocationAddRowRowBox)
Widget clientLocationAddRowLongArabicLabel() => _clientLocationAddRowHosted(
      label: (AppLocalizations _) => clientLocationAddRowLongArabicLabelText,
      width: 390,
    );

/// The Arabic label used by [clientLocationAddRowLongArabicLabel] — a verbose
/// translation of [clientLocationAddRowLongLabelText].
const String clientLocationAddRowLongArabicLabelText =
    'إضافة موقع استلام أو تسليم جديد إلى قائمة أماكنك المحفوظة';

@JeebPreview(group: 'location', name: 'Narrow phone · 320dp', size: _clientLocationAddRowNarrowBox)
Widget clientLocationAddRowNarrowPhone() => _clientLocationAddRowHosted(
      label: (AppLocalizations _) => 'Add another delivery location',
      width: 288,
    );

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
