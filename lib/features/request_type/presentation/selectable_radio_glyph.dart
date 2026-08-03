import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../l10n/app_localizations.dart';
import 'request_tier_card.dart';

/// Decorative single-choice radio glyph used by delivery-create cards.
/// No OMDS radio primitive in catalog; draws ring + filled dot from colorScheme roles.
/// Pointer events owned by host card's InkWell (pure visual, no gesture handling).
class SelectableRadioGlyph extends StatelessWidget {
  const SelectableRadioGlyph({super.key, required this.selected, this.ring});

  final bool selected;

  /// Optional explicit ring colour. Defaults to onPrimary when selected, else primary.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ring ?? (selected ? scheme.onPrimary : scheme.primary);
    return SizedBox.square(
      dimension: Sizes.xLarge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Ring(color: color),
          if (selected) _Dot(color: color),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: Sizes.threeXSmall),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Spacing.small,
      height: Spacing.small,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

// Widget previews for [SelectableRadioGlyph] — run with

/// Specimen box for a single glyph: the glyph is 24dp square, so this is a
/// short, wide box with enough height for the caption to double in the
const Size _selectableRadioGlyphSpecimenBox = Size(340, 150);

/// Wider box for the specimen that shows both states at once.
const Size _selectableRadioGlyphStripBox = Size(390, 190);

/// Taller box for the in-situ specimen: a whole tier card, which at 200% text
/// grows to roughly twice the height it has at 1x.
const Size _selectableRadioGlyphCardBox = Size(390, 300);

/// One specimen: [sample] — the glyph in whatever surround the state calls for
/// — with a caption naming the state underneath it.
Widget _selectableRadioGlyphHosted({
  required String caption,
  required Widget sample,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            sample,
            const SizedBox(height: Spacing.xSmall),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.small),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The card-shaped surround the glyph is always drawn on in production, reduced
/// to the part that decides whether the glyph is visible: the fill.
Widget _selectableRadioGlyphOnCard({
  required Color Function(ColorScheme scheme) fill,
  required Widget Function(ColorScheme scheme) glyph,
  bool outlined = false,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: fill(scheme),
          borderRadius: OmdsBorderRadius.uiLarge,
          border: outlined ? Border.all(color: scheme.outlineVariant) : null,
        ),
        child: glyph(scheme),
      );
    },
  );
}

/// The resting state: an option the user has not chosen.
/// A 2dp `primary` ring and nothing inside it, on the white `surface` fill both
@JeebPreview(
  group: 'request_type',
  name: 'Unselected on its card',
  size: _selectableRadioGlyphSpecimenBox,
)
Widget selectableRadioGlyphUnselected() => _selectableRadioGlyphHosted(
      caption: 'Unselected on its card',
      sample: _selectableRadioGlyphOnCard(
        fill: (ColorScheme scheme) => scheme.surface,
        outlined: true,
        glyph: (_) => const SelectableRadioGlyph(selected: false),
      ),
    );

/// The chosen state, on the only fill its default colour is valid over.
/// `selected: true` resolves ring and dot to `onPrimary`, and the card under it
@JeebPreview(
  group: 'request_type',
  name: 'Selected on its navy card',
  size: _selectableRadioGlyphSpecimenBox,
)
Widget selectableRadioGlyphSelected() => _selectableRadioGlyphHosted(
      caption: 'Selected on its navy card',
      sample: _selectableRadioGlyphOnCard(
        fill: (ColorScheme scheme) => scheme.primary,
        glyph: (_) => const SelectableRadioGlyph(selected: true),
      ),
    );

/// The state that costs the glyph its existence: selected, but not on `primary`.
/// `SelectableRadioGlyph(selected: true)` with no `ring` is a complete, legal
@JeebPreview(
  group: 'request_type',
  name: 'Selected on surface · vanishes',
  size: _selectableRadioGlyphSpecimenBox,
)
Widget selectableRadioGlyphSelectedOnSurface() => _selectableRadioGlyphHosted(
      caption: 'Selected on surface · vanishes',
      sample: _selectableRadioGlyphOnCard(
        fill: (ColorScheme scheme) => scheme.surface,
        outlined: true,
        glyph: (_) => const SelectableRadioGlyph(selected: true),
      ),
    );

/// The same call, rescued by the `ring` escape hatch — the control for the
/// specimen above.
@JeebPreview(
  group: 'request_type',
  name: 'Selected on surface · ring override',
  size: _selectableRadioGlyphSpecimenBox,
)
Widget selectableRadioGlyphRingOverride() => _selectableRadioGlyphHosted(
      caption: 'Selected on surface · ring override',
      sample: _selectableRadioGlyphOnCard(
        fill: (ColorScheme scheme) => scheme.surface,
        outlined: true,
        glyph: (ColorScheme scheme) =>
            SelectableRadioGlyph(selected: true, ring: scheme.primary),
      ),
    );

/// Both states side by side, each on the fill its own card really uses.
/// A radio only means anything next to its siblings: the review question is not
@JeebPreview(
  group: 'request_type',
  name: 'Both states, real fills',
  size: _selectableRadioGlyphStripBox,
)
Widget selectableRadioGlyphBothStates() => _selectableRadioGlyphHosted(
      caption: 'Both states, real fills',
      sample: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _selectableRadioGlyphOnCard(
            fill: (ColorScheme scheme) => scheme.surface,
            outlined: true,
            glyph: (_) => const SelectableRadioGlyph(selected: false),
          ),
          const SizedBox(width: Spacing.medium),
          _selectableRadioGlyphOnCard(
            fill: (ColorScheme scheme) => scheme.primary,
            glyph: (_) => const SelectableRadioGlyph(selected: true),
          ),
        ],
      ),
    );

/// The glyph at its true production proportions, inside a real [RequestTierCard].
/// The card takes only plain arguments — no cubit, no repository — so mounting
@JeebPreview(
  group: 'request_type',
  name: 'In a real tier card',
  size: _selectableRadioGlyphCardBox,
)
Widget selectableRadioGlyphInTierCard() => _selectableRadioGlyphHosted(
      caption: 'In a real tier card',
      sample: Builder(
        builder: (BuildContext context) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
            child: RequestTierCard(
              icon: Icons.bolt_outlined,
              title: l10n.tierFlashTitle,
              speed: l10n.tierFlashSpeed,
              value: l10n.tierFlashValue,
              selected: false,
              onTap: _selectableRadioGlyphNoop,
              semanticIdentifier: 'preview_selectable_radio_glyph_tier',
              semanticLabel: l10n.tierFlashTitle,
              selectedHint: l10n.requestTypeTierSelectedHint,
            ),
          );
        },
      ),
    );

void _selectableRadioGlyphNoop() {}
