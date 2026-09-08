#!/usr/bin/env bash
# Distribution only: upload already-verified candidate symbols, never rebuild.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSYM_ARCHIVE="${1:?retained dSYM archive required}"
FIREBASE_PLIST="${2:?protected Firebase plist required}"
SDK_ROOT="${3:?locked Firebase SDK checkout required}"
IPA_ARCHIVE="${4:?verified retained IPA required}"
EXPECTED_IPA_SHA="${EXPECTED_IPA_SHA256:?verified IPA hash required}"
EXPECTED_SHA="${EXPECTED_DSYM_SHA256:?verified dSYM hash required}"
[[ "${EXPECTED_SHA}" =~ ^[0-9a-f]{64}$ ]] || exit 1
[[ -s "${DSYM_ARCHIVE}" && ! -L "${DSYM_ARCHIVE}" ]] || exit 1
[[ "$(shasum -a 256 "${DSYM_ARCHIVE}" | cut -d ' ' -f1)" == "${EXPECTED_SHA}" ]] || exit 1
[[ "${EXPECTED_IPA_SHA}" =~ ^[0-9a-f]{64}$ ]] || exit 1
[[ -s "${IPA_ARCHIVE}" && ! -L "${IPA_ARCHIVE}" ]] || exit 1
[[ "$(shasum -a 256 "${IPA_ARCHIVE}" | cut -d ' ' -f1)" == "${EXPECTED_IPA_SHA}" ]] || exit 1
bash "${REPO_ROOT}/tool/validate_ios_google_service_info.sh" "${FIREBASE_PLIST}" >/dev/null

sdk_revision="$(jq -er '.pins[] | select(.identity == "firebase-ios-sdk") | .state.revision' \
  "${REPO_ROOT}/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved")"
[[ "${sdk_revision}" =~ ^[0-9a-f]{40}$ ]] || exit 1
[[ "$(git -C "${SDK_ROOT}" rev-parse HEAD)" == "${sdk_revision}" ]] || exit 1
uploader="${SDK_ROOT}/Crashlytics/upload-symbols"
[[ -x "${uploader}" && ! -L "${uploader}" ]] || exit 1
[[ "$(git -C "${SDK_ROOT}" hash-object Crashlytics/upload-symbols)" == \
  "$(git -C "${SDK_ROOT}" rev-parse HEAD:Crashlytics/upload-symbols)" ]] || exit 1

umask 077
symbol_tmp="$(mktemp -d)"
trap 'rm -rf -- "${symbol_tmp}"' EXIT HUP INT TERM
# Inspect all entries before extraction, including symlinks and duplicates.
python3 - "${DSYM_ARCHIVE}" "${IPA_ARCHIVE}" "${symbol_tmp}" <<'PY'
import pathlib, stat, sys, zipfile
for source, target in zip(sys.argv[1:3], ('symbols', 'ipa')):
    with zipfile.ZipFile(source) as archive:
        names = set()
        if len(archive.infolist()) > 25000 or sum(e.file_size for e in archive.infolist()) > 4 * 1024**3:
            raise SystemExit('Archive exceeds extraction limits')
        for entry in archive.infolist():
            path = pathlib.PurePosixPath(entry.filename)
            mode = entry.external_attr >> 16
            normalized = str(path)
            if (path.is_absolute() or '..' in path.parts or '\\' in entry.filename
                    or normalized in names or normalized == '.'
                    or stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)):
                raise SystemExit('Unsafe archive entry')
            names.add(normalized)
        archive.extractall(pathlib.Path(sys.argv[3]) / target)
PY
app="$(find "${symbol_tmp}/ipa/Payload" -maxdepth 1 -type d -name '*.app' -print)"
[[ -n "${app}" && "${app}" != *$'\n'* ]] || exit 1
for binary in Runner App; do
  dwarf="$(find "${symbol_tmp}/symbols" -type f -path "*/Contents/Resources/DWARF/${binary}" -print)"
  [[ -n "${dwarf}" && "${dwarf}" != *$'\n'* ]] || exit 1
  executable="${app}/Runner"
  if [[ "${binary}" == App ]]; then executable="${app}/Frameworks/App.framework/App"; fi
  [[ -s "${executable}" ]] || exit 1
  dwarf_uuids="$(xcrun dwarfdump --uuid "${dwarf}" | awk '/^UUID:/ {print toupper($2), $3}' | sort)"
  executable_uuids="$(xcrun dwarfdump --uuid "${executable}" | awk '/^UUID:/ {print toupper($2), $3}' | sort)"
  [[ -n "${dwarf_uuids}" && "${dwarf_uuids}" == "${executable_uuids}" ]] || exit 1
  grep -Eq '^[0-9A-F-]+ \(arm64\)$' <<<"${dwarf_uuids}"
done
# Firebase's official uploader authenticates this upload using the existing
# GoogleService-Info.plist. No console login or new Firebase app is needed.
"${uploader}" -gsp "${FIREBASE_PLIST}" -p ios "${symbol_tmp}/symbols"
printf 'Crashlytics uploader completed for retained dSYM SHA256 %s\n' "${EXPECTED_SHA}"
