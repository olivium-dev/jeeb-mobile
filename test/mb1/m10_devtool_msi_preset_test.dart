// MB1 ITEM M10 — the owner ruling of 2026-07-31, DEVICE-E2E #2.
//
//   "Dev Tool: ADD http://192.168.2.39:10090 AS A PRESET AND MAKE IT THE DEV
//    DEFAULT. Neither shipped preset is MSI ... so the correct URL must be
//    hand-typed every session. A stale http://127.0.0.1:9000 -- left over from
//    a dead adb reverse tunnel -- SILENTLY BROKE EVERY BACKEND CALL and cost an
//    entire device window, presenting as product bugs (empty profiles, empty
//    lists, [push][register] FAILED). Fold this into the relevant mobile/
//    DevTool batch."
//
// `OWNER-DECISIONS.md` is BINDING and wins over any batch document, so this is
// a member item of MB1 whether or not MB1's member list names it. It landed as
// commit d0cbd72 and the pack had no item for it.
//
// -------------------------------------------------------------------------
// WHY THIS IS A DIFFERENT INSTRUMENT FROM THE ONE THAT SHIPPED WITH IT
// -------------------------------------------------------------------------
// `test/devtool/dev_server_url_presets_test.dart` (written by the writer, in
// the same commit) asserts things about the CONSTANT `kDevServerUrlPresets`:
// that MSI is in it, that MSI is first, that it is origin-only, that the list
// has 3 entries. Every one of those assertions is true of a constant NOBODY
// READS.
//
// Measured at `kPreFixBase`, the page built its chips from an INLINE literal:
//
//     for (final preset in const [
//       'http://10.0.2.2:4010',
//       'https://api.jeeb.app/v1',
//     ])
//
// Reverting that one `for` line to the inline form leaves `kDevServerUrlPresets`
// declared, exported, MSI-first, origin-only and three entries long — the
// writer's whole file stays GREEN — while the operator opens Server URL and
// sees no MSI chip. That is the exact self-fulfilling shape this programme has
// shipped before (a 473-test green with the feature switched off), and it is
// the shape the OWNER'S OWN RULING is about: a wrong base URL is SILENT.
//
// So M10 asserts the RENDERED SURFACE. It builds the real `ServerUrlPage`,
// finds the chip by its visible label, taps it, and requires the text field to
// end up holding the MSI origin. A constant that nothing reads cannot pass it.
//
// NON-CLAIM (GATE.md §3): `suite`. Tapping a chip in a widget tree is not
// reaching MSI. Nothing here opens a socket, resolves a host, or proves
// 192.168.2.39:10090 answers — that is `service`/`device` class and belongs to
// R1. What this proves is that the operator is OFFERED the value, which is the
// entire content of the ruling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/devtool/dev_settings_page.dart';

import 'mb1_pack_support.dart';

