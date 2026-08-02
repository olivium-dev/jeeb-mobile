import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../../../core/role/jeeber_role_activator.dart';
import '../../../core/role/role_availability_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../jeeber_request_feed/cubit/request_feed_state.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../jeeber_request_feed/data/dio_submitted_offers_repository.dart';
import '../../settings/domain/role_switch_repository.dart';
import '../application/availability_cubit.dart';
import '../application/availability_state.dart';
import '../domain/entities/availability_status.dart';
import '../domain/entities/feed_request.dart';
import 'widgets/jeeber_active_deliveries_banner.dart';
import 'widgets/jeeber_feed_tab_view.dart';
import 'widgets/jeeber_no_requests_view.dart';
import 'widgets/jeeber_unregistered_view.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';

class JeeberHomeScreen extends StatefulWidget {
  const JeeberHomeScreen({
    super.key,
    this.onOpenFeedRequest,
    this.onRegister,
    this.isRegistered = true,
    this.profileName,
    this.requestFeedCubit,
    this.registerCtaIdentifier,
    this.submittedOffersCubitFactory,
    this.activeDeliveriesBanner,
  });

  static const Key scaffoldKey = Key('jeeber-home-screen-scaffold');
  static const Key loadErrorRetryKey = Key('jeeber-home-screen-load-retry');

  final ValueChanged<FeedRequest>? onOpenFeedRequest;

  final VoidCallback? onRegister;

  final bool isRegistered;

  final String? profileName;

  final RequestFeedCubit? requestFeedCubit;

  final String? registerCtaIdentifier;

  final SubmittedOffersCubit Function()? submittedOffersCubitFactory;

  final Widget? activeDeliveriesBanner;

  @override
  State<JeeberHomeScreen> createState() => _JeeberHomeScreenState();
}

class _JeeberHomeScreenState extends State<JeeberHomeScreen> {
  bool _bootstrapped = false;

  SubmittedOffersCubit? _submittedOffersCubit;
  bool _submittedOffersResolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    if (widget.isRegistered) {
      context.read<AvailabilityCubit>().load();
    }
  }

  SubmittedOffersCubit? _resolveSubmittedOffersCubit() {
    if (_submittedOffersResolved) return _submittedOffersCubit;
    _submittedOffersResolved = true;
    if (!widget.isRegistered) return null;
    final factory = widget.submittedOffersCubitFactory;
    if (factory != null) {
      _submittedOffersCubit = factory();
    } else if (sl.isRegistered<Dio>()) {
      _submittedOffersCubit = SubmittedOffersCubit(
        repository: DioSubmittedOffersRepository(
          dio: sl<Dio>(),
          tokenStore: sl.isRegistered<AuthTokenStore>()
              ? sl<AuthTokenStore>()
              : null,
        ),
        lifecycleSignals: sl.isRegistered<OfferLifecycleSignals>()
            ? sl<OfferLifecycleSignals>().stream
            : null,
      );
    }
    return _submittedOffersCubit;
  }

  @override
  void dispose() {
    _submittedOffersCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'jeeber_home_root',
      container: true,
      child: Scaffold(
        key: JeeberHomeScreen.scaffoldKey,
        body: _RootBody(
          isRegistered: widget.isRegistered,
          profileName: widget.profileName,
          onRegister: widget.onRegister,
          onOpenFeedRequest: widget.onOpenFeedRequest,
          requestFeedCubit: widget.requestFeedCubit,
          registerCtaIdentifier: widget.registerCtaIdentifier,
          submittedOffersCubit: _resolveSubmittedOffersCubit(),
          activeDeliveriesBanner: widget.activeDeliveriesBanner,
        ),
      ),
    );
  }
}

class _RootBody extends StatelessWidget {
  const _RootBody({
    required this.isRegistered,
    required this.profileName,
    required this.onRegister,
    required this.onOpenFeedRequest,
    required this.requestFeedCubit,
    required this.registerCtaIdentifier,
    required this.submittedOffersCubit,
    required this.activeDeliveriesBanner,
  });

