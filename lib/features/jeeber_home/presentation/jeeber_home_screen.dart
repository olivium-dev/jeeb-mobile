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
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
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
        body: _JeeberHomeField(
          child: _RootBody(
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
      ),
    );
  }
}

/// R16/E3's background: the base wash with ONE quiet glow, and that glow is
/// GREEN — both tiles measure success at ≈16% at the `topEnd` anchor (token
/// sheet §8's success wash), not the client side's orange. `content`, not
/// `hero`: neither tile draws orbit rings, a periwinkle wash or twinkles.
class _JeeberHomeField extends StatelessWidget {
  const _JeeberHomeField({required this.child});

  /// Measured on both tiles at the top-end corner.
  static const double glowAlpha = 0.16;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `expand`: Scaffold lays its body out LOOSE, and the field's Stack would
    // otherwise shrink-wrap a short state and leave the page bottom unpainted.
    return SizedBox.expand(
      child: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowColor: context.jeebRoles.success.withValues(alpha: glowAlpha),
        child: child,
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
    if (view.loadPhase != AvailabilityLoadPhase.ready) {
      return const _LoadingView();
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
    final feed = context.read<RequestFeedCubit?>();
    return JeeberNoRequestsView(
      view: view,
      profileName: profileName,
      activeDeliveriesBanner:
          activeDeliveriesBanner ?? const JeeberActiveDeliveriesBanner(),
      onToggle: cubit.toggle,
      onExtendActivity: cubit.extendActivity,
      // Null with no feed cubit above (the unregistered / bare-test path):
      // E3's refresh pill is omitted rather than shipped inert.
      onRefresh: feed?.refresh,
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

/// The cold read, on the same empty family as E3 — the illustration skeleton
/// breathes and the CTA is withheld (`JeebEmptyState` loading).
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: JeebEmptyState(
        status: JeebEmptyStateStatus.loading,
        variant: JeebEmptyStateVariant.street,
        headline: AppLocalizations.of(context).requestFeedEmptyTitle,
      ),
    );
  }
}

/// The availability read failed — E3's block, danger-tinted, with the frozen
/// retry CTA re-homed onto its action slot.
class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: JeebEmptyState(
        status: JeebEmptyStateStatus.error,
        variant: JeebEmptyStateVariant.street,
        headline: l10n.availabilityLoadError,
        action: Semantics(
          identifier: 'jeeber_home_load_error_retry_cta',
          container: true,
          button: true,
          child: IntrinsicWidth(
            child: JeebCtaButton.primary(
              key: JeeberHomeScreen.loadErrorRetryKey,
              label: l10n.availabilityLoadRetry,
              expand: false,
              onTap: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
const Size _jeeberHomeScreenPhoneBox = Size(390, 844);

const Size _jeeberHomeScreenNarrowBox = Size(360, 640);

const Size _jeeberHomeScreenCompactBox = Size(320, 568);

const String _jeeberHomeScreenOnlineIdleName = 'Nadia';

const String _jeeberHomeScreenColdReadName = 'Rima';

const String _jeeberHomeScreenEmptyFeedName = 'Hiba';

Widget _jeeberHomeScreenFramed(
  Widget screen, {
  Size box = _jeeberHomeScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

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

Widget _jeeberHomeScreenWonBanner(
  CannedAcceptedConversationsRepository repository,
) {
  return JeeberActiveDeliveriesBanner(
    repository: repository,
    onOpenChat: (_) {},
  );
}

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

@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · no requests',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenOffline() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.offlineAvailability(),
);

@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · no requests',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenOnlineNoRequests() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  profileName: _jeeberHomeScreenOnlineIdleName,
);

@JeebPreview(
  group: 'jeeber_home',
  name: 'Cold read in flight',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenColdRead() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.stalledAvailability(),
  profileName: _jeeberHomeScreenColdReadName,
);

@JeebPreview(
  group: 'jeeber_home',
  name: 'Availability load failed · retry',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenLoadError() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.failingAvailability(),
);

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
