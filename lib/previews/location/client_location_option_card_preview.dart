/// Widget previews for [ClientLocationOptionCard] — run with
/// `flutter widget-preview start`.
///
/// The card takes three inputs and nothing else: a `label` string, a `selected`
/// flag and an `onTap`. There is no cubit, no repository and no async work
/// behind it, so every state below is network-free by construction rather than
/// by the guard in [jeebPreviewHost].
///
/// Production drives exactly two of these states — `selected: false/true` on
/// the "Current Location" option, via `CurrentLocationStatusCard`, its only
/// caller. Everything else the widget can be handed comes in through the
/// free-form `label`, so the remaining previews push that string to the shapes
/// that break a one-line row, plus the mutually-exclusive pair the
/// `inMutuallyExclusiveGroup` semantics claim but a single card never shows.
///
/// Measured while writing these (390pt canvas, the screen's own `Spacing.large`
/// page gutters, real Inter):
///
///   * The card is **fixed height and single line**: 350x66 at 1x, 350x82 at
///     200% text. `_Label` sets `overflow: ellipsis` with no `maxLines`, so a
///     label that does not fit is truncated, never wrapped — the card cannot
///     grow. Both localized option labels fit even at 200%, so this only bites
///     the longer labels the mirrored `_SavedAddressCard` renders.
///   * **RTL mirrors correctly** — measured from the card's leading edge, the
///     label starts at 17pt with the radio at x=309 in English, and the radio
///     moves to x=17 with the label at x=57 in Arabic.
///   * The **unselected card has no visible boundary of its own**: its
///     `surface` fill is byte-identical to `scaffoldBackgroundColor` in BOTH
///     themes (1.00:1), leaving the `outlineVariant` hairline as the only
///     delimiter at 1.29:1 light / 1.98:1 dark — under the 3:1 WCAG 1.4.11 asks
///     of a control boundary. The 'Unselected' preview is where to see it.
///   * The [SelectableRadioGlyph] is a hard `Sizes.xLarge` (24pt) square that
///     does not scale with text: at 200% the label line is 40pt next to the
///     same 24pt radio.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/location/presentation/widgets/client_location_option_card.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// The canvas box for one option card: phone width, one card tall.
///
/// The card itself is 66pt (82pt at 200% text); the rest is the vertical
/// rhythm it sits in on the Client Location screen.
const Size _cardBox = Size(390, 140);

/// A taller box for the two-card group.
const Size _groupBox = Size(390, 260);

/// Hosts a card inside the same horizontal gutter the Client Location screen
/// gives it (`DeliveryCreateLayout.pagePadding` → `Spacing.large` each side),
/// so the width the label must fit into is the real one — 350pt, not the full
/// canvas.
Widget _hosted({required String label, required bool selected}) {
  return Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: Spacing.large,
      vertical: Spacing.medium,
    ),
    child: ClientLocationOptionCard(
      label: label,
      selected: selected,
      onTap: () {},
    ),
  );
}

/// Same, but reading the label through [AppLocalizations] exactly the way
/// `CurrentLocationStatusCard` does — so the AR RTL rendering shows the real
/// translation instead of a hardcoded English string, which is the only way a
/// missing ARB key would ever show up here.
Widget _hostedLocalized({
  required String Function(AppLocalizations l10n) label,
  required bool selected,
}) {
  return Builder(
    builder: (BuildContext context) => _hosted(
      label: label(AppLocalizations.of(context)),
      selected: selected,
    ),
  );
}

/// The resting state: an option the customer has not chosen.
///
/// White `surface` fill, `outlineVariant` hairline, navy `primary` label, empty
/// radio ring. This is the rendering that shows the boundary problem noted in
/// the library docs — the fill matches the page exactly in both themes, so the
/// hairline is doing all the work of saying "this is a control", at 1.29:1
/// (light) and 1.98:1 (dark). Look at the AR RTL **dark** rendering: that is
/// where the card reads as loose text rather than a tappable option.
@JeebPreview(group: 'location', name: 'Unselected', size: _cardBox)
Widget clientLocationOptionCardUnselected() => _hostedLocalized(
      label: (AppLocalizations l10n) => l10n.clientLocationNewOption,
      selected: false,
    );

