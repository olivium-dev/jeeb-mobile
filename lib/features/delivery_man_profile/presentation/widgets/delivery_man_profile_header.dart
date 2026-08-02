import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';
import 'delivery_man_meta_row.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Identity header for the delivery-man public profile: large circular avatar +
/// (name row with verified badge) + rating summary + location/availability.
/// Composed from OMDS primitives (design §6: [OmdsProfileCard] is an
/// image-background card, not an inline identity block).
class DeliveryManProfileHeader extends StatelessWidget {
  const DeliveryManProfileHeader({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
    this.isColdStart = false,
  });

  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;

  /// D59 cold-start: when true (jeeber has < 5 reviews) the aggregate score is
  /// hidden — only the review count is shown.
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.small,
      ),
      child: _HeaderRow(
        name: name,
        avatarUrl: avatarUrl,
        isVerified: isVerified,
        rating: rating,
        reviewCount: reviewCount,
        location: location,
        isAvailable: isAvailable,
        isColdStart: isColdStart,
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.name,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
    required this.isColdStart,
  });

  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(name: name, avatarUrl: avatarUrl),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _Details(
            name: name,
            isVerified: isVerified,
            rating: rating,
            reviewCount: reviewCount,
            location: location,
            isAvailable: isAvailable,
            isColdStart: isColdStart,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '?';
    return OmdsProfileAvatar(
      key: const Key('delivery-man-profile-avatar'),
      initial: initial,
      profilePicUrl: avatarUrl,
      size: Sizes.nineXLarge,
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.name,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
    required this.isColdStart,
  });

  final String name;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NameRow(name: name, isVerified: isVerified),
        const SizedBox(height: Spacing.xSmall),
        _RatingRow(
          rating: rating,
          reviewCount: reviewCount,
          isColdStart: isColdStart,
        ),
        const SizedBox(height: Spacing.twoXSmall),
        _AvailabilityRow(location: location, isAvailable: isAvailable),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.reviewCount,
    required this.isColdStart,
  });

  final double rating;
  final int reviewCount;
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // D59 cold-start (< 5 reviews): HIDE the aggregate score. We still surface
    // the review count (no star score), so the header stays coherent without an
    // unverified score. `profile_score` is present ONLY when the score shows,
    // so QA can assert it is absent during cold-start.
    if (isColdStart) {
      return DeliveryManMetaRow(
        icon: Icons.reviews_outlined,
        text: l10n.deliveryManProfileReviewsCount(reviewCount),
        semanticsId: 'delivery_man_profile_rating_summary',
      );
    }
    return DeliveryManMetaRow(
      icon: Icons.star,
      text: l10n.deliveryManProfileRatingSummary(
        rating.toStringAsFixed(1),
        reviewCount,
      ),
      semanticsId: 'profile_score',
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({required this.location, required this.isAvailable});

  final String location;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final availability = _availabilityLabel(l10n);
    // F9: only join location + availability with the separator dot when a
    // location is actually present; otherwise show availability alone so we
    // never render a stray leading "· Available".
    final text = location.trim().isEmpty
        ? availability
        : l10n.deliveryManProfileLocationAvailability(location, availability);
    return DeliveryManMetaRow(
      icon: Icons.location_on,
      text: text,
      semanticsId: 'delivery_man_profile_availability',
    );
  }

  String _availabilityLabel(AppLocalizations l10n) => isAvailable
      ? l10n.deliveryManProfileAvailable
      : l10n.deliveryManProfileUnavailable;
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.isVerified});

  final String name;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: _NameText(name: name)),
        if (isVerified) ...[
          const SizedBox(width: Spacing.xSmall),
          const _NameBadge(),
        ],
      ],
    );
  }
}

