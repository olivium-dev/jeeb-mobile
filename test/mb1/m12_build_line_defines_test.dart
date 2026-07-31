// MB1 ITEM M12 — W1.4, THE BUILD LINE'S DEFINES.
//
// Added by the MB1 TEST AUTHOR. W1.4 ("build on the corrected define line") is
// a member item and the pack had no item that could red for it. The build
// itself is `build` class and takes minutes for a 175 MB APK, so this item does
// not rebuild — it asserts the thing a rebuild would NOT catch: whether each
// `--dart-define` on that line is CONNECTED TO ANYTHING, and whether the one
// deliberately left OFF is safe to leave off.
//
// The line as exercised:
//
//   flutter build apk --debug --flavor dev \
//     --dart-define=JEEB_MOCK_BASE_URL=http://127.0.0.1:9000 \
//     --dart-define=JEEB_DEVTOOL_ENABLED=true \
//     --dart-define=JEEB_BUILD_SHA=<merged sha>
//
// -------------------------------------------------------------------------
// WHY THIS IS NOT PAPERWORK
// -------------------------------------------------------------------------
// `--dart-define` NEVER FAILS. A misspelled key, a key nothing reads, a key
// whose reader was deleted — all build cleanly, exit 0, and produce an APK. The
// value simply is not there at runtime, and `String.fromEnvironment` hands back
// the default instead. So "the build line compiles" (which is the entire W1.4
// receipt in the writer's report) is compatible with every define on it being
// inert.
//
// The owner ruling of 2026-07-31 #2 is a first-hand account of what that costs:
// a wrong base URL is SILENT, it presented as product bugs — empty profiles,
// empty lists, `[push][register] FAILED` — and it burned an entire device
// window before anyone suspected the URL. Two of the three defines on this line
// are load-bearing for the R1 round specifically: `JEEB_BUILD_SHA` is what V-1
// reads off the capture header to attribute the capture to the merged SHA, and
// `JEEB_MOCK_BASE_URL` is the `adb reverse` hop into the api-recorder, without
// which every capture-class row in the batch measures nothing.
//
// -------------------------------------------------------------------------
// THE OMITTED DEFINE, AND WHY ITS ABSENCE IS AN ASSERTION
// -------------------------------------------------------------------------
// The writer's report justifies leaving `GATEWAY_BASE_URL` off the line with
// "it has zero non-test consumers". Re-derived first-hand at this commit, that
// is TRUE — and it is true in a way that is one edit away from being false:
//
//   AppConfig.gatewayBaseUrl = String.fromEnvironment('GATEWAY_BASE_URL',
//                                defaultValue: 'https://api.jeeb.app')
//
//   readers under lib/  : 0   (one doc-comment mention, no code)
//   readers under test/ : 1   (base_url_convention_test.dart)
//   the DI chain instead: injection_container.dart:198 ->
//                         MockGatewayClient.createDio(baseUrl:
//                           DevBaseUrl.read(prefs))       -> :233
//                         effectiveBaseUrl = baseUrl ?? mockBaseUrl
//                         mockBaseUrl = fromEnvironment('JEEB_MOCK_BASE_URL')
//
// So the moment ANY production code reads `AppConfig.gatewayBaseUrl`, a build
// on this line points that code at `https://api.jeeb.app` — a public URL, which
// owner exclusion 3 puts out of scope, and which is NXDOMAIN besides. M12.b is
// that tripwire: it fails the day the omission stops being safe, which is the
// only day anyone needs to know.
//
// (Noted and moved past, per GATE.md §9: the repo carries an agent-memory note
// asserting the app "silently talks to prod" without this define. On THIS tree
// that is stale — nothing under lib/ reads the constant. Not a security finding
// and not gated on; recorded because a verifier who greps that memory will
// otherwise think M12.b contradicts it.)
//
// NON-CLAIM (GATE.md §3): `static` + `suite`. This proves the defines are wired
// to readers and that the omitted one is unread. It does NOT prove an APK was
// built, does not prove one was installed, and does not prove any host was
// reachable. W1.4's build receipt and R1 remain `build`/`device` class.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/config/app_config.dart';
import 'package:jeeb_mobile/core/dev_flags.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_file_sink.dart';

import 'mb1_pack_support.dart';

/// Every `--dart-define` key on MB1's W1.4 build line, with the site that reads
/// it. Counted first-hand at this commit with
/// `git grep -n fromEnvironment -- lib/`.
const Map<String, String> _defines = <String, String>{
  'JEEB_MOCK_BASE_URL': 'lib/core/network/mock_gateway_client.dart',
  'JEEB_DEVTOOL_ENABLED': 'lib/core/dev_flags.dart',
  'JEEB_BUILD_SHA': 'lib/core/diagnostics/diag_file_sink.dart',
};

