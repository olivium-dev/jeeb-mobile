import '../../dev_flags.dart';
import 'model/obs_event.dart';

const bool kObsCompiledIn = kDevToolEnabled && _kObsOverlayRequested;

const bool _kObsOverlayRequested =
    bool.fromEnvironment('JEEB_OBS_OVERLAY', defaultValue: false);

final class ObservabilityConfig {
  ObservabilityConfig._();

  static final ObservabilityConfig instance = ObservabilityConfig._();

  bool enabled = kObsCompiledIn;

  bool captureScreens = true;
  bool captureApi = true;
  bool captureNotifications = true;
  bool captureInteractions = true;

  bool redactionEnabled = true;

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

  void enableAll() {
    enabled = true;
  }

  void reset() {
    enabled = false;
    captureScreens = true;
    captureApi = true;
    captureNotifications = true;
    captureInteractions = true;
    redactionEnabled = true;
    captureApiBodies = true;
    maxBodyBytes = 8192;
  }
}
