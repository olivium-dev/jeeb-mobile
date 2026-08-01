// MB1 R1 step 0 — does reading the hand-over code END the dwell?
//
// THE WIRE requires >=3 `tracking_position` records inside ONE continuous dwell
// bounded by EXACTLY ONE `tracking_screen_open`. `tracking_screen_open` is
// emitted from `LiveTrackingCubit`'s CONSTRUCTOR, so the question "does the
// dwell survive reading the code" reduces to "is the cubit rebuilt".
//
// A review note asserted that it is: that the customer must leave the tracking
// route to read the code, disposing the cubit and minting a SECOND
// `tracking_screen_open`. This file MEASURES that instead of assuming it, using
// the real router shape: `/orders/:id/tracking` and `/orders/:id/otp` are
// SIBLING `GoRoute`s (`app_router.dart:1339` and `:1395`), and the tracking
// screen's "Show OTP" CTA is `context.push('/orders/$deliveryId/otp')`
// (`otp_at_door_card.dart:111`) — a PUSH, not a `go`/replace.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Stands in for `LiveTrackingCubit`: it counts its own construction, which is
/// where the real one emits `tracking_screen_open`.
class _OpenCountingCubit extends Cubit<int> {
  _OpenCountingCubit(this.log) : super(0) {
    log.add('screen_open');
  }
  final List<String> log;
}

void main() {
  testWidgets(
      'pushing the OTP route and popping back does NOT rebuild the tracking '
      'cubit — the dwell survives, and only ONE screen_open is minted',
      (tester) async {
    final log = <String>[];

    final router = GoRouter(
      initialLocation: '/orders/D1/tracking',
      routes: [
        GoRoute(
          path: '/orders/:id/tracking',
          builder: (context, state) => BlocProvider<_OpenCountingCubit>(
            create: (_) => _OpenCountingCubit(log),
            // The real screen reads the cubit through a BlocBuilder, which is
            // what forces the lazy `create` to run. Reproduced, or the provider
            // never constructs and the measurement is vacuous.
            child: BlocBuilder<_OpenCountingCubit, int>(
              builder: (context, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    // EXACTLY what otp_at_door_card.dart:111 does.
                    onPressed: () => context.push('/orders/D1/otp'),
                    child: const Text('Show OTP'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/orders/:id/otp',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(log, ['screen_open'], reason: 'the dwell opened exactly once');

    await tester.tap(find.text('Show OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget, reason: 'the OTP route is up');

    // THE MEASUREMENT. If `push` disposed the route beneath, coming back would
    // re-run `create` and append a second entry.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(
      log,
      ['screen_open'],
      reason:
          'MEASURED: a sibling-route PUSH layers on top; the tracking route is '
          'not popped and its BlocProvider is not disposed, so no second '
          'tracking_screen_open is minted. The dwell survives reading the code.',
    );
  });

  testWidgets(
      'NEGATIVE CONTROL: a `go` (REPLACE) to the OTP route and back DOES '
      'rebuild the cubit — so this test can detect a broken dwell', (tester) async {
    final log = <String>[];

    final router = GoRouter(
      initialLocation: '/orders/D1/tracking',
      routes: [
        GoRoute(
          path: '/orders/:id/tracking',
          builder: (context, state) => BlocProvider<_OpenCountingCubit>(
            create: (_) => _OpenCountingCubit(log),
            child: BlocBuilder<_OpenCountingCubit, int>(
              builder: (context, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/orders/D1/otp'),
                    child: const Text('Show OTP'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/orders/:id/otp',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.go('/orders/D1/tracking'),
                child: const Text('Back'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(log.length, 1);

    await tester.tap(find.text('Show OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(log.length, 2,
        reason:
            'a REPLACE really does end the dwell — the assertion above is not '
            'vacuous, it is discriminating between push and go.');
  });
}
