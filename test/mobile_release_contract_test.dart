import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _canonicalResolution =
    'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved';

String _source(String path) => File(path).readAsStringSync();

Map<String, String> _lockedVersions() {
  final versions = <String, String>{};
  String? package;
  for (final line in _source('pubspec.lock').split('\n')) {
    final header = RegExp(r'^  ([a-z0-9_]+):$').firstMatch(line);
    if (header != null) package = header.group(1);
    final version = RegExp(r'^    version: "([^"]+)"$').firstMatch(line);
    if (package != null && version != null) {
      versions[package] = version.group(1)!;
    }
  }
  return versions;
}

Map<String, String?> _swiftPackageVersions() {
  final json =
      jsonDecode(_source(_canonicalResolution)) as Map<String, dynamic>;
  final pins = json['pins']! as List<dynamic>;
  return {
    for (final pin in pins.cast<Map<String, dynamic>>())
      pin['identity']! as String:
          (pin['state']! as Map<String, dynamic>)['version'] as String?,
  };
}

List<String> _trackedIosResolutions() {
  final result = Process.runSync('git', ['ls-files', 'ios']);
  expect(result.exitCode, 0);
  return (result.stdout as String)
      .split('\n')
      .where((path) => path.endsWith('/Package.resolved'))
      .toList();
}

void _expectContainsAll(String source, Iterable<String> values) {
  for (final value in values) {
    expect(source, contains(value));
  }
}

void _registerAndroidContracts() {
  test('Android production signing inspects the certificate fingerprint', () {
    final gradle = _source('android/app/build.gradle');
    _expectContainsAll(gradle, [
      'verifyProductionReleaseSigning',
      'ANDROID_RELEASE_EXPECTED_CERT_SHA256',
      'java.security.KeyStore.getInstance',
      "java.security.MessageDigest.getInstance('SHA-256')",
      'certificate.encoded',
    ]);
    expect(gradle, isNot(contains('signingConfigs.debug')));
    expect(gradle, isNot(contains('keytool')));
  });

  test('Android negative signing gate is executable and artifact-safe', () {
    final contract = _source('tool/test_android_release_signing.sh');
    _expectContainsAll(contract, [
      ':app:assembleProductionRelease',
      ':app:bundleProductionRelease',
      'missing-fingerprint',
      'mismatched-fingerprint',
      'assert_no_release_artifact',
    ]);
    expect(contract, isNot(contains('-storepass ')));
    expect(contract, isNot(contains('-keypass ')));
  });

  test('Android cleartext policy exists only in the dev source set', () {
    final mainManifest = _source('android/app/src/main/AndroidManifest.xml');
    final devManifest = _source('android/app/src/dev/AndroidManifest.xml');
    final devPolicy = _source(
      'android/app/src/dev/res/xml/network_security_config.xml',
    );
    expect(mainManifest, contains('android:usesCleartextTraffic="false"'));
    expect(mainManifest, isNot(contains('networkSecurityConfig')));
    expect(devManifest, contains('networkSecurityConfig'));
    expect(devPolicy, contains('192.168.2.39'));
    expect(
      File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).existsSync(),
      isFalse,
    );
  });

  test('Android store Firebase config is protected and identity-gated', () {
    final validator = _source('tool/validate_android_google_services.sh');
    final wrapper = _source('tool/run_with_android_firebase_config.sh');
    _expectContainsAll(validator, [
      'REQUIRED_PROJECT_ID="jeeb-5a293"',
      'REQUIRED_PACKAGE="com.olivium.jeeb"',
      'ANDROID_FIREBASE_EXPECTED_APP_ID',
      'ANDROID_FIREBASE_EXPECTED_SHA1',
      'oauth_match_count',
    ]);
    expect(wrapper, contains('unset ANDROID_GOOGLE_SERVICES_JSON_B64'));
    expect(wrapper, contains('trap cleanup EXIT HUP INT TERM'));
    expect(
      _source('.gitignore'),
      contains('/android/app/google-services.json'),
    );
  });

  test('Android release App Links use staging while dev remains stable', () {
    final manifest = _source('android/app/src/main/AndroidManifest.xml');
    final gradle = _source('android/app/build.gradle');
    expect(manifest, contains(r'android:host="${APP_LINK_HOST}"'));
    _expectContainsAll(gradle, [
      "APP_LINK_HOST: 'app.jeeb.fds-1.com'",
      "manifestPlaceholders.APP_LINK_HOST = 'jeeb.app'",
      "manifestPlaceholders.APP_LINK_HOST = 'app.jeeb.fds-1.com'",
    ]);
    expect(manifest, isNot(contains('android:host="jeeb.app"')));
  });
}

