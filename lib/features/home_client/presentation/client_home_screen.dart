import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/client_home_cubit.dart';
import '../application/client_home_state.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';
import 'widgets/active_request_card.dart';
import 'widgets/client_home_greeting.dart';
import 'widgets/client_home_voice_cta.dart';
import 'widgets/recent_delivery_card.dart';

/// Client-role home tab. Shows greeting + voice CTA, then either a list of
/// active delivery requests or an empty-state with a "create your first
/// request" call to action, plus a "Order again" strip when a recent
/// completed delivery exists.
///
/// Drives all state off [ClientHomeCubit]; callbacks for navigation are
/// injected so the screen can be reused outside the shell (e.g. deep links)
/// without taking a hard dependency on `go_router`.
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.onOpenRequest,
    this.onCreateRequest,
    this.onReorder,
  });

  /// Tap on an active-request card. The shell wires this to the tracking
  /// screen; the screen itself doesn't care which route the host uses.
  final void Function(ClientHomeRequest request)? onOpenRequest;

  /// Tap on either the voice CTA or the empty-state "Create your first
  /// request" button. Both route to the same recorder.
  final VoidCallback? onCreateRequest;

  /// Tap on the "Re-order" button on the recent-delivery card.
  final void Function(RecentDeliverySummary summary)? onReorder;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fire the initial load; the cubit guards against re-entry so the
    // post-frame schedule is just here to avoid running it while the
    // build phase is in flight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ClientHomeCubit>();
      if (cubit.state.status == ClientHomeStatus.initial) {
        cubit.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      builder: (context, state) {
        return OmdsPullToRefresh(
          onRefresh: () => context.read<ClientHomeCubit>().refresh(),
          child: _bodyForState(state),
        );
      },
    );
  }

  Widget _bodyForState(ClientHomeState state) {
    switch (state.status) {
      case ClientHomeStatus.initial:
      case ClientHomeStatus.loading:
        return const _LoadingView();
      case ClientHomeStatus.failed:
        return _FailedView(
          onRetry: () => context.read<ClientHomeCubit>().load(),
        );
      case ClientHomeStatus.ready:
        return _ReadyView(
          state: state,
          onOpenRequest: widget.onOpenRequest,
          onCreateRequest: widget.onCreateRequest,
          onReorder: widget.onReorder,
        );
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    // ListView so pull-to-refresh still works while we have no content.
    return ListView(
      key: const Key('client-home-loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: Spacing.fourXLarge),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const Key('client-home-failed'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: Spacing.xLarge),
        OmdsErrorState(
          icon: Icons.cloud_off_outlined,
          title: l10n.homeLoadFailedTitle,
          message: l10n.homeLoadFailedBody,
          retryLabel: l10n.homeLoadFailedRetry,
          onRetry: onRetry,
        ),
      ],
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.state,
    required this.onOpenRequest,
    required this.onCreateRequest,
    required this.onReorder,
  });

  final ClientHomeState state;
  final void Function(ClientHomeRequest request)? onOpenRequest;
  final VoidCallback? onCreateRequest;
  final void Function(RecentDeliverySummary summary)? onReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasRecent = state.recentDeliveries.isNotEmpty;
    return ListView(
      key: const Key('client-home-ready'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: Spacing.twoXLarge),
      children: [
        ClientHomeGreeting(name: state.greetingName),
        ClientHomeVoiceCta(
          onPressed: () => onCreateRequest?.call(),
        ),
        if (state.isEmpty)
          _EmptyState(onCreateRequest: onCreateRequest)
        else
          _ActiveSection(
            requests: state.activeRequests,
            onOpenRequest: onOpenRequest,
          ),
        if (hasRecent) ...[
          const SizedBox(height: Spacing.large),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
            child: Text(
              l10n.homeRecentSectionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: Spacing.small),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
            child: RecentDeliveryCard(
              summary: state.recentDeliveries.first,
              onReorder: () => onReorder?.call(state.recentDeliveries.first),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateRequest});

  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const Key('client-home-empty-state'),
      padding: const EdgeInsets.symmetric(vertical: Spacing.large),
      child: OmdsEmptyState(
        icon: Icons.local_shipping_outlined,
        title: l10n.homeEmptyTitle,
        subtitle: l10n.homeEmptySubtitle,
        buttonText: l10n.homeEmptyCta,
        onButtonTap: onCreateRequest,
      ),
    );
  }
}

class _ActiveSection extends StatelessWidget {
  const _ActiveSection({
    required this.requests,
    required this.onOpenRequest,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest request)? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const Key('client-home-active-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.large),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
          child: Text(
            l10n.homeActiveSectionTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
          ),
        ),
        const SizedBox(height: Spacing.small),
        for (final r in requests)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.medium,
              0,
              Spacing.medium,
              Spacing.small,
            ),
            child: ActiveRequestCard(
              request: r,
              onTap: () => onOpenRequest?.call(r),
            ),
          ),
      ],
    );
  }
}
