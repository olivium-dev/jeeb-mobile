// DEVICE JUDGE F1: the client home Retry re-fetched only /requests and
// /deliveries, so a failed greeting read never recovered in place.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowsThenSucceeds implements CustomerProfileRepository {
  int reads = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (++reads == 1) {
      throw const CustomerProfileRepositoryException.classified(
        CustomerProfileFailure.network,
        appFailure: NetworkFailure(offline: true),
      );
    }
    return const CustomerProfileViewData(name: 'Sami Fawaz');
  }
}

class _ScriptedHome implements ClientHomeRepository {
  _ScriptedHome(this._script);

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

const _offlineSnapshot = ClientHomeSnapshot(
  requestsFailure: NetworkFailure(offline: true),
  inProgressFailure: NetworkFailure(offline: true),
);

const _order = ClientHomeRequest(
  id: 'ip-1',
  title: 'Kamal Hajj',
  destinationLabel: '1 kilo potato',
  status: ClientRequestStatus.enRoute,
  tier: ClientRequestTier.flash,
  progressStep: 3,
);

Widget _host(ClientHomeCubit home, GreetingProfileCubit greeting, Locale l) =>
    wrapForTest(
      MultiBlocProvider(
        providers: [
          BlocProvider<ClientHomeCubit>.value(value: home),
          BlocProvider<GreetingProfileCubit>.value(value: greeting),
        ],
        child: const Scaffold(body: ClientHomeScreen()),
      ),
      locale: l,
    );

void main() {
  // A 440x956 phone, not the 800x600 test default: the pinned voice dock
  // overlaps the scroll tail on a viewport no shipped device has.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(440 * 3, 956 * 3);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('$tag: the home retry re-issues the profile read', (
      tester,
    ) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final profile = _ThrowsThenSucceeds();
      final greeting = GreetingProfileCubit(repository: profile);
      addTearDown(greeting.close);
      final homeRepo = _ScriptedHome([
        _offlineSnapshot,
        const ClientHomeSnapshot(pending: [_order]),
      ]);
      final home = ClientHomeCubit(
        repository: homeRepo,
        greetingNameProvider: () => null,
      );
      addTearDown(home.close);

      await tester.pumpWidget(_host(home, greeting, locale));
      await greeting.load();
      await tester.pumpAndSettle();
      expect(profile.reads, 1);
      expect(homeRepo.calls, 1, reason: 'the screen loads on its first frame');
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsIdentifier('client_home_retry_cta'));
      await tester.pumpAndSettle();

      expect(profile.reads, 2, reason: 'Retry must also re-read /v1/users/me');
      expect(greeting.state.name, 'Sami Fawaz');
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('$tag: pull-to-refresh re-issues the profile read', (
      tester,
    ) async {
      useReduceMotion(tester);
      final profile = _ThrowsThenSucceeds();
      final greeting = GreetingProfileCubit(repository: profile);
      addTearDown(greeting.close);
      final home = ClientHomeCubit(
        repository: _ScriptedHome([const ClientHomeSnapshot(pending: [_order])]),
        greetingNameProvider: () => null,
      );
      addTearDown(home.close);

      await tester.pumpWidget(_host(home, greeting, locale));
      await greeting.load();
      await tester.pumpAndSettle();
      expect(profile.reads, 1);

      await tester.fling(
        find.byKey(const Key('client-home-ready-list')),
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(profile.reads, 2, reason: 'a pull must also re-read /v1/users/me');
      expect(greeting.state.name, 'Sami Fawaz');
    });

    testWidgets('$tag: no greeting provider leaves the retry inert', (
      tester,
    ) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final home = ClientHomeCubit(
        repository: _ScriptedHome([
          _offlineSnapshot,
          const ClientHomeSnapshot(pending: [_order]),
        ]),
        greetingNameProvider: () => null,
      );
      addTearDown(home.close);

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<ClientHomeCubit>.value(
            value: home,
            child: const Scaffold(body: ClientHomeScreen()),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('client_home_retry_cta'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
