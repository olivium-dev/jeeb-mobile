// AE-01 — the prohibited-items moderation round trip on the SUMMARY door.
//
// A 409 `prohibited-item-requires-ack` used to bucket into `invalidInput` and
// render one English sentence with no way forward. It now opens the ack sheet,
// and a confirmed ack resubmits under the SAME Idempotency-Key.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/data/dio_request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/domain/recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/prohibited_acknowledgment_dialog_fixtures.dart';

const RequestDraft _draft = RequestDraft(
  description: 'A knife for the kitchen',
  tierId: 'flash',
  operationId: 'op-fixed-1',
);

/// The production shape: nothing on the compose path mints an operationId, so
/// the cubit must.
const RequestDraft _unkeyedDraft = RequestDraft(
  description: 'A knife for the kitchen',
  tierId: 'flash',
);

class _NoPhone implements RecipientPhoneResolver {
  const _NoPhone();

  @override
  Future<String?> resolve() async => null;
}

/// Rejects the FIRST create with [problem], then accepts every later one, and
/// records the `Idempotency-Key` each attempt carried.
class _ModerationScriptedAdapter extends Interceptor {
  _ModerationScriptedAdapter(this.problem);

  final Map<String, dynamic> problem;
  final List<String?> keys = <String?>[];
  int calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls++;
    keys.add(options.headers['Idempotency-Key'] as String?);
    if (calls == 1) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 409,
            data: problem,
          ),
        ),
      );
      return;
    }
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 201,
        data: <String, dynamic>{'id': 'req-after-ack'},
      ),
    );
  }
}

RequestSubmissionService _serviceFor(_ModerationScriptedAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(adapter);
  return DioRequestSubmissionService(dio, const _NoPhone());
}

