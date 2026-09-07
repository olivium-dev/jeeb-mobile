// LR-28/AE-04/UX-38 — the session read was a `FutureBuilder` built inline (a
// NEW future every rebuild) with no `hasError` arm, so a token-store throw
// rendered the form with `userId: ''`; and every save failure showed the same
// snack, ignoring a 422's per-field messages.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/application/address_form_cubit.dart';
import 'package:jeeb_mobile/features/location/application/address_form_state.dart';
import 'package:jeeb_mobile/features/location/domain/address_form_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/presentation/screens/address_detail_form_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const AddressFormDraft _draft = AddressFormDraft(
  label: 'Home',
  latitude: 33.8869,
  longitude: 35.5131,
  category: SavedLocationCategory.home,
);

/// Answers the session read however the test needs — including by throwing.
class _ScriptedTokenStore extends AuthTokenStore {
  _ScriptedTokenStore({this.throwsOnRead = false});

  final bool throwsOnRead;
  int reads = 0;

  @override
  Future<String?> get userId async {
    reads++;
    if (throwsOnRead) throw const UnauthorizedFailure();
    return 'u1';
  }
}

class _FailingRepository implements AddressFormRepository {
  const _FailingRepository(this.failure);

  final AppFailure failure;

  @override
  Future<SavedLocation> create({
    required String userId,
    required AddressFormDraft draft,
  }) async =>
      throw failure;

  @override
  Future<SavedLocation> update({
    required String userId,
    required String id,
    required AddressFormDraft draft,
  }) async =>
      throw failure;
}

AddressFormCubit _cubit(AppFailure failure) => AddressFormCubit(
      repository: _FailingRepository(failure),
      userId: 'u1',
    );

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  final GoRouter router = GoRouter(
    initialLocation: '/form',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/form', builder: (_, _) => child),
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

void main() {
  tearDown(() async => sl.reset());

  group('AddressFormCubit · the save failure is classified', () {
    test('a 422 carries its field errors onto the state', () async {
      final cubit = _cubit(
        const ValidationFailure(
          fieldErrors: <String, List<String>>{
            'label': <String>['Label is required'],
          },
        ),
      );

      await cubit.save(_draft);

      expect(cubit.state.status, AddressFormStatus.failed);
      expect(cubit.state.fieldErrors['label'], <String>['Label is required']);
      await cubit.close();
    });

    test('a 503 carries the kind and NO field errors', () async {
      final cubit = _cubit(const ServerFailure(status: 503));

      await cubit.save(_draft);

      expect(cubit.state.appFailure, isA<ServerFailure>());
      expect(cubit.state.fieldErrors, isEmpty);
      await cubit.close();
    });

    test('the legacy enum still tracks the kind', () async {
      final cubit = _cubit(const NetworkFailure());

      await cubit.save(_draft);

      expect(cubit.state.error, AddressFormFailure.network);
      expect(cubit.state.appFailure, isA<NetworkFailure>());
      await cubit.close();
    });

    test('a 403 is NOT reported as a connectivity failure', () async {
      final cubit = _cubit(const ForbiddenFailure());

      await cubit.save(_draft);

      expect(cubit.state.error, AddressFormFailure.unknown);
      expect(cubit.state.appFailure, isA<ForbiddenFailure>());
      await cubit.close();
    });
  });

  group('AddressDetailFormScreen · the session gate', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('a throwing token store renders the identified failure '
          'block · ${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        sl.registerSingleton<AuthTokenStore>(
          _ScriptedTokenStore(throwsOnRead: true),
        );

        await tester.pumpWidget(
          _harness(
            const AddressDetailFormScreen(
              repository: _FailingRepository(ServerFailure(status: 500)),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('address_form_session_error'),
          findsOneWidget,
        );
        // The form is NOT rendered with an empty user id behind it.
        expect(
          find.bySemanticsIdentifier('address_form_save_cta'),
          findsNothing,
        );
      });
    }

    // LR-28: the inline FutureBuilder minted a NEW future on every rebuild.
    testWidgets('the session is read exactly once', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final store = _ScriptedTokenStore();
      sl.registerSingleton<AuthTokenStore>(store);

      await tester.pumpWidget(
        _harness(
          const AddressDetailFormScreen(
            repository: _FailingRepository(ServerFailure(status: 500)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();

      expect(store.reads, 1);
      expect(
        find.bySemanticsIdentifier('address_form_session_error'),
        findsNothing,
      );
    });
  });
}
