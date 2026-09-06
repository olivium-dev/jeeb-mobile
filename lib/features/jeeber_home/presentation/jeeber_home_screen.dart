import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../../../core/role/jeeber_role_activator.dart';
import '../../../core/role/role_availability_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/session/greeting_profile_cubit.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../l10n/app_localizations.dart';
import '../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../jeeber_request_feed/cubit/request_feed_state.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../jeeber_request_feed/data/dio_submitted_offers_repository.dart';
import '../../jeeber_request_feed/presentation/jeeber_failure_exit.dart';
import '../../settings/domain/role_switch_repository.dart';
import '../application/availability_cubit.dart';
import '../application/availability_state.dart';
import '../domain/entities/availability_status.dart';
import '../domain/entities/feed_request.dart';
import '../domain/services/availability_gateway.dart';
import 'widgets/jeeber_active_deliveries_banner.dart';
import 'widgets/jeeber_feed_tab_view.dart';
import 'widgets/jeeber_no_requests_view.dart';
import 'widgets/jeeber_unregistered_view.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';

void _retryGreetingIfFailed(BuildContext context) {
  try {
    unawaited(context.read<GreetingProfileCubit>().retryIfFailed());
  } on ProviderNotFoundException {
    return;
  }
}

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
      onRegister: onRegister,
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
    required this.onRegister,
  });

  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;
  final SubmittedOffersCubit? submittedOffersCubit;
  final Widget? activeDeliveriesBanner;
  final VoidCallback? onRegister;

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
          prev.toggleFailure != curr.toggleFailure ||
          prev.locationOutcome != curr.locationOutcome ||
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
        onRegister: widget.onRegister,
      ),
    );
  }

  void _onStateChange(BuildContext context, AvailabilityViewState view) {
    if (view.toggleError) _showToggleErrorSnackbar(context, view);
    _showLocationOutcomeSnackbar(context, view);
    if (view.loadPhase == AvailabilityLoadPhase.loadError) {
      unawaited(_autoActivateJeeber());
    }
  }

  /// Without coordinates the jeeber is silently dropped from new-request
  /// fan-out, so a failed fix must be visible and recoverable.
  void _showLocationOutcomeSnackbar(
    BuildContext context,
    AvailabilityViewState view,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (view.locationOutcome) {
      case GoOnlineLocationOutcome.permissionDenied:
        showJeebSnack(
          context,
          message: l10n.availabilityLocationPermissionBody,
          identifier: 'jeeber_home_location_permission_snack',
          actionLabel: l10n.availabilityLocationOpenSettings,
          onAction: () =>
              unawaited(GeolocatorGeocaptureGateway().openAppSettings()),
        );
      case GoOnlineLocationOutcome.fixFailed:
        showJeebErrorSnack(
          context,
          message: l10n.availabilityLocationFixFailedBody,
          identifier: 'jeeber_home_location_fix_snack',
          retryLabel: l10n.availabilityLocationRetry,
          onRetry: () =>
              unawaited(context.read<AvailabilityCubit>().retryLocationAttach()),
        );
      case GoOnlineLocationOutcome.attached:
      case GoOnlineLocationOutcome.notApplicable:
        break;
    }
  }

  void _showToggleErrorSnackbar(
    BuildContext context,
    AvailabilityViewState view,
  ) {
    if (!view.toggleError) return;
    final l10n = AppLocalizations.of(context);
    // A classified kind speaks for itself; an unclassified one keeps the
    // screen's own line rather than the generic body.
    final failure = view.toggleFailure;
    final classified = failure is UnknownFailure ? null : failure;
    final bool retryable = failure?.isRetryable ?? true;
    showJeebErrorSnack(
      context,
      failure: classified,
      message: classified == null ? l10n.availabilityToggleErrorBody : null,
      identifier: 'jeeber_home_toggle_error_snack',
      retryLabel: retryable ? l10n.actionRetry : null,
      onRetry: retryable
          ? () => unawaited(context.read<AvailabilityCubit>().toggle())
          : null,
    );
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
    required this.onRegister,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;
  final SubmittedOffersCubit? submittedOffersCubit;
  final Widget? activeDeliveriesBanner;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    // JHOME-05: a 404 on the availability read means un-onboarded, not offline.
    if (view.loadPhase == AvailabilityLoadPhase.notRegistered) {
      return _NotRegisteredView(onRegister: onRegister);
    }
    if (view.loadPhase == AvailabilityLoadPhase.loadError) {
      return _LoadErrorView(
        failure: view.loadError,
        onRetry: () {
          context.read<AvailabilityCubit>().load();
          _retryGreetingIfFailed(context);
        },
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
      builder: (context, feedState) {
        final refresh = context.read<RequestFeedCubit>().refresh;
        // JHOME-01: the error rung comes strictly before the empty one.
        if (feedState.status == RequestFeedStatus.error &&
            feedState.requests.isEmpty) {
          return _FeedFailureView(failure: feedState.error, onRetry: refresh);
        }
        // ES-08: a cold read is not an empty feed.
        if (feedState.requests.isEmpty &&
            (feedState.status == RequestFeedStatus.initial ||
                feedState.status == RequestFeedStatus.loading)) {
          return JeebStateHost(
            child: JeebEmptyState(
              status: JeebEmptyStateStatus.loading,
              variant: JeebEmptyStateVariant.street,
              identifier: 'jeeber_home_feed_loading',
              headline: AppLocalizations.of(context).requestFeedLoadingHeadline,
            ),
          );
        }
        if (feedState.requests.isEmpty) {
          return JeebPullToRefresh(
            onRefresh: refresh,
            child: _NoRequestsScope(
              view: view,
              profileName: profileName,
              activeDeliveriesBanner: activeDeliveriesBanner,
            ),
          );
        }
        return _FeedTabBody(
          profileName: profileName,
          onOpenFeedRequest: onOpenFeedRequest,
          submittedOffersCubit: submittedOffersCubit,
          activeDeliveriesBanner: activeDeliveriesBanner,
        );
      },
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
    return JeebStateHost(
      child: JeebEmptyState(
        status: JeebEmptyStateStatus.loading,
        variant: JeebEmptyStateVariant.street,
        identifier: 'jeeber_home_loading',
        headline: AppLocalizations.of(context).availabilityLoadingHeadline,
      ),
    );
  }
}

/// The availability read failed — E3's block, danger-tinted, with the frozen
/// retry CTA re-homed onto its action slot.
class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.failure, required this.onRetry});

  final AppFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolved = failure ?? const UnknownFailure();
    // Forbidden is unrecoverable here: the way out is the KYC gate, not Retry.
    final bool forbidden = resolved is ForbiddenFailure;
    final exit = jeeberFailureExit(context, resolved, l10n);
    return JeebStateHost(
      child: JeebFailureBlock(
        failure: resolved,
        identifier: 'jeeber_home_error',
        retryIdentifier: 'jeeber_home_load_error_retry_cta',
        exitIdentifier: 'jeeber_home_exit_cta',
        variant: JeebEmptyStateVariant.street,
        bodyOverride: forbidden ? l10n.availabilityErrorForbidden : null,
        onRetry: onRetry,
        onExit: exit.onExit,
        exitLabel: exit.label,
      ),
    );
  }
}

