import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Immutable, debug-only configuration that lets a SINGLE dev APK render any
/// screen / state / locale at runtime — no per-state rebuild.
///
/// It generalises the four compile-time `JEEB_DEV_*` dart-defines (which were
/// `const String.fromEnvironment`, so frozen at build time → one value per
/// APK) into a value object resolved at startup from a runtime source (Android
/// intent extras or a pushed device file). The dart-defines remain the lowest
/// fallback so in-flight `--dart-define` flows keep working unchanged.
///
/// Release builds never construct a non-empty instance: every read site is
/// `kDebugMode`-gated and [DevSeam.resolve] short-circuits to [empty] in
/// release. The class is therefore inert (and tree-shakeable) in production.
@immutable
class DevSeamConfig {
  const DevSeamConfig({
    this.route = '',
    this.chatSelector = '',
    this.forcedLocale = '',
    this.homeTab = '',
    this.holdSplash = false,
  });

  /// Builds a config from a flat string map (intent extras or decoded JSON).
  /// Keys mirror the dart-define names without the `JEEB_` prefix, lower-cased
  /// and dotted: `jeeb.route`, `jeeb.state`, `jeeb.locale`, `jeeb.hold_splash`.
  factory DevSeamConfig.fromMap(Map<String, String> map) {
    return DevSeamConfig(
      route: map['jeeb.route']?.trim() ?? '',
      chatSelector: map['jeeb.state']?.trim() ?? '',
      forcedLocale: map['jeeb.locale']?.trim() ?? '',
      homeTab: map['jeeb.home_tab']?.trim() ?? '',
      holdSplash: _asBool(map['jeeb.hold_splash']),
    );
  }

  /// Parses a `jeeb-dev-seam.json` device-file payload. Returns [empty] on any
  /// malformed input — a broken dev file must never crash app startup.
  factory DevSeamConfig.fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return empty;
      final flat = decoded.map((k, v) => MapEntry('$k', '${v ?? ''}'));
      return DevSeamConfig.fromMap(flat);
    } catch (_) {
      return empty;
    }
  }

  /// Direct route override (generalises `JEEB_DEV_HOME`). When non-empty the
  /// router lands straight on this location, bypassing onboarding + biometric
  /// gates. `/` reproduces the old `JEEB_DEV_HOME=true` behaviour.
  final String route;

  /// Chat fixture selector (replaces `JEEB_DEV_CHAT`, e.g. `broadcasting`,
  /// `accepted`, `dm`, `dm-order-picked`, …). When non-empty the router lands
  /// on the fixtures-backed chat preview for that state.
  final String chatSelector;

  /// Forced locale language code (replaces `JEEB_FORCE_LOCALE`, e.g. `ar`).
  final String forcedLocale;

  /// Client "My Orders" filter tab to land on when [route] resolves to the
  /// shell home (`in_progress`, `pending`, `replies`). Debug capture aid only:
  /// the home tab seeds deterministic fixtures and selects this filter so a
  /// single APK renders screens 13/14/15 without a rebuild. Empty in release.
  final String homeTab;

  /// Holds the branded splash on screen after bootstrap (replaces
  /// `JEEB_HOLD_SPLASH`).
  final bool holdSplash;

  /// The inert default. The only instance a release build ever sees.
  static const DevSeamConfig empty = DevSeamConfig();

  bool get hasRoute => route.isNotEmpty;
  bool get hasChatSelector => chatSelector.isNotEmpty;
  bool get hasForcedLocale => forcedLocale.isNotEmpty;
  bool get hasHomeTab => homeTab.isNotEmpty;

  /// True when every field is at its inert default (nothing to apply).
  bool get isEmpty =>
      route.isEmpty &&
      chatSelector.isEmpty &&
      forcedLocale.isEmpty &&
      homeTab.isEmpty &&
      !holdSplash;

  static bool _asBool(String? value) {
    final v = value?.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes';
  }

  @override
  bool operator ==(Object other) =>
      other is DevSeamConfig &&
      other.route == route &&
      other.chatSelector == chatSelector &&
      other.forcedLocale == forcedLocale &&
      other.homeTab == homeTab &&
      other.holdSplash == holdSplash;

  @override
  int get hashCode =>
      Object.hash(route, chatSelector, forcedLocale, homeTab, holdSplash);

  @override
  String toString() => 'DevSeamConfig(route: $route, chat: $chatSelector, '
      'locale: $forcedLocale, homeTab: $homeTab, holdSplash: $holdSplash)';
}
