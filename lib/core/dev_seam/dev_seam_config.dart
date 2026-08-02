import 'dart:convert';

import 'package:flutter/foundation.dart';

enum SessionSeed {
  none,
  customerLoggedIn('customer_logged_in'),
  jeeberLoggedIn('jeeber_logged_in'),
  loggedOutReturning('logged_out_returning'),
  biometricEnrolled('biometric_enrolled'),
  biometricEnrolledLoggedOut('biometric_enrolled_logged_out'),
  suspended('suspended'),

  /// Debug only: real gateway JWT via intent, never baked into binary.
  superLoginPlus('super_login_plus');

  const SessionSeed([this.wireValue = '']);

  final String wireValue;

  /// Typo-resilient: unknown → [none], never crashes startup.
  static SessionSeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return SessionSeed.none;
    for (final seed in SessionSeed.values) {
      if (seed.wireValue == v) return seed;
    }
    return SessionSeed.none;
  }
}

enum JourneySeed {
  none('', ''),
  pendingRequest('pending_request', '/requests/req-client-001-pending/waiting'),
  pendingRequestNoCoverage(
    'pending_request_no_coverage',
    '/requests/req-client-001-pending/waiting',
  ),
  offersReceived('offers_received', ''),
  orderAccepted('order_accepted', '/chat/conv-journey-accepted'),
  activeDelivery('active_delivery', '/orders/del-client-001-active/tracking'),
  deliveryMarkedDone(
    'delivery_marked_done',
    '/orders/del-client-001-delivered/receipt',
  ),
  jeeberRatingPending(
    'jeeber_rating_pending',
    '/orders/del-jeeber-002-delivered/mutual-rate?mode=jeeber',
  ),
  hasSavedAddresses('has_saved_addresses', ''),
  jeeberKycSubmitted('jeeber_kyc_submitted', '/jeeber/onboarding/funding'),
  jeeberFeedWithRequest('jeeber_feed_with_request', ''),
  jeeberPendingOffers('jeeber_pending_offers', ''),
  jeeberActiveDelivery(
    'jeeber_active_delivery',
    '/jeeber/deliveries/del-jeeber-002-active/active',
  ),
  hasNotifications('has_notifications', '/notifications'),
  disputeOpen('dispute_open', '/disputes/dispute-client-001-open'),
  jeeberHasReviews('jeeber_has_reviews', ''),
  walletWithLedger('wallet_with_ledger', ''),
  jeeberWalletFeeTxn('jeeber_wallet_fee_txn', ''),
  jeeberWalletRefundTxn('jeeber_wallet_refund_txn', ''),
  hasOpenDispute('has_open_dispute', ''),
  jeeberWalletLedger('jeeber_wallet_ledger', ''),
  jeeberColdStartProfile('jeeber_cold_start_profile', '');

  const JourneySeed(this.wireValue, this.routePin);

  final String wireValue;
  final String routePin;

  static JourneySeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return JourneySeed.none;
    for (final seed in JourneySeed.values) {
      if (seed.wireValue == v) return seed;
    }
    return JourneySeed.none;
  }
}

enum KycStatusSeed {
  none(''),
  statusNone('none'),
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const KycStatusSeed(this.wireValue);

  final String wireValue;

  static KycStatusSeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return KycStatusSeed.none;
    for (final seed in KycStatusSeed.values) {
      if (seed != KycStatusSeed.none && seed.wireValue == v) return seed;
    }
    return KycStatusSeed.none;
  }
}

enum WalletStateSeed {
  none(''),
  sufficient('sufficient'),
  insufficient('insufficient'),
  empty('empty');

  const WalletStateSeed(this.wireValue);

  final String wireValue;

  static WalletStateSeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return WalletStateSeed.none;
    for (final seed in WalletStateSeed.values) {
      if (seed != WalletStateSeed.none && seed.wireValue == v) return seed;
    }
    return WalletStateSeed.none;
  }
}

