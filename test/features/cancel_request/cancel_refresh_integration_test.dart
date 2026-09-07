// cycle-4 integration-style proof: a successfully cancelled request

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/cancel_request/application/cancelled_request_signals.dart';
import 'package:jeeb_mobile/features/cancel_request/cancel_request_di.dart';
import 'package:jeeb_mobile/features/cancel_request/domain/cancel_request_repository.dart';
import 'package:jeeb_mobile/features/cancel_request/presentation/cancel_request_sheet.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// Mutable "server": the pending list shrinks when the cancel lands.
class _FakeServer {
  _FakeServer(List<ClientHomeRequest> pending)
      : _pending = List.of(pending);

  final List<ClientHomeRequest> _pending;

  List<ClientHomeRequest> get pending => List.unmodifiable(_pending);

  void cancel(String requestId) =>
      _pending.removeWhere((r) => r.id == requestId);
}

class _ServerBackedHomeRepository implements ClientHomeRepository {
  _ServerBackedHomeRepository(this.server);

  final _FakeServer server;

  /// When set, every read parks on it until the test releases it — the slow
  /// gateway the cancel must not wait for.
  Future<void>? gate;

  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    calls += 1;
    // Read the rows BEFORE parking: a read started before the cancel must
    // resolve with the stale list, exactly like the wire does.
    final rows = server.pending;
    final g = gate;
    if (g != null) await g;
    return ClientHomeSnapshot(pending: rows);
  }
}

class _ServerBackedCancelRepository implements CancelRequestRepository {
  _ServerBackedCancelRepository(this.server, {this.failWith});

  final _FakeServer server;
  final CancelRequestFailure? failWith;

  @override
  Future<void> cancelRequest({required String requestId}) async {
    final f = failWith;
    if (f != null) throw CancelRequestException(f);
    server.cancel(requestId);
  }
}