  final bool isRegistered;
  final String? profileName;
  final VoidCallback? onRegister;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final RequestFeedCubit? requestFeedCubit;
  final String? registerCtaIdentifier;
  final SubmittedOffersCubit? submittedOffersCubit;
  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    if (!isRegistered) {
      return JeeberUnregisteredView(
        profileName: profileName,
        onRegister: onRegister ?? () {},
        ctaIdentifier: registerCtaIdentifier,
      );
    }
    final body = _RegisteredBody(
      profileName: profileName,
      onOpenFeedRequest: onOpenFeedRequest,
      hasFeedCubit: requestFeedCubit != null,
      submittedOffersCubit: submittedOffersCubit,
      activeDeliveriesBanner: activeDeliveriesBanner,
    );
    if (requestFeedCubit == null) return body;
    return BlocProvider<RequestFeedCubit>.value(
      value: requestFeedCubit!,
      child: body,
    );
  }
}

class _RegisteredBody extends StatefulWidget {
  const _RegisteredBody({
    required this.profileName,
    required this.onOpenFeedRequest,
    required this.hasFeedCubit,
    required this.submittedOffersCubit,
    required this.activeDeliveriesBanner,
  });

  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;
  final SubmittedOffersCubit? submittedOffersCubit;
  final Widget? activeDeliveriesBanner;

  @override
  State<_RegisteredBody> createState() => _RegisteredBodyState();
}

class _RegisteredBodyState extends State<_RegisteredBody> {
  static const int _autoActivateMaxAttempts = 5;
  static const Duration _autoActivateRetryDelay = Duration(seconds: 2);

  bool _autoActivateTried = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AvailabilityCubit, AvailabilityViewState>(
      listenWhen: (prev, curr) =>
          prev.toggleError != curr.toggleError ||
          (curr.loadPhase == AvailabilityLoadPhase.loadError &&
              prev.loadPhase != AvailabilityLoadPhase.loadError),
      listener: _onStateChange,
      builder: (context, view) => _RegisteredViewSwitch(
        view: view,
        profileName: widget.profileName,
        onOpenFeedRequest: widget.onOpenFeedRequest,
        hasFeedCubit: widget.hasFeedCubit,
        submittedOffersCubit: widget.submittedOffersCubit,
        activeDeliveriesBanner: widget.activeDeliveriesBanner,
      ),
    );
  }

  void _onStateChange(BuildContext context, AvailabilityViewState view) {
    if (view.toggleError) _showToggleErrorSnackbar(context, view);
    if (view.loadPhase == AvailabilityLoadPhase.loadError) {
      unawaited(_autoActivateJeeber());
    }
  }

  void _showToggleErrorSnackbar(
    BuildContext context,
    AvailabilityViewState view,
  ) {
    if (!view.toggleError) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showOmdsSnackbar(context, message: l10n.availabilityToggleErrorBody);
  }

  Future<void> _autoActivateJeeber() async {
    if (_autoActivateTried) return;
    _autoActivateTried = true;
    final roleCubit = context.read<RoleCubit?>();
    final roleAvailabilityCubit = context.read<RoleAvailabilityCubit?>();
    if (roleCubit == null ||
        roleAvailabilityCubit == null ||
        !sl.isRegistered<RoleSwitchRepository>()) {
      return; // no activator wired — leave the manual Retry CTA untouched
    }
    final availabilityCubit = context.read<AvailabilityCubit>();
    final activator = JeeberRoleActivator(
      roleSwitch: sl<RoleSwitchRepository>(),
      roleCubit: roleCubit,
      availabilityCubit: roleAvailabilityCubit,
    );
    for (var attempt = 0; attempt < _autoActivateMaxAttempts; attempt++) {
      final outcome = await activator.activate();
      if (!mounted) return;
      if (outcome == JeeberActivationOutcome.activated) {
        availabilityCubit.load(); // reload with the re-minted jeeber token
        return;
      }
      if (attempt < _autoActivateMaxAttempts - 1) {
        await Future<void>.delayed(_autoActivateRetryDelay);
        if (!mounted) return;
      }
    }
  }
}

