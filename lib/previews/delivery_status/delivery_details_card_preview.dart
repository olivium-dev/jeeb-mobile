/// Widget previews for [DeliveryDetailsCard] — run with
/// `flutter widget-preview start`.
///
/// The card is pure-props: everything it paints comes from the
/// [DeliverySnapshot] it is handed, so no cubit, repository or DI graph is
/// involved and these previews are network-free by construction rather than by
/// the guard in [jeebPreviewHost]. Only three of the snapshot's nine fields are
/// read here — `pickup`, `dropoff`, `tier` — so [_snapshot] pins the rest to
/// inert values and the states below vary only what the card can see.
///
/// The base fixture mirrors `_snapshot()` in
/// `test/delivery_status_screen_test.dart` (Hamra → Verdun, scooter); that test
/// only asserts the card is *present* by [DeliveryDetailsCard.rootKey], never
/// what it says or how it lays out. These previews are the visual half of that
/// contract: three stacked icon+two-line rows are exactly the shape that breaks
/// under RTL mirroring and at the 200%-text ceiling.
library;

import 'package:flutter/material.dart';

import '../../features/delivery_status/domain/delivery_address.dart';
import '../../features/delivery_status/domain/delivery_snapshot.dart';
import '../../features/delivery_status/domain/delivery_stage.dart';
import '../../features/delivery_status/domain/delivery_tier.dart';
import '../../features/delivery_status/presentation/widgets/delivery_details_card.dart';
import '../harness/jeeb_preview.dart';

// Every box below is phone width and sized for the TALLEST of the three
// renderings JeebPreview expands to, not for the EN-light one. A box that fits
// only EN light would report the AR RTL and 200%-text renderings as overflowing
// the CANVAS, which says nothing about the widget.
//
// The heights are measured, not guessed — card height at 390 dp wide:
//
//   state                 EN 1x   AR 1x   EN 2x   (AR 2x)
//   Minimal                 218     218     410      458
//   Sub-lines               334     334     798      798
//   Pickup-truck tier       242     242     602      554
//   Unresolved pickup       260     260     572      620
//   Arabic addresses        286     286     830      878
//   Longest content         574     574    1918     1966
//
// The first three columns are the matrix; AR 2x is not previewed but is the
// real-world worst case (an Arabic user who also raised system text size), and
// it is the tallest column in four of six states. Note that the 2x figures are
// 1.9x-3.3x the 1x figures: NOTHING in this card clamps a line, so text scale
// multiplies straight into height.

/// Shortest state: bare labels, no sub-lines.
const Size _shortCardBox = Size(390, 420);

/// The normal band — sub-lines present, or a label that wraps to two lines.
const Size _cardBox = Size(390, 840);

/// The wrapping ceiling. 1918 dp is over three phone screens of card, and that
/// number IS the finding: nothing in [DeliveryDetailsCard] sets `maxLines`, so
/// a long address at 200% text pushes everything below it off the screen.
const Size _tallCardBox = Size(390, 1960);

/// A delivery address as customers actually dictate one — a full street line
/// plus a landmark the courier needs, well past one line at 390 dp.
const String _longPickupLabel =
    'Rue Abdel Aziz, off Hamra Main Street, Ras Beirut, Beirut Governorate';

/// The matching drop-off: the run-on "which door" instruction that arrives in
/// the sub-line slot.
const String _longDropoffDetail =
    'Building B, the beige one facing the pharmacy, 4th floor, apartment 12, '
    'please ring the intercom twice because the doorbell has been broken since '
    'last week and leave it with the concierge if nobody answers';

/// Builds a snapshot whose only meaningful fields are the three the card reads.
///
/// Stage/lifecycle/timestamps are fixed and invisible here — the card renders
/// no lifecycle state at all, which is itself worth remembering when a bug
/// report says "the details card showed the wrong thing after cancellation".
DeliverySnapshot _snapshot({
  required DeliveryAddress pickup,
  required DeliveryAddress dropoff,
  required DeliveryTier tier,
}) {
  return DeliverySnapshot(
    id: 'd-1',
    stage: DeliveryStage.inTransit,
    lifecycle: DeliveryLifecycle.active,
    stageTimestamps: const <DeliveryStage, DateTime>{},
    pickup: pickup,
    dropoff: dropoff,
    tier: tier,
  );
}

Widget _hosted({
  required DeliveryAddress pickup,
  required DeliveryAddress dropoff,
  required DeliveryTier tier,
}) =>
    DeliveryDetailsCard(
      snapshot: _snapshot(pickup: pickup, dropoff: dropoff, tier: tier),
    );

/// The fixture the screen test already uses: bare neighbourhood names, no
/// sub-lines, scooter tier.
///
/// This is the card at its shortest, and the reason the sub-line is guarded on
/// `isNotEmpty` rather than just `!= null` — two rows collapse to two lines each
/// and the third (tier) never has a sub-line at all. Compare the row rhythm here
/// against 'Sub-lines on both legs': the icon discs must stay on the same
/// baseline as the label in both.
@JeebPreview(group: 'delivery_status', name: 'Minimal (no sub-lines)', size: _shortCardBox)
Widget deliveryDetailsCardMinimal() => _hosted(
      pickup: const DeliveryAddress(label: 'Hamra'),
      dropoff: const DeliveryAddress(label: 'Verdun'),
      tier: DeliveryTier.scooter,
    );

