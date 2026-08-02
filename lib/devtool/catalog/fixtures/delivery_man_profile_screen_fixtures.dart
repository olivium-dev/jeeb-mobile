// Shared dev-only fixtures for `DeliveryManProfileScreen` (screen 27,
// jeeber-profile-reviews — the read-only profile a client sees after tapping a
// jeeber's name on an offer card).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_03_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart`.
//
// The catalog entry HAD fixtures to extract — two `DeliveryManProfileViewData`
// literals written inline in `batch_03_entries.dart` plus a reference to the
// shipped `DevDeliveryManProfileFixtures.sample` — so [populated], [coldStart]
// and [empty] below are those three states moved here verbatim, not rewritten.
// The catalog now names them from here, which is what stops the designer's
// browser and the engineer's canvas from drifting into two different "designed
// states" with the same label.
//
// The remaining values are preview-only ceilings and production states the
// catalog does not carry; they are declared here rather than in the preview
// section so the next person finds every state of this screen in one file. They
// are safe to promote into the catalog — each is a plain value, exactly like
// the three above.
//
// Everything here is an inert `const` value object. `DeliveryManProfileScreen`
// takes its whole world as one `DeliveryManProfileViewData` argument: there is
// no cubit, no repository and no GetIt lookup anywhere on the surface, so these
// fixtures are network-free by construction rather than by the
// `CatalogNetworkGuard` both hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'package:jeeb_mobile/features/delivery_man_profile/data/dev_delivery_man_profile_fixtures.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';

/// The designed states, named once for both dev surfaces.
abstract final class DeliveryManProfileScreenFixtures {
  /// The Figma seed body, as shipped in [DevDeliveryManProfileFixtures] — the
  /// longest review copy screen 27 was drawn against.
  static const String _lorem =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
      'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
      'amet, consectetur adipiscing elit.';

  /// A review long enough to push the card past a phone screenful on its own —
  /// the ceiling a real client can type into the rating form.
  static const String _longBody =
      'Picked up from a fourth-floor walk-up with no lift, waited twenty '
      'minutes while the shop re-packed a broken box, then called ahead to say '
      'he was five minutes out so I could meet him at the gate. Handled a '
      'fragile order without a single scratch and would not take a tip. If you '
      'are reading these to decide, this is the one to pick.';

  // ───────────────────────── Screen Catalog states ────────────────────────
  // The three the catalog entry has shown since it was written. Changing any
  // of them changes what a designer signs off against.

  /// **Catalog state 1** — the shipped Figma seed: Kamal Hajj, 4.3 over 113
  /// reviews, Lebanon, online, two lorem reviews on the page.
  ///
  /// Reference to the SAME `const` the debug route builds
  /// (`app_router.dart` → `/profile/delivery-man` with no `extra`), so the
  /// catalog, the canvas and the dev-seam capture path all render one object.
  ///
  /// Note what it asserts and the app cannot deliver: a populated review list.
  /// The only in-app route into this screen passes `reviews: const []` — see
  /// [fromOfferCard].
  static const DeliveryManProfileViewData populated =
      DevDeliveryManProfileFixtures.sample;

  /// **Catalog state 2** — D59 cold start: fewer than
  /// [DeliveryManProfileViewData.coldStartThreshold] reviews, so the aggregate
  /// score is hidden and the header shows the bare count instead.
  ///
  /// The 5.0 rating is deliberate: it is exactly the unearned score D59 exists
  /// to suppress, so a regression that re-shows the score is visible as
  /// "5.0 . 2 Reviews" rather than as a subtle shift.
  static const DeliveryManProfileViewData coldStart =
      DeliveryManProfileViewData(
    name: 'Rana Ahmad',
    rating: 5,
    reviewCount: 2,
    location: 'Lebanon',
    isAvailable: true,
    jeeberId: 'jeeber-rana',
    reviews: <DeliveryReviewData>[
      DeliveryReviewData(
        id: 'r1',
        reviewerName: 'Sami Fares',
        rating: 5,
        body: 'Fast and friendly, will request again.',
        daysAgo: 1,
      ),
    ],
  );

  /// **Catalog state 3** — a jeeber nobody has reviewed: the `reviews.isEmpty`
  /// branch, which swaps the whole list for an `OmdsEmptyState`, and the
  /// offline availability label.
  ///
  /// Every jeeber passes through this state on the day they are approved.
  static const DeliveryManProfileViewData empty = DeliveryManProfileViewData(
    name: 'New Jeeber',
    rating: 0,
    reviewCount: 0,
    location: 'Lebanon',
    isAvailable: false,
    reviews: <DeliveryReviewData>[],
  );

  // ─────────────────────────── preview-only states ────────────────────────