/// Debug-only config: single APK renders any screen/state/locale at runtime (no rebuild).
@immutable
class DevSeamConfig {
  const DevSeamConfig({
    this.route = '',
    this.chatSelector = '',
    this.forcedLocale = '',
    this.homeTab = '',
    this.feed = '',
    this.holdSplash = false,
    this.skipOnboarding = false,
    this.sessionSeed = SessionSeed.none,
    this.journeySeed = JourneySeed.none,
    this.kycStatusSeed = KycStatusSeed.none,
    this.walletStateSeed = WalletStateSeed.none,
    this.otpCode = '',
    this.otpCountdownExpired = false,
    this.signupCollision = false,
    this.socialLogin = '',
    this.recoveryCode = '',
    this.recoveryCountdownExpired = false,
    this.setPasswordMode = '',
    this.superLoginToken = '',
    this.superLoginRefreshToken = '',
    this.superLoginUserId = '',
    this.superLoginRole = '',
  });

  factory DevSeamConfig.fromMap(Map<String, String> map) {
    return DevSeamConfig(
      route: map['jeeb.route']?.trim() ?? '',
      chatSelector: map['jeeb.state']?.trim() ?? '',
      forcedLocale: map['jeeb.locale']?.trim() ?? '',
      homeTab: map['jeeb.home_tab']?.trim() ?? '',
      feed: map['jeeb.feed']?.trim() ?? '',
      holdSplash: _asBool(map['jeeb.hold_splash']),
      skipOnboarding: _asBool(map['jeeb.skip_onboarding']),
      sessionSeed: SessionSeed.fromWire(map['jeeb.seam.session']),
      journeySeed: JourneySeed.fromWire(map['jeeb.seam.journey']),
      kycStatusSeed: KycStatusSeed.fromWire(map['jeeb.seam.kyc_status']),
      walletStateSeed: WalletStateSeed.fromWire(map['jeeb.seam.wallet_state']),
      otpCode: map['jeeb.seam.otp_code']?.trim() ?? '',
      otpCountdownExpired: _asBool(map['jeeb.seam.otp_countdown_expired']),
      signupCollision: _asBool(map['jeeb.seam.signup_collision']),
      socialLogin: map['jeeb.seam.social_login']?.trim() ?? '',
      recoveryCode: map['jeeb.seam.recovery_code']?.trim() ?? '',
      recoveryCountdownExpired: _asBool(
        map['jeeb.seam.recovery_countdown_expired'],
      ),
      setPasswordMode: map['jeeb.seam.set_password_mode']?.trim() ?? '',
      superLoginToken: map['jeeb.seam.super_login_token']?.trim() ?? '',
      superLoginRefreshToken:
          map['jeeb.seam.super_login_refresh']?.trim() ?? '',
      superLoginUserId: map['jeeb.seam.super_login_user_id']?.trim() ?? '',
      superLoginRole: map['jeeb.seam.super_login_role']?.trim() ?? '',
    );
  }

  /// Returns [empty] on malformed input so broken dev files never crash startup.
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

  final String route;
  final String chatSelector;
  final String forcedLocale;
  final String homeTab;
  final String feed;
  final bool holdSplash;

  /// SECURITY-CRITICAL DEFAULT: false. Route pin used to silently skip onboarding + login.
  /// Now requires explicit opt-in so fresh installs land on /onboarding even with route pinned.
  final bool skipOnboarding;

  final SessionSeed sessionSeed;
  final JourneySeed journeySeed;
  final KycStatusSeed kycStatusSeed;
  final WalletStateSeed walletStateSeed;
  final String otpCode;
  final bool otpCountdownExpired;
  final bool signupCollision;
  final String socialLogin;
  final String recoveryCode;
  final bool recoveryCountdownExpired;
  final String setPasswordMode;
  final String superLoginToken;
  final String superLoginRefreshToken;
  final String superLoginUserId;
  final String superLoginRole;

  static const DevSeamConfig empty = DevSeamConfig();

