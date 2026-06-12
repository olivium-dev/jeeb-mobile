import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../jeeber_request_feed/cubit/request_feed_state.dart';
import '../application/availability_cubit.dart';
import '../application/availability_state.dart';
import '../domain/entities/availability_status.dart';
import '../domain/entities/feed_request.dart';
import 'widgets/jeeber_feed_tab_view.dart';
import 'widgets/jeeber_no_requests_view.dart';
import 'widgets/jeeber_unregistered_view.dart';

/// Jeeber-side home (T-mobile-027 / JEEB-66) with the three states laid
/// out in the Figma design:
///
/// * **State 1 — Unregistered**: hero illustration + "Register now" CTA.
/// * **State 2 — Registered, available, no requests**: greeting +
///   [AvailabilityToggle] + empty hero.
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
  });

  static const Key scaffoldKey = Key('jeeber-home-screen-scaffold');
  static const Key toggleErrorSnackbarKey =
      Key('jeeber-home-screen-toggle-error-snackbar');
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

  @override
  State<JeeberHomeScreen> createState() => _JeeberHomeScreenState();
}

class _JeeberHomeScreenState extends State<JeeberHomeScreen> {
  bool _bootstrapped = false;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: JeeberHomeScreen.scaffoldKey,
      appBar: OMDSAppBar(title: l10n.availabilityHomeTitle, centerTitle: false),
      body: _RootBody(
        isRegistered: widget.isRegistered,
        profileName: widget.profileName,
        onRegister: widget.onRegister,
        onOpenFeedRequest: widget.onOpenFeedRequest,
        requestFeedCubit: widget.requestFeedCubit,
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
  });

  final bool isRegistered;
  final String? profileName;
  final VoidCallback? onRegister;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final RequestFeedCubit? requestFeedCubit;

  @override
  Widget build(BuildContext context) {
    if (!isRegistered) {
      return JeeberUnregisteredView(
        profileName: profileName,
        onRegister: onRegister ?? () {},
      );
    }
    final body = _RegisteredBody(
      profileName: profileName,
      onOpenFeedRequest: onOpenFeedRequest,
      hasFeedCubit: requestFeedCubit != null,
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
class _RegisteredBody extends StatelessWidget {
  const _RegisteredBody({
    required this.profileName,
    required this.onOpenFeedRequest,
    required this.hasFeedCubit,
  });

  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AvailabilityCubit, AvailabilityViewState>(
      listenWhen: (prev, curr) => prev.toggleError != curr.toggleError,
      listener: _showToggleErrorSnackbar,
      builder: (context, view) => _RegisteredViewSwitch(
        view: view,
        profileName: profileName,
        onOpenFeedRequest: onOpenFeedRequest,
        hasFeedCubit: hasFeedCubit,
      ),
    );
  }

  void _showToggleErrorSnackbar(
    BuildContext context,
    AvailabilityViewState view,
  ) {
    if (!view.toggleError) return;
    final l10n = AppLocalizations.of(context);
    // ignore: deprecated_member_use
    // EXEMPT: the org-wide OMDS `showOmdsSnackbar` does not accept a `Key`
    // parameter, yet `jeeber_home_screen_test.dart` asserts on
    // [JeeberHomeScreen.toggleErrorSnackbarKey]. Until OMDS exposes a
    // key-aware wrapper (tracked at JEEB-66 follow-up), the ScaffoldMessenger
    // call below is the only way to surface the key for the test harness.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: JeeberHomeScreen.toggleErrorSnackbarKey,
          content: Text(l10n.availabilityToggleErrorBody),
        ),
      );
  }
}

class _RegisteredViewSwitch extends StatelessWidget {
  const _RegisteredViewSwitch({
    required this.view,
    required this.profileName,
    required this.onOpenFeedRequest,
    required this.hasFeedCubit,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;

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
    );
  }
}

class _AvailableBody extends StatelessWidget {
  const _AvailableBody({
    required this.view,
    required this.profileName,
    required this.onOpenFeedRequest,
    required this.hasFeedCubit,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;
  final bool hasFeedCubit;

  @override
  Widget build(BuildContext context) {
    if (!hasFeedCubit || view.status.state != AvailabilityState.online) {
      return _NoRequestsScope(view: view, profileName: profileName);
    }
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, feedState) => feedState.requests.isEmpty
          ? _NoRequestsScope(view: view, profileName: profileName)
          : _FeedTabBody(
              profileName: profileName,
              onOpenFeedRequest: onOpenFeedRequest,
            ),
    );
  }
}

class _NoRequestsScope extends StatelessWidget {
  const _NoRequestsScope({required this.view, required this.profileName});

  final AvailabilityViewState view;
  final String? profileName;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AvailabilityCubit>();
    return JeeberNoRequestsView(
      view: view,
      profileName: profileName,
      onToggle: cubit.toggle,
      onExtendActivity: cubit.extendActivity,
    );
  }
}

class _FeedTabBody extends StatelessWidget {
  const _FeedTabBody({
    required this.profileName,
    required this.onOpenFeedRequest,
  });

  final String? profileName;
  final ValueChanged<FeedRequest>? onOpenFeedRequest;

  @override
  Widget build(BuildContext context) {
    return JeeberFeedTabView(
      profileName: profileName,
      onOpenRequest: onOpenFeedRequest == null
          ? null
          : (req) => onOpenFeedRequest!(
                FeedRequest(id: req.id, shortLabel: req.pickup.label),
              ),
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
        Text(title, textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium),
        const SizedBox(height: Spacing.medium),
        OmdsPrimaryButton(
          key: JeeberHomeScreen.loadErrorRetryKey,
          text: retryLabel,
          onTap: onRetry,
        ),
      ],
    );
  }
}
