import 'package:flutter/foundation.dart';

import 'app_config.dart';

enum InternalReleaseBuildMode { debug, profile, release }

enum InternalReleasePolicyFailure {
  none,
  dartFlag,
  buildMode,
  flavor,
  gateway,
  realtime,
  clarity,
  native,
}

final class NativeInternalReleasePolicy {
  const NativeInternalReleasePolicy({
    required this.releaseBuild,
    required this.internalFlavor,
    required this.internalResource,
    required this.dedicatedLauncher,
  });

  final bool releaseBuild;
  final bool internalFlavor;
  final bool internalResource;
  final bool dedicatedLauncher;

  bool get allowsInternalBuild =>
      releaseBuild && internalFlavor && internalResource;

  bool get allowsInternalTool => allowsInternalBuild && dedicatedLauncher;
}

final class InternalReleasePolicyInput {
  const InternalReleasePolicyInput({
    required this.buildMode,
    required this.dartFlag,
    required this.appFlavor,
    required this.gatewayOrigin,
    required this.realtimeSocket,
    required this.clarityEnabled,
    required this.clarityPrivacyApproved,
    required this.clarityProjectId,
    required this.native,
  });

  final InternalReleaseBuildMode buildMode;
  final bool dartFlag;
  final String appFlavor;
  final String gatewayOrigin;
  final String realtimeSocket;
  final bool clarityEnabled;
  final bool clarityPrivacyApproved;
  final String clarityProjectId;
  final NativeInternalReleasePolicy native;
}

abstract final class InternalReleasePolicy {
  static const String gatewayOrigin = 'https://app.jeeb.fds-1.com';
  static const String realtimeSocket =
      'wss://app.jeeb.fds-1.com/socket/websocket';
  static const String stagingFlavor = 'staging';

  static const bool _dartFlag = bool.fromEnvironment(
    'JEEB_INTERNAL_RELEASE',
    defaultValue: false,
  );

  static InternalReleasePolicyInput current(
    NativeInternalReleasePolicy native,
  ) => InternalReleasePolicyInput(
    buildMode: _currentBuildMode,
    dartFlag: _dartFlag,
    appFlavor: AppConfig.appFlavor,
    gatewayOrigin: AppConfig.gatewayBaseUrl,
    realtimeSocket: AppConfig.realtimeSocketUrl,
    clarityEnabled: AppConfig.clarityEnabled,
    clarityPrivacyApproved: AppConfig.clarityPrivacyApproved,
    clarityProjectId: AppConfig.clarityProjectId,
    native: native,
  );

  static InternalReleasePolicyFailure evaluate(
    InternalReleasePolicyInput input,
  ) {
    if (!input.dartFlag) return InternalReleasePolicyFailure.dartFlag;
    if (input.buildMode != InternalReleaseBuildMode.release) {
      return InternalReleasePolicyFailure.buildMode;
    }
    if (input.appFlavor != stagingFlavor) {
      return InternalReleasePolicyFailure.flavor;
    }
    if (input.gatewayOrigin != gatewayOrigin) {
      return InternalReleasePolicyFailure.gateway;
    }
    if (input.realtimeSocket != realtimeSocket) {
      return InternalReleasePolicyFailure.realtime;
    }
    if (!_clarityIsOff(input)) return InternalReleasePolicyFailure.clarity;
    if (!input.native.allowsInternalBuild) {
      return InternalReleasePolicyFailure.native;
    }
    return InternalReleasePolicyFailure.none;
  }

  static bool _clarityIsOff(InternalReleasePolicyInput input) =>
      !input.clarityEnabled &&
      !input.clarityPrivacyApproved &&
      input.clarityProjectId.isEmpty;

  static InternalReleaseBuildMode get _currentBuildMode => kReleaseMode
      ? InternalReleaseBuildMode.release
      : kProfileMode
      ? InternalReleaseBuildMode.profile
      : InternalReleaseBuildMode.debug;
}

bool shouldLaunchInternalDevTool({
  required String initialRoute,
  required InternalReleasePolicyFailure failure,
  required NativeInternalReleasePolicy native,
}) =>
    failure == InternalReleasePolicyFailure.none &&
    native.allowsInternalTool &&
    initialRoute == '/devtool';
