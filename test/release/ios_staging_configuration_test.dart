import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

/// Returns the configuration names listed by each `XCConfigurationList`,
/// keyed by the owner comment Xcode writes above it.
Map<String, List<String>> _configurationLists(String pbxproj) {
  final section = RegExp(
    r'/\* Begin XCConfigurationList section \*/(.*?)'
    r'/\* End XCConfigurationList section \*/',
    dotAll: true,
  ).firstMatch(pbxproj)!.group(1)!;

  final lists = <String, List<String>>{};
  final block = RegExp(
    r'\n\t\t[0-9A-F]{24} /\* (.*?) \*/ = \{\n(.*?)\n\t\t\};',
    dotAll: true,
  );
  for (final m in block.allMatches(section)) {
    lists[m.group(1)!] = RegExp(r'/\* ([\w-]+) \*/,')
        .allMatches(m.group(2)!)
        .map((c) => c.group(1)!)
        .toList();
  }
  return lists;
}

void main() {
  group('iOS staging configuration', () {
    // REGRESSION GUARD. `Release-staging` was first registered ONLY in the
    // Runner target's list and not the project's. Xcode does not fail on that:
    // it prints "Configuration Release-staging is not in the project. Building
    // default configuration." and silently builds plain `Release`, so `JEEB_DEV`
    // never applies and the staging build loses the Dev Tool while every other
    // check still passes. That is exactly the outcome this whole change exists
    // to prevent, so it gets a test rather than a comment.
    test('Release-staging is registered in BOTH configuration lists', () {
      final lists = _configurationLists(
        _source('ios/Runner.xcodeproj/project.pbxproj'),
      );

      final project = lists.entries
          .firstWhere((e) => e.key.contains('PBXProject "Runner"'))
          .value;
      final target = lists.entries
          .firstWhere((e) => e.key.contains('PBXNativeTarget "Runner"'))
          .value;

      expect(
        project,
        contains('Release-staging'),
        reason: 'absent from the PBXProject list, xcodebuild silently falls '
            'back to plain Release and the staging build ships with no Dev Tool',
      );
      expect(
        target,
        contains('Release-staging'),
        reason: 'the Runner target must be buildable in the staging '
            'configuration',
      );
    });

    test('EVERY target has Release-staging, not just Runner', () {
      // REGRESSION GUARD. Mapping `Release-staging` in the Podfile makes
      // CocoaPods evaluate that configuration for EVERY target. A target that
      // lacks it resolves to an empty SWIFT_VERSION, and `pod install` then
      // aborts the whole build with:
      //   "There may only be up to 1 unique SWIFT_VERSION per target.
      //    RunnerTests: Swift / RunnerTests: Swift 5.0"
      // That is a hard CI failure with a message that names Swift versions and
      // says nothing about configurations, so it is worth pinning explicitly.
      final lists = _configurationLists(
        _source('ios/Runner.xcodeproj/project.pbxproj'),
      );

      for (final entry in lists.entries) {
        expect(
          entry.value,
          contains('Release-staging'),
          reason: 'configuration list "${entry.key}" is missing '
              'Release-staging; CocoaPods will resolve an empty SWIFT_VERSION '
              'for that target and fail pod install',
        );
      }
    });

    test('Podfile.lock checksum matches the Podfile', () {
      // REGRESSION GUARD. CI runs `pod install --deployment`, which REFUSES any
      // lockfile change and fails with:
      //   "[!] There were changes to the lockfile in deployment mode:
      //    PODFILE CHECKSUM: New ... / Old ..."
      // Editing the Podfile without regenerating Podfile.lock therefore breaks
      // the iOS job with a message that never mentions the Podfile edit that
      // caused it. Cheap to assert here, expensive to rediscover in CI.
      final podfile = File('ios/Podfile').readAsBytesSync();
      final expected = sha1.convert(podfile).toString();
      final lock = _source('ios/Podfile.lock');

      expect(
        lock,
        contains('PODFILE CHECKSUM: $expected'),
        reason: 'ios/Podfile.lock records a stale PODFILE CHECKSUM; run '
            '`cd ios && pod install` and commit the lockfile, or CI\'s '
            '`pod install --deployment` will reject the build',
      );
    });

    test('CocoaPods maps Release-staging as a release configuration', () {
      expect(
        _source('ios/Podfile'),
        contains("'Release-staging' => :release"),
        reason: 'an unmapped configuration makes CocoaPods guess, which can '
            'link debug pods into a release artifact',
      );
    });

    test('the staging profile PROVES the Dev Tool is present, not just allowed',
        () {
      // A permissive deny-list only stops complaining; it cannot distinguish
      // "staging build with the Dev Tool" from "staging build that lost it".
      final scanner = _source('tool/inspect_unsigned_ios_release.sh');

      expect(
        scanner,
        contains(r'if [[ "${RELEASE_PROFILE}" == staging ]]; then'),
        reason: 'the staging artifact needs a POSITIVE control',
      );
      expect(
        scanner,
        contains("LC_ALL=C grep -aFq 'devtool_shake' \"\${RUNNER_BINARY}\" ||"),
        reason: 'the native half is the one a silent Release fallback drops, so '
            'it must be asserted present',
      );
    });

    test('plain Release stays the clean store configuration', () {
      final pbxproj = _source('ios/Runner.xcodeproj/project.pbxproj');
      final blocks = RegExp(
        r'/\* Release \*/ = \{\n\t+isa = XCBuildConfiguration;(.*?)\n\t+name = Release;',
        dotAll: true,
      ).allMatches(pbxproj);

      expect(blocks, isNotEmpty);
      for (final b in blocks) {
        expect(
          b.group(1),
          isNot(contains('JEEB_DEV')),
          reason: 'plain Release is what a store submission archives; it must '
              'never define JEEB_DEV',
        );
      }
    });
  });
}
