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

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryManProfileScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports, and roughly what an Android
/// multi-window split leaves a foreground app. The identity header is an 88 pt
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
  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic route id, not shipped copy, and a latin
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
/// Stateful, and the router is built once and disposed with the host: a
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
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'Cold start · score hidden (D59)',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenColdStart() =>
    _deliveryManProfileScreenHosted(DeliveryManProfileScreenFixtures.coldStart);

/// A jeeber nobody has reviewed yet (the catalog's third state), and the state
/// every jeeber is in on the day they are approved.
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'Empty · no reviews yet',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenEmpty() =>
    _deliveryManProfileScreenHosted(DeliveryManProfileScreenFixtures.empty);

/// **The only state a user can actually reach.**
/// `ClientOffersScreen._openJeeberProfile` is the single in-app push to this
@JeebPreview(
  group: 'delivery_man_profile',
  name: 'From the offer card · 113 reviews, none shown',
  size: _deliveryManProfileScreenPhoneBox,
)
Widget deliveryManProfileScreenFromOfferCard() => _deliveryManProfileScreenHosted(
      DeliveryManProfileScreenFixtures.fromOfferCard,
    );

/// The first review a jeeber ever earns, announced as **"1 Reviews"** — twice.
/// `deliveryManProfileReviewsCount` is `"{count} Reviews"` in `app_en.arb` with
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
