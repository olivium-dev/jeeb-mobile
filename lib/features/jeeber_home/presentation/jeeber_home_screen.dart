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

/// Jeeber-side home (T-mobile-027 / JEEB-66) with the three states laid
/// out in the Figma design:
///
/// * **State 1 — Unregistered**: hero illustration + "Register now" CTA.
/// * **State 2 — Registered, available, no requests**: greeting +
///   `AvailabilityCard` + empty hero.
/// * **State 3 — Registered, available, with requests**: greeting +
///   search bar + [OmdsFilterChips] tab strip + live request feed.
///
/// The cubit is provided by the host (typically the role-aware shell) so
/// the auto-offline ticker keeps running across rebuilds. The feed cubit
/// is optional — pass one to enable State 3; pass `null` (the default) and
/// the screen stays in State 2 even when the Jeeber goes online. Tests
/// rely on the `null` default so they can verify the toggle-only path
/// without a request stream.
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

  /// Tap-through for the feed cards (delegated to the host via
  /// [DashboardTab] so go_router stays out of this widget).
  final ValueChanged<FeedRequest>? onOpenFeedRequest;

  /// Optional tap-through for the State 1 "Register now" CTA. When null
  /// the button no-ops; the host wires it to the KYC route.
  final VoidCallback? onRegister;

  /// Whether the Jeeber has completed the delivery-man registration. When
  /// false the screen renders State 1; when true it picks between State 2
  /// and State 3 based on the cubit state.
  final bool isRegistered;

  /// Profile display name surfaced in the shared greeting header.
  final String? profileName;

  /// Optional pre-wired feed cubit. When present, the screen exposes it
  /// via [BlocProvider.value] so the feed-tab view can read from it.
  final RequestFeedCubit? requestFeedCubit;

  /// JM-036: optional extra Semantics identifier wrapped around the State-1
  /// "Register now" CTA (in addition to the W0 `jeeber_unregistered_register_button`).
  /// The DELIVERY-tab gate host passes `delivery_register_now_cta` so the
  /// JM-036 flow can tap the register prompt's CTA by its coined screen id.
  final String? registerCtaIdentifier;

  /// JM-048 AC3: factory for the cubit backing the feed's Pending-Response
  /// sub-tab (the jeeber's submitted offers). The screen owns the cubit's
  /// lifecycle (closes it on dispose). When null it defaults to a DI-backed
  /// [SubmittedOffersCubit] over `sl<Dio>()` if DI is configured, else null
  /// (the Pending tab then falls back to the request-feed-derived view) so the
  /// screen stays usable in tests / the dev-seam capture path without DI. Tests
  /// inject a scripted factory to assert the real-data path.
  final SubmittedOffersCubit Function()? submittedOffersCubitFactory;

  /// Optional host-injected active-deliveries banner rendered above the
  /// no-requests state for a registered jeeber. The Dashboard host
  /// ([DashboardTab]) builds it so it owns navigation (open chat / manage
  /// delivery) and the [ActiveDeliveriesCubit] lifecycle. When null the screen
  /// falls back to the self-contained [JeeberActiveDeliveriesBanner] so callers
  /// that do not inject one (and widget tests) keep the prior behaviour.
  final Widget? activeDeliveriesBanner;

  @override
  State<JeeberHomeScreen> createState() => _JeeberHomeScreenState();
}

class _JeeberHomeScreenState extends State<JeeberHomeScreen> {
  bool _bootstrapped = false;