class _RegisteredViewSwitch extends StatelessWidget {
  const _RegisteredViewSwitch({
    required this.view,
    required this.profileName,
    required this.onOpenFeedRequest,
    required this.hasFeedCubit,
    required this.submittedOffersCubit,
    required this.activeDeliveriesBanner,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;
  final SubmittedOffersCubit? submittedOffersCubit;
  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    if (view.loadPhase == AvailabilityLoadPhase.loadError) {
      return _LoadErrorView(
        onRetry: () => context.read<AvailabilityCubit>().load(),
      );
    }
    return _AvailableBody(
      view: view,
      profileName: profileName,
      onOpenFeedRequest: onOpenFeedRequest,
      hasFeedCubit: hasFeedCubit,
      submittedOffersCubit: submittedOffersCubit,
      activeDeliveriesBanner: activeDeliveriesBanner,
    );
  }
}

class _AvailableBody extends StatelessWidget {
  const _AvailableBody({
    required this.view,
    required this.profileName,
    required this.onOpenFeedRequest,
    required this.hasFeedCubit,
    required this.submittedOffersCubit,
    required this.activeDeliveriesBanner,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;
  final SubmittedOffersCubit? submittedOffersCubit;
  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    if (!hasFeedCubit || view.status.state != AvailabilityState.online) {
      return _NoRequestsScope(
        view: view,
        profileName: profileName,
        activeDeliveriesBanner: activeDeliveriesBanner,
      );
    }
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, feedState) => feedState.requests.isEmpty
          ? OmdsPullToRefresh(
              onRefresh: () => context.read<RequestFeedCubit>().refresh(),
              child: _NoRequestsScope(
                view: view,
                profileName: profileName,
                activeDeliveriesBanner: activeDeliveriesBanner,
              ),
            )
          : _FeedTabBody(
              profileName: profileName,
              onOpenFeedRequest: onOpenFeedRequest,
              submittedOffersCubit: submittedOffersCubit,
              activeDeliveriesBanner: activeDeliveriesBanner,
            ),
    );
  }
}