ClientHomeRequest _pendingRequest(String id) => ClientHomeRequest(
      id: id,
      title: 'Shawarma from Barbar',
      status: ClientRequestStatus.searching,
      destinationLabel: 'Home',
    );

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() {
    // Tall surface so the whole sheet renders un-culled (mirrors
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    if (!sl.isRegistered<PushRefreshSignals>()) {
      sl.registerLazySingleton<PushRefreshSignals>(PushRefreshSignals.new);
    }
    if (sl.isRegistered<CancelledRequestSignals>()) {
      sl.unregister<CancelledRequestSignals>();
    }
    registerCancelRequestDependencies(sl);
  });

  tearDown(() async {
    if (sl.isRegistered<PushRefreshSignals>()) {
      await sl.unregister<PushRefreshSignals>(
        disposingFunction: (s) => s.dispose(),
      );
    }
    if (sl.isRegistered<CancelledRequestSignals>()) {
      await sl.unregister<CancelledRequestSignals>(
        disposingFunction: (s) => s.dispose(),
      );
    }
  });

  testWidgets(
      'confirming the cancel removes the request from the pending list via '
      'the shared refresh signal', (tester) async {
    final server = _FakeServer([_pendingRequest('req-1')]);
    final homeCubit = ClientHomeCubit(
      repository: _ServerBackedHomeRepository(server),
      greetingNameProvider: () => null,
      // Exactly how lib/features/shell/tabs/home_tab.dart wires the bus.
      refreshSignals: sl<PushRefreshSignals>().stream,
    );
    addTearDown(homeCubit.close);

    await homeCubit.load();
    expect(homeCubit.state.pending.map((r) => r.id), contains('req-1'),
        reason: 'precondition: the request is pending before the cancel');

    var routedHome = 0;
    await tester.pumpWidget(
      _harness(
        CancelRequestSheet(
          requestId: 'req-1',
          repository: _ServerBackedCancelRepository(server),
          onCancelled: () => routedHome++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
    await tester.pump(); // inFlight
    await tester.pump(); // succeeded → listener: signal + onCancelled
    await tester.pump(); // ClientHomeCubit refresh() microtasks flush

    expect(routedHome, 1);
    expect(homeCubit.state.pending, isEmpty,
        reason: 'the cancelled request must disappear from pending after a '
            'successful cancel (refresh signal re-pulled the list)');
  });

  testWidgets('a FAILED cancel does NOT touch the pending list', (tester) async {
    final server = _FakeServer([_pendingRequest('req-1')]);
    final homeCubit = ClientHomeCubit(
      repository: _ServerBackedHomeRepository(server),
      greetingNameProvider: () => null,
      refreshSignals: sl<PushRefreshSignals>().stream,
    );
    addTearDown(homeCubit.close);

    await homeCubit.load();

    var routedHome = 0;
    await tester.pumpWidget(
      _harness(
        CancelRequestSheet(
          requestId: 'req-1',
          repository: _ServerBackedCancelRepository(
            server,
            failWith: CancelRequestFailure.conflict,
          ),
          onCancelled: () => routedHome++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(routedHome, 0);
    expect(homeCubit.state.pending.map((r) => r.id), contains('req-1'),
        reason: 'a surfaced failure must keep the request pending — no '
            'client-side pretend-release');
  });

  // F9 — the device defect: the sheet lives on `/requests/:id/waiting`, so the
  // home list is OFF SCREEN and its deferred gate swallows the push signal.
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'F9 [${locale.languageCode}]: a landed cancel drops the pending row while '
      'the home list is off screen — no pull-to-refresh, no read',
      (tester) async {
        useReduceMotion(tester);
        final server = _FakeServer([_pendingRequest('req-1')]);
        final repo = _ServerBackedHomeRepository(server);
        final homeCubit = ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => null,
          refreshSignals: sl<PushRefreshSignals>().stream,
        );
        addTearDown(homeCubit.close);

        await homeCubit.load();
        expect(homeCubit.state.pending.map((r) => r.id), contains('req-1'));
        final readsBeforeCancel = repo.calls;

        // The waiting route is on top: PollingVisibilityGate has already told
        // the cubit it is not visible, so every push is deferred debt.
        homeCubit.setPollingVisible(false);

        await tester.pumpWidget(
          _harness(
            CancelRequestSheet(
              requestId: 'req-1',
              repository: _ServerBackedCancelRepository(server),
              onCancelled: () {},
            ),
            locale: locale,
          ),
        );
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('cancel_request_confirm_cta'),
          findsOneWidget,
        );
        await tester
            .tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
        await tester.pump(); // inFlight
        await tester.pump(); // succeeded -> listener publishes the cancelled id

        expect(
          homeCubit.state.pending,
          isEmpty,
          reason: 'the row must go on the DELETE, not on a later re-read the '
              'invisible gate is still holding',
        );
        expect(
          repo.calls,
          readsBeforeCancel,
          reason: 'optimistic truth is local: it must cost no snapshot read',
        );
      },
    );
  }

  testWidgets(
    'F9: the row goes immediately while the home repository is still parked',
    (tester) async {
      useReduceMotion(tester);
      final server = _FakeServer([_pendingRequest('req-1')]);
      final repo = _ServerBackedHomeRepository(server);
      final homeCubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
        refreshSignals: sl<PushRefreshSignals>().stream,
      );
      addTearDown(homeCubit.close);

      await homeCubit.load();
      expect(homeCubit.state.pending, hasLength(1));

      // Every read from here on hangs: the slow gateway of the device trace.
      final slow = Completer<void>();
      repo.gate = slow.future;

      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-1',
            repository: _ServerBackedCancelRepository(server),
            onCancelled: () {},
          ),
        ),
      );
      await tester.pump();
      await tester
          .tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
      await tester.pump();
      await tester.pump();

      expect(
        homeCubit.state.pending,
        isEmpty,
        reason: 'no read has returned yet — the row is gone on local truth',
      );

      repo.gate = null;
      slow.complete();
      await tester.pump();
      await tester.pump();
      expect(homeCubit.state.pending, isEmpty);
    },
  );

  testWidgets(
    'F9: a snapshot already in flight at cancel time neither resurrects the '
    'row nor swallows the follow-up read',
    (tester) async {
      useReduceMotion(tester);
      final server = _FakeServer([_pendingRequest('req-1')]);
      final repo = _ServerBackedHomeRepository(server);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
        refreshSignals: sl<PushRefreshSignals>().stream,
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.pending, hasLength(1));

      // A refresh is ALREADY in flight, holding the stale pending list.
      final inFlight = Completer<void>();
      repo.gate = inFlight.future;
      unawaited(cubit.refresh());
      await tester.pump();
      expect(repo.calls, 2, reason: 'the refresh is parked mid-read');

      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-1',
            repository: _ServerBackedCancelRepository(server),
            onCancelled: () {},
          ),
        ),
      );
      await tester.pump();
      await tester
          .tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
      await tester.pump();
      await tester.pump();

      expect(cubit.state.pending, isEmpty, reason: 'optimistic removal');

      repo.gate = null;
      inFlight.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        cubit.state.pending,
        isEmpty,
        reason: 'the stale in-flight snapshot must not put the row back',
      );
      expect(
        repo.calls,
        3,
        reason: 'the push that arrived mid-read must still produce exactly one '
            'follow-up read, not be dropped by the in-flight guard',
      );
    },
  );
}
