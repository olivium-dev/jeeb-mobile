import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/voice_recording_screen_fixtures.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/load_test_fonts.dart';
import '../../support/midnight_test_harness.dart';

class _RejectedUploads implements VoiceRecordingRepository {
  int attempts = 0;
  @override
  Future<TranscriptionResult> upload(VoiceClip clip) async {
    attempts++;
    throw const VoiceUploadException(VoiceUploadFailure.unavailable);
  }
}

void main() {
  setUpAll(loadCatalogCaptureFonts);
  for (final locale in kFailureLocales) {
    for (final width in [320.0, 440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'upload retry readable and real: ${locale.languageCode} $width $scale',
          (tester) async {
            useReduceMotion(tester);
            tester.view.physicalSize = Size(width, 956);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final repo = _RejectedUploads();
            final clip = voiceRecordingScreenClip();
            final cubit = VoiceRecordingCubit(
              recorder: FakeVoiceRecorder(),
              player: FakeVoicePlayer(),
              repository: repo,
              tickerFactory: (_) => const Stream<Duration>.empty(),
              initialState: VoiceRecordingState(
                phase: VoiceRecordingPhase.recorded,
                clip: clip,
                elapsed: clip.duration,
              ),
            );
            addTearDown(cubit.close);
            await tester.pumpWidget(
              wrapMidnight(
                Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: VoiceRecordingScreen(cubit: cubit),
                  ),
                ),
                locale: locale,
                scrollable: false,
              ),
            );
            await cubit.send();
            await tester.pumpAndSettle();
            expect(repo.attempts, 1);
            expect(cubit.state.hasUploadFailure, isTrue);
            final context = tester.element(find.byType(VoiceRecordingScreen));
            final label = find.text(
              AppLocalizations.of(context).voiceRecordingRetryUploadSubmit,
            );
            final button = find.byKey(VoiceRecordingKeys.retryUploadButton);
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            expect(
              tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
              isFalse,
            );
            final labelRect = tester.getRect(label);
            final buttonRect = tester.getRect(button);
            expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
            expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
            expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
            expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
            expect(buttonRect.left, greaterThanOrEqualTo(0));
            expect(buttonRect.right, lessThanOrEqualTo(width));
            expect(tester.takeException(), isNull);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(repo.attempts, 2);
            expect(cubit.state.hasUploadFailure, isTrue);
            expect(cubit.state.clip, clip);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