void main() {
  group('M12.a — every define on the W1.4 line HAS A READER', () {
    _defines.forEach((key, site) {
      test('$key is read in lib/ (named site: $site)', () {
        final hits = nonCommentMatches("'$key'", paths: const <String>['lib/']);
        expect(hits, isNot(-1),
            reason: 'COULD NOT RUN (GATE.md §6.3 L3 — unverifiable is '
                'rejected, not passed)');
        expect(hits, greaterThanOrEqualTo(1),
            reason: 'nothing in lib/ reads $key, so passing it on the build '
                'line is a no-op that exits 0. `--dart-define` never fails: a '
                'key nothing reads and a key spelled correctly produce the '
                'same successful build and the same missing value at runtime.');

        // And it is read at the site this pack names, so a reader moving is
        // visible rather than silently absorbed by some other file.
        expect(occurrencesInFile("'$key'", site), isNotEmpty,
            reason: '$key is read somewhere in lib/, but no longer at $site. '
                'Update this pack deliberately — do not let the citation rot.');
      });
    });

    test('NEG CONTROL: a define nobody passes has ZERO readers', () {
      // Without this, M12.a is satisfied by a matcher that returns a positive
      // count for any string at all.
      expect(
        nonCommentMatches("'JEEB_NOT_A_REAL_DEFINE'",
            paths: const <String>['lib/']),
        0,
        reason: 'the matcher reports readers for a define that does not '
            'exist, so its positive answers above prove nothing',
      );
    });

    test('the two R1-critical defines are readable AS VALUES from this '
        'process, not just as source text', () {
      // `static` evidence can be defeated by a reader that exists but is
      // unreachable. These two are compile-time constants, so the test VM can
      // read the same values the APK would.
      //
      // Under a plain `flutter test` no define is set, so the assertion is
      // about the DEFAULT — which is the honest half. The pack runner's M6b
      // pass re-runs the diag file under `--dart-define=JEEB_BUILD_SHA=<sha>`
      // and requires the header to carry it; that is the other half.
      expect(DiagFileSink.buildSha, isEmpty,
          reason: 'with no --dart-define, buildSha must default to EMPTY so '
              'the capture header OMITS the key. A non-empty default would '
              'stamp every capture with a SHA that is not the build\'s — worse '
              'than none, because it looks like an answer.');
      expect(kDevToolEnabled, isFalse,
          reason: 'JEEB_DEVTOOL_ENABLED must default to false, or the Dev Tool '
              'ships in a production binary');
    });
  });

  group('M12.b — GATEWAY_BASE_URL is omitted, and the omission is SAFE ONLY '
      'while nothing reads it', () {
    test('AppConfig.gatewayBaseUrl has ZERO readers under lib/', () {
      // THE TRIPWIRE. The writer left this define off the build line and
      // justified it with "zero non-test consumers". That is true today. The
      // day it stops being true, a build on this line points production code
      // at the default below.
      final inLib = nonCommentMatches('AppConfig.gatewayBaseUrl',
          paths: const <String>['lib/']);
      expect(inLib, isNot(-1), reason: 'COULD NOT RUN (GATE.md §6.3 L3)');
      expect(inLib, 0,
          reason: 'production code now reads AppConfig.gatewayBaseUrl, and '
              'MB1\'s W1.4 build line does NOT pass GATEWAY_BASE_URL. That '
              'code therefore runs against the compiled-in default — a public '
              'URL, out of scope under owner exclusion 3 and NXDOMAIN besides '
              '— while every other request goes to JEEB_MOCK_BASE_URL. Either '
              'add the define to the build line or remove the reader; do not '
              'relax this test.');

      // POS CONTROL for the matcher: it CAN find this symbol. The convention
      // test under test/ reads it, so a zero above is a scoped absence and not
      // a typo in the needle.
      final inTest = nonCommentMatches('AppConfig.gatewayBaseUrl',
          paths: const <String>['test/']);
      expect(inTest, greaterThan(0),
          reason: 'POS CONTROL FAILED: the matcher finds no reader of '
              'AppConfig.gatewayBaseUrl anywhere, including the convention '
              'test that certainly reads it, so its zero for lib/ is '
              'meaningless');
    });

    test('the compiled-in default IS the out-of-scope public URL — this is '
        'what the omission would expose', () {
      // Asserted as a VALUE, in-process, so the stake is a fact rather than a
      // story told in a comment. Under `flutter test` no GATEWAY_BASE_URL
      // define is set, which is exactly the W1.4 build line's condition.
      expect(AppConfig.gatewayBaseUrl, 'https://api.jeeb.app');
      expect(AppConfig.gatewayBaseUrl.startsWith('https://api.'), isTrue);
    });

    test('the base URL the app ACTUALLY uses comes from JEEB_MOCK_BASE_URL, '
        'through DevBaseUrl', () {
      // The chain that makes JEEB_MOCK_BASE_URL the define that matters:
      //   injection_container.dart -> MockGatewayClient.createDio(
      //                                 baseUrl: DevBaseUrl.read(prefs))
      //   mock_gateway_client.dart -> effectiveBaseUrl = baseUrl ?? mockBaseUrl
      // Asserted so "GATEWAY_BASE_URL is inert" is a demonstrated route, not an
      // absence of evidence.
      final di = stripDartComments(readSource('lib/core/di/injection_container.dart'));
      expect(di, contains('MockGatewayClient.createDio('),
          reason: 'the app Dio is no longer built by MockGatewayClient, so '
              'this pack\'s account of which define reaches the wire is stale');
      expect(di, contains('DevBaseUrl.read('),
          reason: 'the Dev Tool override is the FIRST source of the base URL; '
              'losing it re-opens the hand-typed-URL failure the owner ruling '
              'of 2026-07-31 #2 exists to end');

      final mock = stripDartComments(
          readSource('lib/core/network/mock_gateway_client.dart'));
      expect(mock, contains('baseUrl ?? mockBaseUrl'),
          reason: 'the fallback from "no Dev Tool override" to '
              'JEEB_MOCK_BASE_URL is what makes that define load-bearing for '
              'the R1 recorder hop');
      expect(di.contains('AppConfig.gatewayBaseUrl'), isFalse,
          reason: 'the DI graph reads the define MB1 does NOT pass');
    });
  });
}