/// The gateway says this account has no jeeber profile yet — the way out is
/// registration, not a Retry that will 404 again.
class _NotRegisteredView extends StatelessWidget {
  const _NotRegisteredView({required this.onRegister});

  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebStateHost(
      child: JeebEmptyState(
        reason: JeebEmptyStateReason.nothingYet,
        variant: JeebEmptyStateVariant.street,
        identifier: 'jeeber_home_not_registered_state',
        headline: l10n.availabilityNotRegisteredTitle,
        body: l10n.availabilityNotRegisteredBody,
        action: onRegister == null
            ? null
            : JeebCtaButton.primary(
                label: l10n.jeeberRegisterCta,
                expand: false,
                identifier: 'jeeber_home_register_cta',
                onTap: onRegister,
              ),
      ),
    );
  }
}

/// The feed's own cold failure, inside the availability-ready body.
class _FeedFailureView extends StatelessWidget {
  const _FeedFailureView({required this.failure, required this.onRetry});

  final AppFailure? failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final resolved = failure ?? const UnknownFailure();
    final exit = jeeberFailureExit(
      context,
      resolved,
      AppLocalizations.of(context),
      onReload: onRetry,
    );
    return JeebStateHost(
      onRefresh: onRetry,
      child: JeebFailureBlock(
        failure: resolved,
        identifier: 'jeeber_home_feed_error',
        retryIdentifier: 'jeeber_home_feed_retry_cta',
        exitIdentifier: 'jeeber_home_feed_exit_cta',
        variant: JeebEmptyStateVariant.street,
        onRetry: () => unawaited(onRetry()),
        onExit: exit.onExit,
        exitLabel: exit.label,
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
  name: 'Not registered · register',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenNotRegistered() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.notRegisteredAvailability(),
);

@JeebPreview(
  group: 'jeeber_home',
  name: 'Feed load failed · retry',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenFeedLoadFailed() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  feed: JeeberHomeScreenPreviewFixtures.failedFeed(
    const ServerFailure(status: 503),
  ),
);

@JeebPreview(
  group: 'jeeber_home',
  name: 'Feed refresh failed · stale rows',
  size: _jeeberHomeScreenPhoneBox,
)
Widget jeeberHomeScreenFeedRefreshFailed() => _jeeberHomeScreenHosted(
  JeeberHomeScreenPreviewFixtures.onlineAvailability(),
  feed: JeeberHomeScreenPreviewFixtures.refreshFailedFeed(
    JeeberHomeScreenPreviewFixtures.incomingFeed(),
    const NetworkFailure(offline: true),
  ),
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
