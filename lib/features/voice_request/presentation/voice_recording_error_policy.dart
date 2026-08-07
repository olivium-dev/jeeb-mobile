import '../../../l10n/app_localizations.dart';
import '../cubit/voice_recording_state.dart';

/// Errors that block recording until the user acts. Shared so `/voice-request`
/// and the client home dock cannot drift on which error is which.
bool isBlockingVoiceError(VoiceRecordingError error) =>
    error == VoiceRecordingError.permissionDenied ||
    error == VoiceRecordingError.recorderUnavailable;

bool isUploadVoiceError(VoiceRecordingError error) =>
    error == VoiceRecordingError.uploadNetwork ||
    error == VoiceRecordingError.uploadServer ||
    error == VoiceRecordingError.uploadUnknown;

bool isTransientVoiceError(VoiceRecordingError error) =>
    !isBlockingVoiceError(error) && !isUploadVoiceError(error);

String voiceErrorCopy(AppLocalizations l10n, VoiceRecordingError error) {
  switch (error) {
    case VoiceRecordingError.permissionDenied:
      return l10n.voiceRecordingErrorPermission;
    case VoiceRecordingError.recorderUnavailable:
      return l10n.voiceRecordingErrorUnavailable;
    case VoiceRecordingError.recorderFailed:
      return l10n.voiceRecordingErrorRecorderFailed;
    case VoiceRecordingError.tooShort:
      return l10n.voiceRecordingErrorTooShort;
    case VoiceRecordingError.maxDurationReached:
      return l10n.voiceRecordingErrorMaxReached;
    case VoiceRecordingError.uploadNetwork:
      return l10n.voiceRecordingErrorUploadNetwork;
    case VoiceRecordingError.uploadServer:
      return l10n.voiceRecordingErrorUploadServer;
    case VoiceRecordingError.uploadUnknown:
      return l10n.voiceRecordingErrorUploadGeneric;
  }
}