  /// What the app ACTUALLY renders, because the offer card is the only route
  /// in.
  ///
  /// `ClientOffersScreen._openJeeberProfile` builds the view data from the
  /// offer row and hardcodes `reviews: const <DeliveryReviewData>[]` and
  /// `location: ''`, with `isVerified` left at its `true` default. So a real
  /// tap produces an identity header claiming 113 reviews over an empty list
  /// that says "No reviews yet" — the two halves of the screen contradicting
  /// each other, with no loading state and no error state to explain it.
  ///
  /// Named for the call site rather than for a failure because it is not a
  /// failure path: it is the ONLY path. [populated] is reachable in debug
  /// builds only, through the fixture route.
  static const DeliveryManProfileViewData fromOfferCard =
      DeliveryManProfileViewData(
    name: 'Maya Rizk',
    rating: 4.7,
    reviewCount: 113,
    // Hardcoded empty by the offer-card call site (F9): `_AvailabilityRow`
    // must then render "Available" alone, with no leading separator.
    location: '',
    isAvailable: true,
    jeeberId: 'jeeber-maya',
    reviews: <DeliveryReviewData>[],
  );

  /// The first review a jeeber ever earns, which the copy calls
  /// **"1 Reviews"** — twice, one line above the other.
  ///
  /// `deliveryManProfileReviewsCount` is `"{count} Reviews"` with a plain `int`
  /// placeholder and no ICU plural, and the D59 cold-start branch renders that
  /// same key in the identity header as the substitute for the hidden score.
  /// The reviews-section header renders it again immediately below. Arabic is
  /// no better: `"{count} تقييم"` is one fixed form for every count.
  static const DeliveryManProfileViewData firstReview =
      DeliveryManProfileViewData(
    name: 'Nour Haddad',
    rating: 5,
    reviewCount: 1,
    location: 'Beirut',
    isAvailable: true,
    jeeberId: 'jeeber-nour',
    reviews: <DeliveryReviewData>[
      DeliveryReviewData(
        id: 'r1',
        reviewerName: 'Karl Assaf',
        rating: 5,
        body: 'Arrived early and called ahead.',
        daysAgo: 3,
      ),
    ],
  );

  /// The layout ceiling: longest plausible name, longest plausible location, a
  /// four-digit review count, a rounded-up rating and three long reviews.
  ///
  /// 4.96 is here on purpose — `rating.toStringAsFixed(1)` renders it as
  /// "5.0", rounding a trust signal in the one direction it must not round.
  static const DeliveryManProfileViewData longestContent =
      DeliveryManProfileViewData(
    name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
    rating: 4.96,
    reviewCount: 1284,
    location: 'Beirut, Mount Lebanon Governorate',
    isAvailable: true,
    isVerified: true,
    jeeberId: 'jeeber-abdulrahman',
    avatarUrl: null,
    reviews: <DeliveryReviewData>[
      DeliveryReviewData(
        id: 'r1',
        reviewerName: 'Ghassan Abou-Chakra',
        rating: 5,
        body: _longBody,
        daysAgo: 365,
      ),
      DeliveryReviewData(
        id: 'r2',
        reviewerName: 'Karl Assaf',
        rating: 4,
        body: _lorem,
        daysAgo: 40,
      ),
      // Blank name → the card must attribute to the localized anonymous label
      // and drop the avatar URL (D58 privacy guard), never render a bare "?".
      DeliveryReviewData(
        id: 'r3',
        reviewerName: '   ',
        rating: 3.5,
        body: '',
        daysAgo: 2,
        reviewerAvatarUrl: 'https://example.com/private-avatar.png',
      ),
    ],
  );

  /// The majority case for this app, at the narrow floor: an Arabic name over a
  /// Latin location, so one of the two lines always runs against the ambient
  /// direction whichever locale you are in.
  ///
  /// `AutoDirectionText` picks the name's direction from its own first strong
  /// character; `DeliveryManMetaRow` is a plain `Text` and follows the ambient
  /// direction whatever script its content is.
  static const DeliveryManProfileViewData arabicName =
      DeliveryManProfileViewData(
    name: 'عبد الرحمن المهندس الطرابلسي',
    rating: 4.9,
    reviewCount: 312,
    location: 'Beirut, Mount Lebanon Governorate',
    isAvailable: false,
    jeeberId: 'jeeber-abdulrahman-ar',
    reviews: <DeliveryReviewData>[
      DeliveryReviewData(
        id: 'r1',
        reviewerName: 'مروان الخوري',
        rating: 5,
        body: 'وصل قبل الموعد واتصل قبل الوصول.',
        daysAgo: 6,
      ),
    ],
  );
}
