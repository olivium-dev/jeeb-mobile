import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/internal_release_policy.dart';
import 'package:jeeb_mobile/internal_devtool/internal_devtool_app.dart';
import 'package:jeeb_mobile/internal_devtool/internal_devtool_semantics.dart';
import 'package:jeeb_mobile/internal_devtool/internal_devtool_services.dart';

import '../support/sync_app_localizations.dart';

void main() {
  testWidgets('opens the restricted status surface without authentication', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('internal_devtool_unlock'), findsNothing);
    expect(
      find.bySemanticsIdentifier('internal_devtool_auth_gate'),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier('internal_devtool_launcher'),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier(InternalDevToolSemantics.close),
      findsOne,
    );
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
    await tester.pumpWidget(_app(reader: reader));
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

  testWidgets('clear requires confirmation but no device unlock', (
    tester,
  ) async {
    final clearer = _FakeClearer();
    final closer = _FakeCloser();
    await tester.pumpWidget(_app(clearer: clearer, closer: closer));
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

    expect(clearer.callCount, 1);
    expect(closer.callCount, 1);
    expect(
      find.bySemanticsIdentifier('internal_devtool_auth_gate'),
      findsNothing,
    );
  });

  testWidgets('clear failure still closes the tool', (tester) async {
    final clearer = _FakeClearer(throws: true);
    final closer = _FakeCloser();
    await tester.pumpWidget(_app(clearer: clearer, closer: closer));
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

    expect(clearer.callCount, 1);
    expect(closer.callCount, 1);
    expect(find.bySemanticsIdentifier(InternalDevToolSemantics.root), findsOne);
  });

  testWidgets('warm launcher remains free of authentication lifecycle gates', (
    tester,
  ) async {
    final reader = _FakeStatusReader(<bool>[true]);
    await tester.pumpWidget(_app(reader: reader));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    for (final state in _relockingStates) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.bySemanticsIdentifier(InternalDevToolSemantics.root),
        findsOne,
      );
      expect(
        find.bySemanticsIdentifier('internal_devtool_auth_gate'),
        findsNothing,
      );
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
    await tester.pumpWidget(_app(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(InternalDevToolScreen));
    expect(Directionality.of(element), TextDirection.rtl);
    expect(find.bySemanticsIdentifier('internal_devtool_unlock'), findsNothing);
    expect(find.bySemanticsIdentifier(InternalDevToolSemantics.root), findsOne);
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
  _FakeStatusReader? reader,
  _FakeClearer? clearer,
  _FakeCloser? closer,
  Locale? locale,
}) => InternalDevToolApp(
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
