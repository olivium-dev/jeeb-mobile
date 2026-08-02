/// Widget previews for [SelectableRadioGlyph] — run with
/// `flutter widget-preview start`.
///
/// The glyph is a pure function of two arguments — a `selected` flag and an
/// optional `ring` colour. It owns no state, no cubit and no repository, so
/// every preview below is a plain constructor call: network-free by
/// construction, not just by the guard in [jeebPreviewHost].
///
/// Two things about the widget shape this file:
///
/// * **It renders no text of its own.** A canvas of near-identical 24dp circles
///   is unreadable, and — worse — a render test could not tell one preview from
///   another, which is the exact failure `expectedText` exists to catch. So each
///   preview is a *specimen*: the glyph on the surround the state calls for,
///   plus a caption naming the state. The caption is preview chrome, not part of
///   the component; it is deliberately `labelSmall` / `onSurfaceVariant` so it
///   never reads as the glyph's own label. This follows
///   `lib/previews/customer_profile/customer_profile_icon_disc_preview.dart`.
/// * **The glyph cannot see the surface it is drawn on, but its default colour
///   assumes one.** `selected` picks `onPrimary`; that role is only legible over
///   `primary`. Both production callers ([RequestTierCard] and
///   `ClientLocationOptionCard`) flip their card fill to `primary` in the same
///   breath as they pass `selected: true`, so the assumption holds today by
///   coincidence of call site, not by anything the widget enforces. The two
///   `on surface` specimens below are that coupling, made visible.
///
/// Measured while writing these (both real app themes, `AppTheme.light()` /
/// `AppTheme.dark()`):
///
///   * **Geometry is fixed and text-scale-blind**: a `Sizes.xLarge` (24dp)
///     square holding a `Sizes.threeXSmall` (2dp) ring and, when selected, a
///     `Spacing.small` (12dp) dot. None of the three is a scaled token and
///     nothing here opts into `applyTextScaling`, so at 200% text the glyph is
///     still 24dp next to copy that has doubled — see the last specimen.
///   * **On its intended fill the glyph is comfortable**: unselected navy ring
///     on the white card measures 17.13:1 light / 10.85:1 dark; the selected
///     white ring on the navy card measures 17.13:1 light / 7.70:1 dark.
///   * **On the wrong fill it disappears entirely**: `selected: true` over
///     `surface` puts `onPrimary` on `surface`, which is white-on-white —
///     **1.00:1** in the light scheme and **1.41:1** in the dark one, both far
///     under the 3:1 WCAG 1.4.11 floor for a graphical object.
///   * **RTL is a non-event** — the glyph is a concentric circle with no
///     directional padding, so it is byte-identical mirrored. What RTL *does*
///     move is the glyph's position within its host row, which is asserted over
///     in `test/previews/location/client_location_option_card_preview_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/request_type/presentation/request_tier_card.dart';
import '../../features/request_type/presentation/selectable_radio_glyph.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// Specimen box for a single glyph: the glyph is 24dp square, so this is a
/// short, wide box with enough height for the caption to double in the
/// 200%-text rendering without clipping the evidence.
const Size _specimenBox = Size(340, 150);

/// Wider box for the specimen that shows both states at once.
const Size _stripBox = Size(390, 190);

/// Taller box for the in-situ specimen: a whole tier card, which at 200% text
/// grows to roughly twice the height it has at 1x.
const Size _cardBox = Size(390, 300);

