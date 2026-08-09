// B1 — an offline cold start must render the error state, not a healthy
// empty home. The repository degrades every read into an empty list, so the
// snapshot itself has to carry the load health.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _MockDio extends Mock implements Dio {}

class _ScriptedRepo implements ClientHomeRepository {
  _ScriptedRepo(this._script);

  final List<ClientHomeSnapshot> _script;
  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final snapshot =
        _script[calls < _script.length ? calls : _script.length - 1];
    calls += 1;
    return snapshot;
  }
}

const _order = ClientHomeRequest(
  id: 'ip-1',
  title: 'Kamal Hajj',
  destinationLabel: '1 kilo potato',
  status: ClientRequestStatus.enRoute,
  tier: ClientRequestTier.flash,
  progressStep: 3,
);

Response<dynamic> _resp(String path, Object? data) => Response<dynamic>(
  data: data,
  requestOptions: RequestOptions(path: path),
);

DioException _offline(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
  error: const SocketException('Network is unreachable'),
);

DioException _throttled(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  response: Response<dynamic>(
    statusCode: 429,
    requestOptions: RequestOptions(path: path),
  ),
);

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness(ClientHomeCubit cubit) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    _syncDelegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(
    body: BlocProvider.value(value: cubit, child: const ClientHomeScreen()),
  ),
);

void main() {
  setUpAll(_loadArbs);

  group('DioClientHomeRepository load health (B1)', () {
    late _MockDio dio;
    late DioClientHomeRepository repo;

    setUp(() {
      dio = _MockDio();
      repo = DioClientHomeRepository(dio);
    });

    test('every primary read failing on transport → loadFailed', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (invocation) async =>
            throw _offline(invocation.positionalArguments.first as String),
      );

      final snapshot = await repo.loadSnapshot();

      expect(snapshot.loadFailed, isTrue);
      expect(snapshot.rateLimited, isFalse);
      expect(snapshot.pending, isEmpty);
    });

    test('one surviving primary read → NOT loadFailed', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.positionalArguments.first as String;
        if (path == '/deliveries') return _resp(path, {'shipments': []});
        throw _offline(path);
      });

      final snapshot = await repo.loadSnapshot();

      expect(
        snapshot.loadFailed,
        isFalse,
        reason: 'a partially degraded load is still a load',
      );
    });

    test('an all-429 load stays rateLimited, never loadFailed', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (invocation) async =>
            throw _throttled(invocation.positionalArguments.first as String),
      );

      final snapshot = await repo.loadSnapshot();

      expect(snapshot.rateLimited, isTrue);
      expect(
        snapshot.loadFailed,
        isFalse,
        reason: 'the pinned cold-429-stays-READY contract must survive',
      );
    });
  });

  group('ClientHomeCubit honours loadFailed (B1)', () {
    test(
      'a cold all-failed load lands on FAILED, not an empty READY',
      () async {
        final repo = _ScriptedRepo([
          const ClientHomeSnapshot(loadFailed: true),
        ]);
        final cubit = ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, ClientHomeStatus.failed);
      },
    );

    test(
      'a failed background refresh keeps the cached data on screen',
      () async {
        final repo = _ScriptedRepo([
          const ClientHomeSnapshot(inProgress: [_order]),
          const ClientHomeSnapshot(loadFailed: true),
        ]);
        final cubit = ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        );
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.refresh();

        expect(cubit.state.status, ClientHomeStatus.ready);
        expect(cubit.state.inProgress, hasLength(1));
      },
    );
  });

  group('ClientHomeScreen offline cold start (B1, widget)', () {
    testWidgets('shows the retry CTA, and Retry recovers once online', (
      tester,
    ) async {
      final repo = _ScriptedRepo([
        const ClientHomeSnapshot(loadFailed: true),
        const ClientHomeSnapshot(pending: [_order]),
      ]);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(cubit.state.status, ClientHomeStatus.failed);
      expect(
        find.bySemanticsIdentifier('client_home_retry_cta'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('client-home-ready-list')),
        findsNothing,
        reason: 'an offline cold start must NOT render a healthy empty home',
      );

      await tester.tap(find.bySemanticsIdentifier('client_home_retry_cta'));
      await tester.pumpAndSettle();

      expect(cubit.state.status, ClientHomeStatus.ready);
      handle.dispose();
    });
  });
}
