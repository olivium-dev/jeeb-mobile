import 'package:flutter/foundation.dart';

import 'dev_seam_config.dart';
import 'dev_seam_source.dart';

class DevSeam {
  DevSeam._();

  static DevSeamConfig _current = DevSeamConfig.empty;

  static DevSeamConfig get current => _current;

  static const List<DevSeamSource> _defaultSources = <DevSeamSource>[
    IntentExtrasSource(),
    DeviceFileSource(),
    DartDefineSource(),
  ];

  static Future<void> resolve({List<DevSeamSource>? sources}) async {
    if (!kDebugMode || const bool.fromEnvironment('JEEB_DISABLE_DEV_SEAM')) {
      _current = DevSeamConfig.empty;
      return;
    }
    var merged = DevSeamConfig.empty;
    for (final source in sources ?? _defaultSources) {
      merged = _mergePreferring(merged, await source.read());
    }
    merged = _applyJourneyRoutePin(merged);
    _current = merged;
    if (!merged.isEmpty) {
      debugPrint('DevSeam resolved: $merged');
    }
  }

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
      superLoginToken: config.superLoginToken,
      superLoginRefreshToken: config.superLoginRefreshToken,
      superLoginUserId: config.superLoginUserId,
      superLoginRole: config.superLoginRole,
    );
  }

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
      homeTab: primary.homeTab.isNotEmpty ? primary.homeTab : fallback.homeTab,
      feed: primary.feed.isNotEmpty ? primary.feed : fallback.feed,
      holdSplash: primary.holdSplash || fallback.holdSplash,
      skipOnboarding: primary.skipOnboarding || fallback.skipOnboarding,
      sessionSeed: primary.sessionSeed != SessionSeed.none
          ? primary.sessionSeed
          : fallback.sessionSeed,
      journeySeed: primary.journeySeed != JourneySeed.none
          ? primary.journeySeed
          : fallback.journeySeed,
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
      superLoginToken: primary.superLoginToken.isNotEmpty
          ? primary.superLoginToken
          : fallback.superLoginToken,
      superLoginRefreshToken: primary.superLoginRefreshToken.isNotEmpty
          ? primary.superLoginRefreshToken
          : fallback.superLoginRefreshToken,
      superLoginUserId: primary.superLoginUserId.isNotEmpty
          ? primary.superLoginUserId
          : fallback.superLoginUserId,
      superLoginRole: primary.superLoginRole.isNotEmpty
          ? primary.superLoginRole
          : fallback.superLoginRole,
    );
  }

  @visibleForTesting
  static void debugOverride(DevSeamConfig config) {
    assert(kDebugMode, 'DevSeam.debugOverride must not run in release');
    _current = config;
  }

  @visibleForTesting
  static void debugReset() => _current = DevSeamConfig.empty;
}