class _NoRequestsScope extends StatelessWidget {
  const _NoRequestsScope({
    required this.view,
    required this.profileName,
    required this.activeDeliveriesBanner,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AvailabilityCubit>();
    return JeeberNoRequestsView(
      view: view,
      profileName: profileName,
      activeDeliveriesBanner:
          activeDeliveriesBanner ?? const JeeberActiveDeliveriesBanner(),
      onToggle: cubit.toggle,
      onExtendActivity: cubit.extendActivity,
    );
  }
}

class _FeedTabBody extends StatelessWidget {
  const _FeedTabBody({
    required this.profileName,
    required this.onOpenFeedRequest,
    required this.submittedOffersCubit,
    this.activeDeliveriesBanner,
  });

  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final SubmittedOffersCubit? submittedOffersCubit;

  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    return JeeberFeedTabView(
      profileName: profileName,
      leadingBanner: activeDeliveriesBanner,
      onOpenRequest: onOpenFeedRequest == null
          ? null
          : (req) => onOpenFeedRequest!(
              FeedRequest(
                id: req.id,
                shortLabel: req.pickup.label,
                description: req.itemsSummary,
              ),
            ),
      submittedOffersCubit: submittedOffersCubit,
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
        child: _LoadErrorContent(
          title: l10n.availabilityLoadError,
          retryLabel: l10n.availabilityLoadRetry,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

class _LoadErrorContent extends StatelessWidget {
  const _LoadErrorContent({
    required this.title,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.signal_wifi_off,
          size: Sizes.threeXLarge,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: Spacing.medium),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.medium),
        Semantics(
          identifier: 'jeeber_home_load_error_retry_cta',
          container: true,
          button: true,
          child: OmdsPrimaryButton(
            key: JeeberHomeScreen.loadErrorRetryKey,
            text: retryLabel,
            onTap: onRetry,
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
// Render tests: test/previews/jeeber_home/jeeber_home_screen_preview_test.dart
// ===========================================================================
//
// [JeeberHomeScreen] is the jeeber's whole dashboard. It renders no content of
// its own — it is a four-way branch that picks a body:
//
//     isRegistered == false                     → JeeberUnregisteredView
//     loadPhase    == loadError                 → _LoadErrorView (retry)
//     no feed cubit, or availability != online  → JeeberNoRequestsView
//     online + feed cubit + rows                → JeeberFeedTabView
//
// Each of those leaves is previewed in its own file. What is on review HERE is
// the branch: which body a given pair of collaborators produces, and what the
// two host-injected extras (the feed cubit, the active-deliveries banner) do to
// it. Those are exactly the seams every regression on this screen has landed in.
//
// The fakes and their canned data are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart`, shared with
// the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_04_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". Nothing there can reach the network: the availability gateway is
// [InMemoryAvailabilityGateway] or a never-completing stub, the feed cubit is
// seeded in its constructor instead of `start()`ed, the submitted-offers
// repository answers from a const list, and the active-deliveries banner is
// handed a canned [AcceptedConversationsRepository] so it never resolves
// `sl<Dio>()`. [jeebPreviewHost]'s guard is a net, not the plan.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold` paints inside it. Same nesting the Screen Catalog
//    produces.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_jeeberHomeScreenFramed] pins the same width the annotation's `size:`
//    asks for, so the render tests measure a phone and not the 800 pt test
//    surface. Height is pinned too but the render surface is 800x600, so a box
//    asking for 844 is enforced down to what the host has; the 320x568 box fits
//    and is therefore exact.
//  * **Tapping is not previewing.** The register CTA, a feed card and the
//    banner's "Open chat" all route through a [GoRouter] that does not exist
//    above a preview card, so every callback here is a no-op and the
//    self-routing paths (`_defaultMakeOffer`) return early on
//    `GoRouter.maybeOf(context) == null`. The availability toggle IS live — it
//    writes to the in-memory gateway — because that is the one control a
//    reviewer wants to flip in the canvas.
//
// The states are the five the Screen Catalog names plus five it does not, every
// one of which is a state that has already broken:
//
//   * **The cold read in flight.** There is no loading surface on this screen
//     at all: `_RegisteredViewSwitch` branches on `loadError` and nothing else,
//     so while `GET /v1/availability` is still outstanding the jeeber is shown
//     the settled OFFLINE dashboard — "You're offline", switch off — as a
//     statement of fact about a server answer that has not arrived.
//     [jeeberHomeScreenColdRead] is that frame, and it is byte-identical to
//     [jeeberHomeScreenOffline] apart from the greeting.
//   * **Online with an EMPTY feed cubit** (JEBV4-13 P2-6). The empty copy
//     promises "Pull down to refresh" and this variant was not wrapped in a
//     refresh indicator, so pulling fired no feed GET. It is now an
//     [OmdsPullToRefresh] over the same body [jeeberHomeScreenOnlineNoRequests]
//     renders without one — the pair is here so the two cannot silently
//     converge again.
//   * **A won delivery in the no-requests state** (S007-P1B, and the Fix-6
//     overflow on SM-S921B). The banner is an unbounded column of rows sitting
//     above the empty state; [jeeberHomeScreenActiveWork] puts it on the 360 pt
//     short viewport the overflow was measured on.
//   * **A won delivery ABOVE a live feed** (PUSH-UI-REACTION, 2026-07-05). The
//     card's builder was absent from the feed branch, so right after an
//     `offer_accepted` push — while the just-accepted request still keeps the
//     feed non-empty — the won delivery rendered nowhere for ~95 s.
//     [jeeberHomeScreenJustWonOverFeed] is that exact overlap.
//   * **The layout ceiling at 320 pt**, where the greeting, the availability
//     row and a feed card with an unfittable client name share the narrowest
//     phone the app supports.
//
// [jeeberHomeScreenUnregistered] is deliberately mounted with NO
// `BlocProvider<AvailabilityCubit>` above it. That is not an omission — it is
// the screen-19 crash: `didChangeDependencies` used to read the cubit
// unconditionally and threw `ProviderNotFound` before the first frame painted
// on the one path that never provides one.

/// The phone this dashboard is designed against (iPhone 14 / a tall Android).
const Size _jeeberHomeScreenPhoneBox = Size(390, 844);

/// The Galaxy S22 width on a short viewport — the device and the geometry the
/// active-delivery overflows in `test/features/shell/jeeber_dashboard_overflow_test.dart`
/// were measured on.
const Size _jeeberHomeScreenNarrowBox = Size(360, 640);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _jeeberHomeScreenCompactBox = Size(320, 568);

/// Greeting name for the ONLINE-idle state. Every registered state renders the
/// same greeting band, so each preview carries its own name: that is what lets
/// the render tests tell three structurally different screens apart when their
/// bodies are, by design, identical copy.
const String _jeeberHomeScreenOnlineIdleName = 'Nadia';

/// Greeting name for the still-loading cold read.
const String _jeeberHomeScreenColdReadName = 'Rima';

/// Greeting name for the online-with-an-empty-feed-cubit state.
const String _jeeberHomeScreenEmptyFeedName = 'Hiba';

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _jeeberHomeScreenFramed(
  Widget screen, {
  Size box = _jeeberHomeScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

/// Builds the screen the way the Dashboard shell builds it for a REGISTERED
/// jeeber: an ambient [AvailabilityCubit] (which `didChangeDependencies` then
/// `load()`s, so the real cold-start path runs), an optional pre-wired feed
/// cubit, and an optional host-injected active-deliveries banner.
Widget _jeeberHomeScreenHosted(
  AvailabilityCubit availability, {
  RequestFeedCubit? feed,
  Widget? activeDeliveriesBanner,
  String profileName = JeeberHomeScreenPreviewFixtures.profileName,
  Size box = _jeeberHomeScreenPhoneBox,
}) {
  return _jeeberHomeScreenFramed(
    BlocProvider<AvailabilityCubit>.value(
      value: availability,
      child: JeeberHomeScreen(
        profileName: profileName,
        requestFeedCubit: feed,
        activeDeliveriesBanner: activeDeliveriesBanner,
        submittedOffersCubitFactory:
            JeeberHomeScreenPreviewFixtures.submittedOffersCubit,
        onOpenFeedRequest: (_) {},
      ),
    ),
    box: box,
  );
}

/// The active-work disclosure the Dashboard host injects, over a canned list of
/// won orders instead of `GET /requests?role=jeeber`.
Widget _jeeberHomeScreenWonBanner(
  CannedAcceptedConversationsRepository repository,
) {
  return JeeberActiveDeliveriesBanner(
    repository: repository,
    onOpenChat: (_) {},
  );
}

/// State 1: the user has not completed delivery-man registration.
///
/// Mounted with NO `BlocProvider<AvailabilityCubit>` — the screen-19 condition.
/// The upsell view never reads availability, so the host does not provide it,
/// and this screen must come up anyway. If this preview ever shows a red error
/// box instead of the scooter hero, the guard in `didChangeDependencies` has
/// been removed.
///
/// The matrix is on because this is the one body that is a fixed [Column] with
/// an [Expanded] hero between a greeting and a bottom-pinned CTA: at 200% text
/// the headline and subtitle grow into the hero's box, and in Arabic the whole
/// stack mirrors.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Unregistered · upsell',
  size: _jeeberHomeScreenPhoneBox,
  matrix: true,
)
Widget jeeberHomeScreenUnregistered() => _jeeberHomeScreenFramed(
  JeeberHomeScreen(
    isRegistered: false,
    profileName: JeeberHomeScreenPreviewFixtures.profileName,
    onRegister: () {},
  ),
);

/// State 2, settled OFFLINE: the jeeber is registered and has not gone online.
///
/// The full availability section (title, switch row) rather than the compact
/// online switch, over the empty-feed hero. This is the dashboard a jeeber
/// opens the app to.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · no requests',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenOffline() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.offlineAvailability(),
);

/// State 2, ONLINE with no feed cubit wired — the dev-seam / bare-host path,
/// and the toggle-only state the widget tests drive.
///
/// The availability control collapses to the compact one-line switch; the body
/// is the same empty hero as offline. Note what is NOT here: no pull-to-refresh.
/// The empty copy says "Pull down to refresh" in a body that has no refresh
/// indicator at all, because the wrapper added by JEBV4-13 lives on the
/// feed-cubit branch only ([jeeberHomeScreenEmptyFeed]).
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · no requests',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenOnlineNoRequests() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  profileName: _jeeberHomeScreenOnlineIdleName,
);

/// The cold read still in flight — `GET /v1/availability` has not answered.
///
/// There is no spinner, no skeleton and no disabled state: `loadPhase` is
/// `loading`, `status` is still `AvailabilityStatus.initial`, and the screen
/// renders that as a settled OFFLINE dashboard. A jeeber on a slow connection
/// is therefore told "You're offline" by a screen that does not yet know, and
/// the switch they flip to fix it is racing the fetch that is about to
/// overwrite it.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Cold read in flight',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenColdRead() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.stalledAvailability(),
  profileName: _jeeberHomeScreenColdReadName,
);

/// The availability read FAILED — the whole dashboard is replaced by a centred
/// icon, one line and Retry.
///
/// This is also the surface JEBV4-271/279 self-heals: when the failure is the
/// forbidden-capability 403 (the jeeber role is granted server-side but the
/// local bearer is still client-scoped), `_autoActivateJeeber` re-mints the
/// token and reloads. It degrades to a no-op with no activator wired — which is
/// the case here, and is why this preview stays on the error body instead of
/// flickering through it.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Availability load failed · retry',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenLoadError() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.failingAvailability(),
);

/// State 3: online, feed cubit wired, and at least one live auction on it.
///
/// The only branch that reaches [JeeberFeedTabView], and the only one where the
/// greeting is followed by a search bar and two chip strips rather than by the
/// empty hero. Everything above the first card is ~290 pt of non-flexible
/// header (JEBV4-284), which is why this is previewed at full phone height.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · live feed',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenLiveFeed() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  feed: JeeberHomeScreenPreviewFixtures.feed(
    JeeberHomeScreenPreviewFixtures.incomingFeed(),
  ),
);

/// Online with a feed cubit whose snapshot came back EMPTY — JEBV4-13 P2-6.
///
/// The board is empty, so the screen falls back OUT of [JeeberFeedTabView] and
/// back onto the no-requests body — but wrapped in [OmdsPullToRefresh] this
/// time, so the "Pull down to refresh" the copy promises actually calls
/// `RequestFeedCubit.refresh()`. Visually identical to
/// [jeeberHomeScreenOnlineNoRequests]; the difference is entirely in what a
/// downward drag does, which is the kind of regression a canvas cannot show and
/// the render test therefore pins by widget type.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · empty feed · pull to refresh',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenEmptyFeed() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  feed: JeeberHomeScreenPreviewFixtures.emptyFeed(),
  profileName: _jeeberHomeScreenEmptyFeedName,
);

/// S007-P1B: a won order, reachable from the no-requests dashboard.
///
/// The jeeber's feed only lists OPEN requests, so an accepted order drops off
/// it and used to be reachable only by tapping a push. The injected banner puts
/// it back between the availability row and the empty hero.
///
/// Previewed at 360x640 — the SM-S921B geometry both Fix-6 overflows were found
/// on: the banner is an unbounded [Column] of rows above the empty state, and
/// each row is a non-wrapping `avatar + label + "Open chat"` [Row]. The matrix
/// is on for the second of those: the button label does not ellipsize, and
/// Arabic plus 200% text is where the trailing edge runs out.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Won delivery · no-requests state',
  size: _jeeberHomeScreenNarrowBox,
  matrix: true,
)
Widget jeeberHomeScreenActiveWork() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  activeDeliveriesBanner: _jeeberHomeScreenWonBanner(
    JeeberHomeScreenPreviewFixtures.wonOrders(),
  ),
  box: _jeeberHomeScreenNarrowBox,
);

