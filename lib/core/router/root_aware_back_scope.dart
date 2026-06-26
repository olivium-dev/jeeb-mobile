import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Guards against the "system BACK exits the app" navigation defect for screens
/// that can become the ROOT of the navigation stack.
///
/// Root cause (go vs push): `context.go(...)` / `context.goNamed(...)` — and an
/// inbound platform deep link or push-notification tap (`GoRouter.go`) — REPLACE
/// the navigation stack rather than PUSH onto it. A screen reached that way is
/// the lone page in go_router's `Navigator`. On the system BACK gesture,
/// go_router's `popRoute` sees the `Navigator` cannot pop and lets the event
/// propagate to the OS, exiting the app to the launcher. (`context.push(...)`
/// keeps the parent on the stack and does not exhibit this.)
///
/// Note (go_router 13.x): a `PopScope` does NOT fix this — `popRoute` only fires
/// `Navigator.maybePop` (and therefore `PopScope`) when the `Navigator` already
/// has something to pop, which a lone root page does not. We instead intercept
/// at the [BackButtonListener] layer, which receives the system BACK BEFORE
/// go_router's delegate and ONLY on a real back gesture (never on programmatic
/// navigation, so a screen's own `context.go(...)` — e.g. login success — is
/// untouched).
///
/// Behaviour:
///   * has a back stack (`context.canPop()`) → pop normally to the real parent;
///   * no back stack (the stack root) → navigate to [fallbackLocation] (the
///     screen's logical parent) instead of exiting.
/// Either way the gesture is consumed, so the system BACK never exits the app
/// from a wrapped screen — only the true home/root is left to do that.
class RootAwareBackScope extends StatelessWidget {
  const RootAwareBackScope({
    super.key,
    required this.fallbackLocation,
    required this.child,
  });

  /// Where to land when BACK is invoked and there is nothing to pop — the
  /// screen's logical parent route (e.g. `/` for order-detail, `/settings` for
  /// saved-addresses, `/register` for the login auth funnel). The router's
  /// first-run redirect still applies, so an unauthenticated user routed to `/`
  /// is forwarded to the auth entry rather than reaching Home.
  final String fallbackLocation;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackLocation);
        }
        // Consume the gesture: a wrapped screen never lets system BACK exit the
        // app — it always resolves to a parent destination.
        return true;
      },
      child: child,
    );
  }
}