  bool get hasRoute => route.isNotEmpty;
  bool get hasChatSelector => chatSelector.isNotEmpty;
  bool get hasForcedLocale => forcedLocale.isNotEmpty;
  bool get hasHomeTab => homeTab.isNotEmpty;
  bool get hasFeed => feed.isNotEmpty;
  bool get hasSessionSeed => sessionSeed != SessionSeed.none;
  bool get hasJourneySeed => journeySeed != JourneySeed.none;
  bool get hasKycStatusSeed => kycStatusSeed != KycStatusSeed.none;
  bool get hasWalletStateSeed => walletStateSeed != WalletStateSeed.none;
  bool get hasSetPasswordMode => setPasswordMode.isNotEmpty;
  bool get hasSocialLogin => socialLogin.isNotEmpty;

  bool get isEmpty =>
      route.isEmpty &&
      chatSelector.isEmpty &&
      forcedLocale.isEmpty &&
      homeTab.isEmpty &&
      feed.isEmpty &&
      !holdSplash &&
      !skipOnboarding &&
      sessionSeed == SessionSeed.none &&
      journeySeed == JourneySeed.none &&
      kycStatusSeed == KycStatusSeed.none &&
      walletStateSeed == WalletStateSeed.none &&
      otpCode.isEmpty &&
      !otpCountdownExpired &&
      !signupCollision &&
      socialLogin.isEmpty &&
      recoveryCode.isEmpty &&
      !recoveryCountdownExpired &&
      setPasswordMode.isEmpty &&
      superLoginToken.isEmpty &&
      superLoginRefreshToken.isEmpty &&
      superLoginUserId.isEmpty &&
      superLoginRole.isEmpty;

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
      other.feed == feed &&
      other.holdSplash == holdSplash &&
      other.skipOnboarding == skipOnboarding &&
      other.sessionSeed == sessionSeed &&
      other.journeySeed == journeySeed &&
      other.kycStatusSeed == kycStatusSeed &&
      other.walletStateSeed == walletStateSeed &&
      other.otpCode == otpCode &&
      other.otpCountdownExpired == otpCountdownExpired &&
      other.signupCollision == signupCollision &&
      other.socialLogin == socialLogin &&
      other.recoveryCode == recoveryCode &&
      other.recoveryCountdownExpired == recoveryCountdownExpired &&
      other.setPasswordMode == setPasswordMode &&
      other.superLoginToken == superLoginToken &&
      other.superLoginRefreshToken == superLoginRefreshToken &&
      other.superLoginUserId == superLoginUserId &&
      other.superLoginRole == superLoginRole;

  @override
  int get hashCode => Object.hashAll([
    route,
    chatSelector,
    forcedLocale,
    homeTab,
    feed,
    holdSplash,
    skipOnboarding,
    sessionSeed,
    journeySeed,
    kycStatusSeed,
    walletStateSeed,
    otpCode,
    otpCountdownExpired,
    signupCollision,
    socialLogin,
    recoveryCode,
    recoveryCountdownExpired,
    setPasswordMode,
    superLoginToken,
    superLoginRefreshToken,
    superLoginUserId,
    superLoginRole,
  ]);

  @override
  String toString() =>
      'DevSeamConfig(route: $route, chat: $chatSelector, '
      'locale: $forcedLocale, homeTab: $homeTab, feed: $feed, '
      'holdSplash: $holdSplash, skipOnboarding: $skipOnboarding, '
      'sessionSeed: ${sessionSeed.name}, journeySeed: ${journeySeed.name}, '
      'kycStatusSeed: ${kycStatusSeed.name}, '
      'walletStateSeed: ${walletStateSeed.name}, '
      'otpCode: $otpCode, '
      'otpCountdownExpired: $otpCountdownExpired, '
      'signupCollision: $signupCollision, socialLogin: $socialLogin, '
      'recoveryCode: $recoveryCode, '
      'recoveryCountdownExpired: $recoveryCountdownExpired, '
      'setPasswordMode: $setPasswordMode, '
      'superLoginToken: ${superLoginToken.isNotEmpty ? '[present]' : '[absent]'}, '
      'superLoginUserId: $superLoginUserId, '
      'superLoginRole: $superLoginRole)';
}
