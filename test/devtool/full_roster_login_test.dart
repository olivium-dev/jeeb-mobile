import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/super_login/full_roster_login.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/sync_app_localizations.dart';

class _RosterAdapter implements HttpClientAdapter {
  _RosterAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

DevGatewayClient _client(
  ResponseBody Function(RequestOptions options) respond,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
    ..httpClientAdapter = _RosterAdapter(respond);
  return DevGatewayClient(dio: dio);
}

Widget _host(DevGatewayClient client) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: FullRosterLoginPage(client: client),
  );
}

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<Dio>(Dio(BaseOptions(baseUrl: 'http://unused.test')));
    sl.registerSingleton<AuthTokenStore>(AuthTokenStore());
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('renders users returned by the super-login roster', (
    tester,
  ) async {
    final client = _client(
      (_) => _json(<String, Object?>{
        'users': <Object?>[
          <String, Object?>{
            'userId': 'karim',
            'name': 'Karim Driver',
            'role': 'driver',
            'roles': <String>['customer', 'driver'],
          },
        ],
      }),
    );

    await tester.pumpWidget(_host(client));
    await tester.pumpAndSettle();

    expect(find.text('Karim Driver'), findsOneWidget);
    expect(find.text('driver'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('404 renders the disabled-feature diagnosis', (tester) async {
    final client = _client(
      (_) => _json(<String, Object?>{'title': 'Not Found'}, status: 404),
    );

    await tester.pumpWidget(_host(client));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The full user roster is turned off on this backend (Super-Login / '
        'demo-users flags are disabled here). This is not a Server URL '
        'problem.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Could not load the user roster. Check the Dev Tool Server URL.',
      ),
      findsNothing,
    );
  });

  testWidgets('connection failure renders the unreachable diagnosis', (
    tester,
  ) async {
    final client = _client((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('connection failed'),
      );
    });

    await tester.pumpWidget(_host(client));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not reach the Dev Tool server. Check the Dev Tool Server URL.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('502 renders the upstream-service diagnosis', (tester) async {
    final client = _client(
      (_) => _json(<String, Object?>{'title': 'Bad Gateway'}, status: 502),
    );

    await tester.pumpWidget(_host(client));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "The gateway's upstream user service failed while loading the roster.",
      ),
      findsOneWidget,
    );
  });
}
