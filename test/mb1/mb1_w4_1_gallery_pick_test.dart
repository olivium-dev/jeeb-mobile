import 'package:flutter_test/flutter_test.dart';

import 'mb1_source_lens.dart';

/// MB1 member item **W4.1** — gallery pick, booked "20 min, proof only".
///
/// ## The claim W4.1 actually makes
///
/// Not "a gallery picker exists" — that is trivially true, `StubPhotoPickerService`
/// is a gallery picker and it is what shipped for months. The claim is the
/// narrower and much more failable one: **the surface reaches the REAL
/// `ImagePickerPhotoPickerService` through DI, and the stub is the fallback for
/// unregistered graphs only.**
///
/// The behavioural half of that already has a strong pin —
/// `test/features/chat/chat_picker_binding_test.dart` registers a SPY in
/// `GetIt` and asserts the spy, not the stub, was called. The MB1 runner runs
/// that file as part of this item; duplicating it here would be theatre.
///
/// What that file does NOT cover, and what this one adds, is the part MB1
/// actually changed: **the DI binding names the real service**, and **the
/// stale comment that made W4.1 look like open work is retired**. Both are
/// `static` claims and both can red on their own.
///
/// ## Why a comment is worth a test row at all
///
/// It is the reason this batch carried a 20-minute item for a feature that
/// needed no code. `chat_screen.dart` said the picker was *"the stub picker
/// until image_picker lands in a later mobile task"* while the DI graph had
/// registered the real one since JEBV4-111. A planner reading the tree books
/// the work; a verifier reading the tree books a defect. A stale sentence in a
/// live file is a liability with a cost, and this row is what stops it coming
/// back.

