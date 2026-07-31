// Owner ruling, 2026-07-31 (`docs/execution/OWNER-DECISIONS.md`, "DEVICE-E2E
// rulings", item 2): the Dev Tool must offer `http://192.168.2.39:10090` as a
// preset.
//
// Why this is a test and not a code comment: the ruling exists because a WRONG
// base URL is SILENT. A stale `http://127.0.0.1:9000` left over from a dead
// `adb reverse` tunnel broke every backend call and presented as product bugs —
// empty profiles, empty lists, `[push][register] FAILED` — and cost an entire
// device window before anyone suspected the URL. Nothing in the app says "your
// backend is unreachable"; it just returns nothing. A preset that quietly gets
// dropped in a future refactor would reopen exactly that window, so the ruling
// is pinned mechanically.
//
// NON-CLAIM: this is `suite` evidence about a LIST. It does not prove MSI is
// reachable, does not open a socket, and does not prove the chip renders — the
// page needs the DI graph (`sl<SharedPreferences>()`) to build, which is a
// device/integration concern. What it pins is that the value the page renders
// its chips from still contains MSI, still leads with it, and is still
// origin-only.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/dev_settings_page.dart';

void main() {
  group('Dev Tool server-URL presets (owner ruling 2026-07-31)', () {
    test('MSI 192.168.2.39:10090 is present', () {
      expect(kDevServerUrlPresets, contains(kMsiGatewayBaseUrl));
      expect(kMsiGatewayBaseUrl, 'http://192.168.2.39:10090');
    });

    test('MSI is FIRST — the leftmost chip, the one a tired operator taps', () {
      expect(kDevServerUrlPresets.first, kMsiGatewayBaseUrl);
    });

    test('the MSI preset is ORIGIN-ONLY: no /v1, no trailing slash', () {
      // ARCH-01 / INFRA-01. Dio merges `baseUrl + path` and every request path
      // already carries exactly one `/v1`, so a `/v1` here doubles to `/v1/v1`
      // — the S16 availability NO-GO. `api.jeeb.app/v1` in the list below is
      // the pre-existing, out-of-scope preset and is deliberately not "fixed"
      // here; MB1 does not own it and it is NXDOMAIN anyway.
      expect(kMsiGatewayBaseUrl.endsWith('/'), isFalse);
      expect(kMsiGatewayBaseUrl.contains('/v1'), isFalse);
      expect(Uri.parse(kMsiGatewayBaseUrl).path, isEmpty);
    });

    test('NEG CONTROL: the banned .50 host appears in NO preset', () {
      // Standing owner rule. MSI 192.168.2.39 is the only server; a preset is
      // exactly the kind of place a dead host survives for months.
      for (final preset in kDevServerUrlPresets) {
        expect(preset.contains('192.168.2.50'), isFalse,
            reason: '$preset names the banned .50 host');
      }
      // POS CONTROL for the check itself: the matcher above must be able to
      // fire, or "no .50" is indistinguishable from "the loop ran zero times".
      expect(kDevServerUrlPresets, isNotEmpty);
      expect('http://192.168.2.50:1/'.contains('192.168.2.50'), isTrue);
    });

    test('the pre-existing presets are still offered — this is ADDITIVE', () {
      // A "fix" that silently removed the emulator-loopback mock preset would
      // break every emulator lane that depends on `:4010`.
      expect(kDevServerUrlPresets, contains('http://10.0.2.2:4010'));
      expect(kDevServerUrlPresets, hasLength(3));
    });
  });
}
