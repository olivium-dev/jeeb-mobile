import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/account_status/data/dio_account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Phase V D16 — the raw i18n token must never reach a suspended user.
///
/// Run 3 measured `Label{{Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS}}` on the wire in
/// `detail` and `reason`. The account-status screen renders the server reason
/// VERBATIM, so this is the surface where that string becomes pixels.
///
/// Two halves, both required:
///  * the app refuses the TEMPLATE itself (an older gateway is still deployed,
///    so trusting the server to have stripped it is not a fix);
///  * the KEY is looked up in the viewer's language — en AND ar — instead of an
///    English string being hardcoded where a lookup belongs.
const String kShippedTemplate = 'Label{{Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS}}';

class _ScriptedRepository implements AccountStatusRepository {
  const _ScriptedRepository(this._info);

  final AccountStatusInfo _info;

  @override
  Future<AccountStatusInfo> fetchStatus() async => _info;
}

Widget _harness(AccountStatusRepository repo, {required Locale locale}) {
  final router = GoRouter(
    initialLocation: '/account-status',
    routes: [
      GoRoute(
        path: '/account-status',
        name: 'account-status',
        builder: (context, state) => AccountStatusScreen(repository: repo),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (context, state) => const Scaffold(body: SizedBox.expand()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const Scaffold(body: SizedBox.expand()),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: locale,
    theme: AppTheme.midnight(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

/// Serves one `/v1/users/me` body, so the REAL repository does the parsing.
/// A hand-built AccountStatusInfo would test the test, not the wire.
Dio _dioServing(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://stub.invalid'));
  dio.httpClientAdapter = _OneShotAdapter(body);
  return dio;
}

class _OneShotAdapter implements HttpClientAdapter {
  _OneShotAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        _encode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  static String _encode(Map<String, dynamic> map) {
    final parts = map.entries
        .map((e) => '"${e.key}":${e.value == null ? 'null' : '"${e.value}"'}');
    return '{${parts.join(',')}}';
  }
}

void main() {
  group('the wire — the real repository parses the real body', () {
    test('a whole-string Label{{...}} is WITHHELD as prose and kept as a code',
        () async {
      final repo = DioAccountStatusRepository(_dioServing({
        'status': 'suspended',
        'statusReason': kShippedTemplate,
      }));

      final info = await repo.fetchStatus();

      expect(info.reason, isNull,
          reason: 'a template is not prose; letting it through is D16');
      expect(info.reasonCode, 'Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS');
    });

    test('CONTROL: operator prose is NOT withheld and yields no code',
        () async {
      final repo = DioAccountStatusRepository(_dioServing({
        'status': 'suspended',
        'statusReason': 'Multiple chargeback disputes',
      }));

      final info = await repo.fetchStatus();

      // Without this the fix would be indistinguishable from "always discard
      // the server reason", which is a worse defect wearing the fix's clothes.
      expect(info.reason, 'Multiple chargeback disputes');
      expect(info.reasonCode, isNull);
    });

    test('a reasonCode sent explicitly is preferred over deriving one',
        () async {
      final repo = DioAccountStatusRepository(_dioServing({
        'status': 'suspended',
        'statusReason': 'Contact support.',
        'reasonCode': 'Ban.Label.YOU_ARE_BANNED',
      }));

      final info = await repo.fetchStatus();

      expect(info.reason, 'Contact support.');
      expect(info.reasonCode, 'Ban.Label.YOU_ARE_BANNED');
    });
  });

  group('the pixels — what a suspended user actually reads', () {
    testWidgets('EN: the code becomes English copy, and the token never renders',
        (tester) async {
      await tester.pumpWidget(_harness(
        const _ScriptedRepository(AccountStatusInfo(
          value: AccountStatusValue.suspended,
          reasonCode: 'Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS',
        )),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Label{{'), findsNothing);
      expect(find.textContaining('suspended for 3 days'), findsOneWidget);
    });

    testWidgets('AR: the SAME code becomes Arabic copy — the lookup is real',
        (tester) async {
      await tester.pumpWidget(_harness(
        const _ScriptedRepository(AccountStatusInfo(
          value: AccountStatusValue.suspended,
          reasonCode: 'Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS',
        )),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Label{{'), findsNothing);
      // DISCRIMINATING: if the English string had been hardcoded, this would
      // find the English sentence instead and the Arabic one not at all.
      expect(find.textContaining('3 أيام'), findsOneWidget);
      expect(find.textContaining('suspended for 3 days'), findsNothing);
    });

    testWidgets('an UNKNOWN code falls back to localized copy, never the key',
        (tester) async {
      await tester.pumpWidget(_harness(
        const _ScriptedRepository(AccountStatusInfo(
          value: AccountStatusValue.suspended,
          reasonCode: 'Ban.Label.SOMETHING_THIS_BUILD_HAS_NEVER_HEARD_OF',
        )),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ban.Label.'), findsNothing,
          reason: 'printing the key at the user is the same defect, one layer '
              'along');
      expect(find.textContaining('under review'), findsOneWidget);
    });

    testWidgets('CONTROL: operator prose still renders verbatim', (tester) async {
      await tester.pumpWidget(_harness(
        const _ScriptedRepository(AccountStatusInfo(
          value: AccountStatusValue.suspended,
          reason: 'Multiple chargeback disputes',
        )),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Multiple chargeback disputes'), findsOneWidget);
    });
  });
}
