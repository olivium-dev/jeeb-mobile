import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/application/availability_cubit.dart';
import '../../jeeber_home/domain/entities/availability_status.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../../jeeber_home/domain/services/availability_gateway.dart';
import '../../jeeber_home/presentation/jeeber_home_screen.dart';
import '../../jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart';
import '../../jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import '../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../jeeber_request_feed/data/request_feed_models.dart';
import '../../jeeber_request_feed/data/request_feed_repository.dart';

/// Selector for the deliveryman feed variant the dev seam should render
/// (Figma screens 23-26). Debug capture aid only — never reached in release.
enum _DevFeedView { empty, requests, pending, replies }

/// Jeeber-side "Home" tab in the role-aware bottom-nav shell. Delegates to
/// [JeeberHomeScreen] so the availability toggle is the first thing the
/// Jeeber sees on cold-start.
///
/// Wires the feed card → request-detail route (T-mobile-033) so tapping a
/// candidate from the feed opens the detail screen where the Jeeber can
/// review the request and, if needed, file a prohibited-item report. The
/// "Register now" upsell CTA → the delivery-man onboarding wizard
/// (screen 19 → 20).
///
/// In the dev-seam capture path (`jeeb.feed=<view>`), the tab instead renders
/// a self-contained, seeded feed surface so a single APK captures screens
/// 23-26 without a rebuild; `jeeb.home_tab=unregistered` forces the screen-19
/// Delivery-tab upsell.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final devView = _devSeamView();
    if (devView != null) return _DevFeedScaffold(view: devView);
    return _JeeberHomeHost(unregistered: _devSeamUnregistered());
  }

  /// The deliveryman feed variant requested via the dev seam, or `null` when
  /// the seam isn't driving the dashboard. Debug-only — always `null` in
  /// release builds.
  _DevFeedView? _devSeamView() {
    if (!kDebugMode) return null;
    return switch (DevSeam.current.feed) {
      'empty' => _DevFeedView.empty,
      'requests' => _DevFeedView.requests,
      'pending' => _DevFeedView.pending,
      'replies' => _DevFeedView.replies,
      _ => null,
    };
  }

  /// Debug-only: when the dev seam requests the `unregistered` home-tab state,
  /// render screen 19 (the Delivery-tab upsell) deterministically with the
  /// Figma mock name. Always `false` in release builds.
  bool _devSeamUnregistered() =>
      kDebugMode && DevSeam.current.homeTab == 'unregistered';
}

/// Hosts the production [JeeberHomeScreen] under a [MultiBlocProvider] that
/// supplies the two cubits the registered home reads: an [AvailabilityCubit]
/// (`didChangeDependencies` + `_RegisteredBody`'s `BlocConsumer`) and a
/// [RequestFeedCubit] (the active-delivery / request feed surface).
///
/// Before the availability provider existed, the role-switch into the Jeeber
/// surface mounted `JeeberHomeScreen(isRegistered: true)` with no
/// `AvailabilityCubit` ancestor — only the dev-seam feed path provided one — so
/// the registered screen threw `ProviderNotFound<AvailabilityCubit>` on entry
/// (E2E "Switch to Jeeber" crash).
///
/// JEEBER-LOOP F3: the host also did not pass a `requestFeedCubit`, so
/// [JeeberHomeScreen] stayed in State 2 (availability toggle only, no feed) —
/// the Jeeber had no in-app entry to an active delivery and could only reach
/// one via a deep link. Wiring a DI-backed [RequestFeedCubit] lights up State 3
/// (the live request / active-delivery feed) so tapping a card reaches the
/// chat → "Start delivery" → active-delivery → OTP entry chain that closes the
/// two-party loop. Both cubits are built from DI-registered gateways
/// (`sl<...>()`), matching how sibling route builders construct their
/// screen-scoped cubits.
///
/// Both providers wrap even the `unregistered` (screen-19) path: the
/// availability auto-offline ticker is owned by its cubit and the upsell view
/// simply never reads either cubit, so a single create-site avoids a second
/// provider tree. `BlocProvider.create` owns the cubit lifecycle (it is closed
/// on dispose), so we hand the created [RequestFeedCubit] to
/// [JeeberHomeScreen] — which re-exposes it via `BlocProvider.value` (a
/// non-owning view) — instead of constructing a second, leaked instance.
class _JeeberHomeHost extends StatelessWidget {
  const _JeeberHomeHost({required this.unregistered});

