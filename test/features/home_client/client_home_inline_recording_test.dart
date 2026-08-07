// Recording in place on the client home screen.
//
// The floating mic is the whole voice surface now: press-and-hold records
// without leaving `/`, and `ClientHomeVoiceDock` carries every state the disc
// cannot say on its own. These pin the frozen ids through EVERY phase, the
// permission-denied surface that would otherwise be silent, and the hand-off
// that seeds the compose session before `/client-location`.
//
// NOTE on [_flush]: `StreamSubscription.cancel()` never completes under
// `tester.pump()`, and `VoiceRecordingCubit.stopRecording()` awaits exactly
// that. Every release edge therefore needs a real-async turn.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';

import '../../support/sync_app_localizations.dart';

class _NoopSubmission implements RequestSubmissionService {
  @override
  Future<String> submit(RequestDraft draft) async => 'req-1';
}

/// `FakeTierRepository.defaultCatalog` carries no `serverId`, and a tier with a
/// null `wireId` is a guaranteed 400 `tier-required` on the create POST.
class _WiredTierRepository implements TierRepository {
  const _WiredTierRepository();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[
    Tier(
      id: TierId.standard,
      serverId: 'tier-standard',
      priceLow: 45000,
      priceHigh: 70000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.bikeOrScooter,
      slaMinutes: 240,
      recommended: true,
    ),
  ];
}

/// Holds `start()` open so a release can land BEFORE the platform recorder
/// returns — a real tap, and the first-run permission dialog stealing the touch.
class _GatedRecorder implements VoiceRecorder {
  final Completer<void> _gate = Completer<void>();
  final FakeVoiceRecorder _inner = FakeVoiceRecorder();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<void> start() async {
    await _gate.future;
    await _inner.start();
  }

  @override
  Future<VoiceClip> stop({required Duration recordedDuration}) =>
      _inner.stop(recordedDuration: recordedDuration);

  @override
  Future<void> cancel() => _inner.cancel();

  @override
  Future<void> deleteOwnedClip(VoiceClip clip) => _inner.deleteOwnedClip(clip);
}

/// Hand-driven so the elapsed clock advances without an unsettleable
/// `Stream.periodic`.
late StreamController<Duration> _ticks;
late FakeVoiceRecordingRepository _repo;

VoiceRecordingCubit _buildCubit({
  VoiceRecordingState initialState = const VoiceRecordingState(),
  VoiceRecorderFailure? startFailure,
  VoiceUploadFailure? uploadFailure,
  String? transcript,
  VoiceRecorder? recorder,
}) {
  _ticks = StreamController<Duration>.broadcast();
  _repo = FakeVoiceRecordingRepository(
    failure: uploadFailure,
    transcript: transcript,
  );
  return VoiceRecordingCubit(
    recorder: recorder ?? FakeVoiceRecorder(startFailure: startFailure),
    player: FakeVoicePlayer(),
    repository: _repo,
    tickerFactory: (_) => _ticks.stream,
    initialState: initialState,
  );
}

Future<void> _flush(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Widget _harness(
  VoiceRecordingCubit cubit, {
  void Function(Tier?)? onCreateRequest,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  bool disableAnimations = true,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: InMemoryClientHomeRepository(latency: Duration.zero),
          greetingNameProvider: () => 'Lina',
        ),
        child: ClientHomeScreen(
          initialTab: ClientHomeTab.pendingRequests,
          onCreateRequest: onCreateRequest ?? (_) {},
          voiceCubit: cubit,
        ),
      ),
    ),
  );
}

/// The invariants that must hold in every phase, not just the happy one.
void _expectFrozenIds() {
  expect(find.bySemanticsIdentifier('client_home_mic_cta'), findsOneWidget);
  expect(find.byType(JeebMicHero), findsOneWidget);
  expect(find.byType(FloatingActionButton), findsNothing);
  expect(
    find.bySemanticsIdentifier('orders_create_request_button'),
    findsOneWidget,
  );
}

final VoiceClip _clip = VoiceClip(
  bytes: Uint8List.fromList(List.filled(64, 0x55)),
  duration: const Duration(seconds: 4),
  sourcePath: '/tmp/clip.m4a',
);

