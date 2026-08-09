// The recording focus layer and the redesigned slide-to-cancel.
//
// Two things are under test: the scrim that darkens everything the route owns
// while a clip is being captured, and the gesture that now has a visible
// destination instead of a disc that dead-stops at the wall.
//
// Every assertion here has a reduce-motion twin. A scrim, a chip or a pulse
// that still moves under `disableAnimations` is a vestibular-safety blocker,
// not a cosmetic miss.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_request_hero.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/widgets/recording_waveform.dart';

import '../../support/sync_app_localizations.dart';

const Key _scrimKey = Key('client-home-recording-scrim');
const Key _chipKey = Key('client-home-mic-cancel-chip');

late StreamController<Duration> _ticks;
late FakeVoiceRecordingRepository _repo;

VoiceRecordingCubit _buildCubit({
  VoiceRecordingState initialState = const VoiceRecordingState(),
}) {
  _ticks = StreamController<Duration>.broadcast();
  _repo = FakeVoiceRecordingRepository(transcript: 'apples');
  return VoiceRecordingCubit(
    recorder: FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
    repository: _repo,
    tickerFactory: (_) => _ticks.stream,
    initialState: initialState,
  );
}

/// Zero-duration pumps only: nothing here may advance an animation clock, or
/// the timing assertions below would measure the flush instead of the curve.
Future<void> _flush(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Widget _harness(
  VoiceRecordingCubit cubit, {
  bool disableAnimations = true,
  Locale locale = const Locale('en'),
  ValueListenable<bool>? visible,
}) {
  final Widget screen = ClientHomeScreen(
    initialTab: ClientHomeTab.pendingRequests,
    onCreateRequest: (_) {},
    voiceCubit: cubit,
  );
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: InMemoryClientHomeRepository(latency: Duration.zero),
          greetingNameProvider: () => 'Lina',
        ),
        child: visible == null
            ? screen
            : ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (_, isVisible, _) =>
                    TabVisibility(isVisible: isVisible, child: screen),
              ),
      ),
    ),
  );
}

double _scrimOpacity(WidgetTester tester) {
  return tester
      .widget<FadeTransition>(
        find.descendant(of: find.byKey(_scrimKey), matching: find.byType(FadeTransition)),
      )
      .opacity
      .value;
}

/// True when the scrim's own render object is on the hit path — i.e. the list
/// underneath it can never see the pointer.
bool _scrimAbsorbs(WidgetTester tester, Offset at) {
  final RenderObject scrim = tester.renderObject(find.byKey(_scrimKey));
  return tester
      .hitTestOnBinding(at)
      .path
      .any((HitTestEntry entry) => identical(entry.target, scrim));
}

double _chipOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(_chipKey)).opacity;

/// The chip's PAINTED centre. The keyed [Opacity] sits above the offset
/// transforms, so it must be measured from below them.
Finder _chipPaint() =>
    find.descendant(of: find.byKey(_chipKey), matching: find.byType(CustomPaint));

/// The pinned create door — the capsule half of the split hero.
Finder _createCapsule() => find.descendant(
  of: find.byType(ClientHomeRequestHero),
  matching: find.byType(JeebGlassCard),
);

/// Every circle the arm ring actually puts on the canvas this frame.
///
/// Measured from the real painter, never from the controller: `JHaloPainter`
/// mods the phase, so EVERY resting value would paint the loudest frame.
List<({double radius, double alpha})> _ringCircles(WidgetTester tester) {
  final CustomPainter? painter = tester.widget<CustomPaint>(_chipPaint()).painter;
  if (painter == null) return const <({double radius, double alpha})>[];
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  painter.paint(canvas, tester.getSize(_chipPaint()));
  return canvas.invocations
      .where((RecordedInvocation i) => i.invocation.memberName == #drawCircle)
      .map(
        (RecordedInvocation i) => (
          radius: i.invocation.positionalArguments[1] as double,
          alpha: (i.invocation.positionalArguments[2] as Paint).color.a,
        ),
      )
      .toList();
}

/// The armed disc lands ON the chip at 90% of Ø56 — a ring smaller than this
/// is painted under an opaque disc and can never be seen.
const double _kDockedDiscRadius =
    JeebMicHero.sizeCompact / 2 * (1 - _kMicSlideShrinkMirror);
const double _kMicSlideShrinkMirror = 0.10;

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

JeebMicHero _mic(WidgetTester tester) =>
    tester.widget<JeebMicHero>(find.byType(JeebMicHero));

double _micDx(WidgetTester tester) =>
    tester.getCenter(find.byType(JeebMicHero)).dx;

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(JeebMicHero))).colorScheme;

