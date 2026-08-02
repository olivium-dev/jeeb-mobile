// Regression guard for the "blank/black surface" navigation defect.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

void main() {
  // Mirrors app.dart's `MaterialApp.router` builder: a null router child is
  Widget collapseNullChild(BuildContext context, Widget? child) =>
      child ?? const SizedBox.shrink();

  testWidgets(
    'AppBar back on a go()-replaced screen never empties the Navigator '
    '(no blank surface)',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  // The repro entry: a stack-REPLACING navigation, exactly like
                  onPressed: () => context.go('/wallet'),
                  child: const Text('HOME'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/wallet',
            builder: (context, state) => const Scaffold(
              // Default back handler — no onBackPressed override. This is the
              appBar: OMDSAppBar(title: 'WALLET', showBackButton: true),
              body: Center(child: Text('WALLET BODY')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: collapseNullChild,
        ),
      );

      expect(find.text('HOME'), findsOneWidget);

      // Replace the stack with /wallet (no page beneath it).
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('WALLET BODY'), findsOneWidget);

      // Press AppBar back. Pre-fix: pops the last page → empty Navigator →
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // The surface is NEVER blank: real content is still mounted.
      final hasContent = find.text('WALLET BODY').evaluate().isNotEmpty ||
          find.text('HOME').evaluate().isNotEmpty;
      expect(
        hasContent,
        isTrue,
        reason: 'Back from a go()-replaced screen must not leave an empty '
            'Navigator / blank surface.',
      );
    },
  );

  testWidgets(
    'explicit onBackPressed routes a go()-reached screen back to the shell',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.go('/wallet'),
                  child: const Text('HOME'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/wallet',
            builder: (context, state) => Scaffold(
              appBar: OMDSAppBar(
                title: 'WALLET',
                showBackButton: true,
                // The repro screens' pattern: pop when possible, else go to the
                onBackPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              body: const Center(child: Text('WALLET BODY')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: collapseNullChild,
        ),
      );

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('WALLET BODY'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Lands back on the shell — not a blank surface, not stuck on wallet.
      expect(find.text('HOME'), findsOneWidget);
    },
  );
}
