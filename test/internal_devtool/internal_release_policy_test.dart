import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/internal_release_policy.dart';

const _nativeAllowed = NativeInternalReleasePolicy(
  releaseBuild: true,
  internalFlavor: true,
  internalResource: true,
  dedicatedLauncher: true,
);

InternalReleasePolicyInput _validInput() => const InternalReleasePolicyInput(
  buildMode: InternalReleaseBuildMode.release,
  dartFlag: true,
  appFlavor: InternalReleasePolicy.stagingFlavor,
  gatewayOrigin: InternalReleasePolicy.gatewayOrigin,
  realtimeSocket: InternalReleasePolicy.realtimeSocket,
  clarityEnabled: false,
  clarityPrivacyApproved: false,
  clarityProjectId: '',
  native: _nativeAllowed,
);

void main() {
  test('exact internal release staging policy passes', () {
    expect(
      InternalReleasePolicy.evaluate(_validInput()),
      InternalReleasePolicyFailure.none,
    );
  });

  test('every independent policy drift fails closed', () {
    final valid = _validInput();
    final failures = <InternalReleasePolicyInput>[
      _copy(valid, dartFlag: false),
      _copy(valid, buildMode: InternalReleaseBuildMode.debug),
      _copy(valid, appFlavor: 'production'),
      _copy(valid, gatewayOrigin: 'https://example.invalid'),
      _copy(valid, realtimeSocket: 'wss://example.invalid/socket'),
      _copy(valid, clarityEnabled: true),
      _copy(valid, clarityPrivacyApproved: true),
      _copy(valid, clarityProjectId: 'project'),
      _copy(
        valid,
        native: const NativeInternalReleasePolicy(
          releaseBuild: true,
          internalFlavor: false,
          internalResource: true,
          dedicatedLauncher: true,
        ),
      ),
    ];
    for (final input in failures) {
      expect(
        InternalReleasePolicy.evaluate(input),
        isNot(InternalReleasePolicyFailure.none),
      );
    }
  });

  test('only the exact launcher route opens the restricted tool', () {
    expect(
      shouldLaunchInternalDevTool(
        initialRoute: '/devtool',
        failure: InternalReleasePolicyFailure.none,
        native: _nativeAllowed,
      ),
      isTrue,
    );
    for (final route in [
      '/',
      '/devtool/',
      '/DevTool',
      '/devtool?unsafe=true',
    ]) {
      expect(
        shouldLaunchInternalDevTool(
          initialRoute: route,
          failure: InternalReleasePolicyFailure.none,
          native: _nativeAllowed,
        ),
        isFalse,
      );
    }
    expect(
      shouldLaunchInternalDevTool(
        initialRoute: '/devtool',
        failure: InternalReleasePolicyFailure.native,
        native: _nativeAllowed,
      ),
      isFalse,
    );
    expect(
      shouldLaunchInternalDevTool(
        initialRoute: '/devtool',
        failure: InternalReleasePolicyFailure.none,
        native: const NativeInternalReleasePolicy(
          releaseBuild: true,
          internalFlavor: true,
          internalResource: true,
          dedicatedLauncher: false,
        ),
      ),
      isFalse,
    );
  });
}

InternalReleasePolicyInput _copy(
  InternalReleasePolicyInput source, {
  InternalReleaseBuildMode? buildMode,
  bool? dartFlag,
  String? appFlavor,
  String? gatewayOrigin,
  String? realtimeSocket,
  bool? clarityEnabled,
  bool? clarityPrivacyApproved,
  String? clarityProjectId,
  NativeInternalReleasePolicy? native,
}) => InternalReleasePolicyInput(
  buildMode: buildMode ?? source.buildMode,
  dartFlag: dartFlag ?? source.dartFlag,
  appFlavor: appFlavor ?? source.appFlavor,
  gatewayOrigin: gatewayOrigin ?? source.gatewayOrigin,
  realtimeSocket: realtimeSocket ?? source.realtimeSocket,
  clarityEnabled: clarityEnabled ?? source.clarityEnabled,
  clarityPrivacyApproved:
      clarityPrivacyApproved ?? source.clarityPrivacyApproved,
  clarityProjectId: clarityProjectId ?? source.clarityProjectId,
  native: native ?? source.native,
);
