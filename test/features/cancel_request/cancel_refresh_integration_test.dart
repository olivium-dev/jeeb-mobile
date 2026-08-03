// cycle-4 integration-style proof: a successfully cancelled request

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/cancel_request/domain/cancel_request_repository.dart';
import 'package:jeeb_mobile/features/cancel_request/presentation/cancel_request_sheet.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(pending: server.pending);
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

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
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
  });

  tearDown(() async {
    if (sl.isRegistered<PushRefreshSignals>()) {
      await sl.unregister<PushRefreshSignals>(
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
}
