import 'package:flutter/foundation.dart';

import 'dev_seam_config.dart';
import 'dev_seam_source.dart';

/// Global, debug-only holder of the resolved [DevSeamConfig].
///
/// One dev APK can render any screen / state / locale because every consumer
/// (router, locale cubit, splash host) reads [current] at RUNTIME instead of a
/// compile-time `const`. The value is resolved once during bootstrap from a
/// priority-ordered source list (intent extras → device file → dart-define),
/// then exposed through the typed getters below.
///
/// Release-inert by construction: [resolve] short-circuits to
/// [DevSeamConfig.empty] when `!kDebugMode`, and [current] returns [empty]
/// until/unless a debug resolve runs, so every getter is `false`/empty in
/// production.
class DevSeam {
  DevSeam._();

  static DevSeamConfig _current = DevSeamConfig.empty;

  /// The resolved config. [DevSeamConfig.empty] in release and before
  /// [resolve] completes.
  static DevSeamConfig get current => _current;

  /// Default source order: runtime sources first (so adb can drive a built
  /// APK), dart-define last (so existing build flows still work).
  static const List<DevSeamSource> _defaultSources = <DevSeamSource>[
    IntentExtrasSource(),
    DeviceFileSource(),
    DartDefineSource(),
  ];

  /// Resolves the seam from [sources] (defaults to [_defaultSources]) and
  /// stores the result in [current]. No-op in release builds. Each source is
  /// merged field-by-field: an earlier source overrides only the fields it
  /// actually provides, so e.g. an intent that sets only `jeeb.locale` still
  /// inherits a route from the device file or dart-define.
  static Future<void> resolve({List<DevSeamSource>? sources}) async {
    if (!kDebugMode) {
      _current = DevSeamConfig.empty;
      return;
    }
    var merged = DevSeamConfig.empty;
    for (final source in sources ?? _defaultSources) {
      merged = _mergePreferring(merged, await source.read());
    }
    _current = merged;
    if (!merged.isEmpty) {
      debugPrint('DevSeam resolved: $merged');
    }
  }

  /// Field-wise merge where [primary] (a higher-priority source) wins on any
  /// field it sets; [fallback] fills the gaps.
  static DevSeamConfig _mergePreferring(
    DevSeamConfig primary,
    DevSeamConfig fallback,
  ) {
    return DevSeamConfig(
      route: primary.route.isNotEmpty ? primary.route : fallback.route,
      chatSelector: primary.chatSelector.isNotEmpty
          ? primary.chatSelector
          : fallback.chatSelector,
      forcedLocale: primary.forcedLocale.isNotEmpty
          ? primary.forcedLocale
          : fallback.forcedLocale,
      holdSplash: primary.holdSplash || fallback.holdSplash,
    );
  }

  /// Test-only override; lets widget/unit tests inject a config without a
  /// platform channel. Asserts it is never used outside debug.
  @visibleForTesting
  static void debugOverride(DevSeamConfig config) {
    assert(kDebugMode, 'DevSeam.debugOverride must not run in release');
    _current = config;
  }

  /// Test-only reset to the inert default.
  @visibleForTesting
  static void debugReset() => _current = DevSeamConfig.empty;
}
