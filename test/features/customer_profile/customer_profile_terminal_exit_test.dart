import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/customer_profile/data/dio_customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_status_block.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;
  final List<String> requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ClassifiedRepository implements CustomerProfileRepository {
  const _ClassifiedRepository(this.failure);

  final AppFailure failure;

  @override
  Future<CustomerProfileViewData> fetchProfile() async =>
      throw CustomerProfileRepositoryException.classified(
        CustomerProfileFailure.unauthorized,
        appFailure: failure,
      );
}

class _Fixture {
  _Fixture(int status) : adapter = _StatusAdapter(status) {
    dio = Dio(BaseOptions(baseUrl: 'https://profile.test'))
      ..httpClientAdapter = adapter;
    repository = DioCustomerProfileRepository(dio);
    addTearDown(() => dio.close(force: true));
    addTearDown(profileSelected.dispose);
  }

  final _StatusAdapter adapter;
  final ValueNotifier<bool> profileSelected = ValueNotifier<bool>(true);
  late final Dio dio;
  late final CustomerProfileRepository repository;
  int exits = 0;

  Widget app(Locale locale, {CustomerProfileRepository? overrideRepository}) {
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'shell',
          builder: (_, _) => ValueListenableBuilder<bool>(
            valueListenable: profileSelected,
            builder: (_, selected, _) => selected
                ? CustomerProfileScreen(
                    data: const CustomerProfileViewData(),
                    repository: overrideRepository ?? repository,
                    onExit: () {
                      exits++;
                      profileSelected.value = false;
                    },
                  )
                : const Scaffold(body: Text('HOME')),
          ),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN')),
        ),
      ],
    );
    addTearDown(router.dispose);
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

void main() {
  Finder byId(String id) => find.bySemanticsIdentifier(id);
  const exitId = 'customer_profile_load_exit_cta';
  const signInId = 'customer_profile_error_signin_cta';

  test('repository keeps HTTP 403 distinct from HTTP 401', () async {
    for (final status in <int>[401, 403]) {
      final fixture = _Fixture(status);
      await expectLater(
        fixture.repository.fetchProfile(),
        throwsA(
          isA<CustomerProfileRepositoryException>()
              .having(
                (error) => error.failure,
                'legacy classification',
                status == 401
                    ? CustomerProfileFailure.unauthorized
                    : CustomerProfileFailure.unknown,
              )
              .having(
                (error) => error.appFailure,
                'typed failure',
                status == 401
                    ? isA<UnauthorizedFailure>()
                    : isA<ForbiddenFailure>(),
              ),
        ),
      );
      expect(fixture.adapter.requests, <String>['/v1/users/me']);
    }
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final language = locale.languageCode;

    testWidgets('[$language] HTTP 401 signs in without calling Home exit', (
      tester,
    ) async {
      useReduceMotion(tester);
      final fixture = _Fixture(401);
      await tester.pumpWidget(fixture.app(locale));
      await tester.pumpAndSettle();
      expect(byId(signInId), findsOneWidget);
      expect(byId(exitId), findsNothing);
      expect(byId(CustomerProfileStatusBlock.retryIdentifier), findsNothing);
      await tester.tap(byId(signInId));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(fixture.exits, 0);
    });

    for (final status in <int>[403, 404, 410]) {
      testWidgets('[$language] HTTP $status exits Profile to selected Home', (
        tester,
      ) async {
        useReduceMotion(tester);
        final fixture = _Fixture(status);
        await tester.pumpWidget(fixture.app(locale));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CustomerProfileScreen)),
        );
        expect(
          byId(CustomerProfileStatusBlock.errorIdentifier),
          findsOneWidget,
        );
        expect(byId(signInId), findsNothing);
        expect(find.text(l10n.actionSignIn), findsNothing);
        expect(byId(CustomerProfileStatusBlock.retryIdentifier), findsNothing);
        expect(byId(exitId), findsOneWidget);
        expect(find.text(l10n.actionBack), findsOneWidget);
        await tester.tap(byId(exitId));
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
        expect(find.byType(CustomerProfileScreen), findsNothing);
        expect(fixture.exits, 1);
        expect(fixture.adapter.requests, <String>['/v1/users/me']);
      });
    }

    testWidgets('[$language] typed forbidden overrides legacy unauthorized', (
      tester,
    ) async {
      useReduceMotion(tester);
      final fixture = _Fixture(403);
      await tester.pumpWidget(
        fixture.app(
          locale,
          overrideRepository: const _ClassifiedRepository(ForbiddenFailure()),
        ),
      );
      await tester.pumpAndSettle();
      expect(byId(signInId), findsNothing);
      expect(byId(exitId), findsOneWidget);
      await tester.tap(byId(exitId));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(fixture.exits, 1);
    });

    for (final status in <int>[400, 409]) {
      testWidgets('[$language] HTTP $status keeps a working manual Retry', (
        tester,
      ) async {
        useReduceMotion(tester);
        final fixture = _Fixture(status);
        await tester.pumpWidget(fixture.app(locale));
        await tester.pumpAndSettle();
        expect(
          byId(CustomerProfileStatusBlock.retryIdentifier),
          findsOneWidget,
        );
        expect(byId(exitId), findsNothing);
        expect(byId(signInId), findsNothing);
        await tester.tap(byId(CustomerProfileStatusBlock.retryIdentifier));
        await tester.pumpAndSettle();
        expect(fixture.adapter.requests, <String>[
          '/v1/users/me',
          '/v1/users/me',
        ]);
        expect(
          byId(CustomerProfileStatusBlock.errorIdentifier),
          findsOneWidget,
        );
        expect(fixture.exits, 0);
      });
    }
  }
}
