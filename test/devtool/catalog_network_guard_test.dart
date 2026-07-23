import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_network_guard.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_screen.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/cancel_request/domain/cancel_request_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/sync_app_localizations.dart';

class _RecordingLiveCancelRepository implements CancelRequestRepository {
  final List<String> cancelledRequestIds = <String>[];

  @override
  Future<void> cancelRequest({required String requestId}) async {
    cancelledRequestIds.add(requestId);
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _routerApp(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  setUp(() async {
    await sl.reset();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
    'client-offers catalog Cancel uses its local fake, never the live repo',
    (tester) async {
      final liveRepository = _RecordingLiveCancelRepository();
      sl.registerSingleton<CancelRequestRepository>(liveRepository);

      final entry = kScreenCatalog.singleWhere(
        (entry) =>
            entry.feature == 'client_offers' &&
            entry.screen == 'client_offers_screen',
      );
      final router = GoRouter(
        initialLocation: '/catalog',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: Text('catalog cancel completed')),
          ),
          GoRoute(
            path: '/catalog',
            builder: (_, _) => CatalogStatesScreen(entry: entry),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Loaded — 3 offers'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('offer-review-cancel-cta')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('offer-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('offer-review-cancel-cta')));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('cancel_request_sheet'),
        findsOneWidget,
      );
      await tester.tap(
        find.bySemanticsIdentifier('cancel_request_confirm_cta'),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        liveRepository.cancelledRequestIds,
        isEmpty,
        reason:
            'the catalog fixture must never resolve the DI/live cancel repo',
      );
      expect(find.text('catalog cancel completed'), findsOneWidget);
    },
  );

  testWidgets(
    'catalog preview blocks shared-Dio mutations before the HTTP adapter',
    (tester) async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://live.example.test'))
        ..httpClientAdapter = adapter;
      sl.registerSingleton<Dio>(dio);

      Object? blockedError;
      final entry = CatalogEntry(
        feature: 'guard_test',
        screen: 'mutation_probe',
        states: <CatalogState>[
          CatalogState(
            'Mutation probe',
            (_) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await dio.delete<dynamic>('/v1/requests/danger');
                    } catch (error) {
                      blockedError = error;
                    }
                  },
                  child: const Text('Delete live request'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: CatalogStatesScreen(entry: entry)),
      );
      await tester.tap(find.text('Mutation probe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete live request'));
      await tester.pumpAndSettle();

      expect(adapter.requests, isEmpty);
      expect(
        blockedError,
        isA<DioException>().having(
          (error) => error.error,
          'local guard error',
          isA<CatalogMutationBlockedException>(),
        ),
      );

      await tester.tap(find.byTooltip('Back to catalog'));
      await tester.pumpAndSettle();
      Object? afterPreviewError;
      unawaited(() async {
        try {
          await dio.delete<dynamic>('/v1/requests/after-preview');
        } catch (error) {
          afterPreviewError = error;
        }
      }());
      await tester.pumpAndSettle();
      expect(
        adapter.requests,
        hasLength(1),
        reason: 'the mutation block is scoped to the catalog preview lifetime',
      );
      expect(afterPreviewError, isNull);
    },
  );
}