/// PUSH-UI-REACTION (2026-07-05): the won delivery must also mount ABOVE a
/// live feed.
///
/// This is the two-second window nobody designed for. The jeeber offers on a
/// request, which keeps it on the board; the customer accepts; the
/// `offer_accepted` push refetch returns the won delivery. The feed is still
/// non-empty, so the screen is on the [JeeberFeedTabView] branch — and the
/// banner's builder was absent from that branch, so the just-won card rendered
/// nowhere until the feed emptied ~95 s later. Here it rides as the feed's
/// leading scroll item, above the first request card.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Just won · above a live feed',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenJustWonOverFeed() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  feed: JeeberHomeScreenPreviewFixtures.feed(
    JeeberHomeScreenPreviewFixtures.incomingFeed(),
  ),
  activeDeliveriesBanner: _jeeberHomeScreenWonBanner(
    JeeberHomeScreenPreviewFixtures.justWonOrder(),
  ),
);

/// The layout ceiling on the narrowest supported phone.
///
/// A jeeber name that cannot fit the greeting line, over a request whose client
/// name cannot fit the card header and whose description is a real-world food
/// order, at 320x568. The greeting and the card header both ellipsize
/// (`maxLines: 1`); the card's Ignore/Offer footer is a `Row(mainAxisSize: min)`
/// that does not, which is what the matrix is here to show — the EN light
/// rendering looks clean long after the other two have broken.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Longest content · compact 320',
  size: _jeeberHomeScreenCompactBox,
  matrix: true,
)
Widget jeeberHomeScreenLongestContent() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  feed: JeeberHomeScreenPreviewFixtures.feed(
    JeeberHomeScreenPreviewFixtures.longestContentFeed(),
  ),
  profileName: JeeberHomeScreenPreviewFixtures.longProfileName,
  box: _jeeberHomeScreenCompactBox,
);
