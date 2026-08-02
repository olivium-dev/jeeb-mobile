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