const String _page = 'lib/devtool/dev_settings_page.dart';
const String _msi = 'http://192.168.2.39:10090';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    if (sl.isRegistered<SharedPreferences>()) {
      await sl.unregister<SharedPreferences>();
    }
    sl.registerSingleton<SharedPreferences>(prefs);
  });

  tearDown(() async {
    if (sl.isRegistered<SharedPreferences>()) {
      await sl.unregister<SharedPreferences>();
    }
  });

  group('M10.a — the RENDERED page offers MSI (a constant nobody reads fails)',
      () {
    testWidgets('the MSI chip is on screen, and tapping it fills the field',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ServerUrlPage()));
      await tester.pumpAndSettle();

      // DENOMINATOR: the page built and rendered chips at all. "no MSI chip"
      // and "the page threw during build" would otherwise read identically —
      // this programme has already booked a zero produced by a widget that was
      // never reached.
      expect(find.byType(ActionChip), findsWidgets,
          reason: 'the Server URL page rendered no preset chips at all, so any '
              'statement about WHICH chips it renders is vacuous');

      final chip = find.widgetWithText(ActionChip, _msi);
      expect(chip, findsOneWidget,
          reason: 'the owner ruling is that MSI is OFFERED. A '
              'kDevServerUrlPresets constant that the page does not read '
              'satisfies every assertion in the writer\'s own test file and '
              'still leaves the operator hand-typing the URL every session — '
              'which is the failure the ruling exists to end.');

      await tester.tap(chip);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, _msi,
          reason: 'the chip must actually populate the override field; a chip '
              'that renders and does nothing is worse than none, because it '
              'looks like it worked');
    });

    testWidgets('MSI is the LEFTMOST chip — the one a tired operator taps',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ServerUrlPage()));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .map((c) => (c.label as Text).data)
          .toList();
      expect(labels, isNotEmpty, reason: 'DENOMINATOR: chips were rendered');
      expect(labels.first, _msi, reason: 'rendered order: $labels');
    });

    testWidgets('ADDITIVE: the pre-existing emulator-loopback preset survives',
        (tester) async {
      // A "fix" that swapped the list rather than extending it would break
      // every emulator lane that points at the `:4010` Express mock.
      await tester.pumpWidget(const MaterialApp(home: ServerUrlPage()));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .map((c) => (c.label as Text).data)
          .toList();
      expect(labels, contains('http://10.0.2.2:4010'));
      expect(labels, hasLength(3), reason: 'rendered chips: $labels');
    });

    testWidgets('NEG CONTROL: the banned .50 host is on NO rendered chip',
        (tester) async {
      // Standing owner rule, repeated and escalating: MSI 192.168.2.39 is the
      // ONLY server. A preset list is exactly where a dead host survives for
      // months — it is one tap away from being applied to the whole app.
      await tester.pumpWidget(const MaterialApp(home: ServerUrlPage()));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .map((c) => (c.label as Text).data ?? '')
          .toList();
      const banned = '192.168.2.' '50';
      for (final label in labels) {
        expect(label.contains(banned), isFalse, reason: '$label names $banned');
      }
      // POS CONTROL for the matcher: it can fire. Without this, "no .50" is
      // indistinguishable from a loop that ran zero times or a matcher that
      // never matches anything.
      expect(labels, isNotEmpty);
      expect('http://$banned:1/'.contains(banned), isTrue);
    });
  });

  group('M10.b — the change is REAL: measured against the pre-ruling tree', ()
  {
    test('the base page hardcoded two presets INLINE and named no MSI', () {
      // POSITIVE CONTROL for the whole item. Without it, "MSI is offered"
      // could be a property the page always had, and M10 would be measuring
      // nothing that MB1 did.
      final base = gitShow(_page, ref: kPreFixBase);
      expect(base, isNotNull,
          reason: 'POS CONTROL COULD NOT RUN: cannot read $_page at '
              '$kPreFixBase (GATE.md §6.3 L3 — unverifiable is rejected)');
      expect(base!.contains(_msi), isFalse,
          reason: 'POS CONTROL FAILED: MSI was ALREADY a preset at the base, '
              'so the owner ruling describes a state that already held and '
              'this item measures nothing');
      expect(base.contains("for (final preset in const ["), isTrue,
          reason: 'POS CONTROL FAILED: the base page did not build its chips '
              'from an inline literal, so the regression this item guards '
              'against — reverting to one — is not the shape it was.');
    });

    test('the page reads the SHARED list, and no inline preset literal is left',
        () {
      final code = stripDartComments(readSource(_page));
      expect(code, contains('for (final preset in kDevServerUrlPresets)'),
          reason: 'the rendered chips must come from the shared constant, so '
              'the constant and the surface cannot drift apart');
      expect(code.contains('for (final preset in const ['), isFalse,
          reason: 'the inline literal is back; the constant is now decorative '
              'and the writer\'s own preset test can no longer detect a '
              'missing MSI chip');
    });

    test('the MSI preset is ORIGIN-ONLY (no /v1, no trailing slash)', () {
      // Dio merges `baseUrl + path` and every request path already carries
      // exactly one `/v1`; a `/v1` here doubles to `/v1/v1` and every call
      // 404s — the same SILENT breakage class the ruling is about.
      expect(kMsiGatewayBaseUrl, _msi);
      expect(kMsiGatewayBaseUrl.endsWith('/'), isFalse);
      expect(kMsiGatewayBaseUrl.contains('/v1'), isFalse);
      expect(Uri.parse(kMsiGatewayBaseUrl).path, isEmpty);
      expect(Uri.parse(kMsiGatewayBaseUrl).port, 10090);
    });

    test('the deliberately-unimplemented half of the ruling is RECORDED, not '
        'silently dropped', () {
      // The ruling has two halves — "add it as a preset" and "make it the dev
      // default" — and only the first is implemented. That is defensible (the
      // build default is JEEB_MOCK_BASE_URL, which MB1's own device round
      // points at the api-recorder on 127.0.0.1:9000; hard-defaulting to MSI
      // would route around the recorder and void every capture-class gate row
      // in the batch). What is NOT defensible is dropping half an owner ruling
      // without leaving the reason where the next agent will find it.
      final src = readSource(_page);
      expect(src, contains('OWNER-DECISIONS.md'),
          reason: 'cite the ruling, so a future refactor knows the list is '
              'owner-mandated and not a convenience');
      expect(src, contains('JEEB_MOCK_BASE_URL'),
          reason: 'the reason the second half is unimplemented must be stated '
              'at the site, or it reads as an oversight and gets "fixed" by '
              'someone who then silently voids the recorder captures');
    });
  });
}
