import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/dev_flags.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

import 'mb1_source_lens.dart';

/// MB1 member item **W1.4** — the corrected device build line.
///
/// ```
/// flutter build apk --debug --flavor dev \
///   --dart-define=JEEB_MOCK_BASE_URL=http://127.0.0.1:9000 \
///   --dart-define=JEEB_DEVTOOL_ENABLED=true \
///   --dart-define=JEEB_BUILD_SHA=<sha>
/// ```
///
/// ## What can actually go wrong here, and what a build exit code cannot catch
///
/// `flutter build apk` exits 0 for **any** `--dart-define`. A misspelled key, a
/// key nothing reads, a key that was renamed three PRs ago — all build clean
/// and all produce an APK that silently ignores the operator's intent. Attempt
/// 1's device window was lost to exactly this shape at the other end of the
/// same wire: a stale `http://127.0.0.1:9000` from a dead `adb reverse` tunnel
/// broke every backend call and presented as product bugs.
///
/// So a green `flutter build` is **not** the W1.4 receipt. The receipt is that
/// every key on the line has a LIVE consumer in `lib/`, and that the one key
/// the line deliberately omits is genuinely inert.
///
/// ## The omission that needs justifying
///
/// The writer's build line omits `GATEWAY_BASE_URL` on the stated ground that
/// it "has zero non-test consumers". That is a checkable claim and it is
/// checked below — because if it were false, the APK under gate would be
/// pointing at `AppConfig.gatewayBaseUrl`'s default of `https://api.jeeb.app`,
/// a **non-MSI public host**, which the owner's scope exclusion 3 forbids
/// outright. This row is the one place that risk is measured rather than
/// assumed.
///
/// Class: `build`/`static`.

/// Repo-relative Dart sources under `lib/`, comment-stripped, keyed by path.
/// For SYMBOL receipts only — see [_libRaw] for anything about a URL.
Map<String, String> _libSources() => <String, String>{
  for (final f in MB1Source.dartFilesUnder(<String>['lib']))
    MB1Source.rel(f): MB1Source.stripComments(f.readAsStringSync()),
};

/// The same files, RAW.
///
/// The `.50` ban MUST use this. `stripComments` treats `//` as a line comment,
/// so `'http://192.168.2.50:10090'` strips down to `'http:` and the banned host
/// disappears from the text being searched. The first draft of the HARD RULE
/// case below ran on stripped source and stayed GREEN with the banned host
/// hardcoded in `lib/core/dev_flags.dart` — a confidently wrong PASS on the
/// single most-repeated owner directive in this programme. The negative control
/// is the only reason it was found.
Map<String, String> _libRaw() => <String, String>{
  for (final f in MB1Source.dartFilesUnder(<String>['lib']))
    MB1Source.rel(f): f.readAsStringSync(),
};

/// Files declaring `String/bool.fromEnvironment('<key>')`.
List<String> _declarers(Map<String, String> lib, String key) => <String>[
  for (final e in lib.entries)
    if (RegExp("fromEnvironment\\(\\s*'$key'").hasMatch(e.value)) e.key,
];

/// Files that READ [symbol] somewhere other than its own declaration line.
List<String> _readers(Map<String, String> lib, String symbol, String declFile) =>
    <String>[
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
      reason: 'population sanity — a tiny map makes every "0 readers" result '
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
      // suite's own (undefined) build, so the define is wired to a real getter
      // and not to dead code.
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
      // capture header and matches it to the merged SHA", and
      // `tools/apk-identity.sh` is the instrument. If this define stops
      // reaching the header, every device round in the programme becomes
      // unattributable — which `DEVICE-BUILD.md` §3 records as the state of all
      // 54 historical captures.
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

  group('MB1 W1.4 — the omitted define is genuinely inert', () {
    test('GATEWAY_BASE_URL has ZERO readers in lib/ outside its declaration',
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
        isEmpty,
        reason:
            'THIS is why the build line may omit it. If a reader ever appears, '
            'a build without --dart-define=GATEWAY_BASE_URL silently talks to '
            'the https://api.jeeb.app DEFAULT — a public, non-MSI host, banned '
            'by owner scope exclusion 3. Adding the reader is not the bug; '
            'adding it WITHOUT adding the define to the build line is.',
      );
    });

    test('POSITIVE CONTROL — the reader-counter is not blind', () {
      // Same instrument, a symbol that IS read across the tree. Without this,
      // the isEmpty above is indistinguishable from a broken matcher.
      expect(
        _readers(lib, 'MockGatewayClient.mockBaseUrl',
            'lib/core/network/mock_gateway_client.dart'),
        isNotEmpty,
        reason: 'the devtool page reads it; a zero here means the counter is '
            'measuring nothing',
      );
      expect(
        _readers(lib, 'AppConfigXyzzyNotReal.nope', 'nowhere.dart'),
        isEmpty,
      );
    });

    test('HARD RULE — no lib/ source hardcodes the banned .50 host', () {
      // Owner directive, repeated and escalating. A build line is the surface
      // that decides which host an APK dials, so this row belongs to W1.4.
      //
      // RAW, not stripped. See [_libRaw] — this exact assertion was blind on
      // stripped source.
      final raw = _libRaw();
      final offenders = <String>[
        for (final e in raw.entries)
          if (e.value.contains('192.168.2.50')) e.key,
      ];
      expect(offenders, isEmpty, reason: 'MSI 192.168.2.39 is the only server');

      // POSITIVE CONTROL, and it is the control that matters: the SAME lens,
      // over the same corpus, DOES find the MSI host. A ban assertion whose
      // corpus contains no host strings at all is indistinguishable from a
      // working one.
      final msi = <String>[
        for (final e in raw.entries)
          if (e.value.contains('192.168.2.39')) e.key,
      ];
      expect(
        msi,
        isNotEmpty,
        reason:
            'the lens must be able to see a host literal in lib/ at all — '
            'the DevTool MSI preset is one. A zero here would mean the '
            'isEmpty above measured nothing.',
      );

      // And the stripped lens is demonstrably NOT usable for this: same
      // string, opposite answer.
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
      // COMPILES, nothing more." Recorded as an assertion so the pack cannot
      // be read as having exercised an APK.
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
