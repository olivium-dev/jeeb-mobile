import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/customer_profile_state.dart';

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
  });

  static const String loadingIdentifier = 'customer_profile_loading';
  static const String errorIdentifier = 'customer_profile_load_error';
  static const String retryIdentifier = 'customer_profile_load_retry';

  final CustomerProfileState state;
  final VoidCallback onRetry;

  /// True while the read is in flight and there is nothing seeded to show.
  static bool isBlankLoad(CustomerProfileState state) =>
      state.status == CustomerProfileStatus.loading &&
      state.data.name == null &&
      state.data.email == null &&
      state.data.avatarUrl == null &&
      state.data.rating == null;

  /// Whether this block draws at all for [state].
  static bool showsFor(CustomerProfileState state) =>
      state.error != null || isBlankLoad(state);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.error != null) {
      return JeebEmptyState.compact(
        variant: JeebEmptyStateVariant.radar,
        status: JeebEmptyStateStatus.error,
        identifier: errorIdentifier,
        headline: l10n.customerProfileLoadErrorTitle,
        action: JeebCtaButton.outline(
          label: l10n.customerProfileLoadErrorRetry,
          onTap: onRetry,
          expand: false,
          identifier: retryIdentifier,
        ),
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
