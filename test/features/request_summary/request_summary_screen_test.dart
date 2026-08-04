import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';
import 'package:jeeb_mobile/features/transcription/domain/transcript_audio_player.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

/// Mounts the redesigned summary on its own GoRouter — the screen reads
/// `context.canPop()` for the inline Edit/Change links and `context.go('/')`
/// for the back fallback, so a bare MaterialApp would assert.
Widget _harness(
  RequestDraft draft, {
  Locale locale = const Locale('en'),
  TranscriptAudioPlayer? player,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/request-summary',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/request-summary',
        builder: (BuildContext context, GoRouterState state) =>
            BlocProvider<RequestSummaryCubit>(
              create: (_) =>
                  RequestSummaryCubit(FakeRequestSubmissionService())
                    ..setDraft(draft),
              child: RequestSummaryScreen(audioPlayer: player),
            ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

/// No router at all — the shape that used to make `RequestTicket` throw at
/// build time (doc-13 P0-8b).
Widget _routerlessHarness(RequestDraft? draft) => MaterialApp(
  theme: AppTheme.midnight(),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: BlocProvider<RequestSummaryCubit>(
    create: (_) {
      final cubit = RequestSummaryCubit(FakeRequestSubmissionService());
      if (draft != null) cubit.setDraft(draft);
      return cubit;
    },
    child: const RequestSummaryScreen(),
  ),
);

void main() {
  group('RequestSummaryScreen — ticket', () {
    testWidgets('badge reads VOICE when the draft carries audio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const RequestDraft(
            description: 'Panadol Extra, one box',
            audioUrl: 'audio-123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VOICE REQUEST'), findsOneWidget);
      expect(find.text('TYPED REQUEST'), findsNothing);
    });

    testWidgets('badge reads TYPED when there is no audio at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const RequestDraft(description: 'Two kilos of tomatoes')),
      );
      await tester.pumpAndSettle();

      expect(find.text('TYPED REQUEST'), findsOneWidget);
      expect(find.text('VOICE REQUEST'), findsNothing);
    });

    testWidgets(
      'dedupe: description == transcription renders the sentence once',
      (tester) async {
        const String sentence = 'Bring me medicine from the pharmacy';
        await tester.pumpWidget(
          _harness(
            const RequestDraft(
              description: sentence,
              transcription: sentence,
              audioUrl: 'audio-123',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(sentence), findsOneWidget);
      },
    );

    testWidgets('distinct description and transcription both render', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const RequestDraft(
            description: 'Panadol Extra, one box',
            transcription: 'Bring me medicine from the pharmacy',
            audioUrl: 'audio-123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bring me medicine from the pharmacy'), findsOneWidget);
      expect(find.text('Panadol Extra, one box'), findsOneWidget);
    });

    testWidgets('live voice path: tier, route and photo rows all collapse', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const RequestDraft(
            description: 'Bring me medicine',
            transcription: 'Bring me medicine',
            audioUrl: 'audio-123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No tier chip, no rail labels, no photo counter — the draft carries
      // none of them and the ticket never fabricates a row.
      expect(find.text('Pickup'), findsNothing);
      expect(find.text('Drop-off'), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(find.byIcon(Icons.location_on), findsNothing);
    });

    testWidgets('a populated draft renders tier copy, both stops and photos', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const RequestDraft(
            description: 'Panadol Extra, one box',
            tierName: 'flash',
            pickupAddress: 'Pharmacie du Musee',
            dropoffAddress: 'Rue Monot 42',
            photoUrls: <String>['a', 'b'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The raw slug never reaches the user — it resolves to catalog copy.
      expect(find.text('flash'), findsNothing);
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Pharmacie du Musee'), findsOneWidget);
      expect(find.text('Drop-off'), findsOneWidget);
      expect(find.text('Rue Monot 42'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      // doc-13 P0-8(c): the counter is a real CLDR plural now.
      expect(find.text('2 photos attached'), findsOneWidget);
    });

    testWidgets('an unrecognised tier label is still shown verbatim', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const RequestDraft(
            description: 'Panadol Extra, one box',
            tierName: 'Hyperdrive',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hyperdrive'), findsOneWidget);
    });
  });

  group('RequestSummaryScreen — voice replay band', () {
    late Directory tempDir;
    late File clip;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('jeeb_summary_clip');
      clip = File('${tempDir.path}/clip.m4a')..writeAsStringSync('audio');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    testWidgets('play toggles the disc semantics label and drives the player', (
      tester,
    ) async {
      final FakeTranscriptAudioPlayer player = FakeTranscriptAudioPlayer();
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _harness(
          RequestDraft(
            description: 'Bring me medicine',
            audioUrl: 'audio-123',
            audioLocalPath: clip.path,
            audioDurationMs: 7000,
          ),
          player: player,
        ),
      );
      await tester.pumpAndSettle();

      // Duration comes from the clip, never fabricated.
      expect(find.text('0:07'), findsOneWidget);

      final Finder disc = find.bySemanticsIdentifier(
        'request_summary_voice_play',
      );
      expect(tester.getSemantics(disc).label, 'Play original');

      await tester.tap(disc);
      await tester.pump();

      expect(player.playCalls, 1);
      expect(player.lastPath, clip.path);
      expect(tester.getSemantics(disc).label, 'Pause');

      await tester.tap(disc);
      await tester.pump();

      expect(player.pauseCalls, 1);
      expect(tester.getSemantics(disc).label, 'Play original');

      handle.dispose();
    });

    testWidgets('completion resets the disc back to Play', (tester) async {
      final FakeTranscriptAudioPlayer player = FakeTranscriptAudioPlayer();
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _harness(
          RequestDraft(
            description: 'Bring me medicine',
            audioLocalPath: clip.path,
            audioDurationMs: 7000,
          ),
          player: player,
        ),
      );
      await tester.pumpAndSettle();

      final Finder disc = find.bySemanticsIdentifier(
        'request_summary_voice_play',
      );
      await tester.tap(disc);
      await tester.pump();
      expect(tester.getSemantics(disc).label, 'Pause');

      player.emitCompleted();
      await tester.pump();

      expect(tester.getSemantics(disc).label, 'Play original');
      handle.dispose();
    });

    testWidgets('a missing clip file yields a disabled disc that never plays', (
      tester,
    ) async {
      final FakeTranscriptAudioPlayer player = FakeTranscriptAudioPlayer();
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _harness(
          RequestDraft(
            description: 'Bring me medicine',
            audioLocalPath: '${tempDir.path}/gone.m4a',
            audioDurationMs: 7000,
          ),
          player: player,
        ),
      );
      await tester.pumpAndSettle();

      final Finder disc = find.bySemanticsIdentifier(
        'request_summary_voice_play',
      );
      // The disc still renders (the band is not a data gap) but it is inert:
      // the recorder's temp file was reaped, so there is nothing to play.
      expect(disc, findsOneWidget);

      await tester.tap(disc);
      await tester.pump();
      expect(player.playCalls, 0);

      handle.dispose();
    });

    testWidgets('no duration on the draft renders no read-out', (tester) async {
      await tester.pumpWidget(
        _harness(
          RequestDraft(
            description: 'Bring me medicine',
            audioLocalPath: clip.path,
          ),
          player: FakeTranscriptAudioPlayer(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(':'), findsNothing);
      expect(
        find.bySemanticsIdentifier('request_summary_voice_play'),
        findsOneWidget,
      );
    });

    testWidgets('no local path renders no replay band at all', (tester) async {
      await tester.pumpWidget(
        _harness(
          const RequestDraft(
            description: 'Bring me medicine',
            audioUrl: 'audio-123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('request_summary_voice_play'),
        findsNothing,
      );
      // The badge still says VOICE — the two conditions are distinct.
      expect(find.text('VOICE REQUEST'), findsOneWidget);
    });
  });

  group('RequestSummaryScreen — locale + chrome', () {
    testWidgets('builds under ar without overflowing', (tester) async {
      await tester.pumpWidget(
        _harness(
          const RequestDraft(
            description: 'دواء من الفرماشية',
            transcription: 'جيب لي دوا من الفرماشية يلي حد البيت',
            audioUrl: 'audio-123',
            tierName: 'flash',
            pickupAddress: 'فرماشية المتحف',
            dropoffAddress: 'شارع مونو ٤٢',
            photoUrls: <String>['a', 'b'],
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('مراجعة وإرسال'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('request_summary_submit'),
        findsOneWidget,
      );
    });

    testWidgets('the frozen submit contracts both survive the rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const RequestDraft(description: 'Panadol Extra, one box')),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('request_summary_submit'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('request_summary.submit')), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('request_summary_back'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('request_summary_root'),
        findsOneWidget,
      );
    });
  });

  group('RequestSummaryScreen — Midnight', () {
    testWidgets('renders the content field, never a bare scaffold colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const RequestDraft(description: 'Panadol Extra, one box')),
      );
      await tester.pumpAndSettle();

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('the broadcast CTA is the screen\'s lone solid orange', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const RequestDraft(description: 'Panadol Extra, one box')),
      );
      await tester.pumpAndSettle();

      final BuildContext ctaContext = tester.element(
        find.byKey(const Key('request_summary.submit')),
      );
      expect(Theme.of(ctaContext).colorScheme.secondary, JeebMidnight.orange);
    });

    testWidgets('P0-8b: the ticket builds with no GoRouter ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _routerlessHarness(
          const RequestDraft(
            description: 'Panadol Extra, one box',
            tierName: 'flash',
            pickupAddress: 'Pharmacie du Musee',
            dropoffAddress: 'Rue Monot 42',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Panadol Extra, one box'), findsOneWidget);
      // canPop is false without a router, so the inline editors withdraw
      // instead of offering a pop that cannot happen.
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Change'), findsNothing);
    });

    testWidgets('a draftless cubit renders the loading empty-state family', (
      tester,
    ) async {
      await tester.pumpWidget(_routerlessHarness(null));
      await tester.pump();

      final JeebEmptyState empty = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(empty.status, JeebEmptyStateStatus.loading);
      expect(
        find.bySemanticsIdentifier('request_summary_submit'),
        findsNothing,
      );
    });
  });
}