void _registerIosContracts() {
  test('iOS production source is HTTPS-only and dev owns LAN exceptions', () {
    final production = _source('ios/Runner/Info.plist');
    final development = _source('ios/Runner/Info-dev.plist');
    expect(production, isNot(contains('NSAppTransportSecurity')));
    expect(production, isNot(contains('NSLocalNetworkUsageDescription')));
    expect(development, contains('NSLocalNetworkUsageDescription'));
    expect(development, contains('NSExceptionAllowsInsecureHTTPLoads'));
    expect(production, contains(r'$(GOOGLE_REVERSED_CLIENT_ID)'));
  });

  test('protected iOS config validates and cleans Google Sign-In inputs', () {
    final validator = _source('tool/validate_ios_google_service_info.sh');
    final mapsValidator = _source('tool/validate_ios_maps_api_key.sh');
    final wrapper = _source('tool/run_with_ios_firebase_config.sh');
    _expectContainsAll(validator, [
      'CLIENT_ID',
      'REVERSED_CLIENT_ID',
      'IS_SIGNIN_ENABLED',
      'REQUIRED_BUNDLE_ID="com.olivium.jeeb"',
    ]);
    expect(wrapper, contains('unset IOS_GOOGLE_SERVICE_INFO_PLIST_B64'));
    expect(wrapper, contains('unset IOS_GOOGLE_MAPS_API_KEY_FILE'));
    expect(wrapper, contains('ProtectedFirebase.xcconfig'));
    expect(wrapper, contains('GOOGLE_MAPS_API_KEY'));
    expect(wrapper, contains('trap cleanup EXIT HUP INT TERM'));
    expect(mapsValidator, contains(r'^AIza[A-Za-z0-9_-]{35}$'));
    expect(mapsValidator, contains(r'[[ "${key_mode}" == 600 ]]'));
  });

  test('iOS Release/Profile fail closed and initialize Google Maps', () {
    final release = _source('ios/Flutter/Release.xcconfig');
    final profile = _source('ios/Flutter/Profile.xcconfig');
    final plist = _source('ios/Runner/Info.plist');
    final appDelegate = _source('ios/Runner/AppDelegate.swift');
    expect(release, contains('#include "ProtectedFirebase.xcconfig"'));
    expect(profile, contains('#include "ProtectedFirebase.xcconfig"'));
    expect(release, isNot(contains('#include? "ProtectedFirebase.xcconfig"')));
    expect(profile, isNot(contains('#include? "ProtectedFirebase.xcconfig"')));
    expect(plist, contains(r'<string>$(GOOGLE_MAPS_API_KEY)</string>'));
    _expectContainsAll(appDelegate, [
      'import GoogleMaps',
      'GMSServices.provideAPIKey(mapsAPIKey)',
      'Required iOS Maps configuration is missing or invalid.',
    ]);
    final signedBuilder = _source(
      'tool/build_signed_ios_internal_candidate.sh',
    );
    final signedInspector = _source('tool/inspect_signed_ios_release.sh');
    final exportOptions = _source('ios/ExportOptions.Internal.plist');
    _expectContainsAll(signedBuilder, [
      '-allowProvisioningUpdates',
      '-hideShellScriptEnvironment',
      'APP_FLAVOR=staging',
      'https://app.jeeb.fds-1.com',
    ]);
    expect(exportOptions, contains('<key>testFlightInternalTestingOnly</key>'));
    expect(exportOptions, contains('<key>signingStyle</key>'));
    _expectContainsAll(signedInspector, [
      'codesign --verify --deep --strict',
      'K5RDQ8J7AN.com.olivium.jeeb',
      'aps-environment',
      'applinks:app.jeeb.fds-1.com',
    ]);
  });

  test('release identity and owner-gated entitlements remain explicit', () {
    final project = _source('ios/Runner.xcodeproj/project.pbxproj');
    final entitlements = _source('ios/Runner/Runner.Release.entitlements');
    _expectContainsAll(project, [
      'DEVELOPMENT_TEAM = K5RDQ8J7AN;',
      'PRODUCT_BUNDLE_IDENTIFIER = com.olivium.jeeb;',
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.Release.entitlements;',
    ]);
    expect(entitlements, contains('<string>production</string>'));
    expect(
      entitlements,
      contains('<string>applinks:app.jeeb.fds-1.com</string>'),
    );
  });

  test('iOS localhost protocol literal is vendor-provenance locked', () {
    final inspector = _source('tool/inspect_unsigned_ios_release.sh');
    _expectContainsAll(inspector, [
      'Frameworks/App.framework/App',
      'VerifyAssertionRequest.swift',
      'FIREBASE_VERIFY_ASSERTION_SHA256',
      'runner_localhost_count',
      'source_localhost_count',
      'shasum -a 256',
      '36f46bb2b04544a15ffb339ce522c3a943e9b061567352f078663d7067b8bd83',
    ]);
    expect(inspector, contains(r'if [[ "${runner_localhost_count}" != 0 ]]'));
    expect(inspector, contains(r'[[ "${runner_localhost_count}" == 1 ]]'));
    expect(inspector, contains(r'[[ "${source_localhost_count}" == 1 ]]'));
  });
}

