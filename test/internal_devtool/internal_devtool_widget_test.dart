import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/internal_release_policy.dart';
import 'package:jeeb_mobile/internal_devtool/internal_devtool_app.dart';
import 'package:jeeb_mobile/internal_devtool/internal_devtool_semantics.dart';
import 'package:jeeb_mobile/internal_devtool/internal_devtool_services.dart';

import '../support/sync_app_localizations.dart';

void main() {
  testWidgets('unlock gates the restricted status surface', (tester) async {
    final unlocker = _FakeUnlocker([true]);
    await tester.pumpWidget(_app(unlocker: unlocker));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.unlock),
      findsOne,
    );
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.authGate),
      findsOne,
    );
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.launcher),
      findsOne,
    );
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.close),
      findsOne,
    );
    expect(find.text(InternalReleasePolicy.gatewayOrigin), findsNothing);

    await tester.tap(
      find.bySemanticsIdentifier(InternalDevToolSemantics.unlock),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.banner),
      findsOne,
    );
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.status),
      findsOne,
    );
    expect(find.bySemanticsIdentifier(InternalDevToolSemantics.root), findsOne);
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.close),
      findsOne,
    );
    for (final identifier in _statusIdentifiers) {
      expect(find.bySemanticsIdentifier(identifier), findsOne);
    }
    expect(find.text(InternalReleasePolicy.gatewayOrigin), findsOne);
    expect(find.text(InternalReleasePolicy.realtimeSocket), findsOne);
    expect(find.text('Normal SMS only'), findsOne);
    expect(find.textContaining('Super Login'), findsNothing);
  });

  testWidgets('connectivity probe is local-only and refreshes status', (
    tester,
  ) async {
    final reader = _FakeStatusReader(<bool>[false, true]);
    await tester.pumpWidget(
      _app(unlocker: _FakeUnlocker([true]), reader: reader),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsIdentifier(InternalDevToolSemantics.unlock),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOne);

    await tester.tap(
      find.bySemanticsIdentifier(InternalDevToolSemantics.connectivityProbe),
    );
    await tester.pumpAndSettle();

    expect(reader.readCount, 2);
    expect(find.text('Available'), findsOne);
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.connectivity),
      findsOne,
    );
  });

  testWidgets('clear requires confirmation and a second device unlock', (
    tester,
  ) async {
    final unlocker = _FakeUnlocker([true, true]);
    final clearer = _FakeClearer();
    final closer = _FakeCloser();
    await tester.pumpWidget(
      _app(unlocker: unlocker, clearer: clearer, closer: closer),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsIdentifier(InternalDevToolSemantics.unlock),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsIdentifier(InternalDevToolSemantics.clearData),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsIdentifier(
        '${InternalDevToolSemantics.clearConfirmation}_confirm_cta',
      ),
    );
    await tester.pumpAndSettle();

    expect(unlocker.callCount, 2);
    expect(clearer.callCount, 1);
    expect(closer.callCount, 1);
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.authGate),
      findsOne,
    );
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.root),
      findsNothing,
    );
  });

  testWidgets('clear failure still relocks and closes the warm tool', (
    tester,
  ) async {
    final unlocker = _FakeUnlocker([true, true]);
    final clearer = _FakeClearer(throws: true);
    final closer = _FakeCloser();
    await tester.pumpWidget(
      _app(unlocker: unlocker, clearer: clearer, closer: closer),
    );
    await tester.pumpAndSettle();
    await _unlock(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsIdentifier(InternalDevToolSemantics.clearData),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsIdentifier(
        '${InternalDevToolSemantics.clearConfirmation}_confirm_cta',
      ),
    );
    await tester.pumpAndSettle();

    expect(unlocker.callCount, 2);
    expect(clearer.callCount, 1);
    expect(closer.callCount, 1);
    _expectLocked();
  });

  testWidgets('warm launcher relocks for every background lifecycle state', (
    tester,
  ) async {
    final unlocker = _FakeUnlocker([true, true, true, true]);
    final reader = _FakeStatusReader(<bool>[true]);
    await tester.pumpWidget(_app(unlocker: unlocker, reader: reader));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await _unlock(tester);

    for (final state in _relockingStates) {
      final callsBeforeBackground = unlocker.callCount;
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      if (state == AppLifecycleState.inactive) _expectRelockedState(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      _expectLocked();
      expect(unlocker.callCount, callsBeforeBackground);

      await _unlock(tester);
      expect(unlocker.callCount, callsBeforeBackground + 1);
    }

    expect(
      reader.readCount,
      1,
      reason: 'warm engine keeps one safe status view',
    );
  });

  testWidgets('Arabic surface is RTL and keeps stable semantics identifiers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(unlocker: _FakeUnlocker([true]), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(InternalDevToolUnlockGate));
    expect(Directionality.of(element), TextDirection.rtl);
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.unlock),
      findsOne,
    );
  });
}

