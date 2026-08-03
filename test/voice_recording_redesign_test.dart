// redesign-24 · screen 05 (voice recording).
//
// Locks the four behaviours the rebuilt composer introduced: the max-duration
// arc reads straight off `elapsed`, slide-to-cancel reaches
// `VoiceRecordingCubit.cancelRecording()` in BOTH directions, the Type
// satellite is opt-in and inert mid-recording, and the docked cluster survives
// Arabic at 200% text scale.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// The four strings screen 05 introduces live in
/// `docs/redesign-2026-08/wiring/05-voice-recording.md` and are applied to the
/// ARB by the serialized integrator, not by this lane. Until then this
/// delegate layers them over the real ARB so the screen is testable; once the
/// wiring lands the overlay is a no-op and this class can be deleted in favour
/// of the shared `wrapForTest`.
// TODO(redesign-24): delete once the 05 l10n wiring request is applied.
class _PendingCopyDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _PendingCopyDelegate();

  static const Map<String, Map<String, String>> _pending =
      <String, Map<String, String>>{
        'en': <String, String>{
          'voiceRecordingNewRequestTitle': 'New request',
          'voiceRecordingStatusRecording': 'Recording — release to stop',
          'voiceRecordingSlideToCancel': 'Slide',
          'voiceRecordingTypeInstead': 'Type',
        },
        'ar': <String, String>{
          'voiceRecordingNewRequestTitle': 'طلب جديد',
          'voiceRecordingStatusRecording': 'جارٍ التسجيل — أفلت للإيقاف',
          'voiceRecordingSlideToCancel': 'اسحب',
          'voiceRecordingTypeInstead': 'اكتب',
        },
      };

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) {
    final tag = locale.languageCode;
    final arb = File('lib/l10n/app_$tag.arb').readAsStringSync();
    final base = debugLoadAppLocalizationsSync(locale, arb);
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations(locale, <String, String>{
        ...base.allStrings,
        ...?_pending[tag],
      }),
    );
  }

  @override
  bool shouldReload(_PendingCopyDelegate old) => false;
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: ThemeData.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      _PendingCopyDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

VoiceRecordingCubit _buildCubit() {
  return VoiceRecordingCubit(
    recorder: FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
    repository: FakeVoiceRecordingRepository(),
    tickerFactory: (_) => const Stream.empty(),
  );
}

/// Every error the cubit emits over the test's lifetime.
///
/// The screen acknowledges transient errors as soon as it has shown them, so
/// `cubit.state.error` is null again by the time an assertion runs — the
/// emitted history is what distinguishes a cancel from a too-short release.
List<VoiceRecordingError?> _recordErrors(VoiceRecordingCubit cubit) {
  final raised = <VoiceRecordingError?>[];
  cubit.stream.listen((state) => raised.add(state.error));
  return raised;
}

JeebMicHero _hero(WidgetTester tester) =>
    tester.widget<JeebMicHero>(find.byKey(VoiceRecordingKeys.micButton));

/// Lets the cubit's terminal recording paths finish.
///
/// `stopRecording` / `cancelRecording` both await
/// `StreamSubscription.cancel()`, which never resolves inside the fake-async
/// zone `testWidgets` runs in — pumping alone leaves them pending forever.
/// `runAsync` hands them a real event loop; `voice_recording_cubit_test.dart`
/// sidesteps this by using plain `test()`.
Future<void> _settleCubit(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump();
}

/// Presses the mic, drags [dx] logical px, releases.
Future<void> _pressAndSlide(WidgetTester tester, double dx) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(VoiceRecordingKeys.micButton)),
  );
  // NOT pumpAndSettle: the recording phase now carries two looping Lottie
  // films (the mic sonar + the live waveform, motion spec §2.1/§2.2), so the
  // tree never settles while the mic is held. Two frames are enough — one to
  // flush `startRecording`'s microtasks, one to rebuild into `recording`.
  await tester.pump();
  await tester.pump();
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump();
  await gesture.up();
  await _settleCubit(tester);
}

void main() {
  group('05 · max-duration arc', () {
    testWidgets('idle draws no arc', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(_wrap(VoiceRecordingScreen(cubit: cubit)));
      await tester.pump();

      expect(_hero(tester).progress, isNull);
      expect(_hero(tester).isRecording, isFalse);
    });

    testWidgets('recording at 7s reads elapsed / maxDuration', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(_wrap(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.recording,
          elapsed: const Duration(seconds: 7),
        ),
      );
      await tester.pump();

      expect(_hero(tester).progress, closeTo(7 / 60, 1e-9));
      expect(_hero(tester).isRecording, isTrue);
      expect(
        find.text('00:07'),
        findsNothing,
        reason: 'timer is one rich span',
      );
    });

    testWidgets('clamps to 1.0 past the cap', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(_wrap(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.recording,
          elapsed: const Duration(seconds: 120),
        ),
      );
      await tester.pump();

      expect(_hero(tester).progress, 1.0);
    });
  });

  group('05 · slide-to-cancel', () {
    testWidgets('LTR: sliding toward the start edge cancels, not stops', (
      tester,
    ) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      final raised = _recordErrors(cubit);
      await tester.pumpWidget(_wrap(VoiceRecordingScreen(cubit: cubit)));
      await tester.pump();

      await _pressAndSlide(tester, -80);

      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      // A plain release on a sub-second clip raises tooShort;
      // cancelRecording() discards it silently. The live error is a poor
      // discriminator — the screen's own listener acknowledges it away.
      expect(raised, isNot(contains(VoiceRecordingError.tooShort)));
      expect(cubit.state.clip, isNull);
    });

    testWidgets('RTL: the cancel direction mirrors', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      final raised = _recordErrors(cubit);
      await tester.pumpWidget(
        _wrap(VoiceRecordingScreen(cubit: cubit), locale: const Locale('ar')),
      );
      await tester.pump();

      await _pressAndSlide(tester, 80);

      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(raised, isNot(contains(VoiceRecordingError.tooShort)));
    });

    testWidgets('a short press with no travel still stops (tooShort)', (
      tester,
    ) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      final raised = _recordErrors(cubit);
      await tester.pumpWidget(_wrap(VoiceRecordingScreen(cubit: cubit)));
      await tester.pump();

      await _pressAndSlide(tester, 0);

      expect(raised, contains(VoiceRecordingError.tooShort));
    });

    testWidgets('the × satellite stays independently tappable', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(_wrap(VoiceRecordingScreen(cubit: cubit)));
      await cubit.startRecording();
      await tester.pump();

      await tester.tap(find.byKey(VoiceRecordingKeys.cancelButton));
      await _settleCubit(tester);

      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(cubit.state.error, isNull);
    });
  });

  group('05 · Type satellite', () {
    testWidgets('absent when onSwitchToTyping is null', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(_wrap(VoiceRecordingScreen(cubit: cubit)));
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_type_button'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('emits its identifier and fires when provided', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          VoiceRecordingScreen(cubit: cubit, onSwitchToTyping: () => taps++),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_type_button'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.keyboard));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('is inert while recording', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          VoiceRecordingScreen(cubit: cubit, onSwitchToTyping: () => taps++),
        ),
      );
      await cubit.startRecording();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('05 · RTL + 200% text scale', () {
    testWidgets('the recording surface does not overflow in Arabic', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: VoiceRecordingScreen(
                cubit: cubit,
                onSwitchToTyping: () {},
              ),
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.recording,
          elapsed: const Duration(seconds: 7),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(VoiceRecordingKeys.micButton), findsOneWidget);
      expect(find.byKey(VoiceRecordingKeys.cancelButton), findsOneWidget);
    });
  });
}
