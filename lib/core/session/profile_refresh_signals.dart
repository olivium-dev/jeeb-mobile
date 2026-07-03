import 'dart:async';

/// App-wide broadcast bus for "the signed-in user's profile changed — re-pull
/// getMe". Mirrors [PushRefreshSignals] (`push_refresh_signals.dart`), which
/// plays the same role for order-status pushes.
///
/// Publishers: the display-name save paths (post-OTP onboarding step and the
/// settings profile edit) after a successful `PUT /api/User/profile`.
/// Subscribers: profile-derived display state (e.g. [GreetingProfileCubit])
/// that lives inside the shell's IndexedStack and would otherwise stay stale
/// until the tab remounts.
///
/// Registered as a lazy singleton in the DI container so both sides resolve
/// the SAME instance without a widget-tree provider dependency.
class ProfileRefreshSignals {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// Fires (payload-less) whenever the local user's profile was updated.
  /// Subscribers re-pull their own getMe snapshot.
  Stream<void> get stream => _controller.stream;

  /// Publish a profile-changed signal. No-op after [dispose].
  void signalProfileChanged() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
