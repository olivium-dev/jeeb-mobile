// App-wide system-BACK regression guard (item 1: "fix back buttons across ALL

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/router/root_aware_back_scope.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dispatches the platform `popRoute` message — the exact channel the OS uses
/// for the Android system BACK gesture (routed through the Router's
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

String _locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('backFallbacks map integrity', () {
    test('every fallback is a rooted (absolute) location', () {
      for (final entry in AppRouter.backFallbacks.entries) {
        expect(
          entry.value.startsWith('/'),
          isTrue,
          reason:
              '${entry.key} → "${entry.value}" must be an absolute route path',
        );
      }
    });

    test('deliberately EXCLUDED routes are never wrapped', () {
      // Home/first-run roots (BACK must be allowed to exit), gate screens (BACK
      const excluded = <String>[
        'shell',
        'onboarding',
        'register',
        'login', // self-wraps (fallback /register)
        'biometric-lock',
        'account-status',
        'feedback', // PopScope(canPop:false)
        'mutual-rating', // PopScope(canPop:false)
        'rating-prompt', // redirect-only placeholder
        'dev-chat', // debug only
        'delivery-detail', // self-wraps
        'settings-addresses', // self-wraps
        'jeeber-offer-submission', // self-wraps
      ];
      for (final name in excluded) {
        expect(
          AppRouter.backFallbacks.containsKey(name),
          isFalse,
          reason: '$name must NOT be centrally wrapped (see backFallbacks doc)',
        );
      }
    });

    test('high-risk deep-link / push-notification targets ARE wrapped', () {
      // These are the routes reachable as a stack ROOT from a notification tap
      const mustWrap = <String>[
        'chat-detail',
        'jeeber-request-detail',
        'waiting-no-coverage',
        'delivered-receipt',
        'live-tracking',
        'otp-handover',
        'wallet',
        'notifications',
        'kyc-rejected',
        'support-ticket',
        'dispute-status',
      ];
      for (final name in mustWrap) {
        expect(
          AppRouter.backFallbacks.containsKey(name),
          isTrue,
          reason: '$name is a deep-link/push target and MUST be wrapped',
        );
      }
    });
  });

  group('system BACK never exits from any root-capable route', () {
    // A minimal router that mounts a PLACEHOLDER wrapped exactly as the real
    final distinctFallbacks = AppRouter.backFallbacks.values.toSet();

    GoRouter buildRouter(String probePath, String fallback) {
      return GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('HOME'))),
          ),
          // Register every distinct fallback destination so go(fallback)
          for (final fb in distinctFallbacks)
            if (fb != '/')
              GoRoute(
                path: fb,
                builder: (context, state) =>
                    Scaffold(body: Center(child: Text('FALLBACK:$fb'))),
              ),
          GoRoute(
            path: probePath,
            builder: (context, state) => RootAwareBackScope(
              fallbackLocation: fallback,
              child: const Scaffold(body: Center(child: Text('PROBE'))),
            ),
          ),
        ],
      );
    }

    // One parameterized case per root-capable route.
    for (final entry in AppRouter.backFallbacks.entries) {
      testWidgets(
        'route "${entry.key}" entered as ROOT → system BACK lands on '
        '"${entry.value}", not the launcher',
        (tester) async {
          const probePath = '/__probe';
          final router = buildRouter(probePath, entry.value);
          addTearDown(router.dispose);
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.pumpAndSettle();

          // Stack-REPLACING entry (deep-link / push / go): the probe is the
          router.go(probePath);
          await tester.pumpAndSettle();
          expect(find.text('PROBE'), findsOneWidget);
          expect(_locationOf(router), probePath);

          await systemBack(tester);
          await tester.pumpAndSettle();

          // Consumed the gesture and resolved to the fallback parent — the app
          expect(_locationOf(router), entry.value);
          expect(find.text('PROBE'), findsNothing);
        },
      );
    }

    testWidgets(
      'a PUSHED (non-root) wrapped screen still pops to its real parent, not '
      'the fallback (no regression to in-app navigation)',
      (tester) async {
        final router = buildRouter('/__probe', '/wallet');
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Pushed from HOME: a back stack exists beneath the probe.
        router.push('/__probe');
        await tester.pumpAndSettle();
        expect(find.text('PROBE'), findsOneWidget);

        await systemBack(tester);
        await tester.pumpAndSettle();

        // Popped to HOME (the pushed-from screen), NOT the /wallet fallback.
        expect(_locationOf(router), '/');
        expect(find.text('HOME'), findsOneWidget);
      },
    );
  });

  group('the real AppRouter applies the wrapper', () {
    // Structural proof that `_wrapRootAware` actually ran on the production
    GoRoute? findByName(List<RouteBase> routes, String name) {
      for (final route in routes) {
        if (route is GoRoute) {
          if (route.name == name) return route;
          final nested = findByName(route.routes, name);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    testWidgets(
      'a wrapped route builds a RootAwareBackScope; an excluded route does not',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'app.onboarding.completed': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final onboarding = OnboardingCubit(prefs: prefs);
        final lock = BiometricLockCubit(
          preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
          gateway: const UnavailableBiometricGateway(),
          pinRepository: SharedPrefsPinRepository(prefs: prefs),
        );
        addTearDown(() async {
          await onboarding.close();
          await lock.close();
        });
        final router = AppRouter.create(onboarding: onboarding, biometricLock: lock);
        addTearDown(router.dispose);

        // Build the wrapped route's widget (the builder constructs the widget
        final wrapped =
            findByName(router.configuration.routes, 'delivery-register-prompt');
        expect(wrapped, isNotNull);
        final built = wrapped!.builder!(
          _FakeContext(),
          _fakeState(),
        );
        expect(built, isA<RootAwareBackScope>());
        expect((built as RootAwareBackScope).fallbackLocation, '/');

        // An excluded route (mandatory rating) is NOT wrapped.
        final excluded = findByName(router.configuration.routes, 'mutual-rating');
        expect(excluded, isNotNull);
        final excludedBuilt = excluded!.builder!(_FakeContext(), _fakeState());
        expect(excludedBuilt, isNot(isA<RootAwareBackScope>()));
      },
    );
  });
}

/// A throwaway [BuildContext] good enough to invoke a route builder that
/// constructs a `const` widget (no inherited-widget lookups happen at
/// construction time, only during a real `build`).
class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

GoRouterState _fakeState() => GoRouterState(
      _FakeConfiguration(),
      uri: Uri.parse('/jeeber/register-prompt'),
      matchedLocation: '/jeeber/register-prompt',
      fullPath: '/jeeber/register-prompt',
      pathParameters: const {},
      pageKey: const ValueKey('probe'),
    );

class _FakeConfiguration implements RouteConfiguration {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
