import 'package:flutter/foundation.dart';

import 'dev_seam_config.dart';
import 'dev_seam_source.dart';

/// Global, debug-only holder of the resolved [DevSeamConfig].
///
/// One dev APK can render any screen / state / locale because every consumer
/// (router, locale cubit, splash host) reads [current] at RUNTIME instead of a
/// compile-time `const`. The value is resolved once during bootstrap from a
/// priority-ordered source list (intent extras → device file → dart-define),
/// then exposed through the typed getters below.
///
/// Release-inert by construction: [resolve] short-circuits to
/// [DevSeamConfig.empty] when `!kDebugMode`, and [current] returns [empty]
/// until/unless a debug resolve runs, so every getter is `false`/empty in
/// production.
class DevSeam {
  DevSeam._();

  static DevSeamConfig _current = DevSeamConfig.empty;

  /// The resolved config. [DevSeamConfig.empty] in release and before
  /// [resolve] completes.
  static DevSeamConfig get current => _current;

  /// Default source order: runtime sources first (so adb can drive a built
  /// APK), dart-define last (so existing build flows still work).
  static const List<DevSeamSource> _defaultSources = <DevSeamSource>[
    IntentExtrasSource(),
    DeviceFileSource(),
    DartDefineSource(),
  ];

  /// Resolves the seam from [sources] (defaults to [_defaultSources]) and
  /// stores the result in [current]. No-op in release builds. Each source is
  /// merged field-by-field: an earlier source overrides only the fields it
  /// actually provides, so e.g. an intent that sets only `jeeb.locale` still
  /// inherits a route from the device file or dart-define.
  static Future<void> resolve({List<DevSeamSource>? sources}) async {
    if (!kDebugMode) {
      _current = DevSeamConfig.empty;
      return;
    }
    var merged = DevSeamConfig.empty;
    for (final source in sources ?? _defaultSources) {
      merged = _mergePreferring(merged, await source.read());
    }
    // Wave 1 journey seam (63_W1_TEST_PLAN §4): a `jeeb.seam.journey` value that
    // implies a deep landing folds its route pin into [DevSeamConfig.route] so
    // the EXISTING router route-pin (app_router `_devRoute`) lands the flow on
    // the right screen — without the flow having to also pass `jeeb.route` and
    // without editing the router. An explicit `jeeb.route` always wins (so a
    // flow can still override the journey's default landing). Journeys whose
    // routePin is empty (offers_received / has_saved_addresses) leave the route
    // untouched, so the app lands on the shell and the flow navigates there.
    merged = _applyJourneyRoutePin(merged);
    _current = merged;
    if (!merged.isEmpty) {
      debugPrint('DevSeam resolved: $merged');
    }
  }

  /// Folds [JourneySeed.routePin] into [DevSeamConfig.route] when a journey seed
  /// implies a deep landing and no explicit route was already set. Returns
  /// [config] unchanged when there is no journey, the journey has no route pin,
  /// or an explicit `jeeb.route` is present.
  static DevSeamConfig _applyJourneyRoutePin(DevSeamConfig config) {
    if (!config.hasJourneySeed) return config;
    if (config.route.isNotEmpty) return config; // explicit route wins
    final pin = config.journeySeed.routePin;
    if (pin.isEmpty) return config;
    return DevSeamConfig(
      route: pin,
      chatSelector: config.chatSelector,
      forcedLocale: config.forcedLocale,
      homeTab: config.homeTab,
      feed: config.feed,
      holdSplash: config.holdSplash,
      skipOnboarding: config.skipOnboarding,
      sessionSeed: config.sessionSeed,
      journeySeed: config.journeySeed,
      kycStatusSeed: config.kycStatusSeed,
      walletStateSeed: config.walletStateSeed,
      otpCode: config.otpCode,
      otpCountdownExpired: config.otpCountdownExpired,
      signupCollision: config.signupCollision,
      socialLogin: config.socialLogin,
      recoveryCode: config.recoveryCode,
      recoveryCountdownExpired: config.recoveryCountdownExpired,
      setPasswordMode: config.setPasswordMode,
    );
  }

  /// Field-wise merge where [primary] (a higher-priority source) wins on any
  /// field it sets; [fallback] fills the gaps.
  static DevSeamConfig _mergePreferring(
    DevSeamConfig primary,
    DevSeamConfig fallback,
  ) {
    return DevSeamConfig(
      route: primary.route.isNotEmpty ? primary.route : fallback.route,
      chatSelector: primary.chatSelector.isNotEmpty
          ? primary.chatSelector
          : fallback.chatSelector,
      forcedLocale: primary.forcedLocale.isNotEmpty
          ? primary.forcedLocale
          : fallback.forcedLocale,
      homeTab:
          primary.homeTab.isNotEmpty ? primary.homeTab : fallback.homeTab,
      feed: primary.feed.isNotEmpty ? primary.feed : fallback.feed,
      holdSplash: primary.holdSplash || fallback.holdSplash,
      skipOnboarding: primary.skipOnboarding || fallback.skipOnboarding,
      // Wave 0 dev-seam session/journey harness fields (62_SEAM_HARNESS.md):
      // primary (higher-priority source) wins on any field it sets.
      sessionSeed: primary.sessionSeed != SessionSeed.none
          ? primary.sessionSeed
          : fallback.sessionSeed,
      // Wave 1 journey seam (63_W1_TEST_PLAN §4): primary wins on any journey it
      // sets; the route pin is folded in by [_applyJourneyRoutePin] after merge.
      journeySeed: primary.journeySeed != JourneySeed.none
          ? primary.journeySeed
          : fallback.journeySeed,
      // Wave 2 jeeber seam (65_W2_TEST_PLAN §3): primary wins on any kyc/wallet
      // seed it sets.
      kycStatusSeed: primary.kycStatusSeed != KycStatusSeed.none
          ? primary.kycStatusSeed
          : fallback.kycStatusSeed,
      walletStateSeed: primary.walletStateSeed != WalletStateSeed.none
          ? primary.walletStateSeed
          : fallback.walletStateSeed,
      otpCode: primary.otpCode.isNotEmpty ? primary.otpCode : fallback.otpCode,
      otpCountdownExpired:
          primary.otpCountdownExpired || fallback.otpCountdownExpired,
      signupCollision: primary.signupCollision || fallback.signupCollision,
      socialLogin: primary.socialLogin.isNotEmpty
          ? primary.socialLogin
          : fallback.socialLogin,
      recoveryCode: primary.recoveryCode.isNotEmpty
          ? primary.recoveryCode
          : fallback.recoveryCode,
      recoveryCountdownExpired:
          primary.recoveryCountdownExpired || fallback.recoveryCountdownExpired,
      setPasswordMode: primary.setPasswordMode.isNotEmpty
          ? primary.setPasswordMode
          : fallback.setPasswordMode,
    );
  }

  /// Test-only override; lets widget/unit tests inject a config without a
  /// platform channel. Asserts it is never used outside debug.
  @visibleForTesting
  static void debugOverride(DevSeamConfig config) {
    assert(kDebugMode, 'DevSeam.debugOverride must not run in release');
    _current = config;
  }

  /// Test-only reset to the inert default.
  @visibleForTesting
  static void debugReset() => _current = DevSeamConfig.empty;
}