  final bool unregistered;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AvailabilityCubit>(
          create: (_) => AvailabilityCubit(gateway: sl<AvailabilityGateway>()),
        ),
        BlocProvider<RequestFeedCubit>(
          create: (_) =>
              RequestFeedCubit(repository: sl<RequestFeedRepository>())
                ..start(),
        ),
      ],
      child: Builder(
        builder: (context) => JeeberHomeScreen(
          key: const Key('dashboard-tab-root'),
          isRegistered: !unregistered,
          profileName: unregistered ? 'Kamal' : null,
          requestFeedCubit: context.read<RequestFeedCubit>(),
          onRegister: () => context.pushNamed('jeeber-onboarding'),
          onOpenFeedRequest: (FeedRequest request) {
            context.pushNamed(
              'jeeber-request-detail',
              pathParameters: {'id': request.id},
              extra: request,
            );
          },
        ),
      ),
    );
  }
}

/// Self-contained scaffold for the dev-seam feed capture path. Owns its own
/// seeded [RequestFeedCubit] so it needs no shell-provided availability cubit.
class _DevFeedScaffold extends StatelessWidget {
  const _DevFeedScaffold({required this.view});

  static const _name = 'Kamal';
  static const _avatarUrl = 'https://i.pravatar.cc/150?img=12';

  final _DevFeedView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const Key('dashboard-tab-dev-feed'),
      appBar: OMDSAppBar(title: l10n.availabilityHomeTitle, centerTitle: false),
      body: _DevFeedBody(view: view, name: _name, avatarUrl: _avatarUrl),
    );
  }
}

/// Body of the dev-seam feed scaffold: an empty view or a seeded feed tab view
/// for the selected [view].
class _DevFeedBody extends StatelessWidget {
  const _DevFeedBody({
    required this.view,
    required this.name,
    required this.avatarUrl,
  });

  final _DevFeedView view;
  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (view == _DevFeedView.empty) {
      return JeeberFeedEmptyView(
        profileName: name,
        profileAvatarUrl: avatarUrl,
      );
    }
    // Provide a dev-only availability cubit (always-online) so
    // JeeberFeedTabView can read it for the offline-banner check.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AvailabilityCubit>(
          create: (_) => AvailabilityCubit(
            gateway: InMemoryAvailabilityGateway(
              initial: AvailabilityStatus.initial.copyWith(
                state: AvailabilityState.online,
              ),
            ),
          ),
        ),
        BlocProvider<RequestFeedCubit>(
          create: (_) => RequestFeedCubit(
            repository: SeededRequestFeedRepository(_snapshotFor(view)),
          )..start(),
        ),
      ],
      child: JeeberFeedTabView(
        profileName: name,
        profileAvatarUrl: avatarUrl,
        initialTab: _tabFor(view),
      ),
    );
  }

  List<DeliveryRequest> _snapshotFor(_DevFeedView v) => switch (v) {
        _DevFeedView.requests => DevJeeberFeedFixtures.incoming(),
        _DevFeedView.pending => DevJeeberFeedFixtures.pending(),
        _DevFeedView.replies => DevJeeberFeedFixtures.replies(),
        _DevFeedView.empty => const [],
      };

  JeeberFeedTab _tabFor(_DevFeedView v) => switch (v) {
        _DevFeedView.pending => JeeberFeedTab.pendingResponse,
        _DevFeedView.replies => JeeberFeedTab.replies,
        _DevFeedView.requests || _DevFeedView.empty => JeeberFeedTab.requests,
      };
}
