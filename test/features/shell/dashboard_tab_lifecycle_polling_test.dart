import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/features/shell/tabs/dashboard_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _CountingDio extends Fake implements Dio {
  int getCount = 0;
  Object responseBody = const <String, Object>{
    'items': <Object>[],
    'totalCount': 0,
  };

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    getCount++;
    return Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: responseBody,
        )
        as Response<T>;
  }
}

class _ApprovedKycGate implements JeeberKycStatusGate {
  const _ApprovedKycGate();

  @override
  JeeberKycStatus get status => JeeberKycStatus.approved;

  @override
  bool get isApproved => true;
}

class _OnlineAvailabilityGateway extends InMemoryAvailabilityGateway {
  _OnlineAvailabilityGateway()
    : super(
        initial: AvailabilityStatus.initial.copyWith(
          state: AvailabilityState.online,
        ),
      );
}

LocalizationsDelegate<AppLocalizations> _loadSyncDelegate() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  return _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

GoRouter _router(ValueListenable<bool> visibility) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visibility,
            builder: (context, isVisible, child) =>
                TabVisibility(isVisible: isVisible, child: child!),
            child: const DashboardTab(),
          ),
        ),
      ),
      GoRoute(
        path: '/jeeber/onboarding',
        name: 'jeeber-onboarding',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/jeeber/requests/:id',
        name: 'jeeber-request-detail',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
}

Widget _app(
  LocalizationsDelegate<AppLocalizations> delegate,
  ValueListenable<bool> visibility,
) {
  return MaterialApp.router(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: _router(visibility),
  );
}

RequestFeedCubit _feedCubit(WidgetTester tester) {
  final context = tester.element(find.byType(JeeberHomeScreen));
  return context.read<RequestFeedCubit>();
}

void main() {
  late LocalizationsDelegate<AppLocalizations> delegate;
  late _CountingDio dio;
  late DioRequestFeedRepository repository;

  setUpAll(() {
    delegate = _loadSyncDelegate();
  });

  setUp(() async {
    await sl.reset();
    AppLifecycleGate.debugReset();
    dio = _CountingDio();
    repository = DioRequestFeedRepository(dio: dio);
    sl.registerSingleton<JeeberKycStatusGate>(const _ApprovedKycGate());
    sl.registerLazySingleton<AvailabilityGateway>(
      _OnlineAvailabilityGateway.new,
    );
    sl.registerLazySingleton<RequestFeedRepository>(() => repository);
  });

  tearDown(() async {
    AppLifecycleGate.debugReset();
    await repository.dispose();
    await sl.reset();
  });

  // AC2b USED TO READ "hidden Dashboard cancels feed polling and visible
  // resumes it" — an assertion about a cadence that no longer exists (b02,
  // POLLING-ELIMINATION-PLAN A.1). Restated as the mandate's own criterion:
  // the VISIBLE, foregrounded Dashboard is the worst case, and it must issue
  // zero repeat calls. The old "hidden ⇒ zero" case is now the weaker one and
  // is kept only as a regression guard.
  testWidgets(
    'AC2b: a VISIBLE, foregrounded Dashboard issues ZERO repeat feed GETs '
    'over five minutes of idle time',
    (tester) async {
      final visibility = ValueNotifier<bool>(true);
      addTearDown(visibility.dispose);

      await tester.pumpWidget(_app(delegate, visibility));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // POSITIVE CONTROL — the mount must have fetched at least once, which
      // is what proves the counting Dio is actually wired to this feed. A
      // "zero repeat calls" assertion against an unwired Dio passes vacuously.
      expect(
        dio.getCount,
        greaterThan(0),
        reason: 'the open one-shot must fetch; otherwise the Dio is not wired',
      );

      final visibleBaseline = dio.getCount;
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(
        dio.getCount,
        visibleBaseline,
        reason:
            'foreground + visible + no push + no user action for 5 min must '
            'issue ZERO repeat GETs (POLLING-ELIMINATION-PLAN §0)',
      );

      visibility.value = false;
      await tester.pump();
      final hiddenBaseline = dio.getCount;

      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(
        dio.getCount,
        hiddenBaseline,
        reason: 'a foreground but hidden Dashboard must also issue zero GETs',
      );

      // Regaining the tab is a USER ACTION, and a one-shot catch-up on it is
      // explicitly allowed. Assert it is EXACTLY one, and that nothing
      // periodic follows it.
      visibility.value = true;
      await tester.pump();
      await tester.pump();
      final refocusBaseline = dio.getCount;
      expect(
        refocusBaseline,
        hiddenBaseline + 1,
        reason: 'tab refocus must issue exactly one catch-up GET',
      );

      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(
        dio.getCount,
        refocusBaseline,
        reason: 'the catch-up must not leave a cadence behind it',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AC4: DI feed singleton survives cubit teardown and serves the remount '
    'one-shot fetch',
    (tester) async {
      final firstVisibility = ValueNotifier<bool>(true);
      addTearDown(firstVisibility.dispose);

      await tester.pumpWidget(_app(delegate, firstVisibility));
      await tester.pumpAndSettle();
      final firstCubit = _feedCubit(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      // BlocProvider does not await an async cubit close. Flush its continuation
      // before proving teardown at the feature seam below: a new cubit must
      // fetch through the same DI singleton.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      // Change the payload BEFORE the remount: the remount's own one-shot
      // `start()` fetch is now the only thing that will pull it. Under the old
      // build a periodic tick would have picked it up eventually — which is
      // exactly the difference this test now discriminates.
      final preRemountBaseline = dio.getCount;
      dio.responseBody = const <String, Object>{
        'items': <Object>[
          <String, Object?>{
            'requestId': 'post-remount-request',
            'status': 'pending',
            'description': 'Post-remount delivery',
            'createdAt': '2026-07-26T12:00:00Z',
            'myOffer': null,
          },
        ],
        'totalCount': 1,
      };

      final secondVisibility = ValueNotifier<bool>(true);
      addTearDown(secondVisibility.dispose);
      await tester.pumpWidget(_app(delegate, secondVisibility));
      await tester.pumpAndSettle();
      final secondCubit = _feedCubit(tester);
      expect(secondCubit, isNot(same(firstCubit)));

      expect(
        dio.getCount,
        greaterThan(preRemountBaseline),
        reason: 'the remount one-shot must reach the surviving DI singleton',
      );
      expect(
        secondCubit.state.requests.map((request) => request.id),
        contains('post-remount-request'),
        reason: 'the remount fetch must reach the second cubit state',
      );

      final postRemountBaseline = dio.getCount;
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(
        dio.getCount,
        postRemountBaseline,
        reason: 'the remount must not arm a cadence either',
      );
      expect(repository.debugIsDisposed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        repository.debugIsDisposed,
        isFalse,
        reason: 'the Dashboard cubit borrows the app-lifetime DI singleton',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
