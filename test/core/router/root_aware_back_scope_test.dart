// Unit guard for `RootAwareBackScope` — the reusable wrapper that fixes the

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/router/root_aware_back_scope.dart';

/// Dispatches the platform `popRoute` message — the exact channel the OS uses
/// for the Android system BACK gesture, routed through the Router's
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

void main() {
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('HOME'),
                    ElevatedButton(
                      onPressed: () => context.go('/child'),
                      child: const Text('GO-CHILD'),
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/child'),
                      child: const Text('PUSH-CHILD'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/parent',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('PARENT'))),
          ),
          GoRoute(
            path: '/child',
            builder: (context, state) => const RootAwareBackScope(
              fallbackLocation: '/parent',
              child: Scaffold(body: Center(child: Text('CHILD'))),
            ),
          ),
        ],
      );

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'as stack ROOT (go), system BACK redirects to the fallback parent',
    (tester) async {
      final router = await pump(tester);

      await tester.tap(find.text('GO-CHILD'));
      await tester.pumpAndSettle();
      expect(find.text('CHILD'), findsOneWidget);
      expect(locationOf(router), '/child');

      await systemBack(tester);
      await tester.pumpAndSettle();

      // No back stack under a go()-reached child → fallback to /parent.
      expect(locationOf(router), '/parent');
      expect(find.text('PARENT'), findsOneWidget);
    },
  );

  testWidgets(
    'with a back stack (push), system BACK pops to the real parent (not the '
    'fallback)',
    (tester) async {
      final router = await pump(tester);

      await tester.tap(find.text('PUSH-CHILD'));
      await tester.pumpAndSettle();
      expect(find.text('CHILD'), findsOneWidget);

      await systemBack(tester);
      await tester.pumpAndSettle();

      // Popped back to HOME (the pushed-from screen), NOT the /parent fallback.
      expect(locationOf(router), '/');
      expect(find.text('HOME'), findsOneWidget);
    },
  );
}
