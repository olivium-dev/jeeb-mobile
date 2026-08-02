// MB1 R1 step 0 — does reading the hand-over code END the dwell?

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
