import 'package:flutter/widgets.dart';

/// App-wide [RouteObserver] for screens that need to know when they are the
/// route the user is actually LOOKING AT — not merely mounted.
///
/// Registered on the app [GoRouter]'s `observers:` list (see `AppRouter.create`)
/// alongside `DiagNavObserver`; the router is a flat set of `GoRoute`s on the
/// root navigator (no `ShellRoute` / `StatefulShellRoute` / bare `Navigator(`
/// found in `lib/` by `grep -rn 'ShellRoute\|StatefulShellRoute\|Navigator('`),
/// so one observer on the root navigator sees every transition.
///
/// Why this is not the same thing as `initState`/`dispose`: a screen pushed on
/// TOP of the chat (order summary, dispute evidence, the pinned-summary route)
/// leaves `ChatDetailScreen`'s `State` mounted and undisposed while the user
/// can no longer see the conversation. `RouteAware.didPushNext` /
/// `didPopNext` are the only signals that distinguish those two states, and a
/// suppression that got it wrong would swallow a chat message the user had no
/// way to read.
RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// Mints a FRESH observer, publishes it as [appRouteObserver], and returns it.
///
/// Called by `AppRouter.create` for every router it builds. `NavigatorState`
/// asserts that one `NavigatorObserver` instance is attached to at most one
/// `Navigator` at a time ("The provided observer is already being used by
/// another Navigator instance"), so handing the SAME long-lived instance to
/// two concurrently-mounted routers — two app instances in one widget test,
/// a rebuilt router — would trip a debug assert. Minting per router keeps the
/// global reachable from a screen (no `InheritedWidget` exists for observers)
/// without owning that hazard. Mirrors what `DiagNavObserver()` already does
/// by being constructed inline in the `observers:` list.
RouteObserver<ModalRoute<void>> newAppRouteObserver() =>
    appRouteObserver = RouteObserver<ModalRoute<void>>();
