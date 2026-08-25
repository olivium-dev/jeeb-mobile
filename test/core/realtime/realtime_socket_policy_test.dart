import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/realtime/realtime_socket_policy.dart';

void main() {
  const canonical = 'wss://realtime.example:443/socket/websocket';

  test('production fails closed when compile-time socket URL is absent', () {
    expect(
      const RealtimeSocketPolicy(configuredUrl: '').configuredUri(),
      isNull,
    );
  });

  final rejectedProductionUrls = <String>[
    'ws://realtime.example/socket/websocket',
    'https://realtime.example/socket/websocket',
    'wss://realtime.example/socket',
    'wss://realtime.example/socket/websocket/',
    'wss://user@realtime.example/socket/websocket',
    'wss://realtime.example/socket/websocket?token=x',
    'wss://realtime.example/socket/websocket#fragment',
  ];
  for (final value in rejectedProductionUrls) {
    test('production rejects malformed socket URL $value', () {
      expect(
        RealtimeSocketPolicy(configuredUrl: value).configuredUri(),
        isNull,
      );
    });
  }

  test('production normalizes scheme host port and exact path', () {
    const policy = RealtimeSocketPolicy(configuredUrl: canonical);

    expect(
      policy.descriptorUri('wss://REALTIME.EXAMPLE:443/socket/websocket'),
      Uri.parse(canonical),
    );
  });

  final mismatches = <String>[
    'wss://attacker.example/socket/websocket',
    'wss://realtime.example:444/socket/websocket',
    'wss://realtime.example/socket/other',
    'ws://realtime.example/socket/websocket',
  ];
  for (final value in mismatches) {
    test('descriptor cannot override configured authority with $value', () {
      expect(
        const RealtimeSocketPolicy(
          configuredUrl: canonical,
        ).descriptorUri(value),
        isNull,
      );
    });
  }

  test('cleartext socket is accepted only in explicit development', () {
    const policy = RealtimeSocketPolicy(
      configuredUrl: 'ws://127.0.0.1:5804/socket/websocket',
      isDevelopment: true,
    );

    expect(policy.configuredUri(), isNotNull);
  });
}
