import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _canonicalResolution =
    'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved';

String _source(String path) => File(path).readAsStringSync();

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

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

void _expectBashPasses(String script, [List<String> arguments = const []]) {
  final result = Process.runSync('bash', [script, ...arguments]);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}

void _registerAndroidContracts() {
  test('Android production signing inspects the certificate fingerprint', () {
    final gradle = _source('android/app/build.gradle');
    _expectContainsAll(gradle, [
      'verifyProductionReleaseSigning',
      'ANDROID_UPLOAD_CERT_SHA1',
      'ANDROID_UPLOAD_CERT_SHA256',
      'java.security.KeyStore.getInstance',
      "java.security.MessageDigest.getInstance(algorithm)",
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
      'missing-sha256',
      'wrong-alias',
      'mismatched-sha1',
      'mismatched-sha256',
      'keytool -list -v',
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
      'REQUIRED_PROJECT_NUMBER="1051234312170"',
      'REQUIRED_PACKAGE="com.olivium.jeeb"',
      'ANDROID_FIREBASE_EXPECTED_APP_ID',
      'ANDROID_UPLOAD_CERT_SHA1',
      'ANDROID_UPLOAD_CERT_SHA256',
      'ANDROID_FIREBASE_UPLOAD_OAUTH_CLIENT_ID',
      'ANDROID_FIREBASE_PLAY_OAUTH_CLIENT_ID',
      'upload_oauth_match_count',
      'play_oauth_match_count',
      '2E:CF:AF:7F:13:AB:9E:B5:34:E4:04:AD:3B:A9:F6:B2:A1:EA:77:12',
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
  test('iOS source plists have non-empty media permission purposes', () {
    for (final path in ['ios/Runner/Info.plist', 'ios/Runner/Info-dev.plist']) {
      _expectBashPasses('tool/inspect_ios_permission_descriptions.sh', [
        path,
        'source plist',
      ]);
    }
  });

  test(
    'iOS permission inspector negatives execute and gate both artifacts',
    () {
      _expectBashPasses('tool/test_ios_permission_descriptions.sh');
      final unsigned = _source('tool/inspect_unsigned_ios_release.sh');
      final signed = _source('tool/inspect_signed_ios_release.sh');
      _expectContainsAll(unsigned, [
        'inspect_ios_permission_descriptions.sh',
        "'unsigned iOS app'",
      ]);
      _expectContainsAll(signed, [
        'inspect_ios_permission_descriptions.sh',
        "'signed IPA'",
      ]);
    },
  );

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
      'REQUIRED_PROJECT_NUMBER="1051234312170"',
      'IOS_FIREBASE_EXPECTED_CLIENT_ID',
      'IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID',
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
      '-hideShellScriptEnvironment',
      'APP_FLAVOR=staging',
      'https://app.jeeb.fds-1.com',
      'IOS_EXPORT_OPTIONS_PATH',
      'IOS_PROVISIONING_PROFILE_SPECIFIER',
      'EXPECTED_FIREBASE_CLIENT_ID',
      'EXPECTED_FIREBASE_REVERSED_CLIENT_ID',
      'CODE_SIGN_STYLE=Manual',
      'export policy must remain local and must not upload',
      'export policy must not mutate the App Store build number',
      'export policy must not upload symbols',
      r'IOS_BUILD_NAME="${BUILD_NAME}"',
      r'IOS_BUILD_NUMBER="${BUILD_NUMBER}"',
      'IOS_BUILD_NAME must be explicit and valid',
      'IOS_BUILD_NUMBER must be explicit and valid',
      r'[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]',
    ]);
    expect(signedBuilder, isNot(contains('-allowProvisioningUpdates')));
    expect(signedBuilder, isNot(contains('APP_STORE_CONNECT_')));
    expect(signedBuilder, isNot(contains(r'IOS_BUILD_NAME:-1.0.0')));
    expect(signedBuilder, isNot(contains(r'IOS_BUILD_NUMBER:-26082401')));
    expect(exportOptions, contains('<key>testFlightInternalTestingOnly</key>'));
    expect(exportOptions, contains('<key>signingStyle</key>'));
    _expectContainsAll(signedInspector, [
      'codesign --verify --deep --strict',
      'K5RDQ8J7AN.com.olivium.jeeb',
      'aps-environment',
      'applinks:app.jeeb.fds-1.com',
      'IOS_BUILD_NAME must be explicit',
      'IOS_BUILD_NUMBER must be explicit',
      r'[[ "${expected_build_name}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]',
    ]);
    expect(signedInspector, isNot(contains('26082401')));
    expect(signedInspector, isNot(contains('1.0.0')));
    final inspectorTest = _source('tool/test_inspect_signed_ios_release.sh');
    _expectContainsAll(inspectorTest, [
      '7.8.9',
      '987654',
      "'1.4' '1.4.0.1' 'release'",
      "validate_ios_versions \"\${INFO_PLIST}\" '' '987654'",
    ]);
    final unsignedBuilder = _source(
      'tool/build_unsigned_ios_release_contract.sh',
    );
    _expectContainsAll(unsignedBuilder, [
      'SYNTHETIC_BUILD_NAME=0.0.0',
      'SYNTHETIC_BUILD_NUMBER=1',
      '--build-name="\${SYNTHETIC_BUILD_NAME}"',
      '--build-number="\${SYNTHETIC_BUILD_NUMBER}"',
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
    // Shake-to-DevTool residue must be caught in BOTH scanned binaries: the
    // Dart AOT snapshot (App.framework/App) and the native Runner binary. The
    // two compile-out gates are independent, so one deny-list entry cannot
    // stand in for the other.
    expect(
      'devtool_shake'.allMatches(inspector).length,
      2,
      reason: 'the Dart and native deny-lists must each name devtool_shake',
    );
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
  test('release source contains no retired matching mutation route', () {
    final retired = RegExp(r'/v1/matching/(find-jeebers|broadcast)');
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final source in dartSources) {
      expect(
        source.readAsStringSync(),
        isNot(matches(retired)),
        reason: source.path,
      );
    }
  });

  test('every release build injects and inspects the realtime socket URL', () {
    final workflow = _source('.github/workflows/trusted-mobile-rc.yml');
    final signed = _source('tool/build_signed_ios_internal_candidate.sh');
    final unsigned = _source('tool/build_unsigned_ios_release_contract.sh');
    final androidInspector = _source('tool/inspect_android_release_payload.sh');
    final iosInspector = _source('tool/inspect_unsigned_ios_release.sh');
    _expectContainsAll(workflow, [
      "STAGING_REALTIME_SOCKET_URL: 'wss://app.jeeb.fds-1.com/socket/websocket'",
      'JEEB_REALTIME_SOCKET_URL=\${STAGING_REALTIME_SOCKET_URL}',
    ]);
    for (final source in [signed, unsigned]) {
      expect(source, contains('JEEB_REALTIME_SOCKET_URL='));
      expect(source, contains('--dart-define="JEEB_REALTIME_SOCKET_URL='));
    }
    for (final source in [androidInspector, iosInspector]) {
      expect(source, contains('EXPECTED_REALTIME_SOCKET_URL'));
      expect(source, contains('/v1/matching/(find-jeebers|broadcast)'));
    }
  });

  test('CI compiles synthetic unsigned iOS and executes Android negatives', () {
    final workflow = _source('.github/workflows/ci.yml');
    _expectContainsAll(workflow, [
      'bash tool/test_android_release_signing.sh',
      'bash tool/build_unsigned_ios_release_contract.sh',
      'bash tool/check_ios_dependency_ownership.sh',
      'bash tool/test_inspect_signed_ios_release.sh',
      'pod install --deployment',
      "FLUTTER_SWIFT_PACKAGE_MANAGER: 'true'",
      'runs-on: macos-26',
      '/Applications/Xcode_26.6.app/Contents/Developer',
      'sdk_inventory="\$(xcodebuild -showsdks)"',
      "grep -Eq -- '-sdk iphoneos26\\.[0-9]+' <<<\"\${sdk_inventory}\"",
    ]);
    expect(workflow, isNot(contains('flutter build ipa')));
    expect(workflow, isNot(contains('upload-artifact')));
  });

  test('Flutter and Gradle toolchains are repository-pinned', () {
    final fvm = jsonDecode(_source('.fvmrc')) as Map<String, dynamic>;
    expect(fvm['flutter'], '3.44.2');
    final setup = _source('.github/actions/setup-flutter/action.yml');
    _expectContainsAll(setup, [
      r'flutter-version: ${{ steps.fvm.outputs.version }}',
      'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2',
    ]);
    for (final path in [
      '.github/workflows/ci.yml',
      '.github/workflows/flutter-ci.yml',
      '.github/workflows/mobile-ci.yml',
      '.github/workflows/trusted-mobile-rc.yml',
    ]) {
      final workflow = _source(path);
      expect(workflow, contains('uses: ./.github/actions/setup-flutter'));
      expect(workflow, contains('uses: ./.github/actions/checkout-omds'));
      expect(workflow, isNot(contains('FLUTTER_VERSION:')));
      expect(workflow, isNot(contains('flutter-version: 3.44.2')));
    }
    const omdsRevision = '6f9c16670c1c5c7a1d21e76a4006fb1aec0fc575';
    expect(_source('.omds-revision').trim(), omdsRevision);
    final omdsCheckout = _source('.github/actions/checkout-omds/action.yml');
    _expectContainsAll(omdsCheckout, [
      r'ref: ${{ steps.revision.outputs.sha }}',
      'repository: olivium-dev/omds-flutter',
      'persist-credentials: false',
      'git -C __omds_checkout rev-parse HEAD',
    ]);
    final wrapper = _source('android/gradle/wrapper/gradle-wrapper.properties');
    expect(wrapper, contains('gradle-8.14.4-bin.zip'));
    expect(
      wrapper,
      contains(
        'distributionSha256Sum='
        'f1771298a70f6db5a29daf62378c4e18a17fc33c9ba6b14362e0cdf40610380d',
      ),
    );
    expect(File('android/gradlew').existsSync(), isTrue);
    expect(File('android/gradlew.bat').existsSync(), isTrue);
    expect(
      File('android/gradle/wrapper/gradle-wrapper.jar').existsSync(),
      isTrue,
    );
    expect(
      _sha256('android/gradle/wrapper/gradle-wrapper.jar'),
      '7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172',
    );
    _expectContainsAll(_source('.gitignore'), [
      '!android/gradle/wrapper/',
      '!android/gradle/wrapper/gradle-wrapper.properties',
      '!android/gradle/wrapper/gradle-wrapper.jar',
    ]);
  });

  test(
    'ordinary CI regenerates source and gates the measured coverage floor',
    () {
      for (final path in [
        '.github/workflows/ci.yml',
        '.github/workflows/flutter-ci.yml',
        '.github/workflows/mobile-ci.yml',
      ]) {
        expect(
          _source(path),
          contains('uses: ./.github/actions/run-build-runner'),
        );
      }
      final codegen = _source('.github/actions/run-build-runner/action.yml');
      _expectContainsAll(codegen, [
        'path: .dart_tool/build',
        "hashFiles('.fvmrc', 'pubspec.lock', 'build.yaml')",
        'dart run build_runner build --delete-conflicting-outputs',
      ]);
      final coverage = _source('.github/workflows/flutter-ci.yml');
      _expectContainsAll(coverage, [
        'VeryGoodOpenSource/very_good_coverage@c953fca3e24a915e111cc6f55f03f756dcb3964c',
        'min_coverage: 79',
      ]);
      expect(coverage, isNot(contains('continue-on-error')));
    },
  );

  test(
    'trusted RC is protected-main-only, immutable, signed, and retained',
    () {
      final workflow = _source('.github/workflows/trusted-mobile-rc.yml');
      _expectContainsAll(workflow, [
        'workflow_dispatch:',
        'environment: mobile-rc',
        'MOBILE_RC_MAIN_RULESET_ID',
        "api_get 'environments/mobile-rc'",
        'required_reviewers',
        'required_status_checks',
        'checks: read',
        'Flutter CI + coverage (79%)',
        'Release security scans',
        'check-runs?filter=latest&per_page=100',
        '.prevent_self_review == true',
        'required_approving_review_count',
        r'((.reviewers // []) | length) >= 1',
        r'[[ "${REVIEWED_SHA}" =~ ^[0-9a-f]{40}$ ]]',
        r'[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]',
        r'(( 10#${BUILD_NUMBER} <= 2100000000 ))',
        r'git merge-base --is-ancestor "${REVIEWED_SHA}" HEAD',
        'persist-credentials: false',
        'flutter build appbundle --flavor production --release --no-pub',
        'bash tool/build_signed_ios_internal_candidate.sh',
        'jarsigner -verify -strict -verbose -certs',
        'keytool -printcert -jarfile',
        '7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172',
        'bash tool/inspect_android_release_payload.sh',
        'build/app/outputs/mapping/productionRelease/mapping.txt',
        "-name '*.dSYM'",
        'mapping_sha256',
        'dsym_sha256',
        'source_run_attempt',
        'source_head_sha',
        'source_workflow_path',
        'clarity_enabled: false',
        'runs-on: macos-26',
        '/Applications/Xcode_26.6.app/Contents/Developer',
        "xcodebuild -showsdks | grep -Eq -- '-sdk iphoneos26\\.[0-9]+'",
        'output-metadata.json',
        '.elements[0].versionCode == \$build_number',
        'build/provenance/android-rc.json',
        'build/provenance/ios-rc.json',
        'retained: true, store_uploaded: false',
        'uses: ./.github/actions/run-build-runner',
        'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
        'retention-days: 7',
        'compression-level: 0',
      ]);
      expect(workflow, isNot(contains('pull_request_target')));
      expect(workflow, isNot(contains('upload-google-play')));
      expect(workflow, isNot(contains('fastlane')));
      expect(workflow, isNot(contains('macos-latest')));
      expect(workflow, isNot(contains(r'(\.[0-9]+){1,2}')));
    },
  );

  test('every release build keeps Clarity explicitly disabled', () {
    for (final path in [
      '.github/workflows/trusted-mobile-rc.yml',
      'tool/build_signed_ios_internal_candidate.sh',
      'tool/build_unsigned_ios_release_contract.sh',
    ]) {
      final source = _source(path);
      expect(source, contains('JEEB_CLARITY_ENABLED=false'), reason: path);
      expect(
        source,
        contains('JEEB_CLARITY_PRIVACY_APPROVED=false'),
        reason: path,
      );
      expect(source, isNot(contains('JEEB_CLARITY_ENABLED=true')));
      expect(source, isNot(contains('JEEB_CLARITY_PROJECT_ID=')));
    }
  });

  test('trusted RC keeps Android and iOS secret references disjoint', () {
    final workflow = _source('.github/workflows/trusted-mobile-rc.yml');
    final androidStart = workflow.indexOf('  android-candidate:');
    final iosStart = workflow.indexOf('  ios-candidate:');
    expect(androidStart, greaterThanOrEqualTo(0));
    expect(iosStart, greaterThan(androidStart));
    final android = workflow.substring(androidStart, iosStart);
    final ios = workflow.substring(iosStart);
    expect(android, contains('secrets.ANDROID_OMDS_READ_TOKEN'));
    expect(android, contains('secrets.ANDROID_UPLOAD_KEYSTORE_B64'));
    expect(android, contains('secrets.ANDROID_FIREBASE_PLAY_OAUTH_CLIENT_ID'));
    expect(android, isNot(contains('secrets.IOS_')));
    expect(android, isNot(contains('secrets.APP_STORE_CONNECT_')));
    expect(ios, contains('secrets.IOS_OMDS_READ_TOKEN'));
    expect(ios, contains('secrets.IOS_DISTRIBUTION_CERT_P12_B64'));
    expect(ios, contains('IOS_PROVISIONING_PROFILE_SPECIFIER'));
    expect(ios, contains('signingStyle string manual'));
    expect(ios, contains('uploadSymbols bool false'));
    expect(ios, isNot(contains('-allowProvisioningUpdates')));
    expect(ios, isNot(contains('secrets.APP_STORE_CONNECT_')));
    expect(ios, isNot(contains('secrets.ANDROID_')));
  });

  test('distribution consumes retained bytes and is internal-only', () {
    final workflow = _source(
      '.github/workflows/distribute-mobile-internal.yml',
    );
    _expectContainsAll(workflow, [
      'environment: mobile-internal-distribution',
      'environments/mobile-internal-distribution',
      'required_reviewers',
      '.prevent_self_review == true',
      'android_e2e_run_id:',
      '.path == ".github/workflows/trusted-mobile-rc.yml"',
      '.path == ".github/workflows/android-physical-e2e.yml"',
      'and .head_sha == \$reviewed',
      'source_run_attempt',
      'e2e_run_attempt',
      'android-physical-e2e-evidence-\${E2E_RUN_ID}-\${e2e_attempt}',
      '.digest | sub("^sha256:"; "")',
      'bash tool/validate_android_e2e_manifest.sh',
      'bash tool/validate_ios_rc_artifact.sh',
      'rc_ios_artifact_id',
      'rc_ios_archive_sha256',
      'rc_ipa_sha256',
      'rc_ios_provenance_sha256',
      'rc_dsym_sha256',
      'REST-download and verify exact retained iOS archive',
      'actions/artifacts/\${IOS_ARTIFACT_ID}/zip',
      'EXPECTED_ARCHIVE_SHA256',
      'EXPECTED_IPA_SHA256',
      'EXPECTED_PROVENANCE_SHA256',
      'EXPECTED_DSYM_SHA256',
      'actions/download-artifact@634f93cb2916e3fdff6788551b99b062d0335ce0',
      'source_run_id',
      'artifact_sha256',
      'mapping.txt',
      '*-dSYMs.zip',
      'store_uploaded == false',
      'Dual-store monotonic build-number preflight',
      'bundle exec fastlane preflight_internal',
      'needs: [source-policy, store-build-number-preflight]',
      'uses: ./.github/actions/setup-ruby',
      'working-directory: android',
      'working-directory: ios',
      'bundle exec fastlane android internal',
      'bundle exec fastlane ios internal',
      'secrets.GOOGLE_PLAY_JSON_KEY',
      'secrets.APP_STORE_KEY_ID',
      'secrets.APP_STORE_ISSUER_ID',
      'secrets.APP_STORE_KEY_CONTENT_B64',
    ]);
    expect(workflow, isNot(contains('android_e2e_evidence_sha256')));
    expect(
      workflow,
      contains(r'[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]'),
    );
    expect(workflow, isNot(contains(r'(\.[0-9]+){1,2}')));
    for (final prohibited in [
      'flutter build',
      'xcodebuild',
      'gradlew',
      'track: production',
      'submit_for_review',
      'deliver(',
    ]) {
      expect(workflow, isNot(contains(prohibited)));
    }

    final android = _source('android/fastlane/Fastfile');
    _expectContainsAll(android, [
      "lane :internal",
      "track: 'internal'",
      "release_status: 'completed'",
      'google_play_track_version_codes',
      'BuildNumberPolicy.require_newer!',
    ]);
    expect(android, isNot(contains('lane :production')));

    final ios = _source('ios/fastlane/Fastfile');
    _expectContainsAll(ios, [
      'app_store_connect_api_key',
      'AppStoreBuildInventory.global_max',
      'BuildNumberPolicy.parse_marketing_version!',
      'BuildNumberPolicy.require_newer!',
      'pilot(',
      'distribute_external: false',
      'skip_waiting_for_build_processing: false',
    ]);
    expect(ios, isNot(contains('latest_testflight_build_number')));
    expect(ios, isNot(contains('deliver(')));
    expect(ios, isNot(contains('submit_for_review')));
    expect(_source('Gemfile'), contains("gem 'fastlane', '2.238.0'"));
    expect(_source('Gemfile.lock'), contains('fastlane (2.238.0)'));

    final preflight = _source('fastlane/Fastfile');
    _expectContainsAll(preflight, [
      'lane :preflight_internal',
      'google_play_track_version_codes',
      'AppStoreBuildInventory.global_max',
      'BuildNumberPolicy.parse_marketing_version!',
      "destination: 'Google Play'",
      "destination: 'App Store Connect'",
    ]);
    expect(preflight, isNot(contains('latest_testflight_build_number')));
    expect(preflight, isNot(contains('upload_to_play_store')));
    expect(preflight, isNot(contains('pilot(')));
  });

  test('release evidence validators are fail-closed and negative-tested', () {
    final payload = _source('tool/inspect_android_release_payload.sh');
    _expectContainsAll(payload, [
      r'192\.168\.2\.(39|50)',
      r'10\.0\.2\.2',
      'emulator-',
      r'http://(localhost|127\.0\.0\.1)',
      r'api\.jeeb\.app',
      'devtool_shell\\.dart',
      'main_android_internal\\.dart',
      'DevToolApp',
      'devtool_shake',
      'InternalDevToolApp',
      'internal_devtool_root',
      'Jeeb Internal QA',
      'JEEB_INTERNAL_RELEASE=true',
      'JEEB_DEVTOOL_ENABLED=true',
      'JEEB_CLARITY_ENABLED',
      'JEEB_CLARITY_PRIVACY_APPROVED',
    ]);
    final payloadNegatives = _source(
      'tool/test_inspect_android_release_payload.sh',
    );
    _expectContainsAll(payloadNegatives, [
      '192.168.2.39',
      'emulator-5554',
      'http://localhost',
      'https://api.jeeb.app',
      'devtool_shell.dart',
      'main_android_internal.dart',
      'InternalDevToolApp',
      'devtool_shake',
      'internal_devtool_root',
      'JEEB_INTERNAL_RELEASE=true',
      'JEEB_DEVTOOL_ENABLED=true',
      'run_inspector true false',
      'run_inspector false true',
    ]);

    final evidence = _source('tool/validate_android_e2e_manifest.sh');
    _expectContainsAll(evidence, [
      '.schemaVersion == 1',
      '.verdict == "PASS"',
      '.stage == "pre_distribution_rc"',
      '.finalReleaseGo == false',
      'bundletool-derived-from-retained-aab',
      'JMS-JHP-001',
      'JMS-JHP-002',
      'JMS-JHP-003',
      'phone|otp|chat|location|latitude|longitude|password|secret|token|serial|udid',
    ]);
    final evidenceNegatives = _source(
      'tool/test_validate_android_e2e_manifest.sh',
    );
    _expectContainsAll(evidenceNegatives, [
      'wrong-aab',
      'emulator-device',
      'one-device',
      'failed-jms',
      'wrong-stage',
      'sensitive-field',
      'sideload-drift',
      "'1.4' '1.4.0.1' '' 'release'",
    ]);

    final iosArtifact = _source('tool/validate_ios_rc_artifact.sh');
    _expectContainsAll(iosArtifact, [
      r'[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]',
      'EXPECTED_IPA_SHA256',
      'EXPECTED_PROVENANCE_SHA256',
      'EXPECTED_DSYM_SHA256',
      'source_workflow_path == ".github/workflows/trusted-mobile-rc.yml"',
      'source_workflow_ref ==',
      'ipa_sha256=',
      'provenance_sha256=',
      'dsym_sha256=',
    ]);
    final iosArtifactNegatives = _source(
      'tool/test_validate_ios_rc_artifact.sh',
    );
    _expectContainsAll(iosArtifactNegatives, [
      'wrong-ipa',
      'wrong-dsym',
      'wrong-reviewed-sha',
      'wrong-run-attempt',
      'display-name-source',
      'wrong-workflow-ref',
      'mismatched source-policy IPA hash',
      'mismatched source-policy provenance hash',
      'mismatched source-policy dSYM hash',
    ]);
  });

  test('App Store build inventory is global, paginated, and read-only', () {
    final inventory = _source('fastlane/AppStoreBuildInventory.rb');
    _expectContainsAll(inventory, [
      "BUNDLE_ID = 'com.olivium.jeeb'",
      "IOS_PLATFORM = 'IOS'",
      'get_pre_release_versions(',
      'response.all_pages.map(&:to_models)',
      'get_builds(',
      'preReleaseVersion: pre_release_version_id',
      'parse_cf_bundle_version!',
      'BuildNumberPolicy.parse!',
    ]);
    expect(inventory, isNot(contains('patch_')));
    expect(inventory, isNot(contains('post_')));
    expect(inventory, isNot(contains('delete_')));

    final tests = _source('test/fastlane/app_store_build_inventory_test.rb');
    _expectContainsAll(tests, [
      'older_prerelease_version_can_hold_the_global_maximum',
      'equal_build_numbers_have_one_global_maximum',
      'malformed_cf_bundle_version_fails_closed',
      'empty_inventory_returns_zero',
      'every_prerelease_and_build_page_is_enumerated',
      "['1.4', '1.4.0.1', '', 'release']",
    ]);
  });

  test('release security and Ruby toolchains are repository-pinned', () {
    final security = _source('.github/workflows/release-security.yml');
    _expectContainsAll(security, [
      'name: Release security scans',
      'gitleaks_8.30.1_linux_x64.tar.gz',
      '551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb',
      'gitleaks git . --redact --verbose --exit-code 1',
      '--log-opts="\${base_sha}..\${head_sha}"',
      'bundler-audit --version 0.9.3',
      'bundle-audit check --update',
    ]);
    expect(security, isNot(contains('continue-on-error')));
    expect(_source('.ruby-version').trim(), '3.3.9');
    final rubySetup = _source('.github/actions/setup-ruby/action.yml');
    _expectContainsAll(rubySetup, [
      "version=\"\$(tr -d '[:space:]' <.ruby-version)\"",
      r'ruby-version: ${{ steps.ruby.outputs.version }}',
      'ruby/setup-ruby@95ef2b042f9d7a56d8268cba8559e2842e2ad01b',
    ]);
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
