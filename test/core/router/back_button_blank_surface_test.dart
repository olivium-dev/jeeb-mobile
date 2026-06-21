// Regression guard for the "blank/black surface" navigation defect.
//
// SYMPTOM (on-device): after a stack-REPLACING navigation (e.g. the header
// wallet chip `goNamed('wallet')` or bell `goNamed('notifications')`, or any
// `context.go(...)`), pressing the AppBar back button turned the whole app
// surface BLACK. Background→foreground did NOT recover it; only a force-stop +
// relaunch did.
//
// ROOT CAUSE: `OMDSAppBar`'s default back handler used an UNGUARDED
// `Navigator.of(context).pop()`. A `go`/`goNamed` navigation REPLACES the
// router stack, leaving a SINGLE page in the go_router Navigator. Popping that
// last page leaves the Navigator with an EMPTY page list, so `GoRouter` hands
// `MaterialApp.router`'s `builder` a NULL `child` — which the host renders as
// an empty `SizedBox.shrink()` (a zero-size, contentless surface = the black
// screen). It survives background→foreground because the empty page list is
// in-memory Dart state untouched by an OS lifecycle pause/resume; only a cold
// process restart rebuilds `GoRouter(initialLocation: '/')` and recovers.
//
// THE FIX (omds `OMDSAppBar._buildBackButton`): the default back action is now
// pop-GUARDED (`Navigator.maybePop`), so it can NEVER pop the last page. The
// repro screens (wallet hub / charge-info / notifications) additionally pass an
// explicit `onBackPressed` that pops when possible, else `context.go('/')`, so
// back from a `go`-reached screen lands on the shell instead of doing nothing.
//
// This test reproduces the EXACT failure path: a router whose `builder`
// collapses a null child to `SizedBox.shrink()` (mirroring `app.dart`), a
// `go`-replaced screen carrying an `OMDSAppBar`, then a back tap. Pre-fix this
// emptied the Navigator and the home content vanished; post-fix the surface
// stays populated.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

void main() {
  // Mirrors app.dart's `MaterialApp.router` builder: a null router child is
  // collapsed to `SizedBox.shrink()` — the exact black-surface trigger.
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
                  // the header wallet chip / bell `goNamed(...)`.
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
              // surface the unguarded pop used to empty.
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
      // null router child → SizedBox.shrink() (blank surface). Post-fix: the
      // pop-guard makes this a safe no-op, so the wallet surface stays.
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
                // shell — a real destination instead of a dead back button.
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
