import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/router/root_aware_back_scope.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Dispatches the platform `popRoute` message — the exact channel the OS uses
/// for the Android system BACK gesture.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

/// Minimal offer repository — the composer never submits in this test, so the
/// method body is never reached; it exists only so the screen constructs.
class _FakeOfferRepo implements OfferSubmissionRepository {
  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      const OfferSubmissionResult(offerId: 'off-1', conversationId: 'conv-1');
}

void main() {
  // A router that mounts the REAL offer composer wrapped exactly as
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('HOME-SHELL'))),
          ),
          GoRoute(
            path: '/jeeber/requests/:id/offer',
            builder: (context, state) => RootAwareBackScope(
              fallbackLocation: '/',
              child: OfferSubmissionScreen(
                requestId: state.pathParameters['id'] ?? '',
                submissionService: null,
                repository: _FakeOfferRepo(),
                onWithdrawn: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                onRequestGone: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
          ),
        ],
      );

  Widget collapseNullChild(BuildContext context, Widget? child) =>
      child ?? const SizedBox.shrink();

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: collapseNullChild,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets(
    'system BACK from the offer composer reached via go() (push/deep-link '
    'root) pops to the shell, not the launcher',
    (tester) async {
      final router = await pump(tester);
      expect(find.text('HOME-SHELL'), findsOneWidget);

      // Push-notification / deep-link entry: a stack-REPLACING navigation.
      router.go('/jeeber/requests/req-1/offer');
      await tester.pumpAndSettle();
      expect(find.byType(OfferSubmissionScreen), findsOneWidget);
      expect(locationOf(router), '/jeeber/requests/req-1/offer');

      await systemBack(tester);
      await tester.pumpAndSettle();

      // Landed back on the shell instead of exiting; surface never blank.
      expect(locationOf(router), '/');
      expect(find.text('HOME-SHELL'), findsOneWidget);
    },
  );
}