/// The chosen state: navy `primary` fill, `onPrimary` label, filled radio.
///
/// What "Current Location" looks like once tapped — which on this screen is
/// also what gates the Confirm CTA, so "did my tap register" is answered by
/// this rendering alone. Contrast is comfortable in both themes (17.1:1 light,
/// 7.7:1 dark), and the label survives 200% text without truncating.
@JeebPreview(group: 'location', name: 'Selected', size: _cardBox)
Widget clientLocationOptionCardSelected() => _hostedLocalized(
      label: (AppLocalizations l10n) => l10n.clientLocationCurrentOption,
      selected: true,
    );

/// The layout ceiling: a user-entered saved-address label.
///
/// The `_SavedAddressCard` on the same screen "mirrors [ClientLocationOptionCard]
/// styling" for saved addresses, whose labels are free text the customer typed
/// ("Sassine Square, Ashrafieh" is the fixture the saved-address tests use).
/// This is the state that shows the truncation contract: the card stays 66pt
/// and the tail of the label is replaced by an ellipsis — it never wraps, so
/// there is no second line and no growth. Whether truncating is the right
/// answer for an address is a design question this preview makes askable.
@JeebPreview(group: 'location', name: 'Long label truncates', size: _cardBox)
Widget clientLocationOptionCardLongLabel() => _hosted(
      label: 'Sassine Square, Ashrafieh — Building 12, 3rd floor, blue door',
      selected: false,
    );

/// The same truncation against the navy fill, with no break opportunity.
///
/// Map plus-codes and pasted place identifiers arrive as one unbroken token,
/// which soft wrapping cannot split even if `maxLines` were raised — so this
/// stays a single ellipsized line no matter what. Selected on purpose: the
/// ellipsis is at its lowest contrast in `onPrimary` on navy, and this is the
/// state where a customer can end up unable to tell two saved pins apart.
@JeebPreview(group: 'location', name: 'Unbreakable label', size: _cardBox)
Widget clientLocationOptionCardUnbreakableLabel() => _hosted(
      label: 'W2CH+8XBeirutGovernorateLebanonPlusCodeIdentifier',
      selected: true,
    );

/// A right-to-left label while the app itself is running in English.
///
/// Saved-address labels are user input, so an Arabic-speaking customer on an
/// English UI is a real combination. Unlike the chat surface — which routes
/// user text through `AutoDirectionText` for exactly this reason — this card
/// renders a plain [Text], so the paragraph takes the ambient LTR base
/// direction: the Arabic itself is shaped correctly, but the bracketed Latin
/// digits resolve against the wrong base. Read this preview against its own AR
/// RTL rendering, where the base direction is right and the whole card mirrors.
@JeebPreview(group: 'location', name: 'RTL label under EN locale', size: _cardBox)
Widget clientLocationOptionCardRtlLabel() => _hosted(
      label: 'ساسين، الأشرفية (مبنى 12)',
      selected: false,
    );

/// The mutually-exclusive pair — the state a single card can never show.
///
/// The widget declares `inMutuallyExclusiveGroup: true`, which only means
/// anything next to siblings, and the selected/unselected pair is only
/// reviewable as a pair: this is where you see whether the chosen option
/// actually reads as chosen, and whether the unselected sibling reads as a
/// control at all.
///
/// It also exposes a reuse hazard: `identifier: 'client_location_option_current'`
/// is hardcoded inside the widget, so BOTH cards here publish the same
/// semantics identifier — the one `test/delivery_create_screens_test.dart`
/// asserts `findsOneWidget` on.
@JeebPreview(group: 'location', name: 'Pair in one group', size: _groupBox)
Widget clientLocationOptionCardPair() => const Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.medium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClientLocationOptionCard(
            label: 'Home',
            selected: true,
            onTap: _noop,
          ),
          SizedBox(height: Spacing.small),
          ClientLocationOptionCard(
            label: 'Office',
            selected: false,
            onTap: _noop,
          ),
        ],
      ),
    );

void _noop() {}
