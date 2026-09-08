import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/env_index/env_index_client.dart';
import 'package:jeeb_mobile/devtool/env_index/published_environments_section.dart';

const _staging = EnvIndexEntry(
  id: 'staging',
  label: 'Staging',
  gatewayBaseUrl: 'https://app.jeeb.fds-1.com',
  reachability: 'public',
  cleartext: false,
);

const _msi = EnvIndexEntry(
  id: 'dev-msi-lan',
  label: 'MSI dev (LAN)',
  gatewayBaseUrl: 'http://192.168.2.39:10090',
  reachability: 'lan',
  cleartext: true,
  notes: 'dev flavor only',
);

Widget _host({
  required Future<List<EnvIndexEntry>> Function() fetcher,
  required ValueChanged<String> onPick,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: PublishedEnvironmentsSection(onPick: onPick, fetcher: fetcher),
    ),
  ),
);

void main() {
  testWidgets('lists environments and reports the picked base URL', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      _host(fetcher: () async => [_staging, _msi], onPick: (url) => picked = url),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staging'), findsOneWidget);
    expect(find.text('MSI dev (LAN)'), findsOneWidget);
    // LAN + cleartext entry carries the warning marker.
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);

    await tester.tap(find.text('Staging'));
    expect(picked, 'https://app.jeeb.fds-1.com');
  });

  testWidgets('shows the error and recovers via the refresh button', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        fetcher: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return [_staging];
        },
        onPick: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Staging'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('renders the empty-index message', (tester) async {
    await tester.pumpWidget(
      _host(fetcher: () async => const [], onPick: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('The environment index is empty.'), findsOneWidget);
  });
}
