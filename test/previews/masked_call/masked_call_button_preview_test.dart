// Render tests for the MaskedCallButton previews.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/masked_call/application/masked_call_cubit.dart';
import 'package:jeeb_mobile/features/masked_call/presentation/masked_call_button.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _call = 'Call';
const String _callAr = 'اتصال';
const String _failed = 'Could not start the call. Please try again.';
const String _failedAr = 'تعذّر بدء المكالمة. حاول مرة أخرى.';

/// The Maestro/QA selector the button wraps itself in.
const String _ctaIdentifier = 'masked_call_cta';

/// The cubit a preview mounted above the button, read back the way the button's
/// own view reads it.
MaskedCallCubit _cubitOf(WidgetTester tester) {
  return BlocProvider.of<MaskedCallCubit>(
    tester.element(find.bySemanticsIdentifier(_ctaIdentifier)),
  );
}

/// Pumps [preview], returns the CTA's rect, then UNMOUNTS — so the next preview
/// in the same test builds a fresh element tree instead of silently reusing
Future<Rect> _frameOf(WidgetTester tester, Widget Function() preview) async {
  await pumpPreview(tester, preview);

  expect(find.bySemanticsIdentifier(_ctaIdentifier), findsOneWidget);
  expect(find.text(_call), findsOneWidget);
  expect(find.byType(Text), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);

  final Rect rect = tester.getRect(find.text(_call));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  return rect;
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Failed · error snackbar`, which cannot settle — see
  testPreviewsRender(
    'MaskedCallButton',
    const <String, Widget Function()>{
      'Idle · ready to call': maskedCallButtonIdle,
      'Placing the call': maskedCallButtonPlacing,
      'Session live · nothing changed': maskedCallButtonSessionLive,
      'Failure before subscribe · no trace': maskedCallButtonFailedSilently,
    },
    // The only string this widget owns. `Placing the call` is absent because it
    expectedText: const <String, String>{
      'Idle · ready to call': _call,
      'Session live · nothing changed': _call,
      'Failure before subscribe · no trace': _call,
    },
  );

  // The failure path ends in a `SnackBar`, whose 4s auto-dismiss Timer is still
  group('MaskedCallButton previews · Failed · error snackbar', () {
    Future<void> pumpSnackbar(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(maskedCallButtonFailedSnackbar, locale),
      );
      await tester.pump(); // localizations + the post-frame failed emit
      await tester.pump(); // the emit reaches the listener
      await tester.pump(const Duration(milliseconds: 750)); // entrance
    }

    /// Runs the 4s auto-dismiss timer out so the test ends timer-free.
    Future<void> drain(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Failed · error snackbar · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSnackbar(tester, locale: locale);

        expect(tester.takeException(), isNull);
        await drain(tester);
      });
    }

    testWidgets('renders its own state — the failure copy, in a snackbar', (
      WidgetTester tester,
    ) async {
      await pumpSnackbar(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_failed), findsOneWidget);
      await drain(tester);
    });

    testWidgets('localizes: no English leaks into the AR reading', (
      WidgetTester tester,
    ) async {
      await pumpSnackbar(tester, locale: const Locale('ar'));

      expect(find.text(_failedAr), findsOneWidget);
      expect(find.text(_failed), findsNothing);
      expect(find.text(_callAr), findsOneWidget);
      expect(find.text(_call), findsNothing);
      final Element cta = tester.element(
        find.bySemanticsIdentifier(_ctaIdentifier),
      );
      expect(Directionality.of(cta), TextDirection.rtl);
      await drain(tester);
    });

    testWidgets('the snackbar is the ONLY trace a failure leaves', (
      WidgetTester tester,
    ) async {
      await pumpSnackbar(tester);

      // While it is up, the pill underneath already reads as a plain, live
      expect(find.text(_call), findsOneWidget);
      expect(_cubitOf(tester).state.failed, isTrue);

      await drain(tester);

      // ...and once the 4s timer has run out, the failure is gone from the
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_failed), findsNothing);
      expect(find.text(_call), findsOneWidget);
    });
  });

  group('MaskedCallButton preview specifics', () {
    testWidgets('idle is the real production wiring — no injected cubit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, maskedCallButtonIdle);

      // `MaskedCallButton(orderId: …)` with `cubit: null` is what every real
      final MaskedCallState state = _cubitOf(tester).state;
      expect(state.isLoading, isFalse);
      expect(state.sessionId, isNull);
      expect(state.failed, isFalse);

      expect(find.text(_call), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    // One preview per test, deliberately: pumping a second preview into the
    testWidgets('the in-flight pill has no text at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, maskedCallButtonPlacing);

      // This is what tells `Placing the call` apart from every other preview,
      expect(_cubitOf(tester).state.isLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.text(_call), findsNothing);
    });

    testWidgets('FINDING: the in-flight CTA announces as an unnamed button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, maskedCallButtonPlacing);

      // The `Semantics` wrapper is `container: true` with no `label` of its
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier(_ctaIdentifier),
      );
      expect(node.label, isEmpty);
      expect(node.hint, isEmpty);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.none);

      handle.dispose();
    });

    testWidgets('the idle CTA does carry its name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, maskedCallButtonIdle);

      // The control for the finding above: the same wrapper, the same flags —
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier(_ctaIdentifier),
      );
      expect(node.label, _call);
      expect(node.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('session live keeps the placed call on the cubit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, maskedCallButtonSessionLive);

      // The state IS different from idle — the button simply never reads it.
      expect(_cubitOf(tester).state.sessionId, 'session-DLV-9001');
      expect(find.text(_call), findsOneWidget);
    });

    testWidgets('a failure seeded before subscribe shows nothing at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, maskedCallButtonFailedSilently);

      // `BlocConsumer` runs its listener on state CHANGES, so a `failed`
      expect(_cubitOf(tester).state.failed, isTrue);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_failed), findsNothing);
      expect(find.text(_call), findsOneWidget);
    });

    testWidgets('FINDING: three states paint the SAME pill', (
      WidgetTester tester,
    ) async {
      final Map<String, Rect> byState = <String, Rect>{};
      for (final MapEntry<String, Widget Function()> entry
          in const <String, Widget Function()>{
        'Idle · ready to call': maskedCallButtonIdle,
        'Session live · nothing changed': maskedCallButtonSessionLive,
        'Failure before subscribe · no trace': maskedCallButtonFailedSilently,
      }.entries) {
        byState[entry.key] = await _frameOf(tester, entry.value);
      }

      expect(
        byState.values.toSet(),
        hasLength(1),
        reason: 'a call never started, a call already placed and a call that '
            'failed all render one identical `Call` pill in the same place: '
            '$byState',
      );
    });
  });

  // What the 200% rendering of the matrix shows, held as measurements so it
  group('MaskedCallButton layout ceiling (390x120 canvas box)', () {
    /// Pumps the idle preview into the box the annotation actually declares,
    /// at [textScale] — the way the canvas renders it.
    Future<void> pumpInBox(
      WidgetTester tester, {
      required double textScale,
      Locale locale = const Locale('en'),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 120);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: previewCanvas(maskedCallButtonIdle, locale),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the pill height ignores the text scale (${locale.languageCode})', (
        WidgetTester tester,
      ) async {
        await pumpInBox(tester, textScale: 1.0, locale: locale);
        final double atNormal =
            tester.getRect(find.byType(GestureDetector).first).height;
        final double labelAtNormal = tester.getRect(find.byType(Text)).height;

        await pumpInBox(tester, textScale: 2.0, locale: locale);
        final double atDouble =
            tester.getRect(find.byType(GestureDetector).first).height;
        final double labelAtDouble = tester.getRect(find.byType(Text)).height;

        // `OmdsLoadingButton` defaults to `height: Sizes.fourXLarge`, a hard
        expect(atNormal, 48.0);
        expect(atDouble, 48.0);
        // ...while the label inside it doubles, from 20 dp to 40 dp. It still
        expect(labelAtNormal, 20.0);
        expect(labelAtDouble, 40.0);
        expect(labelAtDouble, lessThan(atDouble));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the label stays centred, both directions (${locale.languageCode})', (
        WidgetTester tester,
      ) async {
        await pumpInBox(tester, textScale: 2.0, locale: locale);

        // A full-bleed pill with a centred single word has nothing to mirror,
        final Rect label = tester.getRect(find.byType(Text));
        final Rect button = tester.getRect(find.byType(GestureDetector).first);
        expect(label.center.dx, closeTo(button.center.dx, 0.5));
      });
    }
  });
}
