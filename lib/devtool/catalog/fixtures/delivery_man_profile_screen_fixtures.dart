// Shared dev-only fixtures for `DeliveryManProfileScreen` (screen 27,

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

  /// **Catalog state 1** — the shipped Figma seed: Kamal Hajj, 4.3 over 113
  /// reviews, Lebanon, online, two lorem reviews on the page.
  static const DeliveryManProfileViewData populated =
      DevDeliveryManProfileFixtures.sample;

  /// **Catalog state 2** — D59 cold start: fewer than
  /// [DeliveryManProfileViewData.coldStartThreshold] reviews, so the aggregate
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
  static const DeliveryManProfileViewData fromOfferCard =
      DeliveryManProfileViewData(
    name: 'Maya Rizk',
    rating: 4.7,
    reviewCount: 113,
    // Hardcoded empty by the offer-card call site (F9): `_AvailabilityRow`
    location: '',
    isAvailable: true,
    jeeberId: 'jeeber-maya',
    reviews: <DeliveryReviewData>[],
  );

  /// The first review a jeeber ever earns, which the copy calls
  /// **"1 Reviews"** — twice, one line above the other.
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
