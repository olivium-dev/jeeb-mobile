import '../../dev_flags.dart';
import 'model/obs_event.dart';

/// Compile-time master gate for the whole session-trace tool (architecture
/// contract §2). Reuses the existing devtool flag so a production build
/// (`JEEB_DEVTOOL_ENABLED` unset) tree-shakes every `Obs*` capturer,
/// observer, interceptor, writer, and dev-UI screen out of the binary — with
/// this const `false`, no code under `session_trace/` is even reachable, so
/// the tree-shaker drops it entirely. NEVER branch on this at runtime in a
/// way that could be `true` in prod.
///
/// OWNER RULING 2026-07-28 — "there is a dev red button, remove it".
///
/// This previously mirrored [kDevToolEnabled] exactly, which meant the floating
/// overlay bubble appeared in EVERY dev build. That is not an edge case: every
/// build our testers install carries `JEEB_DEVTOOL_ENABLED=true`, because the
/// seeded test login (`/dev/seed/user`) needs it. So the bubble was permanently
/// on screen for every device session, sitting on top of the routed content it
/// was meant to observe — and it renders in `colorScheme.primaryContainer`,
/// which this theme maps to a saturated orange-red, hence "the dev red button".
///
/// It is now OPT-IN behind its own define and OFF by default. The Dev Tool
/// still works exactly as before; only the overlay is gone unless explicitly
/// asked for:
///
///   flutter build apk --dart-define JEEB_DEVTOOL_ENABLED=true \
///                     --dart-define JEEB_OBS_OVERLAY=true
///
/// The production guarantee is UNCHANGED and slightly stronger: this can only
/// be true when the devtool flag is also true, so a production build still
/// tree-shakes the entire `session_trace/` tree.
const bool kObsCompiledIn = kDevToolEnabled && _kObsOverlayRequested;

const bool _kObsOverlayRequested =
    bool.fromEnvironment('JEEB_OBS_OVERLAY', defaultValue: false);

/// Runtime configuration for the session-trace tool.
///
/// Mutable singleton so the dev UI (module 5) and `main_devtool.dart` can
/// toggle it live. [enabled] defaults to [kObsCompiledIn]: ON in any devtool
/// build (so the tool — and the host-side ADB recorder that tails the trace
/// file — captures from first launch, no manual Start required), and a
/// compile-time `false` in production (where the whole tool is tree-shaken
/// out anyway). The dev UI can still toggle it off live.
final class ObservabilityConfig {
  ObservabilityConfig._();

  static final ObservabilityConfig instance = ObservabilityConfig._();

  /// Runtime master switch. ON by default in a devtool build ([kObsCompiledIn]
  /// true), a compile-time `false` in production.
  bool enabled = kObsCompiledIn;

  // Per-signal toggles (all default ON, effective only when [enabled]).
  bool captureScreens = true;
  bool captureApi = true;
  bool captureNotifications = true;
  bool captureInteractions = true;

  /// MANDATORY redaction. Default ON. When toggled OFF it relaxes ONLY the
  /// masking of NON-sensitive body/param fields — the hard secret set
  /// (Authorization headers, JWTs, bearer/FCM/device tokens, passwords,
  /// passcodes, OTP/handover codes, api keys/secrets, and pattern-matched
  /// secrets) is ALWAYS redacted regardless of this flag. See
  /// `SecretRedactor`.
  bool redactionEnabled = true;

  /// When false, api events record method/path/status/duration only (no
  /// bodies).
  bool captureApiBodies = true;

  /// Bodies larger than this (post-encode UTF-8 bytes) are truncated with a
  /// `'<truncated N bytes>'` marker. No magic literal at call sites — read
  /// this field instead.
  int maxBodyBytes = 8192;

  /// True when [type] should be recorded right now — folds in the master
  /// [enabled] switch AND the per-signal toggle, so a capturer needs no
  /// second `enabled` check once it has already gated on
  /// `Observability.instance.recording`.
  bool signalEnabled(ObsEventType type) {
    if (!enabled) return false;
    return switch (type) {
      ObsEventType.screen => captureScreens,
      ObsEventType.api => captureApi,
      ObsEventType.notification => captureNotifications,
      ObsEventType.interaction => captureInteractions,
    };
  }

  /// Convenience for `main_devtool.dart` / the dev UI: flip the master switch
  /// ON, leaving the per-signal toggles at their (already-ON) defaults.
  void enableAll() {
    enabled = true;
  }

  /// Resets every field to its default (master OFF). For the dev UI + tests.
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
