import 'package:flutter/widgets.dart';

import '../../../diagnostics/diag_redaction.dart';
import '../observability.dart';
import '../secret_redactor.dart';

/// SCREEN capture — the Jeeb session-trace tool's Module 1 (architecture
/// contract §4).
///
/// A [NavigatorObserver] that emits one `ObsScreenEvent` per navigation
/// transition (push / pop / replace) through [Observability.instance]. It is
/// registered on the app's `GoRouter` via its `observers:` list, so it sees
/// every push/pop/replace including deep-link-driven and redirect-driven
/// transitions.
///
/// Modeled on `DiagNavObserver`
/// (`lib/core/diagnostics/diag_nav_observer.dart`) almost line-for-line —
/// same route-PATTERN/name extraction from `route.settings.name` via
/// [DiagRedaction.scrubPath] (see `lib/core/router/app_router.dart` for the
/// `path:`/`name:` conventions this reads, e.g. `path: '/orders/:id'`,
/// `name: 'delivery-detail'`), same previous-route semantics — but this
/// observer:
///
///  * emits into the richer session-trace tool ([Observability.instance])
///    instead of the `[jeeb-diag]` stream, so it runs ALONGSIDE
///    `DiagNavObserver`, not instead of it — both are registered together,
///    neither replaces the other;
///  * passes path params through the stricter [SecretRedactor] (always
///    `full: true` — architecture contract §7 rule 3: path params are
///    typically bare ids/codes, so the extra long-bare-digit-run precaution
///    always applies here, independent of the live
///    `ObservabilityConfig.redactionEnabled` toggle) rather than
///    `DiagRedaction.scrubMap`.
///
/// It also keeps [Observability.currentScreen] pointing at the route
/// currently on top, exactly like `Diag.currentScreen` — `ObsDioInterceptor`
/// (Module 2) and `ObsInteractionObserver` (Module 4) stamp that value onto
/// their own events, so an exported session answers "which screen was
/// active" for every signal, not just screen transitions.
///
/// Every override is a total, non-throwing no-op whenever
/// [Observability.recording] is false (tool not compiled in, or
/// runtime-disabled) — checked BEFORE any work runs, including reading
/// `route.settings`.
///
/// ## Registration
///
/// This module intentionally does NOT wire itself into `AppRouter.create` —
/// per the architecture contract that is the integration step's job (§6,
/// wiring point **W1**), applied ADDITIVELY next to the existing
/// `DiagNavObserver`, inside `lib/core/router/app_router.dart`'s single
/// `GoRouter(...)` construction (currently `observers: [DiagNavObserver()],`
/// at the time this file was written):
///
/// ```dart
/// observers: [
///   DiagNavObserver(),
///   if (kObsCompiledIn) ObsNavObserver(),   // ADDED
/// ],
/// ```
///
/// No other file needs to change to activate this module — `ObsNavObserver`
/// depends only on [Observability], [SecretRedactor], and [DiagRedaction],
/// all already reachable from `lib/core/router/`.
final class ObsNavObserver extends NavigatorObserver {
  ObsNavObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _emit('push', route, from: previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // On a pop the destination the user LANDS ON is `previousRoute` — the
    // more useful "where am I now" signal — falling back to the popped route
    // itself when go_router didn't supply one. The POPPED route becomes the
    // `previousRoute` CONTEXT on the emitted event (the screen just left).
    _emit('pop', previousRoute ?? route, from: route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _emit('replace', newRoute, from: oldRoute);
  }

  /// Builds + records one `ObsScreenEvent`. Total no-op — not even reading
  /// `route.settings` — whenever [Observability.recording] is false or
  /// [route] is null (e.g. a `didReplace` with no new route).
  void _emit(String action, Route<dynamic>? route, {Route<dynamic>? from}) {
    if (!Observability.instance.recording || route == null) return;
    final settings = route.settings;
    final pattern = _routePattern(settings);
    // Track the active screen for api/interaction stamping BEFORE emitting,
    // so the screen event and anything fired from the new screen agree.
    Observability.instance.currentScreen =
        pattern ?? Observability.instance.currentScreen;
    Observability.instance.recordScreen(
      action: action,
      route: pattern,
      name: _routeName(settings),
      previousRoute: from == null ? null : _routePattern(from.settings),
      params: _redactedPathParams(settings),
    );
  }

  /// The route PATH PATTERN. go_router stashes its `RouteMatchList`-derived
  /// info on `settings.name` for named routes; when the name is a raw
  /// location (`/orders/d-42?x=1`) we strip the query so only the path is
  /// recorded. Identical extraction to `DiagNavObserver._routePattern`.
  static String? _routePattern(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;
    return DiagRedaction.scrubPath(name);
  }

  /// The route NAME. For a go_router named route (see
  /// `lib/core/router/app_router.dart`, e.g. `name: 'delivery-detail'`) this
  /// is the route's declared name; for an unnamed/raw-location route it is
  /// the location, query-stripped. Kept as a separate accessor from
  /// [_routePattern] — even though both currently read the same
  /// `settings.name` field, identically to `DiagNavObserver` — so a future
  /// change that separates the two at the go_router layer only needs to
  /// update one of them.
  static String? _routeName(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;
    return DiagRedaction.scrubPath(name);
  }

  /// Redacts the route's path params (architecture contract §4 Module 1):
  /// unconditionally `full: true`, NOT gated by the live
  /// `ObservabilityConfig.redactionEnabled` toggle. Defensive fallback
  /// (never a forced cast) mirrors `ObsNotificationRecorder._redactData`: an
  /// unexpected runtime shape degrades to an empty map instead of ever
  /// throwing into this hot path.
  static Map<String, Object?> _redactedPathParams(RouteSettings settings) {
    final redacted = SecretRedactor.redactBody(
      _pathParams(settings),
      full: true,
    );
    return redacted is Map<String, Object?>
        ? redacted
        : const <String, Object?>{};
  }

  /// Extracts go_router path params when they were passed via
  /// `settings.arguments` as a `Map`. Non-map arguments (typed `extra`
  /// payloads) are omitted rather than serialized — an arbitrary `extra`
  /// object may carry PII. Identical extraction to
  /// `DiagNavObserver._pathParams`.
  static Map<String, Object?> _pathParams(RouteSettings settings) {
    final args = settings.arguments;
    if (args is Map<String, Object?>) return args;
    if (args is Map) {
      return args.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, Object?>{};
  }
}