void main() {
  tearDown(() async {
    await _ticks.close();
    await sl.reset();
  });

  group('the frozen ids survive every recording phase', () {
    final phases = <String, VoiceRecordingState>{
      'idle': const VoiceRecordingState(),
      'recording': const VoiceRecordingState(
        phase: VoiceRecordingPhase.recording,
        elapsed: Duration(seconds: 3),
      ),
      'recorded': VoiceRecordingState(
        phase: VoiceRecordingPhase.recorded,
        clip: _clip,
      ),
      'sending': VoiceRecordingState(
        phase: VoiceRecordingPhase.sending,
        clip: _clip,
      ),
      'upload failure': VoiceRecordingState(
        phase: VoiceRecordingPhase.recorded,
        clip: _clip,
        error: VoiceRecordingError.uploadNetwork,
      ),
      'permission denied': const VoiceRecordingState(
        error: VoiceRecordingError.permissionDenied,
      ),
    };
    for (final entry in phases.entries) {
      testWidgets('${entry.key} keeps one mic and one create surface', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _harness(_buildCubit(initialState: entry.value)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        _expectFrozenIds();
        expect(
          tester
              .getSemantics(
                find.bySemanticsIdentifier('orders_create_request_button'),
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        handle.dispose();
      });
    }
  });

  testWidgets('the dock is absent at rest and live while recording', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_buildCubit()));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('client_home_voice_status'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('client_home_voice_timer'), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);

    expect(
      find.bySemanticsIdentifier('client_home_voice_status'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('client_home_voice_timer'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('client_home_recording_waveform'),
      findsOneWidget,
    );
    // Recording started WITHOUT a route push — the screen never left home.
    expect(find.byType(ClientHomeScreen), findsOneWidget);

    await gesture.up();
    await _flush(tester);
  });

  testWidgets('press-and-hold records, release finalises and uploads', (
    tester,
  ) async {
    final cubit = _buildCubit(transcript: 'two kilos of apples');
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    expect(cubit.state.phase, VoiceRecordingPhase.recording);

    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    expect(find.text('00:03 / 1:00'), findsOneWidget);

    await gesture.up();
    await _flush(tester);

    expect(_repo.uploadCalls, 1);
    expect(_repo.lastClip?.duration, const Duration(seconds: 3));
    expect(find.byType(ClientHomeScreen), findsOneWidget);
    _expectFrozenIds();
  });

  testWidgets('a slide-cancel throws the clip away and never uploads', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final gesture = await tester.startGesture(centre);
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);

    await gesture.moveTo(
      centre.translate(-JeebMicHero.slideCancelThreshold - 8, 0),
    );
    await gesture.up();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.idle);
    expect(_repo.uploadCalls, 0);
    expect(
      find.bySemanticsIdentifier('client_home_voice_status'),
      findsNothing,
    );
  });

  testWidgets('a permission denial is visible on home, never silent', (
    tester,
  ) async {
    final cubit = _buildCubit(
      startFailure: VoiceRecorderFailure.permissionDenied,
    );
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    await gesture.up();
    await _flush(tester);

    expect(
      find.bySemanticsIdentifier('client_home_voice_blocked_retry'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('client_home_voice_type_cta'),
      findsOneWidget,
    );
    // Blocking errors are persistent, never a one-shot snackbar.
    expect(find.byType(SnackBar), findsNothing);
    _expectFrozenIds();
  });

  testWidgets('"Type instead" runs the host create flow', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        _buildCubit(
          initialState: const VoiceRecordingState(
            error: VoiceRecordingError.permissionDenied,
          ),
        ),
        onCreateRequest: (_) => taps += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('client_home_voice_type_cta'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('an upload failure keeps the clip with both exits', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _buildCubit(
          initialState: VoiceRecordingState(
            phase: VoiceRecordingPhase.recorded,
            clip: _clip,
            error: VoiceRecordingError.uploadNetwork,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('client_home_voice_retry_upload'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('client_home_voice_discard'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  // S2. A release too brief to be a hold is a TAP, and a tap is the second way
  // in — the old `tooShort` snackbar was failure-first teaching.
  testWidgets('a tap keeps recording instead of teaching the gesture', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    await gesture.up();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.recording);
    expect(find.text('Hold the button for at least a second.'), findsNothing);
    expect(find.text('Press and hold the mic to record.'), findsNothing);
    expect(
      find.bySemanticsIdentifier('client_home_voice_status'),
      findsOneWidget,
    );
    _expectFrozenIds();
  });

  testWidgets('a second tap stops the tap-started recording and uploads', (
    tester,
  ) async {
    final cubit = _buildCubit(transcript: 'two kilos of apples');
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final first = await tester.startGesture(centre);
    await _flush(tester);
    await first.up();
    await _flush(tester);
    expect(cubit.state.phase, VoiceRecordingPhase.recording);

    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);

    final second = await tester.startGesture(centre);
    await _flush(tester);
    await second.up();
    await _flush(tester);

    expect(_repo.uploadCalls, 1);
    expect(_repo.lastClip?.duration, const Duration(seconds: 3));
    expect(
      find.bySemanticsIdentifier('client_home_voice_status'),
      findsNothing,
    );
  });

  testWidgets('a hold after a tap still stops on release, never re-latches', (
    tester,
  ) async {
    final cubit = _buildCubit(transcript: 'apples');
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final tap = await tester.startGesture(centre);
    await _flush(tester);
    await tap.up();
    await _flush(tester);

    final hold = await tester.startGesture(centre);
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    await hold.up();
    await _flush(tester);

    expect(_repo.uploadCalls, 1);
    expect(_repo.lastClip?.duration, const Duration(seconds: 3));
  });

  testWidgets('a slide-cancel after a tap clears the latch and throws away', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final tap = await tester.startGesture(centre);
    await _flush(tester);
    await tap.up();
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);

    final slide = await tester.startGesture(centre);
    await _flush(tester);
    await slide.moveTo(
      centre.translate(-JeebMicHero.slideCancelThreshold - 8, 0),
    );
    await slide.up();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.idle);
    expect(_repo.uploadCalls, 0);
  });

  // A brush and a deliberate tap are the same gesture. Only the CONSEQUENCE
  // can tell them apart: the cap is not a stop the customer asked for.
  testWidgets('a latch nobody stopped never uploads itself at the cap', (
    tester,
  ) async {
    final cubit = _buildCubit(transcript: 'ambient noise');
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final brush = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    await brush.up();
    await _flush(tester);
    expect(cubit.state.phase, VoiceRecordingPhase.recording);

    _ticks.add(VoiceRecordingState.maxDuration);
    await _flush(tester);

    expect(
      _repo.uploadCalls,
      0,
      reason: 'a 60s clip from a pocket brush must not upload and hand off',
    );
    expect(
      cubit.state.phase,
      VoiceRecordingPhase.idle,
      reason: 'and it must not be left stranded either',
    );
    expect(find.byType(ClientHomeScreen), findsOneWidget);
  });

  testWidgets('a held clip that hits the cap still sends on release', (
    tester,
  ) async {
    final cubit = _buildCubit(transcript: 'two kilos of apples');
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final hold = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    _ticks.add(VoiceRecordingState.maxDuration);
    await _flush(tester);
    expect(cubit.state.phase, VoiceRecordingPhase.recorded);
    expect(_repo.uploadCalls, 0);

    await hold.up();
    await _flush(tester);
    expect(_repo.uploadCalls, 1);
  });

  // S2 blessed the tap; the tooShort copy must not answer it with "hold".
  testWidgets('a tap stopped under a second is never told to hold', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final first = await tester.startGesture(centre);
    await _flush(tester);
    await first.up();
    await _flush(tester);
    _ticks.add(const Duration(milliseconds: 600));
    await _flush(tester);

    final second = await tester.startGesture(centre);
    await _flush(tester);
    await second.up();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.idle);
    expect(_repo.uploadCalls, 0);
    // The screen-level cover for tooShort: reachable, and gesture-neutral.
    expect(find.text('Hold the button for at least a second.'), findsNothing);
    expect(
      find.text('Too short — record for at least a second.'),
      findsOneWidget,
    );
  });

  testWidgets('a hands-free recording is told how to stop, not how to slide', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final hold = await tester.startGesture(centre);
    await _flush(tester);
    // A finger IS on the glass here, so the slide instruction is obeyable.
    expect(find.text('Slide to cancel'), findsOneWidget);
    expect(find.text('Tap the mic to stop'), findsNothing);

    await hold.up();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.recording);
    expect(
      find.text('Tap the mic to stop'),
      findsOneWidget,
      reason: 'nothing is being held, so "Slide to cancel" cannot be obeyed',
    );
    expect(find.text('Slide to cancel'), findsNothing);
  });

  testWidgets('a sent clip seeds the compose session with a real tier', (
    tester,
  ) async {
    sl.registerSingleton<TierRepository>(const _WiredTierRepository());
    final controller = ComposeRequestController(_NoopSubmission());
    sl.registerSingleton<ComposeRequestController>(controller);

    await tester.pumpWidget(
      _harness(_buildCubit(transcript: 'two kilos of apples')),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    await gesture.up();
    await _flush(tester);

    // setTier clears the description, so a non-atomic seed would lose this.
    expect(controller.description, 'two kilos of apples');
    expect(controller.tier?.wireId, 'tier-standard');
  });

  testWidgets('a catalog with no wireId is tier-blocked, never a silent 400', (
    tester,
  ) async {
    sl.registerSingleton<TierRepository>(const FakeTierRepository());
    sl.registerSingleton<ComposeRequestController>(
      ComposeRequestController(_NoopSubmission()),
    );

    await tester.pumpWidget(_harness(_buildCubit(transcript: 'apples')));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    await gesture.up();
    await _flush(tester);

    expect(
      find.bySemanticsIdentifier('client_home_voice_retry_tier'),
      findsOneWidget,
    );
  });

  testWidgets('no tier means a recoverable dock, not a lost clip', (
    tester,
  ) async {
    sl.registerSingleton<TierRepository>(
      const FakeTierRepository(failWith: TierLoadFailure.network),
    );
    sl.registerSingleton<ComposeRequestController>(
      ComposeRequestController(_NoopSubmission()),
    );

    await tester.pumpWidget(
      _harness(_buildCubit(transcript: 'two kilos of apples')),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    await gesture.up();
    await _flush(tester);

    expect(
      find.bySemanticsIdentifier('client_home_voice_retry_tier'),
      findsOneWidget,
    );
    _expectFrozenIds();
  });

  testWidgets('tapping Retry on the tier dock replays the stranded clip', (
    tester,
  ) async {
    final repo = _FlakyTierRepository();
    sl.registerSingleton<TierRepository>(repo);
    final controller = ComposeRequestController(_NoopSubmission());
    sl.registerSingleton<ComposeRequestController>(controller);

    await tester.pumpWidget(
      _harness(_buildCubit(transcript: 'two kilos of apples')),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    await gesture.up();
    await _flush(tester);

    final retry = find.bySemanticsIdentifier('client_home_voice_retry_tier');
    expect(retry, findsOneWidget);

    repo.healthy = true;
    await tester.tap(retry);
    await _flush(tester);

    // The clip must reach the compose session, not evaporate with the dock.
    expect(controller.description, 'two kilos of apples');
    expect(controller.tier, isNotNull);
    expect(retry, findsNothing);
  });

  testWidgets('a second tier failure keeps the dock and its retry alive', (
    tester,
  ) async {
    sl.registerSingleton<TierRepository>(
      const FakeTierRepository(failWith: TierLoadFailure.network),
    );
    sl.registerSingleton<ComposeRequestController>(
      ComposeRequestController(_NoopSubmission()),
    );

    await tester.pumpWidget(_harness(_buildCubit(transcript: 'apples')));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    await gesture.up();
    await _flush(tester);

    final retry = find.bySemanticsIdentifier('client_home_voice_retry_tier');
    await tester.tap(retry);
    await _flush(tester);

    expect(retry, findsOneWidget);
    expect(
      find.bySemanticsIdentifier('client_home_voice_tier_dismiss'),
      findsOneWidget,
    );
  });

  testWidgets('a permission-denied dock can be dismissed', (tester) async {
    final cubit = _buildCubit(
      initialState: const VoiceRecordingState(
        error: VoiceRecordingError.permissionDenied,
      ),
    );
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    // Retry cannot win against an OS denial the platform will not re-prompt,
    // so an undismissable card would cover the order list forever.
    await tester.tap(
      find.bySemanticsIdentifier('client_home_voice_blocked_dismiss'),
    );
    await _flush(tester);

    expect(
      find.bySemanticsIdentifier('client_home_voice_status'),
      findsNothing,
    );
  });

  testWidgets('the recording timer never reorders under Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _buildCubit(
          initialState: const VoiceRecordingState(
            phase: VoiceRecordingPhase.recording,
            elapsed: Duration(seconds: 7),
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    final clock = find.text('00:07 / 1:00');
    expect(clock, findsOneWidget);
    expect(Directionality.of(tester.element(clock)), TextDirection.ltr);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode}: the recording strip fits 320dp at 2.0x text',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 720 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _harness(
            _buildCubit(
              initialState: const VoiceRecordingState(
                phase: VoiceRecordingPhase.recording,
                elapsed: Duration(seconds: 7),
              ),
            ),
            locale: locale,
            textScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('client_home_voice_timer'),
          findsOneWidget,
        );
        // An overflow is an exception the tester rethrows here.
        expect(tester.takeException(), isNull);
      },
    );
  }

  // The two halves of the release-beats-the-recorder race, which the screen now
  // tells apart by PointerUp vs PointerCancel rather than by guessing.
  testWidgets('a tap that beats the recorder keeps what the recorder opened', (
    tester,
  ) async {
    final recorder = _GatedRecorder();
    final cubit = _buildCubit(recorder: recorder);
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    await gesture.up();
    await _flush(tester);
    recorder.release();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.recording);
    expect(find.text('Press and hold the mic to record.'), findsNothing);
    expect(
      find.bySemanticsIdentifier('client_home_voice_status'),
      findsOneWidget,
    );
  });

  testWidgets('a stolen pointer still says to hold, and captures nothing', (
    tester,
  ) async {
    final recorder = _GatedRecorder();
    final cubit = _buildCubit(recorder: recorder);
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    // The first-run permission dialog cancels the touch; the recorder only
    // comes up once the customer has answered it.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    await gesture.cancel();
    await _flush(tester);
    recorder.release();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.idle);
    expect(_repo.uploadCalls, 0);
    expect(find.text('Press and hold the mic to record.'), findsOneWidget);
  });

  testWidgets('a stolen pointer mid-recording never latches the mic open', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    await _flush(tester);
    expect(cubit.state.phase, VoiceRecordingPhase.recording);

    await gesture.cancel();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.idle);
    expect(_repo.uploadCalls, 0);
  });

  testWidgets('a screen-reader tap toggles recording on then off', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final cubit = _buildCubit(transcript: 'apples');
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final mic = find.bySemanticsIdentifier('client_home_mic_cta');
    final owner = tester.binding.pipelineOwner.semanticsOwner!;
    owner.performAction(tester.getSemantics(mic).id, SemanticsAction.tap);
    await _flush(tester);
    expect(cubit.state.phase, VoiceRecordingPhase.recording);

    _ticks.add(const Duration(seconds: 3));
    await _flush(tester);
    owner.performAction(tester.getSemantics(mic).id, SemanticsAction.tap);
    await _flush(tester);

    expect(_repo.uploadCalls, 1);
    handle.dispose();
  });

  testWidgets('the dock hint arms and disarms with the slide', (tester) async {
    await tester.pumpWidget(_harness(_buildCubit()));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final gesture = await tester.startGesture(centre);
    await _flush(tester);
    expect(find.text('Slide to cancel'), findsOneWidget);

    await gesture.moveTo(
      centre.translate(-JeebMicHero.slideCancelThreshold - 8, 0),
    );
    await tester.pump();
    expect(find.text('Release to cancel'), findsOneWidget);
    expect(find.text('Slide to cancel'), findsNothing);

    // The arm does not latch: coming back under the wall must disarm.
    await gesture.moveTo(centre);
    await tester.pump();
    expect(find.text('Slide to cancel'), findsOneWidget);

    await gesture.up();
    await _flush(tester);
  });

  // Every other harness here pins `disableAnimations: true`, which is the ONE
  // branch where the mic's animated subtree never changes shape.
  testWidgets('slide-to-cancel still cancels with animations ENABLED', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(_harness(cubit, disableAnimations: false));
    await _flush(tester);

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final gesture = await tester.startGesture(centre);
    await _flush(tester);
    expect(cubit.state.phase, VoiceRecordingPhase.recording);

    final double restDx = tester.getCenter(find.byType(JeebMicHero)).dx;
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(centre.translate(-8.0 * step, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.byType(JeebMicHero)).dx,
      lessThan(restDx - 1),
      reason: 'the held disc must visibly follow the finger toward cancel',
    );
    expect(find.text('Release to cancel'), findsOneWidget);

    await gesture.up();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.idle);
    expect(_repo.uploadCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('under Arabic the cancel slide mirrors to the start edge', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await tester.pumpWidget(
      _harness(cubit, locale: const Locale('ar'), disableAnimations: false),
    );
    await _flush(tester);

    final centre = tester.getCenter(find.byType(JeebMicHero));
    final gesture = await tester.startGesture(centre);
    await _flush(tester);

    final double restDx = tester.getCenter(find.byType(JeebMicHero)).dx;
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(centre.translate(8.0 * step, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester.getCenter(find.byType(JeebMicHero)).dx,
      greaterThan(restDx + 1),
      reason: 'RTL cancel travels toward the RIGHT, and so must the disc',
    );

    await gesture.up();
    await _flush(tester);

    expect(cubit.state.phase, VoiceRecordingPhase.idle);
    expect(_repo.uploadCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

/// Fails until [healthy] flips — the exact shape the dock's Retry must survive.
class _FlakyTierRepository implements TierRepository {
  bool healthy = false;

  @override
  Future<List<Tier>> fetchTiers() async {
    if (!healthy) throw const TierLoadException(TierLoadFailure.network);
    return const _WiredTierRepository().fetchTiers();
  }
}
