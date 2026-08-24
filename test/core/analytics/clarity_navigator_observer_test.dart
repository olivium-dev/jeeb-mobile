import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_analytics_port.dart';
import 'package:jeeb_mobile/core/analytics/clarity/presentation/clarity_navigator_observer.dart';

void main() {
  test(
    'allowlist canonicalizes paths without leaking identifiers or queries',
    () {
      expect(
        ClarityRouteAllowlist.canonicalize(
          '/chat/customer@example.com?token=secret&text=hello',
        ),
        ClarityRouteAllowlist.chatDetail,
      );
      expect(
        ClarityRouteAllowlist.canonicalize('/wallet/transactions/123-45'),
        ClarityRouteAllowlist.transactionDetail,
      );
      expect(
        ClarityRouteAllowlist.canonicalize('/profile/delivery-man/reviews'),
        'reviews-list',
      );
      expect(
        ClarityRouteAllowlist.canonicalize('/not-real/private-user-text'),
        ClarityRouteAllowlist.unknown,
      );
    },
  );

  test(
    'observer retains canonical routes for consent-aware late activation',
    () {
      final reporter = _Reporter();
      final observer = ClarityNavigatorObserver(reporter);
      final shell = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const SizedBox(),
      );
      final chat = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/chat/pii-id?token=secret'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(chat, shell);
      observer.didPush(chat, shell);
      observer.didPop(chat, shell);
      observer.didReplace(newRoute: chat, oldRoute: shell);
      expect(reporter.screens, [
        'chat-detail',
        'chat-detail',
        'shell',
        'chat-detail',
      ]);
      expect(reporter.screens.join(), isNot(contains('pii-id')));
    },
  );
}

final class _Reporter implements ClarityScreenReporter {
  final List<String> screens = [];

  @override
  bool get canReportClarityScreen => false;

  @override
  void reportClarityScreen(String screenName) => screens.add(screenName);
}