/// The realistic happy path: a geocoded street line plus the floor/landmark
/// sub-line on both legs.
///
/// Three lines per row is the normal case in production, not the exception —
/// the request-creation flow prompts for the apartment detail. Check that the
/// sub-line reads as secondary (`onSurfaceVariant`, `bodySmall`) and not as a
/// second address; in dark mode that contrast step is the one that collapses.
@JeebPreview(group: 'delivery_status', name: 'Sub-lines on both legs', size: _cardBox)
Widget deliveryDetailsCardWithDetails() => _hosted(
      pickup: const DeliveryAddress(
        label: 'Hamra Main St, Beirut',
        detail: 'Costa Coffee, ground floor',
      ),
      dropoff: const DeliveryAddress(
        label: 'Verdun 730, Beirut',
        detail: 'Building B, 4th floor, Apt 12',
      ),
      tier: DeliveryTier.car,
    );

/// The label collision, made visible.
///
/// `deliveryPickupLabel` is "Pickup" and `deliveryTierPickup` is "Pickup truck",
/// so this is the one state where the same word heads the first row and fills
/// the last. If the tier row ever renders a bare "Pickup" it means
/// `_labelForTier` has been wired to the address key — the two live four lines
/// apart in the ARB and read almost identically in review.
///
/// The icon is the other half of the check: `Icons.local_shipping`, not the
/// `Icons.adjust` target that marks the pickup POINT.
@JeebPreview(group: 'delivery_status', name: 'Pickup-truck tier', size: _cardBox)
Widget deliveryDetailsCardPickupTruckTier() => _hosted(
      pickup: const DeliveryAddress(label: 'Achrafieh, Sassine Square'),
      dropoff: const DeliveryAddress(label: 'Jounieh, Old Souk'),
      tier: DeliveryTier.pickup,
    );

/// Degraded data: the gateway has not resolved the pickup yet, so its label is
/// an empty string, and the drop-off carries an empty sub-line.
///
/// The two are handled asymmetrically on purpose in the code — `secondary` is
/// guarded by `secondary!.isNotEmpty` so the empty sub-line vanishes, but
/// `primary` has no guard, so the empty pickup renders as a labelled row with a
/// blank value under it. This preview exists to make that blank visible: it is
/// the difference between "we're still looking" and "this row is broken", and
/// the card currently says neither.
@JeebPreview(group: 'delivery_status', name: 'Unresolved pickup', size: _cardBox)
Widget deliveryDetailsCardUnresolvedPickup() => _hosted(
      pickup: const DeliveryAddress(label: '', detail: 'Awaiting geocode'),
      dropoff: const DeliveryAddress(label: 'Mar Mikhael, Beirut', detail: ''),
      tier: DeliveryTier.bike,
    );

/// The layout ceiling: longest-plausible label AND longest-plausible sub-line
/// at once.
///
/// Nothing in `_DetailRow` sets `maxLines` or `overflow`, so neither line
/// clamps — the row grows downward and the card grows with it: 574 dp at 1x,
/// **1918 dp at 200% text**, over three phone screens for one card. That is
/// survivable inside the screen's scrolling column, which is what the class doc
/// means by "relies on the caller", but it means a 200%-text user scrolls past
/// three screens of address before reaching the Jeeber card and the action bar
/// that follow it. It is not survivable at all if this card is ever dropped into
/// a fixed-height slot.
///
/// The AR RTL and 200%-text renderings are the ones that matter here: the EN
/// light rendering keeps looking reasonable long after the other two have run
/// off the bottom.
@JeebPreview(group: 'delivery_status', name: 'Longest content', size: _tallCardBox)
Widget deliveryDetailsCardLongContent() => _hosted(
      pickup: const DeliveryAddress(
        label: _longPickupLabel,
        detail: 'Ask for Nadia at the service counter, not the till',
      ),
      dropoff: const DeliveryAddress(
        label: 'Sin El Fil, Horch Tabet, Boulevard Camille Chamoun',
        detail: _longDropoffDetail,
      ),
      tier: DeliveryTier.bike,
    );

/// Bidi: Arabic addresses inside an English UI.
///
/// Addresses are the only free text on this card, so they are the only place the
/// UI locale and the content direction can disagree — a Beirut customer typing
/// Arabic while the app runs in English is the ordinary case, not an edge one.
/// `_DetailRow` uses a plain [Text], which takes the AMBIENT directionality, so
/// in the EN rendering these lines are laid out LTR: watch the trailing comma
/// and the numeral run, which is where a first-strong (UAX#9) treatment would
/// differ visibly from what this card does today.
@JeebPreview(group: 'delivery_status', name: 'Arabic addresses in EN UI', size: _cardBox)
Widget deliveryDetailsCardArabicAddresses() => _hosted(
      pickup: const DeliveryAddress(
        label: 'شارع الحمرا، بيروت',
        detail: 'الطابق الأرضي، مقهى كوستا',
      ),
      dropoff: const DeliveryAddress(
        label: 'فردان ٧٣٠، بيروت',
        detail: 'المبنى ب، الطابق الرابع، شقة ١٢',
      ),
      tier: DeliveryTier.scooter,
    );