const _statusIdentifiers = <String>[
  InternalDevToolSemantics.runtime,
  InternalDevToolSemantics.gateway,
  InternalDevToolSemantics.realtime,
  InternalDevToolSemantics.build,
  InternalDevToolSemantics.clarity,
  InternalDevToolSemantics.authentication,
  InternalDevToolSemantics.connectivity,
];

Widget _app({
  required _FakeUnlocker unlocker,
  _FakeStatusReader? reader,
  _FakeClearer? clearer,
  _FakeCloser? closer,
  Locale? locale,
}) => InternalDevToolApp(
  unlocker: unlocker,
  statusReader: reader ?? _FakeStatusReader(<bool>[true]),
  localDataClearer: clearer ?? _FakeClearer(),
  closer: closer ?? _FakeCloser(),
  locale: locale,
  localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
);

const _relockingStates = <AppLifecycleState>[
  AppLifecycleState.inactive,
  AppLifecycleState.paused,
  AppLifecycleState.detached,
];

Future<void> _unlock(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier(InternalDevToolSemantics.unlock));
  await tester.pumpAndSettle();
  expect(find.bySemanticsIdentifier(InternalDevToolSemantics.root), findsOne);
}

void _expectLocked() {
  expect(
    find.bySemanticsIdentifier(InternalDevToolSemantics.authGate),
    findsOne,
  );
  expect(
    find.bySemanticsIdentifier(InternalDevToolSemantics.root),
    findsNothing,
  );
}

void _expectRelockedState(WidgetTester tester) {
  final stack = tester.widget<IndexedStack>(
    find.descendant(
      of: find.byType(InternalDevToolUnlockGate),
      matching: find.byType(IndexedStack),
    ),
  );
  expect(stack.index, 0);
}

final class _FakeUnlocker implements InternalDeviceUnlocker {
  _FakeUnlocker(this._results);

  final List<bool> _results;
  int callCount = 0;

  @override
  Future<bool> unlock({required String reason}) async {
    final result = _results[callCount];
    callCount++;
    return result;
  }
}

final class _FakeStatusReader implements InternalDevToolStatusReader {
  _FakeStatusReader(this._networkStates);

  final List<bool> _networkStates;
  int readCount = 0;

  @override
  Future<InternalDevToolStatus> read() async {
    final networkAvailable = _networkStates[readCount];
    readCount++;
    return InternalDevToolStatus(
      versionName: '1.0.0',
      buildNumber: '26082601',
      networkAvailable: networkAvailable,
    );
  }
}

final class _FakeClearer implements InternalLocalDataClearer {
  _FakeClearer({this.throws = false});

  final bool throws;
  int callCount = 0;

  @override
  Future<void> clear() async {
    callCount++;
    if (throws) throw StateError('clear failed');
  }
}

final class _FakeCloser implements InternalDevToolCloser {
  int callCount = 0;

  @override
  Future<void> close() async {
    callCount++;
  }
}