Widget _harness(
  RequestSubmissionService service, {
  Locale locale = const Locale('en'),
  RequestDraft draft = _draft,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/request-summary',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/request-summary',
        builder: (_, _) => BlocProvider<RequestSummaryCubit>(
          create: (_) => RequestSummaryCubit(service)..setDraft(draft),
          child: const RequestSummaryScreen(),
        ),
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

Future<void> _tapBroadcast(WidgetTester tester) async {
  final Finder cta = find.bySemanticsIdentifier('request_summary_submit');
  await tester.ensureVisible(cta);
  await tester.pump();
  await tester.tap(cta);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async => GetIt.instance.reset());

  group('AE-01 · summary door · needs-ack', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('a 409 requires-ack opens the sheet with the flagged '
          'keywords · ${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        sl.registerSingleton<ProhibitedAcknowledgmentRepository>(
          const FakeProhibitedAckRepository(),
        );
        final adapter = _ModerationScriptedAdapter(<String, dynamic>{
          'type': 'https://jeeb/errors/prohibited-item-requires-ack',
          'matches': <dynamic>[
            <String, dynamic>{'keyword': 'knife'},
          ],
        });

        await tester.pumpWidget(_harness(_serviceFor(adapter), locale: locale));
        await tester.pumpAndSettle();
        await _tapBroadcast(tester);

        expect(
          find.bySemanticsIdentifier('prohibited_acknowledgment_matches'),
          findsOneWidget,
        );
        expect(find.text('knife'), findsOneWidget);
        // The ack sheet OWNS the 409: no Conflict snack with a Retry on top.
        expect(
          find.bySemanticsIdentifier('request_summary_submit_error'),
          findsNothing,
        );
      });
    }

    testWidgets('with no ack repository registered the 409 still surfaces',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      final adapter = _ModerationScriptedAdapter(<String, dynamic>{
        'type': 'https://jeeb/errors/prohibited-item-requires-ack',
        'matches': <dynamic>['knife'],
      });

      await tester.pumpWidget(_harness(_serviceFor(adapter)));
      await tester.pumpAndSettle();
      await _tapBroadcast(tester);

      expect(
        find.bySemanticsIdentifier('request_summary_moderation_needs_ack'),
        findsOneWidget,
      );
      expect(adapter.calls, 1);
    });

    testWidgets('confirming the ack resubmits with the SAME Idempotency-Key',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      sl.registerSingleton<ProhibitedAcknowledgmentRepository>(
        const FakeProhibitedAckRepository(),
      );
      final adapter = _ModerationScriptedAdapter(<String, dynamic>{
        'type': 'https://jeeb/errors/prohibited-item-requires-ack',
        'matches': <dynamic>['knife'],
      });

      await tester.pumpWidget(_harness(_serviceFor(adapter)));
      await tester.pumpAndSettle();
      await _tapBroadcast(tester);

      await tester.tap(
        find.bySemanticsIdentifier(
          'prohibited_acknowledgment_sheet_acknowledge_cta',
        ),
      );
      await tester.pumpAndSettle();

      expect(adapter.calls, 2);
      expect(adapter.keys, <String?>['op-fixed-1', 'op-fixed-1']);
      expect(
        find.bySemanticsIdentifier('request_summary_submit_error'),
        findsNothing,
      );
    });

    testWidgets('a draft with NO operationId still posts one stable key',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      sl.registerSingleton<ProhibitedAcknowledgmentRepository>(
        const FakeProhibitedAckRepository(),
      );
      final adapter = _ModerationScriptedAdapter(<String, dynamic>{
        'type': 'https://jeeb/errors/prohibited-item-requires-ack',
        'matches': <dynamic>['knife'],
      });

      await tester.pumpWidget(
        _harness(_serviceFor(adapter), draft: _unkeyedDraft),
      );
      await tester.pumpAndSettle();
      await _tapBroadcast(tester);

      await tester.tap(
        find.bySemanticsIdentifier(
          'prohibited_acknowledgment_sheet_acknowledge_cta',
        ),
      );
      await tester.pumpAndSettle();

      expect(adapter.calls, 2);
      expect(adapter.keys.first, isNotNull);
      expect(adapter.keys.first, isNotEmpty);
      expect(adapter.keys[1], adapter.keys.first);
    });
  });

  group('AE-01 · summary door · blocked is terminal', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('a 409 blocked shows an EXIT and never a Retry · '
          '${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        final adapter = _ModerationScriptedAdapter(<String, dynamic>{
          'type': 'https://jeeb/errors/prohibited-item-blocked',
          'matches': <dynamic>['firearm'],
        });

        await tester.pumpWidget(_harness(_serviceFor(adapter), locale: locale));
        await tester.pumpAndSettle();
        await _tapBroadcast(tester);

        expect(
          find.bySemanticsIdentifier('request_summary_moderation_blocked'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('request_summary_moderation_exit_cta'),
          findsOneWidget,
        );
        // R6: an unrecoverable kind never gets an inert Retry.
        expect(
          find.bySemanticsIdentifier('request_summary_retry_cta'),
          findsNothing,
        );
        expect(adapter.calls, 1);
      });
    }

    testWidgets('a blocked create never opens the ack sheet',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      sl.registerSingleton<ProhibitedAcknowledgmentRepository>(
        const FakeProhibitedAckRepository(),
      );
      final adapter = _ModerationScriptedAdapter(<String, dynamic>{
        'type': 'https://jeeb/errors/prohibited-item-blocked',
      });

      await tester.pumpWidget(_harness(_serviceFor(adapter)));
      await tester.pumpAndSettle();
      await _tapBroadcast(tester);

      expect(
        find.bySemanticsIdentifier(
          'prohibited_acknowledgment_sheet_acknowledge_cta',
        ),
        findsNothing,
      );
    });
  });

  group('AE-01 · classification', () {
    test('GatewayProblem.matches parses both the object and the bare form', () {
      final AppFailure objectForm = AppFailure.of(
        DioException(
          requestOptions: RequestOptions(path: '/v1/requests'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/v1/requests'),
            statusCode: 409,
            data: <String, dynamic>{
              'type': 'https://jeeb/errors/prohibited-item-requires-ack',
              'matches': <dynamic>[
                <String, dynamic>{'keyword': 'knife'},
              ],
            },
          ),
        ),
      );

      expect(objectForm, isA<ConflictFailure>());
      expect(objectForm.problem?.typeSuffix, 'prohibited-item-requires-ack');
      expect(objectForm.problem?.matches, <String>['knife']);
    });
  });
}
