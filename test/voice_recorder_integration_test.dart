import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/domain/audioplayers_voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/record_voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

// ---------------------------------------------------------------------------
// Mocks: stand in for the platform plugins so the wrappers are exercised in
// pure Dart (no method-channel, no real mic / audio session).
// ---------------------------------------------------------------------------
class _MockAudioRecorder extends Mock implements AudioRecorder {}

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeRecordConfig extends Fake implements RecordConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRecordConfig());
    registerFallbackValue(DeviceFileSource('fallback'));
  });

  // -------------------------------------------------------------------------
  // RecordVoiceRecorder — wraps the `record` package behind VoiceRecorder.
  // -------------------------------------------------------------------------
  group('RecordVoiceRecorder (T-MOB-011)', () {
    late _MockAudioRecorder platform;
    late Directory tempDir;

    setUp(() async {
      platform = _MockAudioRecorder();
      tempDir = await Directory.systemTemp.createTemp('voice_rec_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    RecordVoiceRecorder build({ClipBytesReader? bytesReader}) {
      return RecordVoiceRecorder(
        recorder: platform,
        tempDirResolver: () async => tempDir,
        bytesReader: bytesReader ??
            (path) async => Uint8List.fromList(List<int>.filled(64, 0x42)),
      );
    }

    test('start throws permissionDenied when the mic permission is refused',
        () async {
      when(() => platform.hasPermission()).thenAnswer((_) async => false);

      final recorder = build();

      await expectLater(
        recorder.start(),
        throwsA(
          isA<VoiceRecorderException>().having(
            (e) => e.failure,
            'failure',
            VoiceRecorderFailure.permissionDenied,
          ),
        ),
      );
      // Must NOT have attempted to start the platform recorder after denial.
      verifyNever(() => platform.start(any(), path: any(named: 'path')));
    });

    test('start asks for permission then records to a temp m4a path',
        () async {
      when(() => platform.hasPermission()).thenAnswer((_) async => true);
      when(() => platform.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});

      final recorder = build();
      await recorder.start();

      final captured = verify(
        () => platform.start(any(), path: captureAny(named: 'path')),
      ).captured.single as String;
      expect(captured, startsWith(tempDir.path));
      expect(captured, endsWith('.m4a'));
    });

    test('stop reads the recorded bytes back into a VoiceClip with sourcePath',
        () async {
      const recordedPath = '/tmp/voice-clip.m4a';
      final payload = Uint8List.fromList(List<int>.filled(128, 0x7F));
      when(() => platform.hasPermission()).thenAnswer((_) async => true);
      when(() => platform.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
      when(() => platform.stop()).thenAnswer((_) async => recordedPath);

      final recorder = build(bytesReader: (path) async {
        expect(path, recordedPath);
        return payload;
      });

      await recorder.start();
      final clip = await recorder.stop(
        recordedDuration: const Duration(seconds: 3),
      );

      expect(clip.bytes, payload);
      expect(clip.duration, const Duration(seconds: 3));
      expect(clip.sourcePath, recordedPath);
      expect(clip.mimeType, 'audio/m4a');
    });

    test('stop throws unknown when the platform yields an empty buffer',
        () async {
      when(() => platform.hasPermission()).thenAnswer((_) async => true);
      when(() => platform.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
      when(() => platform.stop()).thenAnswer((_) async => '/tmp/empty.m4a');

      final recorder = build(bytesReader: (_) async => Uint8List(0));

      await recorder.start();
      await expectLater(
        recorder.stop(recordedDuration: const Duration(seconds: 2)),
        throwsA(
          isA<VoiceRecorderException>().having(
            (e) => e.failure,
            'failure',
            VoiceRecorderFailure.unknown,
          ),
        ),
      );
    });

    test('stop throws unknown when the platform returns a null path',
        () async {
      when(() => platform.hasPermission()).thenAnswer((_) async => true);
      when(() => platform.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
      when(() => platform.stop()).thenAnswer((_) async => null);

      // bytesReader returns data, but with no path nor active path the clip
      // can't be resolved — fresh recorder, never started.
      final recorder = RecordVoiceRecorder(
        recorder: platform,
        tempDirResolver: () async => tempDir,
        bytesReader: (_) async => Uint8List.fromList([1, 2, 3]),
      );

      await expectLater(
        recorder.stop(recordedDuration: const Duration(seconds: 2)),
        throwsA(
          isA<VoiceRecorderException>().having(
            (e) => e.failure,
            'failure',
            VoiceRecorderFailure.unknown,
          ),
        ),
      );
    });

    test('cancel aborts the platform recorder and deletes the temp file',
        () async {
      // Create a real temp file so cancel's delete path is exercised.
      final file = File('${tempDir.path}/clip-to-cancel.m4a');
      await file.writeAsBytes(Uint8List.fromList([0, 1, 2]));
      when(() => platform.hasPermission()).thenAnswer((_) async => true);
      when(() => platform.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
      when(() => platform.cancel()).thenAnswer((_) async {});

      // Force the active path to be the file we created by stubbing the
      // resolver to return our temp dir and pre-seeding via start().
      final recorder = RecordVoiceRecorder(
        recorder: platform,
        tempDirResolver: () async => tempDir,
        bytesReader: (_) async => Uint8List(0),
      );
      // Drive start so _activePath is populated, then point it at our file.
      await recorder.start();
      final startedPath = verify(
        () => platform.start(any(), path: captureAny(named: 'path')),
      ).captured.single as String;
      // Recreate the started file so cancel has something to delete.
      await File(startedPath).writeAsBytes(Uint8List.fromList([9, 9, 9]));
      expect(File(startedPath).existsSync(), isTrue);

      await recorder.cancel();

      verify(() => platform.cancel()).called(1);
      expect(File(startedPath).existsSync(), isFalse);
    });

    test('maps a permission-flavoured plugin error onto permissionDenied',
        () async {
      when(() => platform.hasPermission())
          .thenThrow(Exception('RECORD permission not granted'));

      final recorder = build();

      await expectLater(
        recorder.start(),
        throwsA(
          isA<VoiceRecorderException>().having(
            (e) => e.failure,
            'failure',
            VoiceRecorderFailure.permissionDenied,
          ),
        ),
      );
    });

    test('maps an unavailable-flavoured plugin error onto unavailable',
        () async {
      when(() => platform.hasPermission()).thenAnswer((_) async => true);
      when(() => platform.start(any(), path: any(named: 'path')))
          .thenThrow(Exception('Recorder is busy / unavailable'));

      final recorder = build();

      await expectLater(
        recorder.start(),
        throwsA(
          isA<VoiceRecorderException>().having(
            (e) => e.failure,
            'failure',
            VoiceRecorderFailure.unavailable,
          ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // AudioPlayersVoicePlayer — wraps `audioplayers` behind VoicePlayer.
  // -------------------------------------------------------------------------
  group('AudioPlayersVoicePlayer (T-MOB-011)', () {
    late _MockAudioPlayer platform;
    late StreamController<Duration> positionController;
    late StreamController<void> completeController;

    setUp(() {
      platform = _MockAudioPlayer();
      positionController = StreamController<Duration>.broadcast();
      completeController = StreamController<void>.broadcast();
      when(() => platform.onPositionChanged)
          .thenAnswer((_) => positionController.stream);
      when(() => platform.onPlayerComplete)
          .thenAnswer((_) => completeController.stream);
      when(() => platform.play(any())).thenAnswer((_) async {});
      when(() => platform.pause()).thenAnswer((_) async {});
      when(() => platform.stop()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await positionController.close();
      await completeController.close();
    });

    VoiceClip clip({String? path}) => VoiceClip(
          bytes: Uint8List.fromList(List<int>.filled(16, 0x11)),
          duration: const Duration(seconds: 4),
          sourcePath: path,
        );

    test('play streams a DeviceFileSource when the clip has a sourcePath',
        () async {
      final player = AudioPlayersVoicePlayer(player: platform);

      await player.play(
        clip(path: '/tmp/recorded.m4a'),
        onPosition: (_) {},
        onCompleted: () {},
      );

      final source =
          verify(() => platform.play(captureAny())).captured.single as Source;
      expect(source, isA<DeviceFileSource>());
      expect((source as DeviceFileSource).path, '/tmp/recorded.m4a');
    });

    test('play falls back to BytesSource when no sourcePath is present',
        () async {
      final player = AudioPlayersVoicePlayer(player: platform);

      await player.play(
        clip(),
        onPosition: (_) {},
        onCompleted: () {},
      );

      final source =
          verify(() => platform.play(captureAny())).captured.single as Source;
      expect(source, isA<BytesSource>());
    });

    test('play bridges position ticks and the completion event to callbacks',
        () async {
      final player = AudioPlayersVoicePlayer(player: platform);
      final positions = <Duration>[];
      var completed = 0;

      await player.play(
        clip(path: '/tmp/recorded.m4a'),
        onPosition: positions.add,
        onCompleted: () => completed++,
      );

      positionController.add(const Duration(seconds: 1));
      positionController.add(const Duration(seconds: 2));
      completeController.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(positions, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      expect(completed, 1);
    });

    test('stop cancels the subscriptions so no further ticks reach callbacks',
        () async {
      final player = AudioPlayersVoicePlayer(player: platform);
      final positions = <Duration>[];

      await player.play(
        clip(path: '/tmp/recorded.m4a'),
        onPosition: positions.add,
        onCompleted: () {},
      );
      await player.stop();

      positionController.add(const Duration(seconds: 9));
      await Future<void>.delayed(Duration.zero);

      expect(positions, isEmpty);
      verify(() => platform.stop()).called(1);
    });

    test('pause delegates to the platform player without tearing down streams',
        () async {
      final player = AudioPlayersVoicePlayer(player: platform);
      final positions = <Duration>[];

      await player.play(
        clip(path: '/tmp/recorded.m4a'),
        onPosition: positions.add,
        onCompleted: () {},
      );
      await player.pause();

      // After pause the subscription is still live (cubit re-resumes on toggle).
      positionController.add(const Duration(seconds: 3));
      await Future<void>.delayed(Duration.zero);

      expect(positions, [const Duration(seconds: 3)]);
      verify(() => platform.pause()).called(1);
    });
  });
}
