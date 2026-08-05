import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';

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

  test('uses the directory as an honest role-unknown fallback', () async {
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
    expect(users.single.isJeeber, isFalse);
    expect(users.single.roleForOfferInitiation, 'driver');
  });

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
