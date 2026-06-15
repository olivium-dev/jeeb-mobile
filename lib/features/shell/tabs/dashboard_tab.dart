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

/// Hosts the production [JeeberHomeScreen] under a [BlocProvider]
/// `<AvailabilityCubit>` so the registered path has the cubit it reads
/// (`didChangeDependencies` + `_RegisteredBody`'s `BlocConsumer`).
///
/// Before this host existed, the role-switch into the Jeeber surface mounted
/// `JeeberHomeScreen(isRegistered: true)` with no `AvailabilityCubit` ancestor
/// — only the dev-seam feed path provided one — so the registered screen threw
/// `ProviderNotFound<AvailabilityCubit>` on entry (E2E "Switch to Jeeber"
/// crash). The cubit is built from the DI-registered [AvailabilityGateway],
/// matching how sibling route builders (escalate/tracking/rating) construct
/// their screen-scoped cubits from `sl<...>()`.
///
/// The provider wraps even the `unregistered` (screen-19) path because the
/// auto-offline ticker is owned by the cubit and the upsell view simply never
/// reads it; keeping a single create-site avoids a second provider tree.
class _JeeberHomeHost extends StatelessWidget {
  const _JeeberHomeHost({required this.unregistered});

  final bool unregistered;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AvailabilityCubit>(
      create: (_) =>
          AvailabilityCubit(gateway: sl<AvailabilityGateway>()),
      child: JeeberHomeScreen(
        key: const Key('dashboard-tab-root'),
        isRegistered: !unregistered,
        profileName: unregistered ? 'Kamal' : null,
        onRegister: () => context.pushNamed('jeeber-onboarding'),
        onOpenFeedRequest: (FeedRequest request) {
          context.pushNamed(
            'jeeber-request-detail',
            pathParameters: {'id': request.id},
            extra: request,
          );
        },
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
