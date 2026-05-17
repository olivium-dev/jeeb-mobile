import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/availability_cubit.dart';
import '../application/availability_state.dart';
import '../domain/entities/feed_request.dart';
import 'widgets/availability_status_block.dart';
import 'widgets/availability_toggle.dart';
import 'widgets/inactivity_warning_banner.dart';

/// Jeeber-side home. T-mobile-027 implements the availability toggle as
/// the first thing the Jeeber sees on cold start. The feed of available
/// requests (T-mobile-013) renders below the toggle and routes through
/// [onOpenFeedRequest] when a card is tapped.
///
/// The cubit is provided by the host (typically the role-aware shell)
/// so the auto-offline ticker keeps running across rebuilds.
class JeeberHomeScreen extends StatefulWidget {
  const JeeberHomeScreen({
    super.key,
    this.onOpenFeedRequest,
  });

  static const Key scaffoldKey = Key('jeeber-home-screen-scaffold');
  static const Key toggleErrorSnackbarKey =
      Key('jeeber-home-screen-toggle-error-snackbar');
  static const Key loadErrorRetryKey = Key('jeeber-home-screen-load-retry');

  /// Tap-through for the feed cards (delegated to the host via
  /// [DashboardTab] so go_router stays out of this widget). T-mobile-027
  /// leaves the feed empty; the callback is wired so T-mobile-013 can
  /// drop in the feed list without touching this file.
  final ValueChanged<FeedRequest>? onOpenFeedRequest;

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
    // Kick off the cold-start fetch once the cubit is in scope.
    context.read<AvailabilityCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: JeeberHomeScreen.scaffoldKey,
      appBar: AppBar(title: Text(l10n.availabilityHomeTitle)),
      body: BlocConsumer<AvailabilityCubit, AvailabilityViewState>(
        listenWhen: (prev, curr) => prev.toggleError != curr.toggleError,
        listener: (context, view) {
          if (!view.toggleError) return;
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                key: JeeberHomeScreen.toggleErrorSnackbarKey,
                content: Text(l10n.availabilityToggleErrorBody),
              ),
            );
        },
        builder: (context, view) {
          if (view.loadPhase == AvailabilityLoadPhase.loadError) {
            return _LoadErrorView(
              onRetry: () => context.read<AvailabilityCubit>().load(),
            );
          }
          return _ReadyView(view: view);
        },
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.view});

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AvailabilityCubit>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Spacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Spacing.medium),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
              child: Text(
                l10n.availabilityCardTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            const SizedBox(height: Spacing.large),
            Center(
              child: AvailabilityToggle(
                state: view.status.state,
                isInFlight: view.isToggleInFlight,
                onTap: cubit.toggle,
              ),
            ),
            const SizedBox(height: Spacing.large),
            AvailabilityStatusBlock(view: view),
            if (view.warningVisible) ...[
              const SizedBox(height: Spacing.large),
              InactivityWarningBanner(onExtend: cubit.extendActivity),
            ],
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.signal_wifi_off,
              size: Sizes.threeXLarge,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: Spacing.medium),
            Text(
              l10n.availabilityLoadError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.medium),
            OmdsPrimaryButton(
              key: JeeberHomeScreen.loadErrorRetryKey,
              text: l10n.availabilityLoadRetry,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
