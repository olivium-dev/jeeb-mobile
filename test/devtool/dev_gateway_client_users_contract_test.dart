import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/super_login/full_roster_login.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';

class _RosterAdapter implements HttpClientAdapter {
  _RosterAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

void main() {
  test('online-ready Dev Tool handoff persists the Jeeber active role', () {
    final source = File(
      'lib/devtool/users/scenario_users_page.dart',
    ).readAsStringSync();

    expect(source, contains('RoleCubit.rolePrefKey'));
    expect(source, contains('UserRole.jeeber.storageKey'));
  });

  test('Super Login Plus selects the active role from all roster roles', () {
    const jeeber = RosterUser(
      userId: 'jeeber',
      name: 'Jeeber',
      role: 'customer',
      roles: <String>['customer', 'driver'],
    );
    const client = RosterUser(
      userId: 'client',
      name: 'Client',
      role: 'customer',
      roles: <String>['customer'],
    );

    expect(jeeber.activeRole, UserRole.jeeber);
    expect(client.activeRole, UserRole.client);
  });

  test(
    'Super Login Plus trusts authenticated capabilities over stale roster',
    () {
      const staleJeeber = RosterUser(
        userId: 'jeeber',
        name: 'Seeded Jeeber',
        role: 'customer',
        roles: <String>['customer'],
      );

      expect(
        resolveSuperLoginActiveRole(staleJeeber, <String, dynamic>{
          'activeRole': 'client',
          'availableRoles': <String>['client', 'jeeber'],
        }),
        UserRole.jeeber,
      );
      expect(
        resolveSuperLoginActiveRole(staleJeeber, <String, dynamic>{
          'available_roles': <String>['customer'],
        }),
        UserRole.client,
      );
    },
  );

  test('Super Login Plus can resolve roles from the minted JWT offline', () {
    final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
    final payload = base64Url.encode(
      utf8.encode('{"roles":["client","jeeber"]}'),
    );
    final token = '$header.$payload.signature';
    const staleJeeber = RosterUser(
      userId: 'jeeber',
      name: 'Seeded Jeeber',
      role: 'customer',
      roles: <String>['customer'],
    );

    final roles = superLoginRolesFromAccessToken(token);
    expect(roles, <String>['client', 'jeeber']);
    expect(
      resolveSuperLoginActiveRole(staleJeeber, null, tokenRoles: roles),
      UserRole.jeeber,
    );
    expect(superLoginRolesFromAccessToken('opaque-token'), isEmpty);
  });

  test('Super Login Plus never forwards stale roster roles to token mint', () {
    final source = File(
      'lib/devtool/super_login/full_roster_login.dart',
    ).readAsStringSync();

    expect(source, contains("data: <String, dynamic>{'userId': user.userId}"));
    expect(source, isNot(contains("'roles': user.roles")));
    expect(source, contains("'/v1/users/me'"));
  });

  test('roleless /auth/tokens mint is the valid fresh-user path', () async {
    final adapter = _RosterAdapter((options) {
      expect(options.path, '/auth/tokens');
      expect(options.method, 'POST');
      expect(options.data, <String, dynamic>{'userId': 'fresh-user'});
      return _json(<String, Object?>{'accessToken': 'fresh-user-token'});
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
      ..httpClientAdapter = adapter;

    final token = await DevGatewayClient(
      dio: dio,
    ).mintTokenForUser('fresh-user');

    expect(token, 'fresh-user-token');
    expect(adapter.requests, hasLength(1));
  });

  test('fetches the super-login roster with roles intact', () async {
    final adapter = _RosterAdapter((options) {
      return _json(<String, Object?>{
        'users': <Object?>[
          <String, Object?>{
            'userId': 'karim',
            'name': 'Karim Driver',
            'role': 'customer',
            'roles': <String>['customer', 'driver'],
          },
        ],
      });
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
      ..httpClientAdapter = adapter;

    final users = await DevGatewayClient(dio: dio).fetchSuperLoginRoster();

    expect(users, hasLength(1));
    expect(users.single.id, 'karim');
    expect(users.single.username, 'Karim Driver');
    expect(users.single.roles, <String>['customer', 'driver']);
    expect(adapter.requests.single.path, '/api/User/super-login/users');
  });

  test('super-login roster 404 reports its actual feature gates', () async {
    final adapter = _RosterAdapter(
      (_) => _json(<String, Object?>{'title': 'Not Found'}, status: 404),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
      ..httpClientAdapter = adapter;

    await expectLater(
      DevGatewayClient(dio: dio).fetchSuperLoginRoster(),
      throwsA(
        isA<DevGatewayException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having(
              (error) => error.message,
              'message',
              allOf(
                contains('SuperLogin:OpenMode'),
                isNot(contains('Features:DevEndpoints')),
              ),
            ),
      ),
    );
  });

  test('merges the fuller roster and trusts roles[] over flat role', () async {
    final adapter = _RosterAdapter((options) {
      if (options.path == '/api/User/super-login/users') {
        return _json(<String, Object?>{
          'users': <Object?>[
            <String, Object?>{
              'userId': 'karim',
              'name': 'Karim Driver',
              'role': 'customer',
              'roles': <String>['customer', 'driver'],
            },
            <String, Object?>{
              'userId': 'nour',
              'name': 'Nour Demo',
              'role': 'customer',
              'roles': <String>['customer'],
            },
            <String, Object?>{
              'userId': 'roster-only',
              'name': 'Roster Jeeber',
              'role': 'customer',
              'roles': <String>['customer', 'driver'],
            },
          ],
        });
      }
      if (options.path == '/dev/data/users') {
        return _json(<String, Object?>{
          'users': <Object?>[
            <String, Object?>{
              'userId': 'karim',
              'username': 'Karim Driver',
              'email': 'karim@example.test',
              'status': 'active',
            },
            <String, Object?>{
              'userId': 'directory-only',
              'username': 'Synthetic User',
              'email': 'synthetic@example.test',
              'status': 'active',
            },
          ],
          'count': 2,
        });
      }
      return _json(<String, Object?>{}, status: 404);
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
      ..httpClientAdapter = adapter;

    final users = await DevGatewayClient(dio: dio).listUsers();

    expect(users.map((user) => user.id), <String>[
      'karim',
      'nour',
      'roster-only',
      'directory-only',
    ]);
    final karim = users.first;
    expect(karim.role, 'customer');
    expect(karim.roles, <String>['customer', 'driver']);
    expect(karim.isJeeber, isTrue);
    expect(karim.roleForOfferInitiation, 'driver');
    expect(karim.email, 'karim@example.test');
    expect(users[1].isJeeber, isFalse);
    expect(users[2].isJeeber, isTrue);
    expect(users[3].isJeeber, isFalse);
    expect(adapter.requests.map((request) => request.path), <String>[
      '/api/User/super-login/users',
      '/dev/data/users',
    ]);
    expect(adapter.requests.last.queryParameters, <String, dynamic>{
      'skip': 0,
      'limit': 100,
    });
  });

  test(
    'uses the directory singular role as a legacy Jeeber fallback',
    () async {
      final adapter = _RosterAdapter((options) {
        if (options.path == '/api/User/super-login/users') {
          return _json(<String, Object?>{'title': 'unavailable'}, status: 503);
        }
        return _json(<String, Object?>{
          'users': <Object?>[
            <String, Object?>{
              'userId': 'flat-driver',
              'username': 'Flat Driver',
              'role': 'driver',
            },
          ],
        });
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
        ..httpClientAdapter = adapter;

      final users = await DevGatewayClient(dio: dio).listUsers();

      expect(users.single.role, 'driver');
      expect(users.single.roles, isEmpty);
      expect(users.single.isJeeber, isTrue);
      expect(users.single.roleForOfferInitiation, 'driver');
    },
  );

  test('customer-only users cannot be treated as offer initiators', () {
    const user = DevUser(
      id: 'customer-only',
      username: 'Customer Only',
      status: 'active',
      role: 'customer',
      roles: <String>['customer'],
    );

    expect(user.roleForOfferInitiation, isNull);
  });
}
