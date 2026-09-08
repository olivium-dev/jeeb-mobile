// F4 (P0) + F21/NET-22 — a FAILED server acknowledge used to latch locally and
// emit `acknowledged`, so the user was never asked again and the server never
// recorded it; and an unrecognised catalogue body returned `const []`, so the
// user acknowledged a BLANK policy.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/prohibited_acknowledgment_dialog_fixtures.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_cubit.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

Dio _dioReplying(Object? body, {int status = 200}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) => h.resolve(
        Response<dynamic>(requestOptions: o, statusCode: status, data: body),
      ),
    ),
  );
  return dio;
}

Dio _dioRejecting(int status) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) => h.reject(
        DioException(
          requestOptions: o,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(requestOptions: o, statusCode: status),
        ),
      ),
    ),
  );
  return dio;
}

Widget _dialogHarness(
  Widget child, {
  Locale locale = const Locale('en'),
}) =>
    MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  group('ProhibitedAcknowledgmentCubit · F4', () {
    test('a failed server ack NEVER calls saveLocalAcknowledgment', () async {
      final repo = AckFailingProhibitedAckRepository();
      final cubit = ProhibitedAcknowledgmentCubit(repository: repo);

      await cubit.load();
      await cubit.acknowledge();

      expect(cubit.state.status, ProhibitedAckStatus.acknowledgeFailed);
      expect(cubit.state.failure, isA<ServerFailure>());
      expect(repo.savedLocally, isFalse);
      await cubit.close();
    });

    test('the acknowledgeFailed state is retryable', () async {
      final repo = AckFailingProhibitedAckRepository();
      final cubit = ProhibitedAcknowledgmentCubit(repository: repo);

      await cubit.load();
      await cubit.acknowledge();
      await cubit.acknowledge();

      expect(cubit.state.status, ProhibitedAckStatus.acknowledgeFailed);
      await cubit.close();
    });

    test('the load in-flight guard drops a duplicate load', () async {
      final cubit = ProhibitedAcknowledgmentCubit(
        repository: const PendingProhibitedAckRepository(),
      );

      unawaitedLoad(cubit);
      await Future<void>.delayed(Duration.zero);
      await cubit.load();

      expect(cubit.state.status, ProhibitedAckStatus.loading);
      await cubit.close();
    });

    test('a failed catalogue read carries the classified kind', () async {
      final cubit = ProhibitedAcknowledgmentCubit(
        repository: const FakeProhibitedAckRepository(throwOnFetch: true),
      );

      await cubit.load();

      expect(cubit.state.status, ProhibitedAckStatus.error);
      expect(cubit.state.failure, isA<ServerFailure>());
      await cubit.close();
    });
  });

  group('DioProhibitedAcknowledgmentRepository · F21/NET-22', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    // F21: acknowledging a BLANK policy is worse than failing.
    test('an unknown catalogue body THROWS instead of returning []', () async {
      final repo = DioProhibitedAcknowledgmentRepository(
        dio: _dioReplying('nonsense'),
        prefs: prefs,
      );

      await expectLater(
        repo.fetchItems(),
        throwsA(predicate<UnknownFailure>((UnknownFailure f) => f.parse)),
      );
    });

    test('a transport failure on fetchItems becomes an AppFailure', () async {
      final repo = DioProhibitedAcknowledgmentRepository(
        dio: _dioRejecting(503),
        prefs: prefs,
      );

      await expectLater(repo.fetchItems(), throwsA(isA<ServerFailure>()));
    });

    test('a transport failure on acknowledge becomes an AppFailure', () async {
      final repo = DioProhibitedAcknowledgmentRepository(
        dio: _dioRejecting(403),
        prefs: prefs,
      );

      await expectLater(repo.acknowledge(), throwsA(isA<ForbiddenFailure>()));
    });
  });

  group('ProhibitedAcknowledgmentDialog · the failed-ack surface', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('a failed ack keeps the dialog open with a retry · '
          '${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        final repo = AckFailingProhibitedAckRepository();

        await tester.pumpWidget(
          _dialogHarness(
            ProhibitedAckDialogHost(repository: repo),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsIdentifier(
            'prohibited_acknowledgment_sheet_acknowledge_cta',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('prohibited_acknowledgment_ack_retry_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(
            'prohibited_acknowledgment_ack_failed_note',
          ),
          findsOneWidget,
        );
        expect(repo.savedLocally, isFalse);
      });
    }

    testWidgets('the catalogue failure renders the identified error rung', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _dialogHarness(
          const ProhibitedAckDialogHost(
            repository: FakeProhibitedAckRepository(throwOnFetch: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('prohibited_acknowledgment_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('prohibited_acknowledgment_sheet_retry_cta'),
        findsOneWidget,
      );
    });

    testWidgets('the loading rung is identified', (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _dialogHarness(
          const ProhibitedAckDialogHost(
            repository: PendingProhibitedAckRepository(),
          ),
        ),
      );
      // The host opens the dialog on a post-frame callback, then the route
      // transition needs settling before the body is on screen.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.bySemanticsIdentifier('prohibited_acknowledgment_loading'),
        findsOneWidget,
      );
    });

    // AE-01: the flagged keywords sit above the catalogue.
    testWidgets('the matched keywords render when the caller passes them', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _dialogHarness(
          const ProhibitedAckDialogHost(
            repository: FakeProhibitedAckRepository(),
            matches: <String>['knife', 'lighter'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('prohibited_acknowledgment_matches'),
        findsOneWidget,
      );
      expect(find.text('knife · lighter'), findsOneWidget);
    });

    testWidgets('no keywords means no matches header', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _dialogHarness(
          const ProhibitedAckDialogHost(
            repository: FakeProhibitedAckRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('prohibited_acknowledgment_matches'),
        findsNothing,
      );
    });
  });
}

/// Starts a load without awaiting it, so the in-flight guard is observable.
void unawaitedLoad(ProhibitedAcknowledgmentCubit cubit) {
  cubit.load();
}