void _registerDependencyContracts() {
  test('resolved Dart graph is the aligned FlutterFire generation', () {
    expect(_lockedVersions(), containsPair('firebase_core', '3.14.0'));
    expect(_lockedVersions(), containsPair('firebase_auth', '5.6.0'));
    expect(_lockedVersions(), containsPair('firebase_messaging', '15.2.7'));
    expect(_lockedVersions(), containsPair('firebase_crashlytics', '4.3.7'));
    expect(_lockedVersions(), containsPair('cloud_firestore', '5.6.9'));
    expect(_lockedVersions(), containsPair('image_cropper', '12.2.1'));
  });

  test('SwiftPM solely owns Firebase and TOCrop native dependencies', () {
    final versions = _swiftPackageVersions();
    expect(versions, containsPair('firebase-ios-sdk', '11.15.0'));
    expect(versions, containsPair('flutterfire', '3.14.0-firebase-core-swift'));
    expect(versions, containsPair('googlesignin-ios', '8.0.0'));
    expect(versions, containsPair('tocropviewcontroller', '3.2.0'));
    expect(_trackedIosResolutions(), [_canonicalResolution]);
    expect(
      _source('pubspec.yaml'),
      contains('enable-swift-package-manager: true'),
    );
    expect(
      _source('tool/build_unsigned_ios_release_contract.sh'),
      contains('FLUTTER_SWIFT_PACKAGE_MANAGER=true'),
    );
  });

  test('CocoaPods graph is retained but disjoint from SwiftPM ownership', () {
    final podfile = _source('ios/Podfile');
    final lock = _source('ios/Podfile.lock');
    for (final dependency in [
      'FirebaseCoreInternal',
      'FirebaseSharedSwift',
      'TOCropViewController',
    ]) {
      expect(podfile, isNot(contains("pod '$dependency'")));
      expect(lock, isNot(contains(dependency)));
    }
    expect(lock, contains('flutter_local_notifications'));
    expect(lock, contains('google_maps_flutter_ios'));
  });
}

void _registerCiContracts() {
  test('CI compiles synthetic unsigned iOS and executes Android negatives', () {
    final workflow = _source('.github/workflows/ci.yml');
    _expectContainsAll(workflow, [
      'bash tool/test_android_release_signing.sh',
      'bash tool/build_unsigned_ios_release_contract.sh',
      'bash tool/check_ios_dependency_ownership.sh',
      'pod install --deployment',
      "FLUTTER_SWIFT_PACKAGE_MANAGER: 'true'",
    ]);
    expect(workflow, isNot(contains('flutter build ipa')));
    expect(workflow, isNot(contains('upload-artifact')));
  });

  test('release gateway has no committed LAN fallback', () {
    final config = _source('lib/core/config/app_config.dart');
    final gateway = _source('lib/core/network/mock_gateway_client.dart');
    expect(config, contains("'GATEWAY_BASE_URL',\n    defaultValue: '',"));
    expect(config, isNot(contains('api.jeeb.app')));
    expect(gateway, isNot(contains('192.168.2.39')));
    expect(gateway, isNot(contains('api.jeeb.app')));
    expect(gateway, isNot(contains('_releaseFallbackBaseUrl')));
    expect(gateway, isNot(contains('unified-payment-gateway')));
    expect(gateway, isNot(contains('/v1/payments/')));
    expect(gateway, contains("uri.scheme == 'https'"));
    expect(gateway, contains('AppConfig.isDevelopmentFlavor'));
  });

  test('store identity is permanent while staging remains runtime config', () {
    final gradle = _source('android/app/build.gradle');
    final project = _source('ios/Runner.xcodeproj/project.pbxproj');
    _expectContainsAll(gradle, [
      'namespace "com.olivium.jeeb"',
      'applicationId "com.olivium.jeeb"',
      'targetSdk 36',
    ]);
    expect(gradle, isNot(contains('applicationIdSuffix ".staging"')));
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = com.olivium.jeeb;'));
  });
}

void main() {
  _registerAndroidContracts();
  _registerIosContracts();
  _registerDependencyContracts();
  _registerCiContracts();
}
