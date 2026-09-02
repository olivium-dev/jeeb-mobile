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
  test('production payload gates deny every local session-log marker', () {
    const markers = <String>[
      'JEEB_OBS_OVERLAY',
      'obs_trace',
      r'devtool\.session_logs',
      'Session Logs',
    ];
    final androidInspector = _source('tool/inspect_android_release_payload.sh');
    final androidNegative = _source(
      'tool/test_inspect_android_release_payload.sh',
    );
    final iosInspector = _source('tool/inspect_unsigned_ios_release.sh');
    _expectContainsAll(androidInspector, markers);
    _expectContainsAll(iosInspector, markers);
    _expectContainsAll(androidNegative, const <String>[
      'JEEB_OBS_OVERLAY',
      'obs_trace',
      'devtool.session_logs',
      'Session Logs',
    ]);
  });

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
    final project = _source('ios/Runner.xcodeproj/project.pbxproj');
    _expectContainsAll(signedBuilder, [
      '-hideShellScriptEnvironment',
      'APP_FLAVOR=staging',
      'https://app.jeeb.fds-1.com',
      'IOS_EXPORT_OPTIONS_PATH',
      'APP_STORE_CONNECT_API_KEY_PATH',
      'APP_STORE_CONNECT_API_KEY_ID',
      'APP_STORE_CONNECT_API_ISSUER_ID',
      'EXPECTED_FIREBASE_CLIENT_ID',
      'EXPECTED_FIREBASE_REVERSED_CLIENT_ID',
      'CODE_SIGN_STYLE=Automatic',
      r'OTHER_CODE_SIGN_FLAGS="--keychain ${SIGNING_KEYCHAIN_PATH}"',
      'IOS_SIGNING_KEYCHAIN_PATH',
      'IOS_DEVELOPMENT_SIGNING_IDENTITY_SHA1',
      'protected iOS signing keychain is missing',
      'protected iOS development identity fingerprint is malformed',
      'protected iOS development identity is unavailable',
      '-allowProvisioningUpdates',
      '-authenticationKeyPath',
      '-authenticationKeyID',
      '-authenticationKeyIssuerID',
      "stat -f '%Lp'",
      'openssl pkey',
      'export policy must use automatic signing',
      'export policy must remain local and must not upload',
      'export policy must remain TestFlight-internal-only',
      'export policy must not mutate the App Store build number',
      'export policy must not upload symbols',
      r'IOS_BUILD_NAME="${BUILD_NAME}"',
      r'IOS_BUILD_NUMBER="${BUILD_NUMBER}"',
      'IOS_BUILD_NAME must be explicit and valid',
      'IOS_BUILD_NUMBER must be explicit and valid',
      r'[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]',
    ]);
    expect(
      project,
      isNot(
        contains(
          '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Distribution";',
        ),
      ),
    );
    expect(signedBuilder, isNot(contains('CODE_SIGN_IDENTITY=')));
    expect(signedBuilder, isNot(contains('CODE_SIGN_STYLE=Manual')));
    expect(
      signedBuilder,
      isNot(contains('IOS_PROVISIONING_PROFILE_SPECIFIER')),
    );
    expect(signedBuilder, isNot(contains('IOS_SIGNING_CERTIFICATE')));
    expect('-allowProvisioningUpdates'.allMatches(signedBuilder).length, 2);
    expect(signedBuilder, isNot(contains(r'IOS_BUILD_NAME:-1.0.0')));
    expect(signedBuilder, isNot(contains(r'IOS_BUILD_NUMBER:-26082401')));
    expect(exportOptions, contains('<key>testFlightInternalTestingOnly</key>'));
    expect(exportOptions, contains('<key>signingStyle</key>'));
    _expectContainsAll(signedInspector, [
      'codesign --verify --deep --strict',
      'K5RDQ8J7AN.com.olivium.jeeb',
      'aps-environment',
      'applinks:app.jeeb.fds-1.com',
      ':com.apple.developer.applesignin',
      r'Print ${entitlement_path}:0',
      "'signed app'",
      "'embedded provisioning profile'",
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
      "grep -Fq 'unbound variable'",
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
    //
    // This used to assert a bare count of 2. That was brittle: adding the
    // staging POSITIVE control (which also names `devtool_shake`, to prove the
    // staging artifact actually CONTAINS the Dev Tool) pushed the count to 4
    // and reddened the contract without anything having weakened. Assert the
    // STRUCTURE instead — it is both stricter and stable, because it pins
    // where each occurrence must live rather than how many there are.
    final denyList = 'devtool_shake'.allMatches(
      inspector.split('== production ]]').last.split('== staging ]]').first,
    );
    expect(
      denyList.length,
      2,
      reason:
          'the production profile must forbid devtool_shake in BOTH the '
          'Dart snapshot and the native Runner binary',
    );
    expect(
      inspector,
      contains(r'if [[ "${RELEASE_PROFILE}" == production ]]; then'),
      reason:
          'developer-surface markers must be scoped to a profile that '
          'DEFAULTS to production, never unconditionally permitted',
    );
    expect(
      inspector,
      contains(r'RELEASE_PROFILE="${JEEB_IOS_RELEASE_PROFILE:-production}"'),
      reason: 'an unset or misspelled profile must inspect as a store build',
    );
    // And the staging artifact must PROVE it carries the tool, so a silent
    // fallback to plain `Release` cannot pass as a successful staging build.
    expect(
      'devtool_shake'.allMatches(inspector.split('== staging ]]').last).length,
      2,
      reason:
          'the staging positive control must assert the Dev Tool is '
          'present in BOTH binaries',
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
    final android = _source('.github/workflows/ci-android-stage.yml');
    final ios = _source('.github/workflows/ci-ios-stage.yml');
    _expectContainsAll(android, ['bash tool/test_android_release_signing.sh']);
    _expectContainsAll(ios, [
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
    for (final workflow in [android, ios]) {
      expect(workflow, isNot(contains('flutter build ipa')));
      expect(workflow, isNot(contains('upload-artifact')));
    }
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
      '.github/workflows/ci-flutter-stage.yml',
      '.github/workflows/ci-android-stage.yml',
      '.github/workflows/ci-ios-stage.yml',
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
    const omdsRevision = '459b724ad267d3f83858b8309c3ea8a4079309a0';
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
        '.github/workflows/ci-flutter-stage.yml',
        '.github/workflows/ci-android-stage.yml',
        '.github/workflows/ci-ios-stage.yml',
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

  test('trusted RC is protected-main-only, immutable, signed, and retained', () {
    final workflow = _source('.github/workflows/trusted-mobile-rc.yml');
    _expectContainsAll(workflow, [
      'workflow_dispatch:',
      'environment: mobile-rc',
      "api_get 'environments/mobile-rc'",
      '.deployment_branch_policy.protected_branches == true',
      '.deployment_branch_policy.custom_branch_policies == false',
      'checks: read',
      'Flutter CI + coverage (79%)',
      'Release security scans',
      'check-runs?filter=latest&per_page=100',
      'actions/workflows/ci.yml/runs?branch=main&event=push&head_sha=',
      '.path == ".github/workflows/ci.yml"',
      'max_by(.run_number)',
      '.status == "completed"',
      '.conclusion == "success"',
      'REVIEWED_SHA: \${{ inputs.reviewed_sha }}',
      r'[[ "${REVIEWED_SHA}" =~ ^[0-9a-f]{40}$ ]]',
      r'[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]',
      r'(( 10#${BUILD_NUMBER} <= 2100000000 ))',
      'CANDIDATE_PLATFORM: \${{ inputs.platform }}',
      r'"${CANDIDATE_PLATFORM}" == both',
      "inputs.platform != 'ios'",
      "inputs.platform != 'android'",
      r'git merge-base --is-ancestor "${REVIEWED_SHA}" HEAD',
      'persist-credentials: false',
      'flutter build appbundle --flavor production --release --no-pub',
      'bash tool/build_signed_ios_internal_candidate.sh',
      'environment: mobile-internal-distribution',
      'secrets.OMDS_FLUTTER_PAT',
      'secrets.APP_STORE_KEY_ID',
      'secrets.APP_STORE_ISSUER_ID',
      'secrets.APP_STORE_KEY_CONTENT_B64',
      'secrets.IOS_DEVELOPMENT_CERTIFICATE_P12_B64',
      'secrets.IOS_DEVELOPMENT_CERTIFICATE_PASSWORD',
      'secrets.IOS_DEVELOPMENT_CERTIFICATE_SHA256',
      'APP_STORE_CONNECT_API_KEY_PATH',
      'IOS_SIGNING_KEYCHAIN_PATH',
      'IOS_DEVELOPMENT_SIGNING_IDENTITY_SHA1',
      'security create-keychain',
      'security set-key-partition-list',
      'security delete-keychain',
      'Protected iOS keychain must contain exactly one usable development identity.',
      '1.2.840.113635.100.6.1.2',
      'Protected iOS development certificate fingerprint drifted.',
      'unset APP_STORE_KEY_CONTENT_B64',
      r'chmod 0600 "${firebase_plist}" "${maps_key_file}" "${api_key_path}"',
      'trap cleanup EXIT HUP INT TERM',
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
      'xcode_version="\$(xcodebuild -version)"',
      "grep -Fxq 'Xcode 26.6' <<<\"\${xcode_version}\"",
      'sdk_inventory="\$(xcodebuild -showsdks)"',
      "grep -Eq -- '-sdk iphoneos26\\.[0-9]+' <<<\"\${sdk_inventory}\"",
      'iphoneos_version="\$(xcrun --sdk iphoneos --show-sdk-version)"',
      "grep -Eq '^26\\.[0-9]+' <<<\"\${iphoneos_version}\"",
      "metadata_root='build/app/intermediates/merged_manifests/productionRelease'",
      '.artifactType.type == "MERGED_MANIFESTS"',
      '.applicationId == "com.olivium.jeeb"',
      '.variantName == "productionRelease"',
      'output-metadata.json',
      '.elements[0].versionCode == \$build_number',
      'build/provenance/android-rc.json',
      'build/provenance/ios-rc.json',
      r'$ARGS.named + {clarity_enabled: false, retained: true,',
      'uses: ./.github/actions/run-build-runner',
      'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
      'retention-days: 7',
      'compression-level: 0',
    ]);
    expect(r'$ARGS.named +'.allMatches(workflow).length, 2);
    expect(workflow, isNot(contains("'{platform, reviewed_sha")));
    expect(workflow, isNot(contains('pull_request_target')));
    expect(workflow, isNot(contains('MOBILE_RC_MAIN_RULESET_ID')));
    expect(workflow, isNot(contains('rulesets/')));
    expect(workflow, isNot(contains('required_reviewers')));
    expect(workflow, isNot(contains('IOS_DISTRIBUTION_CERT_P12_B64')));
    expect(workflow, isNot(contains('IOS_PROVISIONING_PROFILE_B64')));
    expect(workflow, isNot(contains('upload-google-play')));
    expect(workflow, isNot(contains('fastlane')));
    expect(workflow, isNot(contains('macos-latest')));
    expect(workflow, isNot(contains(r'(\.[0-9]+){1,2}')));
  });

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

  test(
    'trusted RC scopes platform secrets and reuses repository OMDS auth',
    () {
      final workflow = _source('.github/workflows/trusted-mobile-rc.yml');
      final androidStart = workflow.indexOf('  android-candidate:');
      final iosStart = workflow.indexOf('  ios-candidate:');
      expect(androidStart, greaterThanOrEqualTo(0));
      expect(iosStart, greaterThan(androidStart));
      final android = workflow.substring(androidStart, iosStart);
      final ios = workflow.substring(iosStart);
      expect(android, contains('secrets.OMDS_FLUTTER_PAT'));
      expect(android, contains('secrets.ANDROID_UPLOAD_KEYSTORE_B64'));
      expect(
        android,
        contains('secrets.ANDROID_FIREBASE_PLAY_OAUTH_CLIENT_ID'),
      );
      expect(android, isNot(contains('secrets.IOS_')));
      expect(android, isNot(contains('secrets.APP_STORE_CONNECT_')));
      expect(ios, contains('secrets.OMDS_FLUTTER_PAT'));
      expect(ios, contains('secrets.APP_STORE_KEY_ID'));
      expect(ios, contains('secrets.APP_STORE_ISSUER_ID'));
      expect(ios, contains('secrets.APP_STORE_KEY_CONTENT_B64'));
      expect(ios, contains('secrets.IOS_DEVELOPMENT_CERTIFICATE_P12_B64'));
      expect(ios, contains('secrets.IOS_DEVELOPMENT_CERTIFICATE_PASSWORD'));
      expect(ios, contains('secrets.IOS_DEVELOPMENT_CERTIFICATE_SHA256'));
      expect(ios, contains('APP_STORE_CONNECT_API_KEY_PATH'));
      expect(ios, contains('IOS_SIGNING_KEYCHAIN_PATH'));
      expect(ios, contains('IOS_DEVELOPMENT_SIGNING_IDENTITY_SHA1'));
      expect(ios, contains('Apple Development: Ouday Khaled (3T9KFY9HYY)'));
      expect(ios, contains('B76F89AC9D9C87A1E1446CE31E8513A8173D38FD'));
      expect(
        ios,
        isNot(
          contains(
            'Apple Development: khaledouday1990@gmail.com '
            '(3T9KFY9HYY)',
          ),
        ),
      );
      expect(ios, contains('signingStyle string automatic'));
      expect(ios, contains('uploadSymbols bool false'));
      expect(ios, isNot(contains('secrets.IOS_SIGNING_CERTIFICATE_')));
      expect(ios, isNot(contains('IOS_DISTRIBUTION_CERT_P12_B64')));
      expect(ios, isNot(contains('IOS_PROVISIONING_PROFILE_B64')));
      expect(ios, isNot(contains('secrets.ANDROID_')));
    },
  );

  test('iOS distribution consumes retained bytes and is internal-only', () {
    final workflow = _source(
      '.github/workflows/distribute-mobile-internal.yml',
    );
    _expectContainsAll(workflow, [
      'name: Distribute retained iOS RC internally',
      'environment: mobile-internal-distribution',
      'environments/mobile-internal-distribution',
      '.deployment_branch_policy.protected_branches == true',
      '.deployment_branch_policy.custom_branch_policies == false',
      '.path == ".github/workflows/trusted-mobile-rc.yml"',
      'and .head_sha == \$reviewed',
      'and .conclusion == "success"',
      'source_run_attempt',
      '.digest | sub("^sha256:"; "")',
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
      'source_run_id',
      'artifact_sha256',
      '*-dSYMs.zip',
      'Dual-store monotonic build-number preflight',
      'bundle exec fastlane preflight_internal',
      'needs: [source-policy, store-build-number-preflight]',
      'uses: ./.github/actions/setup-ruby',
      'working-directory: ios',
      'bundle exec fastlane ios internal',
      'secrets.GOOGLE_PLAY_JSON_KEY',
      'secrets.APP_STORE_KEY_ID',
      'secrets.APP_STORE_ISSUER_ID',
      'secrets.APP_STORE_KEY_CONTENT_B64',
      'stage: "internal_distribution"',
      'physical_device_verification: "pending"',
      'final_release_go: false',
    ]);
    for (final removedGate in [
      'android_e2e_run_id',
      'E2E_RUN_ID',
      'android-physical-e2e.yml',
      'android-physical-e2e-evidence',
      'validate_android_e2e_manifest.sh',
      'e2e_run_id',
      'e2e_run_attempt',
      'e2e_artifact_sha256',
      'e2e_manifest_sha256',
      'required_reviewers',
      'prevent_self_review',
      'inputs.platform',
      'DISTRIBUTION_PLATFORM',
      'rc_aab_sha256',
      'rc_android_provenance_sha256',
      'working-directory: android',
      'bundle exec fastlane android internal',
      'actions/download-artifact',
      'mapping.txt',
    ]) {
      expect(workflow, isNot(contains(removedGate)), reason: removedGate);
    }
    expect(
      'physical_device_verification: "pending"'.allMatches(workflow).length,
      1,
    );
    expect('final_release_go: false'.allMatches(workflow).length, 1);
    expect(r'$ARGS.named +'.allMatches(workflow).length, 1);
    expect(workflow, isNot(contains("'{platform, destination")));
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
      'devtool_launcher',
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
      'devtool_launcher',
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
