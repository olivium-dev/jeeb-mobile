import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/registration/data/super_login_demo_user.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_picker.dart';

import 'support/sync_app_localizations.dart';

/// Fake roster service whose behaviour is set per test: returns [users], or
/// throws [error] when [error] is non-null. Records call count for retry tests.
class _FakeDemoUserService implements SuperLoginDemoUserService {
  _FakeDemoUserService({this.users = const [], this.error});

  List<SuperLoginDemoUser> users;
  SuperLoginDemoUserException? error;
  int calls = 0;

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async {
    calls++;
    final err = error;
    if (err != null) throw err;
    return users;
  }
}

const _client = SuperLoginDemoUser(
  userId: '11111111-1111-4111-8111-111111111111',
  name: 'Sami',
  role: 'customer',
  availableRoles: ['customer'],
);
const _jeeber = SuperLoginDemoUser(
  userId: '22222222-2222-4222-8222-222222222222',
  name: 'Kamal',
  role: 'driver',
  availableRoles: ['customer', 'driver'],
);

void main() {
  // Host that opens the picker with the injected service and stashes the
  // selected user so the test can assert on what a tap returned.
  Widget host(
    SuperLoginDemoUserService service, {
    void Function(SuperLoginDemoUser?)? onResult,
    Locale locale = const Locale('en'),
  }) =>
      wrapForTest(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () async {
                  final user =
                      await showSuperLoginPicker(context, service: service);
                  onResult?.call(user);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        locale: locale,
      );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump(); // start the sheet route
    // Advance the modal's slide-up entry animation so the content lands inside
    // the viewport (otherwise the sheet is still translated below the screen
    // and any row/CTA tap derives an off-screen offset and misses).
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('SuperLoginDemoUser model', () {
    test('fromJson maps username->name, active_role->role (LIST contract)', () {
      final user = SuperLoginDemoUser.fromJson(const {
        'userId': 'u1',
        'username': 'Nour',
        'active_role': 'customer',
        'available_roles': ['customer'],
      });
      expect(user, isNotNull);
      expect(user!.userId, 'u1');
      expect(user.name, 'Nour');
      expect(user.role, 'customer');
      expect(user.isJeeber, isFalse);
    });

    test('fromJson maps gateway demo-users {name, role} shape and ignores '
        'the row passcode', () {
      final user = SuperLoginDemoUser.fromJson(const {
        'userId': 'd1000000-0000-4000-8000-000000000001',
        'name': 'Nour',
        'role': 'jeeber',
        'passcode': 'JEEB-SL-should-be-ignored',
      });
      expect(user, isNotNull);
      expect(user!.userId, 'd1000000-0000-4000-8000-000000000001');
      expect(user.name, 'Nour');
      expect(user.role, 'jeeber');
      // The row passcode is never surfaced on the model.
      expect(user.isJeeber, isTrue);
    });

    test('isJeeber is true when active_role is driver', () {
      expect(_jeeber.isJeeber, isTrue);
    });

    test('isJeeber is true when available_roles contains driver', () {
      final user = SuperLoginDemoUser.fromJson(const {
        'userId': 'u2',
        'username': 'Rima',
        'active_role': 'customer',
        'available_roles': ['customer', 'driver'],
      });
      expect(user!.isJeeber, isTrue);
    });

    test('fromJson drops a row with a missing/blank userId or username', () {
      expect(
        SuperLoginDemoUser.fromJson(const {
          'userId': '',
          'username': 'Nour',
          'active_role': 'customer',
        }),
        isNull,
      );
      expect(
        SuperLoginDemoUser.fromJson(const {
          'userId': 'u1',
          'username': '',
          'active_role': 'customer',
        }),
        isNull,
      );
    });
  });

  group('Super-login-plus picker widget', () {
    testWidgets('shows a loading indicator while the fetch is in flight',
        (tester) async {
      // Never-completing future keeps the picker in the waiting state.
      final service = _SlowService();
      await tester.pumpWidget(host(service));
      await open(tester);

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'picker must show a loading spinner during the fetch',
      );
      // The list/error regions must NOT be present while loading.
      expect(find.byKey(const Key('superLoginPlus.pickerList')), findsNothing);
      expect(find.byKey(const Key('superLoginPlus.pickerError')), findsNothing);
    });

    testWidgets('lists each demo user with name + role badge', (tester) async {
      final service = _FakeDemoUserService(users: const [_client, _jeeber]);
      await tester.pumpWidget(host(service));
      await open(tester);
      await tester.pump(); // resolve the future

      // Both names render.
      expect(find.text('Sami'), findsOneWidget);
      expect(find.text('Kamal'), findsOneWidget);
      // Role badges render (OMDS chip labels).
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Jeeber'), findsOneWidget);
      // Per-user addressability ids resolve to keyed rows.
      expect(
        find.byKey(Key('superLoginPlus.user.${_client.userId}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('superLoginPlus.user.${_jeeber.userId}')),
        findsOneWidget,
      );
      // Per-user Semantics identifiers required by the ticket
      // (super_login_plus_user_<userId>).
      expect(
        find.bySemanticsIdentifier('super_login_plus_user_${_client.userId}'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('super_login_plus_user_${_jeeber.userId}'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a row pops the picker with the selected user',
        (tester) async {
      final service = _FakeDemoUserService(users: const [_client, _jeeber]);
      SuperLoginDemoUser? result;
      await tester.pumpWidget(host(service, onResult: (u) => result = u));
      await open(tester);
      await tester.pump();

      await tester.tap(find.byKey(Key('superLoginPlus.user.${_jeeber.userId}')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.userId, _jeeber.userId);
      // Picker dismissed.
      expect(find.byKey(const Key('superLoginPlus.pickerList')), findsNothing);
    });

    testWidgets('network error shows the error state with a Retry CTA, and '
        'Retry re-issues the fetch', (tester) async {
      final service = _FakeDemoUserService(
        error: const SuperLoginDemoUserException(
          SuperLoginDemoUserError.network,
        ),
      );
      await tester.pumpWidget(host(service));
      await open(tester);
      await tester.pump(); // resolve the (throwing) future

      expect(find.byKey(const Key('superLoginPlus.pickerError')), findsOneWidget);
      expect(
        find.text('Could not load demo users. Check your connection.'),
        findsOneWidget,
      );
      expect(service.calls, 1);

      // Now make the next fetch succeed and tap Retry.
      service
        ..error = null
        ..users = const [_client];
      await tester.tap(find.text('Retry'));
      await tester.pump(); // re-issue + resolve
      await tester.pump();

      expect(service.calls, 2);
      expect(find.text('Sami'), findsOneWidget);
      expect(find.byKey(const Key('superLoginPlus.pickerError')), findsNothing);
    });

    testWidgets('empty roster falls back to the error state (nothing to pick)',
        (tester) async {
      final service = _FakeDemoUserService(users: const []);
      await tester.pumpWidget(host(service));
      await open(tester);
      await tester.pump();

      expect(find.byKey(const Key('superLoginPlus.pickerError')), findsOneWidget);
    });

    testWidgets('renders RTL with Arabic copy under Locale(ar)', (tester) async {
      final service = _FakeDemoUserService(users: const [_client]);
      await tester.pumpWidget(
        host(service, locale: const Locale('ar')),
      );
      await open(tester);
      await tester.pump();

      final dir = Directionality.of(
        tester.element(find.byKey(const Key('superLoginPlus.pickerTitle'))),
      );
      expect(dir, TextDirection.rtl);
      expect(find.text('اختر مستخدماً تجريبياً'), findsOneWidget);
      // Arabic client role badge.
      expect(find.text('عميل'), findsOneWidget);
    });
  });
}

/// Service whose fetch future never completes — used to assert the loading
/// state without a race on resolution.
class _SlowService implements SuperLoginDemoUserService {
  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() =>
      Completer<List<SuperLoginDemoUser>>().future;
}