Color _accent(WidgetTester tester) =>
    tester.element(find.byType(JeebMicHero)).jeebRoles.accent;

void main() {
  tearDown(() async {
    await _ticks.close();
    await sl.reset();
  });

  group('the recording focus scrim', () {
    testWidgets('is absent at rest, washes in on record, and clears on send', (
      tester,
    ) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit, disableAnimations: false));
      await _flush(tester);
      expect(_scrimOpacity(tester), 0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(JeebMicHero)),
      );
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.recording);
      await tester.pump(const Duration(milliseconds: 240));
      expect(_scrimOpacity(tester), 1);

      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      await gesture.up();
      await _flush(tester);

      // The send exit is the slow one: still visible at the cancel tempo.
      await tester.pump(const Duration(milliseconds: 151));
      expect(_scrimOpacity(tester), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scrimOpacity(tester), 0);
    });

    testWidgets('cuts out on cancel, faster than it would on send', (
      tester,
    ) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit, disableAnimations: false));
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 240));
      expect(_scrimOpacity(tester), 1);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold - 8, 0),
      );
      await tester.pump();
      await gesture.up();
      await _flush(tester);

      await tester.pump(const Duration(milliseconds: 151));
      expect(_scrimOpacity(tester), 0);
      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(_repo.uploadCalls, 0);
    });

    testWidgets('never covers a frozen screen: sending alone shows nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          _buildCubit(
            initialState: const VoiceRecordingState(
              phase: VoiceRecordingPhase.sending,
            ),
          ),
        ),
      );
      await _flush(tester);
      expect(_scrimOpacity(tester), 0);
    });

    testWidgets('absorbs a stray second pointer without acting on it', (
      tester,
    ) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      const Offset overList = Offset(400, 120);
      expect(_scrimAbsorbs(tester, overList), isFalse);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(JeebMicHero)),
      );
      await _flush(tester);
      expect(_scrimAbsorbs(tester, overList), isTrue);

      // A palm landing on the scrim must not become "discard the recording".
      final palm = await tester.startGesture(overList);
      await palm.up();
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.recording);

      // S2: the wash tracks the RECORDING, not the finger. Releasing this
      // early leaves a tap-started recording running, so the scrim stays.
      await gesture.up();
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.recording);
      expect(_scrimAbsorbs(tester, overList), isTrue);

      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      final stop = await tester.startGesture(
        tester.getCenter(find.byType(JeebMicHero)),
      );
      await _flush(tester);
      await stop.up();
      await _flush(tester);
      expect(_scrimAbsorbs(tester, overList), isFalse);
    });

    testWidgets('reduce motion swaps it instantly, both directions', (
      tester,
    ) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();
      expect(_scrimOpacity(tester), 0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(JeebMicHero)),
      );
      await _flush(tester);
      expect(_scrimOpacity(tester), 1);

      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      await gesture.up();
      await _flush(tester);
      expect(_scrimOpacity(tester), 0);
    });
  });

  group('the cancel chip', () {
    testWidgets('stays hidden through the grip and materialises on the drag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      expect(_chipOpacity(tester), 0);
      expect(
        _micDx(tester) - tester.getCenter(_chipPaint()).dx,
        closeTo(64, 0.01),
        reason: 'the destination sits toward the LTR start edge',
      );

      // t = 0.2 — still inside the grip band.
      await gesture.moveTo(centre.translate(-12.8, 0));
      await tester.pump();
      expect(_chipOpacity(tester), 0);

      await gesture.moveTo(centre.translate(-32, 0));
      await tester.pump();
      expect(_chipOpacity(tester), greaterThan(0));

      await gesture.moveTo(centre.translate(-44.8, 0));
      await tester.pump();
      expect(_chipOpacity(tester), 1);

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('travels over the pinned create door, which the scrim owns', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_buildCubit()));
      await _flush(tester);

      final Rect capsule = tester.getRect(_createCapsule());
      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await _flush(tester);

      // The chip's destination is INSIDE the capsule's band by design; what
      // keeps that honest is the scrim, not a gap.
      expect(tester.getCenter(_chipPaint()).dx, lessThan(capsule.right));
      expect(
        _scrimAbsorbs(tester, capsule.center),
        isTrue,
        reason:
            'a create door still tappable under the cancel chip is the '
            'defect pinning it into the mic band could have introduced',
      );

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('fires one ring pulse, drawn wide enough to clear the disc', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      expect(
        _ringCircles(tester),
        isEmpty,
        reason: 'an un-fired pulse must not paint',
      );

      await gesture.moveTo(centre.translate(-32, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_ringCircles(tester), isEmpty, reason: 'the drag alone does not pulse');

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      // The first frame after a ticker starts carries zero elapsed time.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final List<({double radius, double alpha})> ring = _ringCircles(tester);
      expect(ring, hasLength(1));
      expect(ring.single.alpha, greaterThan(0.2));
      expect(
        ring.single.radius,
        greaterThan(_kDockedDiscRadius),
        reason: 'a ring inside the docked disc is a controller nobody can see',
      );

      // One-shot: it dies back to silence and does not restart.
      await tester.pump(const Duration(milliseconds: 500));
      expect(_ringCircles(tester), isEmpty);

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('reduce motion gives it a binary appearance and no pulse', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_buildCubit()));
      await tester.pumpAndSettle();

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      expect(_chipOpacity(tester), 0);

      await gesture.moveTo(centre.translate(-12.8, 0));
      await tester.pump();
      expect(_chipOpacity(tester), 0);

      // Exactly 0 or exactly 1 — never an intermediate frame.
      await gesture.moveTo(centre.translate(-32, 0));
      await tester.pump();
      expect(_chipOpacity(tester), 1);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      expect(_chipOpacity(tester), 1);
      expect(_ringCircles(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _ringCircles(tester),
        isEmpty,
        reason: 'a still frame of the pulse is still a ring on screen',
      );

      await gesture.up();
      await _flush(tester);
    });
  });

  group('the rubber band', () {
    testWidgets('tracks 1:1 to the knee, then falls behind the finger', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      await gesture.moveTo(centre.translate(-24, 0));
      await tester.pump();
      expect(restDx - _micDx(tester), closeTo(24, 0.01));

      // Past 32dp the disc must LAG: 32 + 16 * 0.75 = 44 for 48dp of finger.
      await gesture.moveTo(centre.translate(-48, 0));
      await tester.pump();
      final double dragged = restDx - _micDx(tester);
      expect(dragged, lessThan(48));
      expect(dragged, closeTo(44, 0.01));

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('the magnetic dock closes the last gap only once armed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      expect(restDx - _micDx(tester), closeTo(56, 0.01));

      await tester.pump(const Duration(milliseconds: 120));
      expect(restDx - _micDx(tester), closeTo(64, 0.01));

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('under Arabic the band and the chip mirror to the start edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          _buildCubit(),
          disableAnimations: false,
          locale: const Locale('ar'),
        ),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);
      final double chipRest = tester.getCenter(_chipPaint()).dx;
      expect(
        chipRest - restDx,
        closeTo(64, 0.01),
        reason: 'the RTL start edge is the RIGHT one',
      );

      // RTL cancel travels toward the RIGHT, and the band must follow it.
      await gesture.moveTo(centre.translate(48, 0));
      await tester.pump();
      expect(_micDx(tester) - restDx, closeTo(44, 0.01));
      expect(_chipOpacity(tester), greaterThan(0));

      await gesture.moveTo(centre);
      await tester.pump();
      await gesture.up();
      await _flush(tester);
    });

    testWidgets('reduce motion refuses to move the disc at all', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_buildCubit()));
      await tester.pumpAndSettle();

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      for (final double travel in <double>[24, 48, 64, 96]) {
        await gesture.moveTo(centre.translate(-travel, 0));
        await tester.pump();
        expect(_micDx(tester), restDx);
      }

      await gesture.up();
      await _flush(tester);
    });
  });

  group('the disc tints instead of fading', () {
    testWidgets('lerps accent toward error over the back half of the travel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final Color accent = _accent(tester);
      final Color error = _scheme(tester).error;
      expect(_mic(tester).discColor, accent);

      // t = 0.5 is where the tint starts, so the grip half stays pure accent.
      await gesture.moveTo(centre.translate(-32, 0));
      await tester.pump();
      expect(_mic(tester).discColor, accent);

      await gesture.moveTo(centre.translate(-48, 0));
      await tester.pump();
      expect(_mic(tester).discColor, isNot(accent));
      expect(_mic(tester).discColor, isNot(error));

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      expect(_mic(tester).discColor, error);

      // The 0.45 breathe fade is GONE: nothing may dim the held disc.
      for (final Element element in find
          .ancestor(
            of: find.byType(JeebMicHero),
            matching: find.byType(Opacity),
          )
          .evaluate()) {
        expect(
          (element.widget as Opacity).opacity,
          greaterThanOrEqualTo(0.9),
          reason: 'a faded disc reads as disabled, not as armed',
        );
      }

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('swaps the tint and the glyph binarily under reduce motion', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_buildCubit()));
      await tester.pumpAndSettle();

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final Color accent = _accent(tester);
      final Color error = _scheme(tester).error;

      await gesture.moveTo(centre.translate(-48, 0));
      await tester.pump();
      expect(_mic(tester).discColor, accent);
      expect(_mic(tester).glyphCrossfade, 0);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      expect(_mic(tester).discColor, error);
      expect(_mic(tester).glyphCrossfade, 1);

      await gesture.up();
      await _flush(tester);
    });
  });

  group('arming and un-arming', () {
    testWidgets('the armed disc docks, turns the glyph over and drops the halo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      expect(_mic(tester).halo, isTrue);
      expect(_mic(tester).glyphCrossfade, 0);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_mic(tester).halo, isFalse);
      expect(_mic(tester).glyphCrossfade, 1);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('sliding back reverses every armed value symmetrically', (
      tester,
    ) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit, disableAnimations: false));
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final Color accent = _accent(tester);
      final double restDx = _micDx(tester);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold - 24, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_mic(tester).discColor, _scheme(tester).error);
      expect(_mic(tester).glyphCrossfade, 1);
      expect(_chipOpacity(tester), 1);

      await gesture.moveTo(centre);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_mic(tester).discColor, accent);
      expect(_mic(tester).glyphCrossfade, 0);
      expect(_mic(tester).halo, isTrue);
      expect(_chipOpacity(tester), 0);
      expect(_micDx(tester), closeTo(restDx, 0.01));

      // A reversed cancel is still a recording: releasing here must UPLOAD.
      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      await gesture.up();
      await _flush(tester);
      expect(_repo.uploadCalls, 1);
    });

    testWidgets('the send release glides the disc home instead of teleporting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      await gesture.moveTo(centre.translate(-48, 0));
      await tester.pump();
      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);

      await gesture.up();
      await _flush(tester);
      // Mid-glide: the disc is neither where it was nor already home.
      await tester.pump(const Duration(milliseconds: 40));
      final double midway = restDx - _micDx(tester);
      expect(midway, greaterThan(0));
      expect(midway, lessThan(44));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_micDx(tester), closeTo(restDx, 0.01));
    });

    testWidgets('a new press stops the exit curve dead', (tester) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit, disableAnimations: false));
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      var gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      await gesture.moveTo(centre.translate(-48, 0));
      await tester.pump();
      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      await gesture.up();
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 40));

      final double midGlide = _micDx(tester);
      expect(midGlide, greaterThan(restDx - 44));
      expect(midGlide, lessThan(restDx));

      // Pressing the disc where it actually is, mid-glide.
      gesture = await tester.startGesture(
        tester.getCenter(find.byType(JeebMicHero)),
      );
      await _flush(tester);
      expect(_micDx(tester), closeTo(restDx, 0.01));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_micDx(tester), closeTo(restDx, 0.01));

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('the mic element survives the whole armed round trip', (
      tester,
    ) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit, disableAnimations: false));
      await _flush(tester);

      final Element before = tester.element(find.byType(JeebMicHero));
      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      for (final double travel in <double>[16, 40, 64, 96, 40, 64]) {
        await gesture.moveTo(centre.translate(-travel, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.element(find.byType(JeebMicHero)),
          same(before),
          reason: 'a re-inflated mic orphans the live press',
        );
      }

      await gesture.up();
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(_repo.uploadCalls, 0);

      // The held sink MUST come back to 0 on its own, or the disc stays
      // docked and the dock hint latches on "Release to cancel".
      await tester.pump(const Duration(milliseconds: 500));
      expect(_micDx(tester), closeTo(restDx, 0.01));
      expect(tester.element(find.byType(JeebMicHero)), same(before));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the chip is inert to the pointer and to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_chipOpacity(tester), 1);

      // One mic node, one mic widget — the chip adds neither.
      expect(find.bySemanticsIdentifier('client_home_mic_cta'), findsOneWidget);
      expect(find.byType(JeebMicHero), findsOneWidget);

      final RenderObject chip = tester.renderObject(find.byKey(_chipKey));
      expect(
        tester
            .hitTestOnBinding(tester.getCenter(find.byKey(_chipKey)))
            .path
            .any((HitTestEntry entry) => identical(entry.target, chip)),
        isFalse,
        reason: 'the chip sits over the dock; it must never outrank it',
      );

      await gesture.up();
      await _flush(tester);
      handle.dispose();
    });
  });

  group('the armed dead band', () {
    testWidgets('a thumb parked on the wall cannot strobe the armed state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_mic(tester).glyphCrossfade, 1);
      expect(_ringCircles(tester), isEmpty, reason: 'the one-shot is spent');

      // Touch noise around the wall, every sample inside the 52..64 band.
      for (final double travel in <double>[63, 65, 58, 53, 64.5]) {
        await gesture.moveTo(centre.translate(-travel, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(_mic(tester).glyphCrossfade, 1);
        expect(_mic(tester).halo, isFalse);
        expect(_mic(tester).discColor, _scheme(tester).error);
        expect(_chipOpacity(tester), 1);
        expect(restDx - _micDx(tester), closeTo(64, 0.01));
        expect(
          _ringCircles(tester),
          isEmpty,
          reason: 'a re-fired ring means the armed state flipped',
        );
      }

      // Past the band it does disarm, on the documented 52dp release.
      await gesture.moveTo(centre.translate(-51, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_mic(tester).glyphCrossfade, 0);
      expect(_mic(tester).halo, isTrue);

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('releasing inside the band still cancels, as the disc says', (
      tester,
    ) async {
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit, disableAnimations: false));
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);

      await gesture.moveTo(
        centre.translate(-JeebMicHero.slideCancelThreshold, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.moveTo(centre.translate(-58, 0));
      await tester.pump();
      expect(_mic(tester).glyphCrossfade, 1, reason: 'still armed at 58dp');

      await gesture.up();
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(_repo.uploadCalls, 0);
    });
  });

  group('the destructive disc stays readable', () {
    testWidgets('the glyph ink re-picks its role as the fill turns to error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      expect(
        _mic(tester).glyphColor,
        tester.element(find.byType(JeebMicHero)).jeebRoles.onAccent,
        reason: 'an untinted disc keeps the role it was measured against',
      );

      for (final double travel in <double>[32, 40, 48, 56, 60, 64]) {
        await gesture.moveTo(centre.translate(-travel, 0));
        await tester.pump();
        final JeebMicHero mic = _mic(tester);
        expect(
          _contrast(mic.discColor!, mic.glyphColor!),
          greaterThanOrEqualTo(4.35),
          reason: 'white on #FF5252 is 3.19:1 — the pair has to swap',
        );
      }
      expect(_mic(tester).glyphColor, _scheme(tester).onError);

      await gesture.up();
      await _flush(tester);
    });
  });

  group('the assistive route', () {
    testWidgets('a screen reader can throw away a recording it started', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(JeebMicHero)),
      );
      // The deprecated accessor still identifies the active test pipeline.
      final SemanticsOwner owner =
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner!;
      final int micId = tester
          .getSemantics(find.bySemanticsIdentifier('client_home_mic_cta'))
          .id;
      owner.performAction(micId, SemanticsAction.tap);
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.recording);

      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      final int cancelId = CustomSemanticsAction.getIdentifier(
        CustomSemanticsAction(label: l10n.homeMicCancelRecording),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('client_home_mic_cta'))
            .getSemanticsData()
            .customSemanticsActionIds,
        contains(cancelId),
        reason: 'the slide is raw pointer; AT needs an action of its own',
      );

      owner.performAction(micId, SemanticsAction.customAction, cancelId);
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(_repo.uploadCalls, 0, reason: 'a cancel must never upload');
      handle.dispose();
    });

    testWidgets('never speaks an instruction a hands-free user cannot obey', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final List<String> spoken = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            Object? message,
          ) async {
            final Map<Object?, Object?> data =
                (message! as Map<Object?, Object?>)['data']!
                    as Map<Object?, Object?>;
            final Object? line = data['message'];
            if (line is String) spoken.add(line);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      final cubit = _buildCubit();
      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(JeebMicHero)),
      );
      // The deprecated accessor still identifies the active test pipeline.
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        tester
            .getSemantics(find.bySemanticsIdentifier('client_home_mic_cta'))
            .id,
        SemanticsAction.tap,
      );
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.recording);

      expect(spoken, contains(l10n.homeMicLabelRecording));
      expect(spoken, isNot(contains(l10n.voiceRecordingStatusRecording)));
      expect(
        tester
            .widget<RecordingWaveform>(find.byType(RecordingWaveform))
            .semanticLabel,
        l10n.homeMicLabelRecording,
      );
      handle.dispose();
    });
  });

  group('the scrim and a hidden tab', () {
    testWidgets('a tab switch mid-recording never replays the wash on return', (
      tester,
    ) async {
      final ValueNotifier<bool> visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);
      final cubit = _buildCubit();
      await tester.pumpWidget(
        _harness(cubit, disableAnimations: false, visible: visible),
      );
      await _flush(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(JeebMicHero)),
      );
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 240));
      expect(_scrimOpacity(tester), 1);

      // The shell hides the tab: the screen cancels, but a muted ticker can
      // never advance the fade-out.
      visible.value = false;
      await _flush(tester);
      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(_scrimOpacity(tester), 0);

      visible.value = true;
      await tester.pump();
      expect(
        _scrimOpacity(tester),
        0,
        reason: 'the first frame back must not be a full-screen wash',
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(_scrimOpacity(tester), 0);

      await gesture.up();
      await _flush(tester);
    });

    testWidgets('an exit curve in flight lands instead of freezing', (
      tester,
    ) async {
      final ValueNotifier<bool> visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        _harness(_buildCubit(), disableAnimations: false, visible: visible),
      );
      await _flush(tester);

      final centre = tester.getCenter(find.byType(JeebMicHero));
      final gesture = await tester.startGesture(centre);
      await _flush(tester);
      final double restDx = _micDx(tester);

      await gesture.moveTo(centre.translate(-48, 0));
      await tester.pump();
      _ticks.add(const Duration(seconds: 3));
      await _flush(tester);
      await gesture.up();
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 40));
      expect(_micDx(tester), lessThan(restDx));

      visible.value = false;
      await _flush(tester);
      expect(tester.takeException(), isNull);

      visible.value = true;
      await tester.pump();
      expect(
        _micDx(tester),
        closeTo(restDx, 0.01),
        reason: 'a frozen glide would resume minutes later, on return',
      );
    });
  });
}
