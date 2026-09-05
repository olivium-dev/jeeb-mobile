// VOICE-03 — `_wrap` classified recorder failures by sniffing
// `error.toString().toLowerCase().contains('permission')`, so a busy-recorder
// PlatformException whose MESSAGE mentioned permissions was read as a denied
// mic. The platform code is authoritative now; the sniff is the fallback.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/voice_request/domain/record_voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';

VoiceRecorderFailure _classify(Object raised) =>
    classifyRecorderFailure(raised).failure;

void main() {
  group('RecordVoiceRecorder · the platform code wins', () {
    test('PlatformException(record_permission) → permissionDenied', () {
      expect(
        _classify(PlatformException(code: 'record_permission')),
        VoiceRecorderFailure.permissionDenied,
      );
    });

    test('PlatformException(record_unavailable) → unavailable', () {
      expect(
        _classify(PlatformException(code: 'record_unavailable')),
        VoiceRecorderFailure.unavailable,
      );
    });

    test('PlatformException(busy) → unavailable', () {
      expect(
        _classify(PlatformException(code: 'busy')),
        VoiceRecorderFailure.unavailable,
      );
    });

    // The old sniff read this as a denied mic because the MESSAGE says so.
    test('a busy CODE wins over a message mentioning permission', () {
      expect(
        _classify(
          PlatformException(
            code: 'record_unavailable',
            message: 'the permission service is busy',
          ),
        ),
        VoiceRecorderFailure.unavailable,
      );
    });

    test('an unrecognised code falls back to the string sniff', () {
      expect(
        _classify(
          PlatformException(code: 'weird', message: 'permission denied'),
        ),
        VoiceRecorderFailure.permissionDenied,
      );
    });

    test('a bare Exception still classifies by its prose', () {
      expect(
        _classify(Exception('microphone unavailable')),
        VoiceRecorderFailure.unavailable,
      );
      expect(
        _classify(Exception('something else entirely')),
        VoiceRecorderFailure.unknown,
      );
    });

    test('an already-classified exception passes through untouched', () {
      expect(
        _classify(
          const VoiceRecorderException(VoiceRecorderFailure.permissionDenied),
        ),
        VoiceRecorderFailure.permissionDenied,
      );
    });
  });
}