  /// JM-048 AC3: cubit backing the feed's Pending-Response sub-tab, owned by
  /// this state (closed in [dispose]). Built lazily on first build so an
  /// unregistered (State-1) screen never constructs it.
  SubmittedOffersCubit? _submittedOffersCubit;
  bool _submittedOffersResolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    // State 1 (unregistered) renders `JeeberUnregisteredView`, which never
    // reads the availability cubit, so the host does not provide one on that
    // path. Reading it unconditionally here threw `ProviderNotFound` before
    // the first frame painted (screen-19 crash). Only bootstrap availability
    // when the Jeeber is registered and the cubit is actually consumed.
    if (widget.isRegistered) {
      context.read<AvailabilityCubit>().load();
    }
  }

  /// Resolve the submitted-offers cubit once, for the registered path only.
  /// Prefers the injected factory (tests), then a DI-backed default, then null
  /// (no Dio in DI — Pending tab falls back to the request-feed-derived view).
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
        // sprint-009: the feed's Pending-Response sub-tab reacts to
        // offer_accepted/offer_lost pushes the same way the standalone list does.
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
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_home_root',
      container: true,
      child: Scaffold(
        key: JeeberHomeScreen.scaffoldKey,
        appBar: OMDSAppBar(
          title: l10n.availabilityHomeTitle,
          centerTitle: false,
        ),
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

/// Picks the right top-level view based on registration state and (when
/// registered) wraps the body in a [BlocProvider.value] for the request
/// feed cubit so [JeeberFeedTabView] can read it.
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

/// State 2/3 dispatch. Reads the availability cubit to choose between the
/// load-error retry, the no-requests view, and the feed tab view.
///
/// JEBV4-271 / JEBV4-279 — auto-online after auto-KYC with NO re-login
/// (jeeber-surface safety net). When the availability load fails with a
/// forbidden-capability 403 — the jeeber role is granted server-side but the
/// local bearer is still CLIENT-scoped, so `/v1/availability` 403s and the
/// screen shows "Couldn't load your availability" — this fires
/// [JeeberRoleActivator.activate] (`POST /v1/users/me/role/switch`) to re-mint
/// the jeeber-capable token, then reloads availability so the jeeber comes
/// ONLINE on its own. It is the counterpart to KycStatusView's approved-body
/// activation for EVERY path that reaches the Jeeber dashboard WITHOUT passing
/// through the KYC approved screen — e.g. a relaunch that lands here via
/// RoleSync adopting `available_roles: [..., jeeber]` while the token is still
/// client-scoped (the on-device root cause: role/switch never fired from the
/// jeeber surface). It runs at most once per mount, with a bounded auto-retry
/// for a still-propagating role grant, and degrades to a no-op — leaving the
/// manual Retry CTA — when no activator is wired (bare harness / DI-less test)
/// or the switch stays gated (kyc) / failed (network).
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
  /// A brief role-grant projection lag can answer the first `role/switch` with a
  /// 403 (kycGated); retry a bounded number of times with a short backoff so the
  /// jeeber still comes online on its own, mirroring the KYC approved body.
  static const int _autoActivateMaxAttempts = 5;
  static const Duration _autoActivateRetryDelay = Duration(seconds: 2);

  /// One-shot per mount: never re-enter activation after a reload re-emits
  /// loadError (a persistent non-403 failure), so there is no switch/reload loop.
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

  /// Self-heal the availability 403: switch to the jeeber role (re-minting a
  /// jeeber-capable token) and reload availability. See [_RegisteredBody] doc.
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
    // Capture the home cubit before any await so the reload never touches a
    // possibly-unmounted BuildContext.
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
      // kycGated (projection lag) / failed (network): back off and retry.
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
          // JEBV4-13 P2-6: the empty state's copy promises "Pull down to
          // refresh", but this (online, feed-cubit-backed) variant was never
          // wrapped in a refresh indicator — pulling fired NO feed GET. Wire
          // the same OmdsPullToRefresh → cubit.refresh() the non-empty feed
          // list already uses so the affordance is honest.
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
              // PUSH-UI-REACTION (2026-07-05): the active-deliveries card must
              // also mount ABOVE the live feed — not only in the no-requests
              // scope. Right after a jeeber offers, the offered (still-pending)
              // request keeps the feed NON-empty, so this branch renders; when
              // the customer accepts, the `offer_accepted` push refetch returns
              // the won delivery and the ActiveDeliveriesCubit emits — but the
              // card's BlocBuilder was absent from THIS branch, so it rendered
              // nowhere until the feed later emptied (~95s) and the no-requests
              // scope mounted the banner. Passing it here makes the just-won
              // card surface within a couple seconds of the push in every
              // jeeber-home state. The banner self-hides (zero height) when
              // there is no active delivery, so the feed layout is unchanged in
              // the common case.
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
    // S007-P1B + iter6: surface the jeeber's ACCEPTED (won) deliveries above the
    // no-requests state so they are reachable in-app, not push-only. Prefer the
    // host-injected banner (Dashboard owns navigation + the ActiveDeliveriesCubit
    // lifecycle); fall back to the self-contained banner for callers/tests that
    // do not inject one. Either renders nothing when there are none, so the prior
    // layout is unchanged.
    // Fix 6 (b): the active-deliveries banner is an unbounded Column of cards.
    // Placing it as a fixed child above an `Expanded` no-requests view let the
    // banner push the Column past the viewport when it held one or more tall
    // cards (45px / 477px bottom RenderFlex overflow on SM-S921B). A
    // CustomScrollView lets the surface SCROLL when the banner is tall, while
    // `SliverFillRemaining(hasScrollBody: false)` keeps the no-requests view
    // filling the remaining space when there is room (unchanged when the banner
    // self-hides / holds a single card).
    return CustomScrollView(
      // JEBV4-13 P2-6: without AlwaysScrollable physics this scroll view
      // rejects the drag when its content fits the viewport (the common empty
      // state), so the enclosing OmdsPullToRefresh could never fire. The inner
      // JeeberNoRequestsView scroll view keeps default physics and therefore
      // yields the gesture to this one when it has nothing to scroll.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: activeDeliveriesBanner ?? const JeeberActiveDeliveriesBanner(),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: JeeberNoRequestsView(
            view: view,
            profileName: profileName,
            onToggle: cubit.toggle,
            onExtendActivity: cubit.extendActivity,
          ),
        ),
      ],
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

  /// PUSH-UI-REACTION: the host-injected active-deliveries card, mounted as a
  /// header ABOVE the feed so a just-won delivery surfaces on the push refetch
  /// even while the feed still lists the (now-accepted) request. Null for
  /// callers/tests that do not inject one — then the bare feed renders,
  /// unchanged.
  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    return JeeberFeedTabView(
      profileName: profileName,
      // PUSH-UI-REACTION: the active-deliveries card rides INSIDE the feed's
      // scrollable list as a leading header (NOT a fixed sibling above the feed
      // — the feed's own greeting + availability card + search + tabs already
      // fill a short 360dp viewport, so a fixed header would overflow on
      // SM-S921B). It self-hides to zero height when there is no active
      // delivery, so the feed is unchanged in the common case.
      leadingBanner: activeDeliveriesBanner,
      // JM-048: leave `onMakeOffer` null so the feed self-routes the make-offer
      // CTA through the KYC gate / composer (the shell is not edited). The card
      // tap still opens the request detail via the host callback.
      onOpenRequest: onOpenFeedRequest == null
          ? null
          : (req) => onOpenFeedRequest!(
              FeedRequest(
                id: req.id,
                shortLabel: req.pickup.label,
                // G1: carry the customer's request content into the detail
                // (feed items parse the gateway `description` into
                // [DeliveryRequest.itemsSummary]).
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
