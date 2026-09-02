import '../../dev_flags.dart';
import 'model/obs_event.dart';

const bool kObsCompiledIn = kDevToolEnabled && _kObsOverlayRequested;

const bool _kObsOverlayRequested = bool.fromEnvironment(
  'JEEB_OBS_OVERLAY',
  defaultValue: false,
);

final class ObservabilityConfig {
  ObservabilityConfig._();

  static final ObservabilityConfig instance = ObservabilityConfig._();

  // Recording is always an explicit Dev Tool action, even in a compiled-in
  // build. Merely launching the app must not create or append a trace.
  bool enabled = false;

  bool captureScreens = true;
  bool captureApi = true;
  bool captureNotifications = true;
  bool captureInteractions = true;

  /// Compatibility-only view for older Dev Tool code. Redaction is mandatory;
  /// assigning `false` is intentionally ignored.
  @Deprecated('Session-trace redaction is always enabled')
  bool get redactionEnabled => true;

  @Deprecated('Session-trace redaction cannot be disabled')
  set redactionEnabled(bool _) {}

  bool captureApiBodies = true;

  int maxBodyBytes = 8192;

  bool signalEnabled(ObsEventType type) {
    if (!enabled) return false;
    return switch (type) {
      ObsEventType.screen => captureScreens,
      ObsEventType.api => captureApi,
      ObsEventType.notification => captureNotifications,
      ObsEventType.interaction => captureInteractions,
    };
  }

  void reset() {
    enabled = false;
    captureScreens = true;
    captureApi = true;
    captureNotifications = true;
    captureInteractions = true;
    captureApiBodies = true;
    maxBodyBytes = 8192;
  }
}