void main() {
  group('MB1 W4.1 — the DI graph binds the REAL picker', () {
    test('PhotoPickerService resolves to ImagePickerPhotoPickerService', () {
      final di = MB1Source.strippedLib('lib/core/di/injection_container.dart');
      // Comment-stripped: the container's own prose explains the JEBV4-111 bug
      // and names both classes, so a raw `contains` cannot tell the fix from
      // the description of the bug.
      final binding = RegExp(
        r'registerLazySingleton<PhotoPickerService>\(\s*\(\)\s*=>\s*(\w+)\(',
      ).firstMatch(di);
      expect(
        binding,
        isNotNull,
        reason:
            'no PhotoPickerService registration at all means every capture '
            'surface silently falls back to the stub — the JEBV4-111 bug.',
      );
      expect(
        binding!.group(1),
        'ImagePickerPhotoPickerService',
        reason:
            'binding the STUB here is the exact regression: synthetic bytes '
            'that render as "Invalid image data" instead of opening the OS '
            'gallery. It would leave every behavioural test green, because a '
            'spy registered by a test overrides this binding anyway.',
      );
    });

    test('ChatScreen resolves the picker from DI FIRST, stub only as fallback',
        () {
      final screen = MB1Source.strippedLib(
        'lib/features/chat/presentation/chat_screen.dart',
      );
      final resolver = RegExp(
        r'PhotoPickerService _resolvePicker\(\)\s*\{(.*?)\n  \}',
        dotAll: true,
      ).firstMatch(screen);
      expect(resolver, isNotNull, reason: '_resolvePicker must exist');
      final body = resolver!.group(1)!;
      final diAt = body.indexOf('sl.isRegistered<PhotoPickerService>()');
      final stubAt = body.indexOf('StubPhotoPickerService()');

      // PRESENCE BEFORE ORDER. This is not defensive noise — the first draft
      // asserted only `diAt < stubAt`, and a negative control that DELETED the
      // DI lookup outright passed it: `indexOf` returns -1 for absent, and
      // -1 < 12 is true. The mutation that reproduces the exact P4/P5 bug —
      // a resolver that returns the stub and never consults `sl` — sailed
      // through the assertion written to catch it.
      expect(
        diAt,
        greaterThanOrEqualTo(0),
        reason:
            'the DI lookup is GONE. Every host that omits `pickerService` now '
            'gets synthetic bytes and the OS gallery never opens — P4/P5, '
            'exactly.',
      );
      expect(stubAt, greaterThanOrEqualTo(0), reason: 'the stub fallback is '
          'gone; widget tests and the dev catalog depend on it');
      expect(
        diAt,
        lessThan(stubAt),
        reason: 'the DI lookup must come FIRST, not merely be present.',
      );
    });

    test('POSITIVE CONTROL — the regexes can match, and can miss', () {
      // Both patterns above are `isNotNull`-gated, which is only meaningful if
      // they are capable of returning null on plausible-but-wrong source.
      final pattern = RegExp(
        r'registerLazySingleton<PhotoPickerService>\(\s*\(\)\s*=>\s*(\w+)\(',
      );
      expect(
        pattern
            .firstMatch(
              'sl.registerLazySingleton<PhotoPickerService>(\n'
              '  () => StubPhotoPickerService(),\n);',
            )
            ?.group(1),
        'StubPhotoPickerService',
        reason: 'the regex reads the bound class, so the real assertion above '
            'is a measurement and not a syntax check',
      );
      expect(
        pattern.firstMatch('sl.registerLazySingleton<CdnAssetGateway>(() => X('),
        isNull,
      );
    });
  });

  group('MB1 W4.1 — the stale "stub picker" claim is retired', () {
    test('every "stub picker until" occurrence is RETRACTED, not live', () {
      final raw = MB1Source.raw(
        'lib/features/chat/presentation/chat_screen.dart',
      );
      // NOT `isFalse` on the phrase. The programme's own convention — DT0's T9,
      // ratified in `OWNER-DECISIONS.md` — is that a superseded claim is DATED
      // AS HISTORY and RETAINED, never deleted, so the next reader can see what
      // changed and why. `chat_screen.dart` follows it: the stale sentence is
      // QUOTED inside its own retraction. A bare absence assertion is therefore
      // a guaranteed false red on correct work, and the first draft of this
      // file was exactly that.
      //
      // What must actually hold is that no occurrence is a LIVE claim. Every
      // one has to sit next to a retraction marker.
      final live = <int>[];
      for (final m in RegExp(
        r'stub picker until',
        caseSensitive: false,
      ).allMatches(raw)) {
        final from = (m.start - 400).clamp(0, raw.length);
        final context = raw.substring(from, m.start);
        final retracted = context.contains('used to read') ||
            context.contains('RETRACTED') ||
            context.contains('That has been false') ||
            context.contains('W4.1');
        if (!retracted) live.add(m.start);
      }
      expect(
        live,
        isEmpty,
        reason:
            'an UNretracted "stub picker until …" is why MB1 booked 20 minutes '
            'for shipped work: a planner reading it books the work, a verifier '
            'reading it books a defect against a working feature.',
      );
      // POSITIVE CONTROL — the detector can see a live occurrence. Without
      // this, `live` is empty for a tree with no occurrences at all, for a
      // misspelled pattern, and for a correctly-retracted file alike.
      const fabricated =
          '/// and a [PhotoPickerService] (the stub picker until image_picker '
          'lands in a later mobile task), and';
      expect(
        RegExp(r'stub picker until').allMatches(fabricated).length,
        1,
        reason: 'the pattern matches the pre-MB1 sentence verbatim',
      );
      expect(
        fabricated.contains('used to read') || fabricated.contains('W4.1'),
        isFalse,
        reason: 'and that sentence carries NO retraction marker, so the loop '
            'above would have classified it live',
      );
      // The correction must NAME the real service, not merely delete the false
      // sentence — deletion alone leaves the next reader with no way to know
      // which picker is actually live.
      expect(raw, contains('ImagePickerPhotoPickerService'));
    });

    test(
      'the behavioural pin for this item exists and is not vacuous',
      () {
        // The MB1 runner executes this file as the behavioural leg of W4.1.
        // Asserting its EXISTENCE and its SPY SHAPE here means a future
        // "cleanup" that deletes or neuters it reds this row rather than
        // silently removing the only proof that DI is reached at runtime.
        final pin = MB1Source.raw(
          'test/features/chat/chat_picker_binding_test.dart',
        );
        expect(pin, contains('registerSingleton<PhotoPickerService>(spy)'));
        expect(pin, contains('galleryCalls'));
        expect(
          pin,
          contains('isNot(isA<StubPhotoPickerService>())'),
          reason:
              'the pin must assert the stub was NOT what answered. Counting '
              'spy calls alone passes on a tree where both are invoked.',
        );
      },
    );
  });
}