/// One specimen: [sample] — the glyph in whatever surround the state calls for
/// — with a caption naming the state underneath it.
Widget _hosted({required String caption, required Widget sample}) {
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
///
/// [fill] and [glyph] both receive the ambient [ColorScheme] so a specimen can
/// state its fill and its ring in the same vocabulary the widget uses, and both
/// follow the canvas cell's brightness. `outlined: true` adds the
/// `outlineVariant` hairline the real cards draw around their unselected state —
/// without it a `surface` swatch is invisible against a `surface` page and there
/// is no way to see where the glyph is supposed to be.
Widget _onCard({
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
///
/// A 2dp `primary` ring and nothing inside it, on the white `surface` fill both
/// callers use for an unselected card — 17.13:1 light, 10.85:1 dark. This is the
/// baseline reading; everything else in this file is a departure from it.
@JeebPreview(group: 'request_type', name: 'Unselected on its card', size: _specimenBox)
Widget selectableRadioGlyphUnselected() => _hosted(
  caption: 'Unselected on its card',
  sample: _onCard(
    fill: (ColorScheme scheme) => scheme.surface,
    outlined: true,
    glyph: (_) => const SelectableRadioGlyph(selected: false),
  ),
);

/// The chosen state, on the only fill its default colour is valid over.
///
/// `selected: true` resolves ring and dot to `onPrimary`, and the card under it
/// has flipped to `primary` — 17.13:1 light, 7.70:1 dark. Read this against the
/// next specimen: the widget is identical in both, and only the fill changed.
@JeebPreview(group: 'request_type', name: 'Selected on its navy card', size: _specimenBox)
Widget selectableRadioGlyphSelected() => _hosted(
  caption: 'Selected on its navy card',
  sample: _onCard(
    fill: (ColorScheme scheme) => scheme.primary,
    glyph: (_) => const SelectableRadioGlyph(selected: true),
  ),
);

/// The state that costs the glyph its existence: selected, but not on `primary`.
///
/// `SelectableRadioGlyph(selected: true)` with no `ring` is a complete, legal
/// call — nothing in the constructor, the analyzer or the type system says it
/// needs a navy surface. Drawn over `surface` it is `onPrimary` on `surface`:
/// **1.00:1** in the light scheme (pure white on pure white — the EN light
/// rendering of this specimen shows an empty card) and **1.41:1** in the dark
/// one, both under the 3:1 WCAG 1.4.11 floor for graphical objects.
///
/// This is not a hypothetical shape. It is what any third caller gets by
/// default: a selected radio on a card that did not also change colour — a
/// checklist, a settings row, a filter sheet. The `outlineVariant` hairline is
/// preview chrome; it is the only thing marking where the glyph should be.
@JeebPreview(group: 'request_type', name: 'Selected on surface · vanishes', size: _specimenBox)
Widget selectableRadioGlyphSelectedOnSurface() => _hosted(
  caption: 'Selected on surface · vanishes',
  sample: _onCard(
    fill: (ColorScheme scheme) => scheme.surface,
    outlined: true,
    glyph: (_) => const SelectableRadioGlyph(selected: true),
  ),
);

/// The same call, rescued by the `ring` escape hatch — the control for the
/// specimen above.
///
/// Identical fill, identical `selected: true`, one added argument:
/// `ring: scheme.primary`. The glyph reappears at 17.13:1. This is what a caller
/// has to know to do, and the pair of specimens is the argument for making the
/// widget derive it instead — from `onPrimary`/`primary` chosen against the
/// ambient surface rather than from `selected` alone.
///
/// Nothing here changes production: `ring` is an existing public parameter, and
/// `ClientLocationOptionCard` already routes its own `foreground` through it.
@JeebPreview(group: 'request_type', name: 'Selected on surface · ring override', size: _specimenBox)
Widget selectableRadioGlyphRingOverride() => _hosted(
  caption: 'Selected on surface · ring override',
  sample: _onCard(
    fill: (ColorScheme scheme) => scheme.surface,
    outlined: true,
    glyph: (ColorScheme scheme) =>
        SelectableRadioGlyph(selected: true, ring: scheme.primary),
  ),
);

/// Both states side by side, each on the fill its own card really uses.
///
/// A radio only means anything next to its siblings: the review question is not
/// "is this circle fine" but "does the filled one read as chosen and the empty
/// one as choosable". A single specimen cannot answer that, and neither can the
/// widget's own tests, which never render two.
///
/// It also shows what the selected state costs: the ring is 2dp and the dot is
/// 12dp inside a 20dp inner circle, so the gap between them is 4dp. At a glance
/// on a small screen the selected glyph reads closer to a filled disc than to a
/// ring-plus-dot.
@JeebPreview(group: 'request_type', name: 'Both states, real fills', size: _stripBox)
Widget selectableRadioGlyphBothStates() => _hosted(
  caption: 'Both states, real fills',
  sample: Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      _onCard(
        fill: (ColorScheme scheme) => scheme.surface,
        outlined: true,
        glyph: (_) => const SelectableRadioGlyph(selected: false),
      ),
      const SizedBox(width: Spacing.medium),
      _onCard(
        fill: (ColorScheme scheme) => scheme.primary,
        glyph: (_) => const SelectableRadioGlyph(selected: true),
      ),
    ],
  ),
);

/// The glyph at its true production proportions, inside a real [RequestTierCard].
///
/// The card takes only plain arguments — no cubit, no repository — so mounting
/// the real one costs nothing and is more honest than a reproduction of its
/// layout. The copy is the live localized Flash tier strings, so the AR
/// rendering carries "فوري" rather than an English placeholder.
///
/// This specimen exists for its **EN 200% text** rendering. `Sizes.xLarge`,
/// `Sizes.threeXSmall` and `Spacing.small` are all fixed tokens and neither
/// [Container] nor [SizedBox] opts into text scaling, so the copy block roughly
/// doubles while the glyph stays exactly 24dp. Nothing clips — the card grows —
/// but the trailing column stops reading as a control and becomes a dot beside
/// the text, which is the state a low-vision user has to hit accurately.
@JeebPreview(group: 'request_type', name: 'In a real tier card', size: _cardBox)
Widget selectableRadioGlyphInTierCard() => _hosted(
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
          onTap: _noop,
          semanticIdentifier: 'preview_selectable_radio_glyph_tier',
          semanticLabel: l10n.tierFlashTitle,
          selectedHint: l10n.requestTypeTierSelectedHint,
        ),
      );
    },
  ),
);

void _noop() {}
