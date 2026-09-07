import 'package:flutter/foundation.dart';

/// Whether this build explicitly requested the Jeeber Dev Tool.
const bool kDevToolRequested = bool.fromEnvironment(
  'JEEB_DEVTOOL_ENABLED',
  defaultValue: false,
);

/// Whether this build is the STAGING internal-QA artifact.
///
/// Passed only by the protected Android Internal Testing workflow and by
/// `tool/build_signed_ios_internal_candidate.sh`. It is deliberately a
/// separate define from [kDevToolRequested]: a build must both request the Dev
/// Tool AND declare itself a staging artifact, so a stray
/// `JEEB_DEVTOOL_ENABLED=true` on a store build still resolves to `false`.
///
/// The native half is gated INDEPENDENTLY by `#if JEEB_DEV`, which the plain
/// `Release` configuration does not define. Both halves must agree for the Dev
/// Tool to exist, so neither define alone can put it in an App-Store-bound
/// binary.
const bool kStagingDevToolRequested = bool.fromEnvironment(
  'JEEB_STAGING_DEVTOOL',
  defaultValue: false,
);

/// Compile-time gate for the Jeeber Dev Tool.
///
/// Owner directive 2026-08-27: **the staging build must carry the Dev Tool.**
/// iOS has no launcher icon and no URL scheme, so without this a staging tester
/// has no way into the tool at all — the reason a TestFlight build shipped
/// without it and was useless for QA.
///
/// This is NOT a general release unlock. `kDebugMode` still covers local dev;
/// [kStagingDevToolRequested] covers exactly one artifact, the internal-only
/// staging artifact that is distributed only through Play Internal Testing or
/// internal TestFlight (`pilot(distribute_external: false)`). A plain `Release`
/// build — the one a store submission would use — satisfies neither branch.
const bool kDevToolEnabled =
    (kDebugMode || kStagingDevToolRequested) && kDevToolRequested;

/// True in debug or Dev-Tool-enabled builds; NEVER in a store build.
const bool kDevAffordancesAllowed = kDevToolEnabled || kDebugMode;

/// Proof-only action-snack lifetime (ms); non-positive values keep the default.
/// Honoured only under [kDevAffordancesAllowed], never in store builds.
const int kDevSnackActionMsOverride = int.fromEnvironment(
  'JEEB_DEV_SNACK_ACTION_MS',
  defaultValue: 0,
);

/// Whether this build requested the shake-to-open affordance for the Dev Tool.
///
/// Defaults ON so every Dev-Tool build gets it; pass
/// `--dart-define=JEEB_DEVTOOL_SHAKE=false` to compile just the shake wiring
/// out while keeping the rest of the Dev Tool.
const bool kShakeToDevToolRequested = bool.fromEnvironment(
  'JEEB_DEVTOOL_SHAKE',
  defaultValue: true,
);

/// Compile-time gate for shake-to-open-the-Dev-Tool (iOS entry point).
///
/// Derived from [kDevToolEnabled], so it is a compile-time `false` in every
/// release and profile build — the shake wiring, and with it the import of the
/// Dev Tool shell, tree-shakes out of the product binary. The native half of
/// the gesture is gated independently by `#if JEEB_DEV` in
/// `ios/Runner/AppDelegate.swift`; neither gate depends on the other.
const bool kShakeToDevToolEnabled = kDevToolEnabled && kShakeToDevToolRequested;

/// Hard assertion for code that must never run in production.
void assertDevToolOnly([String? context]) {
  if (!kDevToolEnabled) {
    throw StateError(
      'Dev Tool code path reached while the Dev Tool is disabled'
      '${context == null ? '' : ': $context'}',
    );
  }
}

/// Selects the Dev Tool only for its exact native initial route.
bool shouldLaunchDevTool({
  required bool enabled,
  required String initialRoute,
}) => enabled && initialRoute == '/devtool';
