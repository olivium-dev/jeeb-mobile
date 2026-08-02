import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_summary.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Shows the matched Jeeber's avatar, display name, vehicle, and rating.
///
/// Renders a `looking for…` placeholder while [jeeber] is null. The card
/// intentionally does not embed the Contact CTA — that's owned by the
/// screen's action bar so the layout stays uniform across lifecycle states.
class DeliveryJeeberCard extends StatelessWidget {
  const DeliveryJeeberCard({super.key, required this.jeeber});

  static const Key rootKey = Key('delivery-status-jeeber-card');

  final JeeberSummary? jeeber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      key: rootKey,
      title: l10n.deliveryJeeberCardTitle,
      content: jeeber == null ? _Waiting() : _JeeberRow(jeeber: jeeber!),
    );
  }
}

class _Waiting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const OmdsLoadingState(
          size: Sizes.xLarge,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Text(
            AppLocalizations.of(context).deliveryJeeberWaiting,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _JeeberRow extends StatelessWidget {
  const _JeeberRow({required this.jeeber});

  final JeeberSummary jeeber;

  String _initial() {
    final trimmed = jeeber.displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OmdsProfileAvatar(
          initial: _initial(),
          profilePicUrl: jeeber.avatarUrl,
          size: Sizes.threeXLarge,
          backgroundColor: colorScheme.primaryContainer,
          initialColor: colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                jeeber.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Sizes.threeXSmall),
              Text(
                jeeber.vehicleLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (jeeber.rating != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.small,
              vertical: Spacing.twoXSmall,
            ),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: OmdsBorderRadius.small,
            ),
            child: Text(
              l10n.deliveryJeeberRating(jeeber.rating!.toStringAsFixed(1)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
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
// Render tests: test/previews/delivery_status/delivery_jeeber_card_preview_test.dart
// ===========================================================================

// Widget previews for [DeliveryJeeberCard] — run with
// `flutter widget-preview start`.
//
// The card is pure-props: its whole surface comes from the one nullable
// [JeeberSummary] it is handed, so there is no cubit, no repository and no DI
// graph involved. These previews are network-free by construction rather than
// by the guard in [jeebPreviewHost] — with one caveat, which is also why no
// state below passes a photo:
//
// **Why no state passes a real `avatarUrl`.** It is the single field on
// [JeeberSummary] that reaches the network: a non-empty URL sends
// `OmdsProfileAvatar` down `OmdsCachedImage` → `CachedNetworkImage`, which
// resolves in neither the canvas nor a test and lands back on exactly the
// initials disc a null URL renders directly. Previewing it would add cards
// that look identical to the ones already here while making the suite depend
// on a CDN. Every state below therefore renders the initials disc — which is
// what the card paints for any jeeber who has not uploaded a photo, the common
// case in production. The photo path is left to the screen goldens.
//
// **Why [_hosted] freezes the ticker.** The `jeeber == null` state renders
// `OmdsLoadingState`, an indeterminate [CircularProgressIndicator] that never
// stops scheduling frames, so the render tests' `pumpAndSettle` hangs on it
// (measured: `pumpAndSettle timed out`). [TickerMode] mutes it, which also
// makes the canvas card deterministic — a still preview wants a still spinner.
//
// Fixtures are the ones this widget is already tested with elsewhere, so the
// previews and the tests describe the same two people: 'Karim H.' / Scooter /
// 4.8 from `test/delivery_status_screen_test.dart` (and the Screen Catalog
// entry in `lib/devtool/catalog/entries/batch_03_entries.dart`), and
// 'Kamal Hajj' / Motorbike from `test/order_tracking_jeeber_card_test.dart`.
// Neither test asserts anything about layout — one checks the card is present
// by [DeliveryJeeberCard.rootKey], the other checks two strings and paint
// order — so the visual half of the contract is what these previews add. An
// avatar + a two-line column + a trailing chip is the shape that breaks first
// under RTL mirroring and at the 200%-text ceiling.
//
// **Measured geometry** — height of the whole card including the
// `OMDSSectionCard` title and its trailing divider, read off the render tree
// (bundled Inter), not eyeballed:
//
// | state                  | 390: EN 1x / AR 1x / EN 2x | 320: EN 1x / EN 2x |
// |------------------------|----------------------------|--------------------|
// | Matched · rating shown |      100 / 100 /  278      |     100 /  390     |
// | Waiting for a match    |       84 /  84 /  252      |     100 /  252     |
// | No rating yet          |      100 / 100 /  206      |     100 /  278     |
// | Blank display name     |      100 / 100 /  238      |     114 /  302     |
// | Longest content        |      202 / 202 /  742      |     258 / 1366     |
// | Arabic name in EN UI   |      100 / 100 /  278      |     118 /  462     |
//
// Two things in that table are the point of this file, and neither is visible
// in the EN-light reading anyone opens first:
//
// * **The rating chip is not in an [Expanded], so it takes its width first and
//   the name column pays.** Compare 'Matched · rating shown' (278) with
//   'No rating yet' (206) at 200% text: same layout, same box, one extra chip
//   — and the name wraps in the first and not the second. A report that "the
//   name is cut for some drivers and not others" is this, not bad data.
// * **Nothing clamps.** Neither the name nor the vehicle [Text] sets
//   `maxLines` or `overflow`, so long content wraps and the card grows without
//   limit: 1366 dp on a 320 dp phone at 200% text, roughly two screens for one
//   card. Both call sites put it in a scrolling column, so this degrades
//   rather than overflowing — but it is not survivable in a fixed-height slot.
//
// No `RenderFlex` overflow was raised in any of the 24 measured renderings; the
// row absorbs pressure by growing downward, never by clipping.

/// Phone width by the tallest 200%-text rendering of the five single-row
/// states (278 dp, 'Matched · rating shown'). Sizing the box to the EN-light
/// height instead would report the AR and 200% renderings as overflowing the
/// CANVAS, which says nothing about the widget.
const Size _deliveryJeeberCardBox = Size(390, 300);

/// The wrapping ceiling: 742 dp at 200% text, and that number is the finding
/// rather than a canvas detail.
const Size _deliveryJeeberCardTallCardBox = Size(390, 780);

/// A jeeber's name as the gateway sends it when the account carries a full
/// legal name instead of the privacy-preserving "first name + initial" form.
const String _deliveryJeeberCardLongDisplayName = 'Abdulrahman Al-Muhandis Al-Trabulsi';

/// `vehicleLabel` is free text off the jeeber's KYC record, not an enum — this
/// is the longest plausible one, and it lands in the same column as the name.
const String _deliveryJeeberCardLongVehicleLabel =
    'Pickup truck with refrigerated cargo box (large)';

/// [DeliveryJeeberCard] takes one nullable prop, so a preview is a constructor
/// call; the [TickerMode] is the only scaffolding, and it is inert for every
/// state except the spinner (see the library doc).
Widget _deliveryJeeberCardHosted(JeeberSummary? jeeber) => TickerMode(
      enabled: false,
      child: DeliveryJeeberCard(jeeber: jeeber),
    );

/// The happy path, and the fixture `test/delivery_status_screen_test.dart`
/// already pins: a matched jeeber with the short privacy-preserving name, a
/// vehicle label and a rating.
///
/// The only state that shows the trailing rating chip, so the only one that
/// poses the card's real layout question: a fixed 40 dp avatar
/// (`Sizes.threeXLarge`) + an [Expanded] name/vehicle column + a chip that is
/// NOT in an [Expanded]. Read the **AR RTL dark** rendering to confirm the chip
/// mirrors to the leading edge, and the **EN 200% text** one to see how little
/// of 390 dp the name column keeps once the chip has doubled with it.
@JeebPreview(
  group: 'delivery_status',
  name: 'Matched · rating shown',
  size: _deliveryJeeberCardBox,
  matrix: true,
)
Widget deliveryJeeberCardMatched() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: 'Karim H.',
        vehicleLabel: 'Scooter',
        phoneE164: '+96171000000',
        rating: 4.8,
      ),
    );

/// Pre-match: `jeeber == null`, so the card swaps its entire content for the
/// spinner + "Looking for a Jeeber…" placeholder.
///
/// Worth knowing where this is reachable. `DeliveryStatusScreen` mounts the
/// card unconditionally (`delivery_status_screen.dart:265`), so it is a real
/// state there. `LiveTrackingScreen` deliberately does NOT — it mounts
/// `_TrackingJeeberSection` only once a jeeber is assigned, precisely so this
/// placeholder "never shows on an already GPS-streaming delivery"
/// (`live_tracking_screen.dart:571`), a rule
/// `test/order_tracking_jeeber_card_test.dart` pins. If this copy is ever
/// reworded into something that reads as an error rather than a wait, that
/// second screen's reason for hiding it changes with it.
///
/// The EN copy is also the longer one here: at 320 dp it wraps to two lines
/// (100 dp) where the Arabic fits on one (84 dp) — the reverse of the usual
/// direction, and the reason this state is measured in both.
@JeebPreview(
  group: 'delivery_status',
  name: 'Waiting for a match',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardWaiting() => _deliveryJeeberCardHosted(null);

/// A matched jeeber with **no** rating: the chip is dropped entirely
/// (`if (jeeber.rating != null)`) rather than rendered as "—" or "0.0".
///
/// The ordinary case for a new jeeber, and also what the blind-reveal rule
/// documented on [JeeberSummary] produces mid-flight. Compare against
/// 'Matched · rating shown': the name column silently gains the chip's width
/// back, so the two states have different truncation budgets for the same
/// name — 206 dp against 278 dp at 200% text.
@JeebPreview(
  group: 'delivery_status',
  name: 'No rating yet',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardNoRating() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: 'Kamal Hajj',
        vehicleLabel: 'Motorbike',
      ),
    );

/// Degraded data: the gateway returned an empty `displayName`.
///
/// `_initial()` guards this and paints '?' in the avatar disc — and that guard
/// is the widget's ONLY handling of it. The name [Text] has no fallback, so the
/// card renders a blank first line above the vehicle label and quietly loses a
/// line of height. This preview exists to make that blank visible: '?' over an
/// empty line reads as a broken card rather than as "we don't have their name
/// yet", and nothing on the card says which it is.
@JeebPreview(
  group: 'delivery_status',
  name: 'Blank display name',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardBlankName() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: '',
        vehicleLabel: 'Pickup truck',
        rating: 3.0,
      ),
    );

/// The layout ceiling: longest plausible name AND longest plausible vehicle
/// label, with the rating chip present to squeeze them.
///
/// Neither [Text] sets `maxLines` or `overflow`, so nothing ellipsizes — both
/// lines wrap and the row grows downward: 202 dp at 1x, **742 dp at 200%
/// text**, 1366 dp on a 320 dp phone at 200%. Read the **EN 200% text**
/// rendering first; that is where the fixed avatar and the doubled chip leave
/// the wrapping column its smallest share of the width.
@JeebPreview(
  group: 'delivery_status',
  name: 'Longest content',
  size: _deliveryJeeberCardTallCardBox,
  matrix: true,
)
Widget deliveryJeeberCardLongContent() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: _deliveryJeeberCardLongDisplayName,
        vehicleLabel: _deliveryJeeberCardLongVehicleLabel,
        rating: 5.0,
      ),
    );

/// Bidi: an Arabic name and vehicle label inside the English UI.
///
/// The name and the vehicle label are the only free text on this card, so they
/// are the only place the UI locale and the content direction can disagree —
/// and a Beirut jeeber whose KYC name is Arabic while the sender runs the app
/// in English is the ordinary case, not an edge one. Both are plain [Text]
/// widgets taking the AMBIENT directionality, so in this reading they are laid
/// out LTR. The chip is the other half: `deliveryJeeberRating` is `{rating} ★`
/// in BOTH ARB files and the value arrives from `toStringAsFixed(1)`, so the
/// rating reads "4.5 ★" in Western digits in Arabic too — watch where the star
/// lands here against the AR rendering the render test pumps.
@JeebPreview(
  group: 'delivery_status',
  name: 'Arabic name in EN UI',
  size: _deliveryJeeberCardBox,
)
Widget deliveryJeeberCardArabicName() => _deliveryJeeberCardHosted(
      const JeeberSummary(
        displayName: 'كريم حجازي',
        vehicleLabel: 'دراجة نارية',
        rating: 4.5,
      ),
    );
