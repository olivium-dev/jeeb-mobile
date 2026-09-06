import 'package:flutter/material.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_feed/presentation/jeeber_failure_exit.dart';

import '../../../core/previews/jeeb_preview.dart';

/// F2/F3: the capability read FAILED with no cached roles, so the shell says so
/// and offers a re-read — never the invitation an approved jeeber would reject.
class JeeberTabFailureState extends StatelessWidget {
  const JeeberTabFailureState({
    super.key,
    required this.identifier,
    required this.failure,
    this.onRetry,
  });

  const JeeberTabFailureState.dashboard({
    super.key,
    required this.failure,
    this.onRetry,
  }) : identifier = dashboardIdentifier;

  const JeeberTabFailureState.earnings({
    super.key,
    required this.failure,
    this.onRetry,
  }) : identifier = earningsIdentifier;

  static const String dashboardIdentifier = 'jeeber_home_error';

  static const String earningsIdentifier = 'jeeber_earnings_error';

  final String identifier;

  final AppFailure failure;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exit = jeeberFailureExit(context, failure, l10n);
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      animateDecor: false,
      child: SafeArea(
        child: JeebStateHost(
          child: JeebFailureBlock(
            failure: failure,
            identifier: identifier,
            variant: JeebEmptyStateVariant.street,
            headlineOverride: l10n.jeeberTabsUnavailableTitle,
            onRetry: onRetry,
            onExit: exit.onExit,
            exitLabel: exit.label,
          ),
        ),
      ),
    );
  }
}

/// The capability read is still in flight, so the tab breathes: error/empty are
/// never the first frame of a load.
class JeeberTabLoadingState extends StatelessWidget {
  const JeeberTabLoadingState({super.key, required this.identifier});

  const JeeberTabLoadingState.dashboard({super.key})
      : identifier = dashboardIdentifier;

  const JeeberTabLoadingState.earnings({super.key})
      : identifier = earningsIdentifier;

  static const String dashboardIdentifier = 'jeeber_home_loading';

  static const String earningsIdentifier = 'jeeber_earnings_loading';

  final String identifier;

  @override
  Widget build(BuildContext context) {
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      animateDecor: false,
      child: SafeArea(
        child: JeebStateHost(
          child: JeebEmptyState(
            status: JeebEmptyStateStatus.loading,
            variant: JeebEmptyStateVariant.street,
            identifier: identifier,
            headline: AppLocalizations.of(context).jeeberTabsLoadingHeadline,
          ),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for the preview
// canvas and the preview tests.

/// A full tab body — the shell hands these states the whole page.
const Size _jeeberTabFailureStatePhoneBody = Size(390, 680);

/// The commonest F2 state: gateway unreachable with no cached role, so the tab
/// says so instead of inviting a jeeber to register again.
@JeebPreview(
  group: 'shell',
  name: 'Dashboard tab · availability unreachable',
  size: _jeeberTabFailureStatePhoneBody,
  matrix: true,
)
Widget jeeberTabFailureStateDashboard() => JeeberTabFailureState(
      identifier: JeeberTabFailureState.dashboardIdentifier,
      failure: const NetworkFailure(offline: true),
      onRetry: () {},
    );

/// F3, on the same read: Earnings carries its own identifier pair.
@JeebPreview(
  group: 'shell',
  name: 'Earnings tab · availability unreachable',
  size: _jeeberTabFailureStatePhoneBody,
)
Widget jeeberTabFailureStateEarnings() => JeeberTabFailureState(
      identifier: JeeberTabFailureState.earningsIdentifier,
      failure: const ServerFailure(status: 503),
      onRetry: () {},
    );

/// The unrecoverable kind: KYC-pending 403 leaves by the gate, not by Retry.
@JeebPreview(
  group: 'shell',
  name: 'Dashboard tab · forbidden',
  size: _jeeberTabFailureStatePhoneBody,
)
Widget jeeberTabFailureStateForbidden() => JeeberTabFailureState(
      identifier: JeeberTabFailureState.dashboardIdentifier,
      failure: const ForbiddenFailure(),
      onRetry: () {},
    );

/// The first frame of a cold start, before `available_roles` resolves.
@JeebPreview(
  group: 'shell',
  name: 'Dashboard tab · availability loading',
  size: _jeeberTabFailureStatePhoneBody,
)
Widget jeeberTabLoadingStateDashboard() => const JeeberTabLoadingState(
      identifier: JeeberTabLoadingState.dashboardIdentifier,
    );

/// The same rung on the Earnings tab.
@JeebPreview(
  group: 'shell',
  name: 'Earnings tab · availability loading',
  size: _jeeberTabFailureStatePhoneBody,
)
Widget jeeberTabLoadingStateEarnings() => const JeeberTabLoadingState(
      identifier: JeeberTabLoadingState.earningsIdentifier,
    );
