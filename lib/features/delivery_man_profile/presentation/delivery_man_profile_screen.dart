import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/delivery_man_profile_view_data.dart';
import 'widgets/delivery_man_profile_header.dart';
import 'widgets/delivery_reviews_header.dart';
import 'widgets/delivery_reviews_list.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/delivery_man_profile_screen_fixtures.dart';


















class DeliveryManProfileScreen extends StatelessWidget {
  const DeliveryManProfileScreen({super.key, required this.data});

  
  
  static const String rootId = 'delivery_man_profile_screen_root';

  
  
  static const Key rootKey = Key('delivery-man-profile-screen-root');

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: rootId,
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: '',
          automaticallyImplyLeading: false,
          actions: [_CloseButton(label: l10n.deliveryManProfileCloseLabel)],
        ),
        body: _DeliveryManProfileBody(data: data),
      ),
    );
  }
}

class _DeliveryManProfileBody extends StatelessWidget {
  const _DeliveryManProfileBody({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: DeliveryManProfileScreen.rootKey,
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
      children: [
        _Header(data: data),
        const SizedBox(height: Spacing.large),
        DeliveryReviewsHeader(
          reviewCount: data.reviewCount,
          onViewAll: () => _openAllReviews(context),
        ),
        
        DeliveryReviewsList(reviews: data.reviews),
      ],
    );
  }

  
  
  
  
  
  void _openAllReviews(BuildContext context) {
    final jeeberId = data.jeeberId;
    context.pushNamed(
      'reviews-list',
      queryParameters: {
        if (jeeberId != null && jeeberId.isNotEmpty) 'jeeberId': jeeberId,
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    return DeliveryManProfileHeader(
      name: data.name,
      avatarUrl: data.avatarUrl,
      isVerified: data.isVerified,
      rating: data.rating,
      reviewCount: data.reviewCount,
      location: data.location,
      isAvailable: data.isAvailable,
      isColdStart: data.isColdStart, 
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    
    return Semantics(
      identifier: 'profile_close',
      button: true,
      label: label,
      child: IconButton(
        key: const Key('delivery-man-profile-close'),
        icon: const Icon(Icons.close),
        tooltip: label,
        color: Theme.of(context).colorScheme.secondaryContainer,
        onPressed: () => _close(context),
      ),
    );
  }

  
  
  
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/delivery_man_profile/delivery_man_profile_screen_preview_test.dart
// ===========================================================================
//
// [DeliveryManProfileScreen] takes its entire world as ONE value — a
// `DeliveryManProfileViewData` handed in by the caller. There is no cubit, no
// repository and no GetIt lookup anywhere on the surface, so every state below
// is one constructor argument and is network-free by construction rather than
// by the guard in [jeebPreviewHost].
//
// The fixtures are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/delivery_man_profile_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_03_entries.dart`), so the designer's browser
// and this canvas name the same states with the same data. The first three
// previews below ARE the catalog's three states; the rest are ceilings and
// production states the catalog does not carry.
//
// Two things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and the
//    screen's own `Scaffold + OMDSAppBar` paints inside it — the same nesting
//    the Screen Catalog produces. The frame is therefore pinned in the TREE as
//    well as in `size:`, because an unpinned screen is 800 pt wide in the
//    render tests and none of the layout under review applies at that width.
//    (The render surface is 800 x 600, so the phone box's 844 is enforced down
//    to what the host has; the compact 320 x 568 box fits and is exact.)
//  * **Both of the screen's edges are wired, so the canvas is honest to tap
//    in.** `profile_close` and `profile_view_all_reviews` are the only two
//    affordances, and both navigate: [_DeliveryManProfileScreenHost] puts a
//    real `Router` above the screen with the profile PUSHED onto an
//    offer-review-list stand-in, which is the production posture (JM-067: the
//    profile is pushed from the offer card, so `profile_close` pops back to
//    it). Without that stack `context.canPop()` is false and the close button
//    silently takes the cold-deep-link branch to `/`, which is a fact about
//    the preview rather than about the screen.
//
// What these previews are for — the states that break:
//
//  * **The screen has no loading state and no error state at all.** It is a
//    pure value, so "the reviews are still loading", "the reviews call failed"
//    and "this jeeber has no reviews" are the SAME picture: the
//    `OmdsEmptyState` reading "No reviews yet". [deliveryManProfileScreenEmpty]
//    and [deliveryManProfileScreenFromOfferCard] are that identity, previewed
//    adjacently and deliberately — the second one carries a header claiming
//    113 reviews over the empty list, and nothing on the surface reconciles
//    them or offers a retry.
//  * **[deliveryManProfileScreenFromOfferCard] is the ONLY state a user can
//    actually reach.** `ClientOffersScreen._openJeeberProfile` is the single
//    in-app push to this route and it hardcodes `reviews: const []` and
//    `location: ''`. The populated state below it is a debug fixture: it is
//    what the catalog, the canvas and the dev-seam capture path render, and
//    what nobody using the app has ever seen.
//  * **The count line is rendered twice under D59 cold start.** The identity
//    header substitutes `deliveryManProfileReviewsCount` for the hidden
//    aggregate score, and the reviews section header renders the same key
//    directly beneath it — "2 Reviews" over "2 Reviews" in
//    [deliveryManProfileScreenColdStart]. At one review both read the
//    ungrammatical **"1 Reviews"** ([deliveryManProfileScreenFirstReview]):
//    the ARB value is `"{count} Reviews"` with a plain `int` placeholder, no
//    ICU plural, and Arabic's `"{count} تقييم"` is one fixed form for every
//    count.
//  * **The close "X" is the only exit, and it is inked with a container
//    role.** `_CloseButton` passes `colorScheme.secondaryContainer` as the
//    icon colour. In the light scheme that role is hard-coded to the brand
//    navy and reads fine on the white app bar; the dark scheme is
//    `ColorScheme.fromSeed(_jeebNavy, dark)`, where the same role is a dark
//    container tone on an almost equally dark `surface` — under the 3:1 WCAG
//    floor for a UI component, pinned in this preview's render test. Open the
//    **AR RTL dark** rendering of [deliveryManProfileScreenPopulated]: the way
//    out of a modal screen is nearly invisible. The same role-as-ink mistake
//    is flagged from the other side in `delivery_reviews_header.dart` and
//    `delivery_man_profile_header.dart`.
//  * **`reviewCount` and `reviews.length` are independent inputs and the
//    screen never reconciles them.** The populated fixture shows two cards
//    under a header that says 113, with no "showing 2 of 113" and no
//    pagination — "View all" is the only way on, and it leaves the screen.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryManProfileScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports, and roughly what an Android
/// multi-window split leaves a foreground app. The identity header is an 88 pt
/// avatar plus a details column, so this is where the name and the
/// location/availability line run out of room first.
const Size _deliveryManProfileScreenCompactBox = Size(320, 568);

/// Catches a navigation and names it, so a tap in the canvas shows WHICH
/// destination the edge resolved to.
class _DeliveryManProfileScreenRouteStandIn extends StatelessWidget {
  const _DeliveryManProfileScreenRouteStandIn({
    required this.leg,
    this.query = '',
  });

  final String leg;

  /// The raw query string, which is how `profile_view_all_reviews` carries the
  /// jeeber (`?jeeberId=…`) — the one destination whose target depends on more
  /// than the path.
  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic route id, not shipped copy, and a latin
          // identifier reorders visually inside an RTL paragraph.
          query.isEmpty ? leg : '$leg?$query',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [DeliveryManProfileScreen], with the profile
/// PUSHED onto an offer-review-list stand-in exactly as JM-067 describes.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt every frame would drop the navigation state
/// `context.canPop()` reads. `Router.withConfig` is what `MaterialApp.router`
/// does internally, so this adds a Router and nothing else — theme, locale and
/// text scale still come from the preview host above it.
class _DeliveryManProfileScreenHost extends StatefulWidget {
  const _DeliveryManProfileScreenHost({required this.data});

  final DeliveryManProfileViewData data;

  @override
  State<_DeliveryManProfileScreenHost> createState() =>
      _DeliveryManProfileScreenHostState();
}

class _DeliveryManProfileScreenHostState
    extends State<_DeliveryManProfileScreenHost> {
  /// Two matched routes, so the Navigator holds TWO pages and
  /// `context.canPop()` is true — the production stack, where the profile was
  /// pushed from an offer card. Landing straight on the profile instead would
  /// preview the cold-deep-link fallback (`context.go('/')`) and nothing else.
  late final GoRouter _router = GoRouter(
    initialLocation: '/requests/preview/offers/jeeber',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const _DeliveryManProfileScreenRouteStandIn(
          leg: 'home (cold deep-link fallback)',
        ),
      ),
      GoRoute(
        path: '/requests/:id/offers',
        name: 'offer-review',
        builder: (_, _) => const _DeliveryManProfileScreenRouteStandIn(
          leg: 'offer-review-list',
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'jeeber',
            builder: (_, _) => DeliveryManProfileScreen(data: widget.data),
          ),
        ],
      ),
      // Pushed BY NAME with a query parameter, so it cannot be folded into the
      // stack above.
      GoRoute(
        path: '/profile/delivery-man/reviews',
        name: 'reviews-list',
        builder: (_, GoRouterState state) =>
            _DeliveryManProfileScreenRouteStandIn(
          leg: 'reviews-list',
          query: state.uri.query,
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

/// Pins the screen to a device-sized frame inside whatever box the canvas
/// gives it.
Widget _deliveryManProfileScreenHosted(
  DeliveryManProfileViewData data, {
  Size box = _deliveryManProfileScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: box.width,
      height: box.height,
      child: _DeliveryManProfileScreenHost(data: data),
    ),
  );
}

/// The shipped Figma seed: Kamal Hajj, 4.3 over 113 reviews, Lebanon, online,
/// two lorem reviews on the page (`DevDeliveryManProfileFixtures.sample`, the
/// catalog's first state).
///
/// The baseline a reviewer signs off — and a state no user can reach: the only
/// in-app route into this screen passes an empty review list (see
/// [deliveryManProfileScreenFromOfferCard]). Read it as the design intent
/// rather than as a rendering of production data.
///
/// Two things to look at in the **AR RTL dark** rendering. The close "X" — the
/// only way off this modal screen — is inked with `colorScheme.secondaryContainer`,
/// a container role, and in the dark scheme that is a dark tone on the app
/// bar's equally dark `surface`. And the header claims 113 reviews above a list
/// of two, with nothing between them to say so.
///
/// Matrixed because this is the fullest surface the screen has: an identity row
/// that mirrors, a section header whose count and button swap edges, and review
/// cards whose avatars and stars lead from the other side.
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'Populated · shipped fixture',
  size: _deliveryManProfileScreenPhoneBox,
  matrix: true,
)
Widget deliveryManProfileScreenPopulated() =>
    _deliveryManProfileScreenHosted(DeliveryManProfileScreenFixtures.populated);

/// D59 cold start: under five reviews, so the aggregate score is hidden
/// (the catalog's second state).
///
/// `_RatingRow` swaps the star for `Icons.reviews_outlined`, drops the
/// `profile_score` Semantics identifier — which is how QA asserts the score is
/// absent — and renders the review COUNT in the score's place. The reviews
/// section header then renders the same string again, immediately below it: on
/// this screen "2 Reviews" appears twice, one line under the other, saying the
/// same thing in two different type styles. Neither line is wrong on its own;
/// together they read as a rendering bug, and the duplication is only visible
/// with the whole screen composed — pinned in this preview's render test.
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'Cold start · score hidden (D59)',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenColdStart() =>
    _deliveryManProfileScreenHosted(DeliveryManProfileScreenFixtures.coldStart);

/// A jeeber nobody has reviewed yet (the catalog's third state), and the state
/// every jeeber is in on the day they are approved.
///
/// The whole list is replaced by an `OmdsEmptyState` — "No reviews yet" —
/// under a section header that still offers a live "View all", which pushes the
/// paginated reviews route so a client can arrive at a second empty list. The
/// header above is in cold start too, so the score is hidden and the count line
/// reads "0 Reviews" twice.
///
/// This is also the screen's error state and its loading state, because it has
/// neither: nothing here distinguishes "no reviews" from "the reviews did not
/// load".
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'Empty · no reviews yet',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenEmpty() =>
    _deliveryManProfileScreenHosted(DeliveryManProfileScreenFixtures.empty);

/// **The only state a user can actually reach.**
///
/// `ClientOffersScreen._openJeeberProfile` is the single in-app push to this
/// route, and it builds the view data from the offer row with
/// `reviews: const <DeliveryReviewData>[]` and `location: ''` hardcoded, with
/// `isVerified` left at its `true` default. So a real tap on a jeeber's name
/// produces exactly this: an identity header claiming a 4.7 average over 113
/// reviews, a section header repeating "113 Reviews", and an empty state
/// underneath saying there are none.
///
/// Three defects share the frame, and only the first is about copy:
///
///  * the two halves of the screen contradict each other, and there is no
///    loading state, no error state and no retry to explain the gap;
///  * F9: with `location: ''`, `_AvailabilityRow` must render "Available"
///    alone — a stray leading " . Available" means the guard was undone;
///  * the verified badge is granted by a DEFAULT. Nothing on the offer path
///    ever sets `isVerified`, so every jeeber reached this way wears the
///    strongest trust mark on the screen.
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'From the offer card · 113 reviews, none shown',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenFromOfferCard() => _deliveryManProfileScreenHosted(
      DeliveryManProfileScreenFixtures.fromOfferCard,
    );

/// The first review a jeeber ever earns, announced as **"1 Reviews"** — twice.
///
/// `deliveryManProfileReviewsCount` is `"{count} Reviews"` in `app_en.arb` with
/// a plain `int` placeholder and no `plural` select, and `AppLocalizations`
/// resolves it by literal `replaceFirst('{count}', '$count')`. Under D59 cold
/// start that key is also what stands in for the hidden score, so the
/// ungrammatical string is rendered once in the identity header and once in the
/// section header below it.
///
/// Reachable the moment any jeeber gets their first rating, i.e. constantly,
/// and invisible to a preview that only ever renders 113. Arabic is worse, not
/// better: `"{count} تقييم"` is a single fixed form, so the 3–10 band
/// (`تقييمات`) is wrong there too. Fixing it is an ARB change plus a
/// regenerate; this state exists so the bug is on screen instead of in a
/// backlog.
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'First review · "1 Reviews", twice',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenFirstReview() => _deliveryManProfileScreenHosted(
      DeliveryManProfileScreenFixtures.firstReview,
    );

/// The layout ceiling at phone width: longest plausible name, longest plausible
/// location, a four-digit review count and three long reviews.
///
/// Four things to read here, all of them in the widgets this screen composes:
///
///  * the name does not ellipsize. `_NameText` wraps its `AutoDirectionText` in
///    a `Flexible` but passes no `maxLines`/`overflow`, so it wraps rather than
///    truncating and the header grows with it — 112 → 172 pt at 1x and 436 pt
///    at the 200% ceiling, measured on this same name in
///    `delivery_man_profile_header.dart` — which is over half a 390 x 844
///    phone for the header alone, pushing the reviews it heads below the fold;
///  * the location line truncates at 1x on a full-size phone, and because
///    `Text` cuts the END what disappears is " . Available" — the availability
///    state, i.e. the answer to "can this jeeber take my delivery?";
///  * `rating.toStringAsFixed(1)` renders 4.96 as "5.0". A jeeber who is not
///    perfect is presented as perfect, and the count beside it is interpolated
///    as `'$count'` — "1284", ungrouped, in Western digits even in Arabic;
///  * the third review is anonymous (blank reviewer name) and carries an avatar
///    URL. The card must attribute it to the localized "Jeeb customer" with the
///    neutral "J" initial and DROP the URL — if a photo ever appears there, a
///    private image is being shown beside an anonymised name.
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'Longest plausible content',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenLongest() => _deliveryManProfileScreenHosted(
      DeliveryManProfileScreenFixtures.longestContent,
    );

/// The mixed-direction majority case at the 320 pt floor: an Arabic name over a
/// Latin location, offline, on the narrowest phone the app supports.
///
/// **This is the preview to open**, and the rendering to open is AR RTL dark.
/// `AutoDirectionText` picks the name's direction from its own first strong
/// character, so in the EN rendering the name lays out RTL inside a
/// left-aligned column while "Beirut, Mount Lebanon Governorate . Unavailable"
/// below it stays LTR — and the mirror image of that in AR. The meta rows get
/// no such treatment: `DeliveryManMetaRow` is a plain `Text`, so a Latin
/// location inside an Arabic template follows the ambient direction whatever
/// script it is in.
///
/// 320 pt is also where the truncation above stops being a ceiling and becomes
/// the default: the details column is what is left of 320 pt after an 88 pt
/// avatar and two 20 pt gutters, and "Unavailable" is the word being cut.
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'Compact 320 pt · Arabic name',
  size: _deliveryManProfileScreenCompactBox,
  matrix: true,
)
Widget deliveryManProfileScreenCompactArabicName() =>
    _deliveryManProfileScreenHosted(
      DeliveryManProfileScreenFixtures.arabicName,
      box: _deliveryManProfileScreenCompactBox,
    );
