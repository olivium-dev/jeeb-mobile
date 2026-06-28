#!/usr/bin/env bash
# SPRINT-001 cross-device unblock — run the Jeeb app against the REAL MSI backend.
#
# Why this exists:
#   * The compiled-in default GATEWAY_BASE_URL is https://api.jeeb.app (FROZEN by
#     base_url_convention_test.dart). That host FAILS DNS from the test devices,
#     so the dev build never reaches a real backend. Do NOT edit that default
#     (it is contract-pinned); override it at run time via --dart-define instead.
#   * The real backend is the native JeebGateway on the MSI box:
#       http://192.168.2.39:10090   (origin-only, no /v1 — each request adds /v1)
#   * This script performs a REAL OTP login. It intentionally passes NO
#     `jeeb.seam.session` intent extra, so the debug session-seam (which would
#     fabricate a `mock-jwt-access-*` token) is NEVER engaged. The app does a
#     genuine POST /v1/auth/otp/request + /v1/auth/otp/verify against :10090.
#
# Usage:
#   tool/run_realbackend_msi.sh android   # Android physical device (R5CT71TVVAJ)
#   tool/run_realbackend_msi.sh ios       # iOS Simulator (shares this Mac's LAN)
#   GATEWAY=http://<ip>:<port> tool/run_realbackend_msi.sh android   # override host
#
# Network notes (handed to the iOS / Android-native sprint, NOT changed here):
#   * :10090 is plaintext HTTP. Android release/marshmallow blocks cleartext to a
#     raw IP unless android/app/src/.../network_security_config.xml permits
#     192.168.2.39 (cleartextTrafficPermitted). The dev flavor is debuggable so
#     cleartext is allowed by default in debug, but confirm on-device.
#   * iOS ATS blocks plaintext HTTP unless Info.plist has an
#     NSAppTransportSecurity exception for 192.168.2.39 (NSAllowsLocalNetworking
#     or a per-domain NSExceptionAllowsInsecureHTTPLoads). Owned by the iOS sprint.
set -euo pipefail

GATEWAY="${GATEWAY:-http://192.168.2.39:10090}"
PLATFORM="${1:-android}"

COMMON_DEFINES=(
  --dart-define=GATEWAY_BASE_URL="${GATEWAY}"
  --dart-define=USE_MOCK_GATEWAY=false
)

echo "[run_realbackend_msi] platform=${PLATFORM} gateway=${GATEWAY}"
echo "[run_realbackend_msi] real OTP login only — no jeeb.seam.session extra is passed."

case "${PLATFORM}" in
  android)
    # Flavor 'dev' only changes app id/name; the URL comes from the dart-define.
    exec flutter run --flavor dev -d R5CT71TVVAJ "${COMMON_DEFINES[@]}"
    ;;
  ios)
    # iOS Simulator on this Mac reaches 192.168.2.39 over the host LAN.
    exec flutter run -d "iPhone" "${COMMON_DEFINES[@]}"
    ;;
  *)
    echo "unknown platform: ${PLATFORM} (use 'android' or 'ios')" >&2
    exit 2
    ;;
esac
