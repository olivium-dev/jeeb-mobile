import 'package:flutter/widgets.dart';

import '../domain/clarity_analytics_port.dart';

final class ClarityNavigatorObserver extends NavigatorObserver {
  ClarityNavigatorObserver(this._reporter);

  final ClarityScreenReporter _reporter;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _report(newRoute);
  }

  void _report(Route<dynamic>? route) {
    // The controller caches this canonical value while capture is off, then
    // applies it when consent/auth initialization activates later.
    _reporter.reportClarityScreen(
      ClarityRouteAllowlist.canonicalize(route?.settings.name),
    );
  }
}

abstract final class ClarityRouteAllowlist {
  static const String unknown = 'unknown';
  static const String chatDetail = 'chat-detail';
  static const String transactionDetail = 'transaction-detail';

  static const Set<String> canonicalNames = <String>{
    unknown,
    'account-status',
    'address-detail',
    'biometric-lock',
    'capture-location',
    chatDetail,
    'client-location',
    'compose-dictation',
    'compose-dictation-review',
    'customer-profile',
    'customer-wallet',
    'delivered-receipt',
    'delivery-cancel',
    'delivery-detail',
    'delivery-man-profile',
    'delivery-register-prompt',
    'dispute-status',
    'earnings',
    'escalate',
    'feedback',
    'jeeber-active-delivery',
    'jeeber-offer-submission',
    'jeeber-onboarding',
    'jeeber-pending-offers',
    'jeeber-request-detail',
    'kyc-rejected',
    'kyc-status',
    'language-settings',
    'live-tracking',
    'mutual-rating',
    'notifications',
    'offer-kyc-gate',
    'offer-review',
    'onboarding',
    'onboarding-funding',
    'order-summary',
    'otp-handover',
    'password-security',
    'rating-prompt',
    'register',
    'request-summary',
    'request-type',
    'reviews-list',
    'reviews-list-by-id',
    'set-password',
    'settings',
    'settings-addresses',
    'settings-diagnostics',
    'settings-notifications',
    'settings-profile',
    'shell',
    'support-ticket',
    'support-ticket-detail',
    'support-ticket-detail-legacy',
    transactionDetail,
    'transcription',
    'voice-request',
    'waiting-no-coverage',
    'wallet',
    'wallet-activity',
    'wallet-charge-info',
  };

  static const Map<String, String> _exactPaths = <String, String>{
    '/': 'shell',
    '/onboarding': 'onboarding',
    '/register': 'register',
    '/lock': 'biometric-lock',
    '/set-password': 'set-password',
    '/account-status': 'account-status',
    '/profile/kyc': 'kyc-status',
    '/jeeber/onboarding': 'jeeber-onboarding',
    '/profile/customer': 'customer-profile',
    '/profile/delivery-man': 'delivery-man-profile',
    '/profile/delivery-man/reviews': 'reviews-list',
    '/settings': 'settings',
    '/settings/profile': 'settings-profile',
    '/settings/addresses': 'settings-addresses',
    '/settings/addresses/edit': 'address-detail',
    '/settings/notifications': 'settings-notifications',
    '/settings/diagnostics': 'settings-diagnostics',
    '/settings/language': 'language-settings',
    '/settings/password': 'password-security',
    '/voice-request': 'voice-request',
    '/request-type': 'request-type',
    '/client-location': 'client-location',
    '/capture-location': 'capture-location',
    '/voice-request/transcription': 'transcription',
    '/compose-dictation': 'compose-dictation',
    '/compose-dictation/review': 'compose-dictation-review',
    '/request-summary': 'request-summary',
    '/jeeber/onboarding/funding': 'onboarding-funding',
    '/jeeber/offer-gate': 'offer-kyc-gate',
    '/jeeber/register-prompt': 'delivery-register-prompt',
    '/kyc/rejected': 'kyc-rejected',
    '/jeeber/pending-offers': 'jeeber-pending-offers',
    '/wallet': 'wallet',
    '/wallet/customer': 'customer-wallet',
    '/wallet/charge-info': 'wallet-charge-info',
    '/earnings': 'earnings',
    '/wallet/activity': 'wallet-activity',
    '/notifications': 'notifications',
    '/support': 'support-ticket',
  };

  static String canonicalize(String? input) {
    if (input == null || input.isEmpty || input.length > 2048) return unknown;
    if (canonicalNames.contains(input)) return input;
    final path = Uri.tryParse(input)?.path;
    if (path == null) return unknown;
    final exact = _exactPaths[path];
    if (exact != null) return exact;
    return _dynamicPath(path);
  }

  static String _dynamicPath(String path) {
    final segments = Uri.tryParse(path)?.pathSegments ?? const <String>[];
    if (segments.length == 2 && segments.first == 'chat') return chatDetail;
    if (segments.length == 3 &&
        segments[0] == 'wallet' &&
        segments[1] == 'transactions') {
      return transactionDetail;
    }
    if (segments.length == 2 && segments.first == 'disputes') {
      return 'dispute-status';
    }
    if (segments.length == 3 &&
        segments.first == 'support' &&
        segments[1] == 'tickets') {
      return 'support-ticket-detail';
    }
    if (segments.length == 2 && segments.first == 'support') {
      return 'support-ticket-detail-legacy';
    }
    if (segments.length >= 2 && segments.first == 'orders') {
      if (segments.length == 2) return 'delivery-detail';
      return switch (segments[2]) {
        'receipt' => 'delivered-receipt',
        'summary' => 'order-summary',
        'cancel' => 'delivery-cancel',
        'rate' => 'rating-prompt',
        'tracking' => 'live-tracking',
        'otp' => 'otp-handover',
        'feedback' => 'feedback',
        'mutual-rate' => 'mutual-rating',
        'escalate' => 'escalate',
        _ => unknown,
      };
    }
    if (segments.length == 3 && segments.first == 'requests') {
      return switch (segments[2]) {
        'offers' => 'offer-review',
        'waiting' => 'waiting-no-coverage',
        _ => unknown,
      };
    }
    if (segments.length >= 3 && segments.first == 'jeeber') {
      if (segments[1] == 'requests') {
        return segments.length == 4 && segments[3] == 'offer'
            ? 'jeeber-offer-submission'
            : 'jeeber-request-detail';
      }
      if (segments[1] == 'deliveries' &&
          segments.length == 4 &&
          segments[3] == 'active') {
        return 'jeeber-active-delivery';
      }
    }
    if (segments.length == 4 &&
        segments[0] == 'profile' &&
        segments[1] == 'delivery-man' &&
        segments[3] == 'reviews') {
      return 'reviews-list-by-id';
    }
    return unknown;
  }
}
