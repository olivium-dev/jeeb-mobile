// MIDNIGHT · M3-45 capture. `VoiceRequestScreen` drops the delegate's `cubit`
// seam, so the catalog cannot mount the WRAPPER — only this one-off can.
@Tags(<String>['capture'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_request_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/load_test_fonts.dart';
import '../support/sync_app_localizations.dart';

const Size _kCanvas = Size(440, 956);
const String _kCapturePath = '/capture';

GoRouter _captureRouter(WidgetBuilder builder) => GoRouter(
  initialLocation: _kCapturePath,
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(),
      routes: <RouteBase>[
        GoRoute(
          path: _kCapturePath.substring(1),
          builder: (BuildContext context, _) => builder(context),
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(loadCatalogCaptureFonts);

  setUp(() {
    sl
      ..registerSingleton<VoiceRecorder>(FakeVoiceRecorder())
      ..registerSingleton<VoicePlayer>(FakeVoicePlayer())
      ..registerSingleton<VoiceRecordingRepository>(
        FakeVoiceRecordingRepository(),
      );
  });

  tearDown(() async => sl.reset());

  testWidgets(
    'capture voice-request__voicerequestscreen__0-idle-through-the-wrapper',
    (WidgetTester tester) async {
      tester.view.physicalSize = _kCanvas;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final GoRouter router = _captureRouter(
        (_) => VoiceRequestScreen(onSwitchToTyping: () {}),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        OmdsColorTokensProvider(
          tokens: jeebMidnightOmdsTokens,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: withCaptureTestFonts(AppTheme.midnight()),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<Object?>>[
              SyncAppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/redesign-midnight/captures/M3-45/'
          'voice-request__voicerequestscreen__0-idle-through-the-wrapper.png',
        ),
      );
    },
  );
}
