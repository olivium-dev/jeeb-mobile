import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// JEEBER-LOOP F1 + F2 — close the two-party delivery loop.
///
/// These are navigation tests, so they need a real [GoRouter] (not a bare
/// [MaterialApp]) — `context.go` is a no-op without one. Each test routes from
/// the OTP screen and then asserts the *resolved location*, which is the
/// router's contract surface (`isClient = mode != 'jeeber'`). They fail on the
/// pre-fix source: F1 because `_DoneBody` went to `/feedback` with no `mode`,
/// F2 because the client display had no CTA at all.
class _MockRepo extends Mock implements OtpHandoverRepository {}

GoRouter _router(OtpHandoverCubit cubit, {required bool isClient}) {
  return GoRouter(
    initialLocation: '/otp',
    routes: [
      GoRoute(
        path: '/otp',
        builder: (context, state) => BlocProvider<OtpHandoverCubit>.value(
          value: cubit,
          child: OtpHandoverScreen(deliveryId: 'DLV-770001', isClient: isClient),
        ),
      ),
      // Stub destinations — we assert on the landed URI, not their contents,
      // so they render nothing and pull in no DI.
      GoRoute(
        path: '/orders/:id/mutual-rate',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('MUTUAL_RATE_STUB'))),
      ),
      GoRoute(
        path: '/orders/:id/feedback',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('FEEDBACK_STUB'))),
      ),
      // redesign-2026-08 screen 13's docked exit. The real route exists in
      // app_router.dart; this stub keeps the harness DI-free.
      GoRoute(
        path: '/orders/:id/escalate',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('ESCALATE_STUB'))),
      ),
    ],
  );
}

Widget _app(GoRouter router) {
  return MaterialApp.router(
    theme: ThemeData.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  );
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  group('F1: OTP-done navigation threads isClient into mutual-rate', () {
    testWidgets(
        'Jeeber done → /orders/DLV-770001/mutual-rate?mode=jeeber (NOT /feedback)',
        (tester) async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenAnswer((_) async => const OtpHandoverResult(success: true));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: false,
      );
      final router = _router(cubit, isClient: false);

      await tester.pumpWidget(_app(router));
      await tester.pump(); // Jeeber starts in `ready` — no spinner.

      // Drive to the success/done state.
      await cubit.submitOtp('1234');
      await tester.pump();
      expect(find.text('Delivery Complete!'), findsOneWidget);

      // Tap "Rate your Jeeber" on the done screen.
      await tester.tap(find.text('Rate your Jeeber'));
      await tester.pumpAndSettle();

      expect(
        _location(router),
        '/orders/DLV-770001/mutual-rate?mode=jeeber',
        reason: 'Jeeber leg must carry ?mode=jeeber so the router resolves '
            'isClient=false; the pre-fix code went to /feedback with no mode.',
      );
      expect(find.text('MUTUAL_RATE_STUB'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('Client done → /orders/DLV-770001/mutual-rate (no mode param)',
        (tester) async {
      // Client done state is exercised directly by toggling the cubit; the
      // client constructor would otherwise load a display code, but the done
      // body is identical regardless of role except for the route suffix.
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '1234'));
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenAnswer((_) async => const OtpHandoverResult(success: true));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );
      final router = _router(cubit, isClient: true);

      await tester.pumpWidget(_app(router));
      await tester.pump(); // resolve the constructor fetch → ready

      // Force the shared done body (client leg).
      await cubit.submitOtp('1234');
      await tester.pump();
      expect(find.text('Delivery Complete!'), findsOneWidget);

      await tester.tap(find.text('Rate your Jeeber'));
      await tester.pumpAndSettle();

      expect(
        _location(router),
        '/orders/DLV-770001/mutual-rate',
        reason: 'Client leg must NOT carry mode → router resolves isClient=true.',
      );
      await cubit.close();
    });
  });

  group('F2: client OTP display exposes client_otp_rate_now CTA', () {
    testWidgets(
        'client_otp_rate_now is present and navigates to client mutual-rate',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '1234'));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );
      final router = _router(cubit, isClient: true);

      await tester.pumpWidget(_app(router));
      await tester.pump(); // resolve the display-code fetch → ready

      // The code display is up (the client is parked here pre-fix). Addressed
      // by key: redesign-2026-08 renders the code as one tile per digit, so
      // there is no single `'1234'` string any more.
      expect(find.byKey(const Key('otpHandover.codeDisplay')), findsOneWidget);

      // The new addressable CTA exists by its accessibility identifier.
      final rateNow = find.byKey(const Key('otpHandover.clientRateNow'));
      expect(
        rateNow,
        findsOneWidget,
        reason: 'F2: client OTP display must surface a forward CTA so the '
            'client is not parked indefinitely after handover.',
      );

      await tester.tap(rateNow);
      await tester.pumpAndSettle();

      expect(
        _location(router),
        '/orders/DLV-770001/mutual-rate',
        reason: 'client_otp_rate_now navigates the client leg to mutual-rate.',
      );
      expect(find.text('MUTUAL_RATE_STUB'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('client_otp_rate_now is exposed as a Semantics identifier',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '1234'));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );
      final router = _router(cubit, isClient: true);

      await tester.pumpWidget(_app(router));
      await tester.pump();

      // QA-targetable identifier surfaces in the semantics tree.
      expect(
        find.bySemanticsLabel(RegExp('.*')),
        findsWidgets,
      );
      final semantics = tester.getSemantics(
        find.byKey(const Key('otpHandover.clientRateNow')),
      );
      expect(semantics.identifier, 'client_otp_rate_now');
      await cubit.close();
    });
  });

  group('13: the docked dispute exit', () {
    testWidgets('otp_handover_dispute pushes /orders/:id/escalate',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '1234'));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );
      final router = _router(cubit, isClient: true);

      await tester.pumpWidget(_app(router));
      await tester.pump();

      final dispute = find.bySemanticsIdentifier('otp_handover_dispute');
      expect(dispute, findsOneWidget);

      await tester.tap(dispute);
      await tester.pumpAndSettle();

      expect(find.text('ESCALATE_STUB'), findsOneWidget);

      // `push`, not `go`: the handoff screen is still on the stack, so BACK
      // returns the customer to the code they were reading at the door.
      // (An imperative push deliberately leaves `currentConfiguration.uri` at
      // the base location, so the stack — not the URI — is the assertion.)
      expect(_location(router), '/otp');
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('otpHandover.codeDisplay')), findsOneWidget);
      await cubit.close();
    });
  });
}