class _NameText extends StatelessWidget {
  const _NameText({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_man_profile_name',
      child: AutoDirectionText(
        name,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NameBadge extends StatelessWidget {
  const _NameBadge();

  @override
  Widget build(BuildContext context) {
    return JeebVerifiedBadge(
      semanticsLabel:
          AppLocalizations.of(context).deliveryManProfileVerifiedBadgeLabel,
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
// Render tests: test/previews/delivery_man_profile/delivery_man_profile_header_preview_test.dart
// ===========================================================================

// Widget previews for [DeliveryManProfileHeader] — run with
// `flutter widget-preview start`.
//
// The header is a pure [StatelessWidget] over eight plain fields, so every
// state below is one constructor call: no cubit, no repository, nothing to
// seed. It is network-free by construction, not merely by [jeebPreviewHost]'s
// guard.
//
// **Why there is no "avatar photo" state.** `avatarUrl` is the one field that
// reaches the wire (`OmdsProfileAvatar` → `OmdsCachedImage`), and the shipped
// fixture URL (`https://i.pravatar.cc/150?img=33`) resolves in neither the
// canvas nor a test — both fall back to the same initial placeholder the
// `null` states already show. A preview that renders identically to its
// neighbours is the exact failure `expectedText` exists to catch, so every
// state here passes `avatarUrl: null` and the photo path is left to the screen
// goldens. Same call the sibling `customer_profile_header_preview.dart` makes.
//
// Fixture values are the ones already shipping rather than invented:
// `DevDeliveryManProfileFixtures.sample` (Kamal Hajj, 4.3, 113, Lebanon), the
// two catalog states in `lib/devtool/catalog/entries/batch_03_entries.dart`
// (Rana Ahmad cold start; the "New Jeeber" empty profile), and the
// `'Sami' / 4.8 / 12 / 'Riyadh'` jeeber from
// `test/features/delivery_man_profile/delivery_man_profile_header_location_test.dart`.
//
// **Measured geometry** (390 dp wide, bundled Inter loaded into the test
// binding, read off the render tree — not eyeballed). `Spacing.large` gutters
// on both sides, an `Sizes.nineXLarge` (88 dp) avatar and a `Spacing.small`
// gap leave the details column 250 dp; the name row gives up a further 28 dp
// to the verified badge and its gap, so a verified name wraps at 222 dp.
// Header heights:
//
// | state                            | 1x     | 200% text |
// |----------------------------------|--------|-----------|
// | populated / cold start / F9      | 112 dp | 244 dp    |
// | unavailable + unverified         | 112 dp | 180 dp    |
// | Arabic name                      | 140 dp | 308 dp    |
// | longest plausible                | 172 dp | 436 dp    |
//
// At 1x the 88 dp avatar is the tallest thing in the row, so the first two
// rows are the same 112 dp; the last two are taller because their name has
// already wrapped. Each canvas box below is sized to hold its own 200%
// rendering, so an overflow stripe in the canvas means a real regression.
//
// **RTL mirrors correctly** — measured, because this is the first thing a
// header row usually gets wrong: in `ar` the avatar moves to 282–370 (the same
// 20 dp gutter, from the trailing edge) and both meta glyphs lead their text
// from the right. `EdgeInsetsDirectional` + plain [Row]s are doing their job.
//
// Seven things these previews surface, all in the widget, its child
// `DeliveryManMetaRow` or its copy rather than in the previews — see the notes
// on the individual states:
//
//  * the name is inked with `colorScheme.secondaryContainer`, a *container*
//    role used as ink: brand navy on white (17.1:1), but #44455A on the
//    #131318 surface of `ColorScheme.fromSeed(_jeebNavy, dark)` — **1.98:1**,
//    below the 3:1 WCAG floor for large text. The AR RTL dark rendering of
//    every state below is the jeeber's name nearly dissolved into the page,
//    and `JeebVerifiedBadge` beside it takes the same role and dissolves with
//    it;
//  * both meta rows are inked with `colorScheme.onSecondaryContainer`, which
//    in the LIGHT scheme is `_jeebMutedPurple` (#777FC0) on white — **3.76:1**
//    at 14 dp regular, below the 4.5:1 AA floor for body text. That is the
//    default theme, in the EN light rendering, on the score and the
//    location/availability line — i.e. every word of this header except the
//    name. The dark scheme measures 14.3:1 on the same role, so this is the
//    one failure the light rendering owns and the dark one does not. Already
//    flagged from the other side in `delivery_man_meta_row_preview.dart`;
//  * `DeliveryManMetaRow`'s own doc says its leading glyph is "brand orange
//    ([ColorScheme.primary] per design §4)", but the Jeeb light scheme maps
//    `primary` to `_jeebNavy` — the star and the pin measure #0B1351, navy.
//    Brand orange is `tertiary` in this palette;
//  * D59 hides the aggregate score under five reviews, but the copy that
//    replaces it has no plural form in either locale — the key is resolved by
//    literal `{count}` substitution, so a jeeber's first review reads
//    "1 Reviews" and no ARB edit can fix it (`{count} تقييم` is the Arabic
//    singular for every count from the other side). This file previews the
//    two-review case; the hole is the same at any count;
//  * `rating.toStringAsFixed(1)` rounds 4.96 UP to "5.0" — the one direction a
//    trust signal must not round;
//  * `_NameText` passes no `maxLines`/`overflow`, so a long name wraps and
//    grows the header rather than ellipsizing, and `_NameRow` centres the
//    verified badge against the whole wrapped block;
//  * `DeliveryManMetaRow._MetaText` does the opposite — `ellipsis` with
//    `maxLines: null`, which resolves to single-line truncation — and because
//    the location and the availability are joined into ONE string with
//    availability last, a long place name silently eats the availability
//    state. Measured at 1x on a 390 dp phone, no text scaling required.

/// Phone width, for the states whose details column stays one line per row:
/// 112 dp at 1x, 244 dp at 200% text.
const Size _deliveryManProfileHeaderBox = Size(390, 260);

/// For the state whose name already wraps at 1x: 140 dp, 308 dp at 200%.
const Size _deliveryManProfileHeaderWrappingBox = Size(390, 320);

/// Over half a 390 × 844 phone, because that is the point of the state it
/// frames: at 200% text this header alone is 436 dp.
const Size _deliveryManProfileHeaderPhoneScreenBox = Size(390, 460);

/// One specimen, under the width the header really gets.
///
/// The 390 dp is pinned in the fixture rather than left to the canvas [Size],
/// for the reason `customer_profile_rating_preview.dart` pins its column: the
/// canvas honours `size`, but the render tests pump onto a fixed 800 × 600
/// surface, so a header left to fill its host would wrap on the phone and not
/// wrap under test — the state that breaks would break in only one of the two
/// places it is looked at.
///
/// Argument list mirrors the call site at
/// `lib/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart:105`,
/// including `isColdStart`, which the screen derives from
/// `DeliveryManProfileViewData.isColdStart` (`reviewCount < 5`) — so the
/// previews below pass the value that view data would have computed.
Widget _deliveryManProfileHeaderHosted({
  required String name,
  required double rating,
  required int reviewCount,
  required String location,
  bool isVerified = true,
  bool isAvailable = true,
  bool isColdStart = false,
}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: 390,
      child: DeliveryManProfileHeader(
        name: name,
        // Always null — see the library doc above.
        avatarUrl: null,
        isVerified: isVerified,
        rating: rating,
        reviewCount: reviewCount,
        location: location,
        isAvailable: isAvailable,
        isColdStart: isColdStart,
      ),
    ),
  );
}

/// The happy path, and the only fixture that ships: `Kamal Hajj`, 4.3 over 113
/// reviews, Lebanon, online (`DevDeliveryManProfileFixtures.sample`).
///
/// Everything on at once — initial avatar, name + SealCheck, star + score,
/// pin + "Lebanon . Available". Two things to check in **AR RTL dark**: the
/// avatar and both meta glyphs must swap to the trailing edge (they are plain
/// [Row]s inside an `EdgeInsetsDirectional` padding, so they rely entirely on
/// ambient [Directionality]), and the name must stay legible — it is painted
/// with `colorScheme.secondaryContainer`, which is brand navy on white but a
/// dark tone on the dark scheme's equally dark surface.
///
/// Look at the separator too. The rating row renders "4.3 . 113 Reviews" — the
/// ARB value is `{rating} . {count}`, a full stop with a space on either side,
/// not the "·" the design writes — so it parses as a sentence break and a
/// screen reader announces it as one. `deliveryManProfileLocationAvailability`
/// has the same body.
@JeebPreview(group: 'delivery_man_profile', name: 'Populated (shipped fixture)', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderPopulated() => _deliveryManProfileHeaderHosted(
      name: 'Kamal Hajj',
      rating: 4.3,
      reviewCount: 113,
      location: 'Lebanon',
    );

/// D59 cold start: fewer than five reviews, so the aggregate score is hidden.
///
/// The catalog's own cold-start state (`batch_03_entries.dart`): Rana Ahmad,
/// two reviews, a perfect 5.0 that must NOT be shown. `_RatingRow` swaps the
/// star for `Icons.reviews_outlined` and drops the `profile_score` identifier
/// entirely, which is how QA asserts the score is absent — worth keeping in the
/// canvas beside [deliveryManProfileHeaderPopulated], because the two rows are
/// one glyph and one number apart and it is easy to "fix" this branch back into
/// showing a score.
///
/// The copy is the defect here: at one review it reads "1 Reviews".
/// `AppLocalizations` resolves this key by literal `{count}` substitution with
/// no ICU plural support, so it cannot be fixed in the ARB, and the Arabic
/// value `{count} تقييم` is the singular for every count from the other side.
@JeebPreview(group: 'delivery_man_profile', name: 'Cold start · score hidden (D59)', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderColdStart() => _deliveryManProfileHeaderHosted(
      name: 'Rana Ahmad',
      rating: 5,
      reviewCount: 2,
      location: 'Lebanon',
      isColdStart: true,
    );

/// What a client actually sees, because the offer card is the only route in.
///
/// `ClientOffersScreen._openJeeberProfile` builds the view data with
/// `location: ''` **unconditionally** and `isAvailable: true`, and falls the
/// name back to the localized `offersCardJeeberFallback` ("New Jeeber") when
/// the offer row carries a synthetic handle. A brand-new jeeber accepted off
/// that card therefore lands here: no location, no score, "0 Reviews".
///
/// This is the F9 regression guard made visible — `_AvailabilityRow` joins
/// location and availability with the separator only when a location is present,
/// so the row must read "Available" alone. A stray leading "· Available" (or
/// " . Available", the ARB's own separator) means the guard has been undone;
/// `delivery_man_profile_header_location_test.dart` asserts the same thing in
/// text, this shows it in the frame.
///
/// The verified badge is the thing to argue with. `DeliveryManProfileViewData`
/// defaults `isVerified` to **true** and the offer-card call site never passes
/// it, so an account with zero reviews and no name of its own is shown a
/// SealCheck — the strongest trust signal on the screen, granted by a default.
@JeebPreview(group: 'delivery_man_profile', name: 'From offer card · no location (F9)', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderNoLocation() => _deliveryManProfileHeaderHosted(
      name: 'New Jeeber',
      rating: 0,
      reviewCount: 0,
      location: '',
      isColdStart: true,
    );

/// Offline and unverified: the negative branch of both booleans at once.
///
/// The `'Sami' / 4.8 / 12 / 'Riyadh'` jeeber from
/// `delivery_man_profile_header_location_test.dart`, taken unavailable. This is
/// the only state with no SealCheck, so it is where the name row's spare 28 dp
/// goes back to the name, and the only state whose availability label is
/// negative.
///
/// Note what does NOT change: "Unavailable" is the same muted
/// `onSecondaryContainer` ink as "Available", on the same [Icons.location_on]
/// pin, in the same position. Availability is carried by one word — no colour,
/// no dot, no chip — so at a glance an offline jeeber and an online one are the
/// same card. In **AR RTL** the pair reads "الرياض . غير متاح", where the
/// negation is a separate leading word.
@JeebPreview(group: 'delivery_man_profile', name: 'Unavailable + unverified', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderUnavailable() => _deliveryManProfileHeaderHosted(
      name: 'Sami',
      rating: 4.8,
      reviewCount: 12,
      location: 'Riyadh',
      isVerified: false,
      isAvailable: false,
    );

/// An Arabic name over a Latin location — the majority case for this app, and
/// the mixed-direction state `AutoDirectionText` exists to serve.
///
/// `_NameText` picks the name's direction from its own first strong character
/// (UAX #9), so in the **EN light** rendering the name lays out RTL inside a
/// left-aligned column while "Lebanon . Available" below it stays LTR — and the
/// mirror image of that in **AR RTL**. Whichever locale you are in, one of these
/// two lines runs against the ambient direction.
///
/// The meta rows get no such treatment: `DeliveryManMetaRow` is a plain [Text],
/// so the location follows the ambient direction whatever script it is in. In
/// **AR RTL** a Latin location inside an Arabic template ("Lebanon . متاح") is
/// where that shows.
///
/// It is also the shortest name in this file that already wraps: measured at
/// 222 × 64 dp — two lines — at 1x, taking the header to 140 dp before anyone
/// touches the text-size slider. A four-word Arabic name is ordinary, so the
/// wrap is the common case, not the ceiling.
@JeebPreview(group: 'delivery_man_profile', name: 'Arabic name, Latin location', size: _deliveryManProfileHeaderWrappingBox)
Widget deliveryManProfileHeaderArabicName() => _deliveryManProfileHeaderHosted(
      name: 'كمال حاج الطرابلسي',
      rating: 4.9,
      reviewCount: 312,
      location: 'Lebanon',
    );

/// The layout ceiling: longest plausible name, longest plausible location, and
/// a four-digit review count.
///
/// Four defects share this frame:
///
///  * `_NameText` wraps its `AutoDirectionText` in a `Flexible` but passes no
///    `maxLines`/`overflow`, so — unlike `ClientHomeGreeting`, which clamps to
///    one line + ellipsis — the name does not ellipsize. It wraps to **three**
///    lines of the 222 dp verified column (measured 222 × 96 dp) and takes the
///    header from 112 dp to 172 dp at 1x and to **436 dp at 200% text**, which
///    is over half a 390 × 844 phone for the header alone and pushes the
///    reviews list it heads below the fold;
///  * `_NameRow` centres the badge (`CrossAxisAlignment.center`) against the
///    whole wrapped block — measured at y 50–70 against a name spanning
///    y 12–108 — so the SealCheck floats beside the middle line, reading as an
///    orphaned glyph rather than as a mark on the name;
///  * the location line truncates **at 1x**, on a full-size phone. `_MetaText`
///    sets `overflow: TextOverflow.ellipsis` with `maxLines: null`, which the
///    paragraph builder resolves to single-line truncation, and this label
///    wants more than the 226 dp it gets (`didExceedMaxLines` is true). Because
///    `Text` cuts the END, what disappears is " . Available" — the availability
///    state — leaving a truncated place name where the answer to "can this
///    jeeber take my delivery?" should be;
///  * `rating.toStringAsFixed(1)` renders 4.96 as **"5.0"**. A jeeber who is
///    not perfect is presented as perfect — and the count beside it is
///    interpolated as `'$count'`, so it reads "1284" ungrouped in English and
///    in Western digits in Arabic, where the rest of the label is Arabic script.
@JeebPreview(group: 'delivery_man_profile', name: 'Longest plausible content', size: _deliveryManProfileHeaderPhoneScreenBox)
Widget deliveryManProfileHeaderLongest() => _deliveryManProfileHeaderHosted(
      name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      rating: 4.96,
      reviewCount: 1284,
      location: 'Beirut, Mount Lebanon Governorate',
    );
