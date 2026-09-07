// Stage 2 / X2 — the LIVE route hands `onDeclineRequest` to the detail screen.
//
// In-fence coverage lives at
// test/features/jeeber_request_detail/jeeber_request_detail_decline_test.dart;
// this pins the wiring in app_router.dart itself.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/observability/crash_reporter.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _RecordingFeedRepository implements RequestFeedRepository {
  _RecordingFeedRepository({this.failure});

  final Object? failure;
  final List<String> declined = <String>[];

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async => const <DeliveryRequest>[];

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async {
    declined.add(id);
    if (failure != null) throw failure!;
    return RequestActionOutcome.declined;
  }

  @override
  Future<void> dispose() async {}
}

Future<GoRouter> _routerWith(
  SharedPreferences prefs,
  _RecordingFeedRepository repository,
) async {
  if (GetIt.I.isRegistered<RequestFeedRepository>()) {
    await GetIt.I.unregister<RequestFeedRepository>();
  }
  GetIt.I.registerSingleton<RequestFeedRepository>(repository);
  return AppRouter.create(
    onboarding: OnboardingCubit(prefs: prefs),
    biometricLock: BiometricLockCubit(
      preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
      gateway: const UnavailableBiometricGateway(),
      pinRepository: SharedPrefsPinRepository(prefs: prefs),
    ),
  );
}

Widget _harness(GoRouter router, SharedPreferences prefs) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<RoleCubit>(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider<RoleEligibilityCubit>(
        create: (_) => RoleEligibilityCubit(),
      ),
      BlocProvider<LocaleCubit>(create: (_) => LocaleCubit(prefs: prefs)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

const _extra = FeedRequest(id: 'REQ-777', shortLabel: 'Hamra, Beirut');

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await GetIt.I.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
    prefs = await SharedPreferences.getInstance();
    configureDependencies(
      sharedPreferences: prefs,
      crashReporter: const NoopCrashReporter(),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  testWidgets('the route passes a non-null onDeclineRequest', (tester) async {
    final repository = _RecordingFeedRepository();
    final router = await _routerWith(prefs, repository);
    router.push('/jeeber/requests/REQ-777', extra: _extra);

    await tester.pumpWidget(_harness(router, prefs));
    await tester.pumpAndSettle();

    final screen = tester.widget<JeeberRequestDetailScreen>(
      find.byType(JeeberRequestDetailScreen),
    );
    expect(screen.onDeclineRequest, isNotNull);
  });

  testWidgets('a SUCCESSFUL decline calls decline(id), then pops', (
    tester,
  ) async {
    final repository = _RecordingFeedRepository();
    final router = await _routerWith(prefs, repository);
    router.push('/jeeber/requests/REQ-777', extra: _extra);

    await tester.pumpWidget(_harness(router, prefs));
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsIdentifier('jeeber-request-detail-decline'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));

    expect(repository.declined, <String>['REQ-777']);
    expect(find.byType(JeeberRequestDetailScreen), findsNothing);
  });

  testWidgets('a FAILING decline shows the snack and does NOT pop', (
    tester,
  ) async {
    final repository = _RecordingFeedRepository(
      failure: const ServerFailure(status: 500),
    );
    final router = await _routerWith(prefs, repository);
    router.push('/jeeber/requests/REQ-777', extra: _extra);

    await tester.pumpWidget(_harness(router, prefs));
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsIdentifier('jeeber-request-detail-decline'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.declined, <String>['REQ-777']);
    expect(
      find.bySemanticsIdentifier('jeeber_request_detail_decline_failed_snack'),
      findsOneWidget,
    );
    expect(find.byType(JeeberRequestDetailScreen), findsOneWidget);
  });
}
