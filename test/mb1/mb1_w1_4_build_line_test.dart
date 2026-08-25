import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/config/app_config.dart';
import 'package:jeeb_mobile/core/dev_flags.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

import 'mb1_source_lens.dart';

/// W1.4 — verify build line has live consumers and omissions are inert.

Map<String, String> _libSources() => <String, String>{
  for (final f in MB1Source.dartFilesUnder(<String>['lib']))
    MB1Source.rel(f): MB1Source.stripComments(f.readAsStringSync()),
};

Map<String, String> _libRaw() => <String, String>{
  for (final f in MB1Source.dartFilesUnder(<String>['lib']))
    MB1Source.rel(f): f.readAsStringSync(),
};

List<String> _declarers(Map<String, String> lib, String key) => <String>[
  for (final e in lib.entries)
    if (RegExp("fromEnvironment\\(\\s*'$key'").hasMatch(e.value)) e.key,
];

List<String> _readers(
  Map<String, String> lib,
  String symbol,
  String declFile,
) => <String>[
  for (final e in lib.entries)
    if (e.key != declFile && e.value.contains(symbol)) e.key,
];

void main() {
  late Map<String, String> lib;

  setUpAll(() {
    lib = _libSources();
    expect(
      lib.length,
      greaterThan(200),
      reason:
          'population sanity — a tiny map makes every "0 readers" result '
          'a measurement of the walker, not of the tree',
    );
  });

  group('MB1 W1.4 — every define on the build line has a LIVE consumer', () {
    test('JEEB_MOCK_BASE_URL is read by MockGatewayClient', () {
      expect(
        _declarers(lib, 'JEEB_MOCK_BASE_URL'),
        contains('lib/core/network/mock_gateway_client.dart'),
      );
      // Runtime half: the constant resolves to a usable origin under the
      expect(Uri.parse(MockGatewayClient.mockBaseUrl).hasScheme, isTrue);
    });

    test('JEEB_DEVTOOL_ENABLED is read by DevFlags', () {
      expect(
        _declarers(lib, 'JEEB_DEVTOOL_ENABLED'),
        contains('lib/core/dev_flags.dart'),
      );
      expect(
        kDevToolEnabled,
        isFalse,
        reason:
            'the suite runs with no dart-define, so the default must be OFF. '
            'A `true` here would mean the dev tool ships in a build that '
            'never asked for it.',
      );
      expect(
        _readers(lib, 'kDevToolEnabled', 'lib/core/dev_flags.dart'),
        isNotEmpty,
        reason: 'a flag nothing reads is a flag that does nothing',
      );
    });

    test('JEEB_BUILD_SHA is read, and reaches the capture HEADER', () {
      // Load-bearing for the gate itself: V-1 "reads buildSha off the on-device
      final declarers = _declarers(lib, 'JEEB_BUILD_SHA');
      expect(
        declarers,
        contains('lib/core/diagnostics/diag_file_sink.dart'),
        reason: 'the diag session header is what apk-identity.sh reads',
      );
      expect(declarers.length, greaterThanOrEqualTo(2));
      expect(
        MB1Source.strippedLib('lib/core/diagnostics/diag_file_sink.dart'),
        contains('buildSha'),
      );
    });
  });

  group('MB1 W1.4 — the production gateway fallback is explicit and safe', () {
    test(
      'GATEWAY_BASE_URL has one declaration and a live transport reader',
      () {
        const declFile = 'lib/core/config/app_config.dart';
        expect(
          _declarers(lib, 'GATEWAY_BASE_URL'),
          <String>[declFile],
          reason: 'the define is declared exactly once',
        );
        final readers = _readers(lib, 'AppConfig.gatewayBaseUrl', declFile);
        expect(
          readers,
          contains('lib/core/network/mock_gateway_client.dart'),
          reason:
              'release transport must consume the canonical gateway origin '
              'instead of falling back to a committed LAN endpoint',
        );
        final defaultGateway = Uri.parse(AppConfig.gatewayBaseUrl);
        expect(defaultGateway.hasScheme, isFalse);
        expect(
          AppConfig.gatewayBaseUrl,
          isEmpty,
          reason: 'production must fail closed without an explicit gateway',
        );
      },
    );

    test('POSITIVE CONTROL — the reader-counter is not blind', () {
      // Same instrument, a symbol that IS read across the tree. Without this,
      expect(
        _readers(
          lib,
          'MockGatewayClient.mockBaseUrl',
          'lib/core/network/mock_gateway_client.dart',
        ),
        isNotEmpty,
        reason:
            'the devtool page reads it; a zero here means the counter is '
            'measuring nothing',
      );
      expect(
        _readers(lib, 'AppConfigXyzzyNotReal.nope', 'nowhere.dart'),
        isEmpty,
      );
    });

    test('HARD RULE — no lib/ source hardcodes a banned or LAN host', () {
      // Owner directive, repeated and escalating. A build line is the surface
      final raw = _libRaw();
      final offenders = <String>[
        for (final e in raw.entries)
          if (e.value.contains('192.168.2.50')) e.key,
      ];
      expect(offenders, isEmpty, reason: 'MSI 192.168.2.39 is the only server');

      final lan = <String>[
        for (final e in raw.entries)
          if (e.value.contains('192.168.2.39')) e.key,
      ];
      expect(
        lan,
        isEmpty,
        reason:
            'production Dart source must not contain a committed LAN fallback; '
            'development may inject one through its explicit build define',
      );

      final stalePublicOrigin = <String>[
        for (final e in raw.entries)
          if (e.value.contains('api.jeeb.app')) e.key,
      ];
      expect(
        stalePublicOrigin,
        isEmpty,
        reason: 'the unresolved legacy public hostname must not ship',
      );

      // Positive control: the SAME raw lens sees reserved non-routable defaults.
      final reservedOrigin = <String>[
        for (final e in raw.entries)
          if (e.value.contains('gateway.dev.invalid')) e.key,
      ];
      expect(
        reservedOrigin,
        isNotEmpty,
        reason:
            'the lens must be able to see a host literal in lib/ at all. '
            'A zero here would mean the '
            'isEmpty above measured nothing.',
      );

      // And the stripped lens is demonstrably NOT usable for this: same
      const url = "const String h = 'http://192.168.2.50:10090';";
      expect(url.contains('192.168.2.50'), isTrue);
      expect(
        MB1Source.stripComments(url).contains('192.168.2.50'),
        isFalse,
        reason:
            'demonstrated, not asserted: comment-stripping destroys the host. '
            'If this ever becomes true, stripComments learned about string '
            'literals and the RAW/stripped split above can be revisited.',
      );
    });
  });

  group('the non-claim, stated explicitly', () {
    test('a green build proves COMPILATION, not installation or behaviour', () {
      // `MB1.md`: "The writer did NOT install it … This row proves the line
      expect(
        kDevToolEnabled,
        isFalse,
        reason:
            'if this were true the suite would be running under the device '
            'build line, which it is not and cannot be',
      );
    });
  });
}
