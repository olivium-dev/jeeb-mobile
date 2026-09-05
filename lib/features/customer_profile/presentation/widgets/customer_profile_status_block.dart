import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/app_failure.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/customer_profile_state.dart';
import '../../domain/customer_profile_repository.dart';

/// The two `GET /users/me` states the identity card cannot carry on its own,
/// drawn by the Midnight empty family (`JeebEmptyState`, kit ruling 1: loading
/// is the breathing skeleton, error is the danger-tinted centre).
///
/// `radar` is the variant: it is the only one whose drawn subjects are identity
/// discs (E2's letter avatars) over a "listening for a signal" core, which is
/// what an unresolved account read is. Every other variant draws a *request*
/// subject — a mic, a parcel, a scooter — and would tell the wrong story on a
/// profile surface.
///
/// It is [JeebEmptyState.compact] because it sits INSIDE the page under a
/// mounted identity card rather than owning the screen, and it never replaces
/// the row groups: signing out has to stay reachable when the read fails.
class CustomerProfileStatusBlock extends StatelessWidget {
  const CustomerProfileStatusBlock({
    super.key,
    required this.state,
    required this.onRetry,
    this.onDismissRefreshError,
  });

  static const String loadingIdentifier = 'customer_profile_loading';
  static const String errorIdentifier = 'customer_profile_load_error';
  static const String retryIdentifier = 'customer_profile_load_retry';

  static const String refreshErrorIdentifier = 'customer_profile_refresh_error';

  final CustomerProfileState state;
  final VoidCallback onRetry;

  /// Clears `refreshError`; null renders the strip without a dismiss act.
  final VoidCallback? onDismissRefreshError;

  /// True while the read is in flight and there is nothing seeded to show.
  static bool isBlankLoad(CustomerProfileState state) =>
      state.status == CustomerProfileStatus.loading &&
      state.data.name == null &&
      state.data.email == null &&
      state.data.avatarUrl == null &&
      state.data.rating == null;

  /// Whether this block draws at all for [state].
  static bool showsFor(CustomerProfileState state) =>
      state.appFailure != null ||
      state.refreshError != null ||
      isBlankLoad(state);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final AppFailure? refreshError = state.refreshError;
    if (refreshError != null) {
      // The stale profile stays on screen; only the strip reports the miss.
      return JeebRefreshFailedNote(
        failure: refreshError,
        identifier: refreshErrorIdentifier,
        onDismiss: onDismissRefreshError ?? () {},
        onRetry: onRetry,
      );
    }
    final AppFailure? failure = state.appFailure;
    if (failure != null) {
      final unauthorized = state.error == CustomerProfileFailure.unauthorized;
      // A terminal kind gets an exit, never an inert block with no CTA at all.
      final exit = !failure.isRetryable;
      return JeebFailureBlock.compact(
        failure: failure,
        identifier: errorIdentifier,
        variant: JeebEmptyStateVariant.radar,
        retryIdentifier: retryIdentifier,
        onRetry: failure.isRetryable ? onRetry : null,
        onExit: !exit
            ? null
            : () => unauthorized
                  ? context.goNamed('login')
                  : context.goNamed('shell'),
        exitLabel: !exit
            ? null
            : (unauthorized ? l10n.actionSignIn : l10n.actionBack),
        exitIdentifier: exit && unauthorized
            ? 'customer_profile_error_signin_cta'
            : null,
      );
    }
    return JeebEmptyState.compact(
      variant: JeebEmptyStateVariant.radar,
      status: JeebEmptyStateStatus.loading,
      identifier: loadingIdentifier,
      headline: l10n.customerProfileLoadingHeadline,
    );
  }
}
