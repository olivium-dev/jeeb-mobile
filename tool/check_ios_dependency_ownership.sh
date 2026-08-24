#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PODFILE="${REPO_ROOT}/ios/Podfile"
POD_LOCK="${REPO_ROOT}/ios/Podfile.lock"
CANONICAL_RESOLUTION="ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved"
PROJECT_RESOLUTION="ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

fail() {
  printf 'iOS dependency ownership invalid: %s\n' "$1" >&2
  exit 1
}

[[ -s "${PODFILE}" ]] || fail 'Podfile is missing'
[[ -s "${POD_LOCK}" ]] || fail 'Podfile.lock is missing'
[[ -s "${REPO_ROOT}/${CANONICAL_RESOLUTION}" ]] ||
  fail 'canonical workspace Package.resolved is missing'
grep -Fq 'enable-swift-package-manager: true' "${REPO_ROOT}/pubspec.yaml" ||
  fail 'project SwiftPM opt-in is missing'
grep -Fq 'FLUTTER_SWIFT_PACKAGE_MANAGER=true' \
  "${REPO_ROOT}/tool/build_unsigned_ios_release_contract.sh" ||
  fail 'unsigned release contract does not force SwiftPM'
grep -Fq 'FLUTTER_SWIFT_PACKAGE_MANAGER:' \
  "${REPO_ROOT}/.github/workflows/ci.yml" ||
  fail 'CI does not force SwiftPM'

tracked_resolutions="$(
  git -C "${REPO_ROOT}" ls-files ios | grep '/Package.resolved$' || true
)"
[[ "${tracked_resolutions}" == "${CANONICAL_RESOLUTION}" ]] ||
  fail 'exactly the canonical workspace Package.resolved must be tracked'
if git -C "${REPO_ROOT}" ls-files --error-unmatch \
  "${PROJECT_RESOLUTION}" >/dev/null 2>&1; then
  fail 'redundant project Package.resolved must not be tracked'
fi

for dependency in FirebaseCoreInternal FirebaseSharedSwift TOCropViewController; do
  if grep -Eq "pod[[:space:]]+['\"]${dependency}['\"]" "${PODFILE}"; then
    fail 'SwiftPM-owned dependency is declared in the Podfile'
  fi
  if grep -Fq "${dependency}" "${POD_LOCK}"; then
    fail 'SwiftPM-owned dependency resolved through CocoaPods'
  fi
  if [[ -d "${REPO_ROOT}/ios/Pods" ]] && find "${REPO_ROOT}/ios/Pods" \
    \( -name "${dependency}" -o -name "${dependency}.framework" \) \
    -print -quit | grep -q .; then
    fail 'SwiftPM-owned dependency remains in the CocoaPods sandbox'
  fi
done

grep -Fq 'flutter_install_all_ios_pods' "${PODFILE}" ||
  fail 'Flutter CocoaPods integration is missing'
grep -Fq 'flutter_local_notifications' "${POD_LOCK}" ||
  fail 'CocoaPods plugin graph was not resolved'
grep -Fq 'google_maps_flutter_ios' "${POD_LOCK}" ||
  fail 'CocoaPods Google Maps plugin graph was not resolved'

assert_pods_config() {
  local config="$1"
  local pods_config="$2"
  grep -Fq "${pods_config}" "${REPO_ROOT}/ios/Flutter/${config}" ||
    fail 'Runner build configuration does not include its matching Pods config'
}
assert_pods_config Profile.xcconfig Pods-Runner.profile.xcconfig
assert_pods_config Release.xcconfig Pods-Runner.release.xcconfig
assert_pods_config Profile-dev.xcconfig Pods-Runner.profile-dev.xcconfig
assert_pods_config Release-dev.xcconfig Pods-Runner.release-dev.xcconfig
grep -Fq \
  'baseConfigurationReference = D30000000000000000000005 /* Profile.xcconfig */;' \
  "${REPO_ROOT}/ios/Runner.xcodeproj/project.pbxproj" ||
  fail 'Runner Profile is not wired to Profile.xcconfig'

if [[ -s "${REPO_ROOT}/ios/Pods/Manifest.lock" ]] &&
  ! cmp -s "${POD_LOCK}" "${REPO_ROOT}/ios/Pods/Manifest.lock"; then
  fail 'CocoaPods sandbox does not match Podfile.lock'
fi

python3 - "${REPO_ROOT}/${CANONICAL_RESOLUTION}" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

pins = data.get("pins", [])
identities = [pin.get("identity") for pin in pins]
if len(identities) != len(set(identities)):
    raise SystemExit("iOS dependency ownership invalid: duplicate SwiftPM pin")

versions = {
    pin["identity"]: pin.get("state", {}).get("version") for pin in pins
}
expected = {
    "firebase-ios-sdk": "11.15.0",
    "flutterfire": "3.14.0-firebase-core-swift",
    "googlesignin-ios": "8.0.0",
    "tocropviewcontroller": "3.2.0",
}
if any(versions.get(name) != version for name, version in expected.items()):
    raise SystemExit(
        "iOS dependency ownership invalid: canonical SwiftPM graph drifted"
    )
PY

GENERATED_PACKAGE="${REPO_ROOT}/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [[ -s "${GENERATED_PACKAGE}" ]]; then
  for plugin in firebase-core firebase-auth firebase-messaging image-cropper; do
    grep -Fq ".product(name: \"${plugin}\"" "${GENERATED_PACKAGE}" ||
      fail 'generated SwiftPM plugin graph is incomplete'
  done
fi

printf '%s\n' 'iOS dependency ownership: CocoaPods and SwiftPM graphs are disjoint.'
