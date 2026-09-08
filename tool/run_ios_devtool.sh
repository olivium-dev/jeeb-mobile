#!/usr/bin/env bash

set -euo pipefail

locale="${JEEB_IOS_LOCALE:-en_US.UTF-8}"
export LANG="${locale}"
export LC_ALL="${locale}"

device="${1:-${JEEB_IOS_DEVICE:-iPhone 15}}"
base_url="${JEEB_IOS_BASE_URL:-http://192.168.2.39:10090}"
flutter_bin="${JEEB_FLUTTER_BIN:-flutter}"
mock_prefixes="${JEEB_USE_MOCK_PREFIXES:-false}"
realtime_socket_url="${JEEB_IOS_REALTIME_SOCKET_URL:-ws://192.168.2.39:5804/socket/websocket}"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [simulator-name-or-id]" >&2
  exit 64
fi

if [[ ! "${base_url}" =~ ^https?://[^[:space:]]+$ ]]; then
  echo "JEEB_IOS_BASE_URL must be an http(s) origin: ${base_url}" >&2
  exit 64
fi

if [[ "${mock_prefixes}" != "true" && "${mock_prefixes}" != "false" ]]; then
  echo "JEEB_USE_MOCK_PREFIXES must be true or false." >&2
  exit 64
fi

# Env-index decrypt key comes from the shell, never from this file (public repo).
extra_defines=()
if [[ -n "${JEEB_ENV_INDEX_KEY:-}" ]]; then
  extra_defines+=(--dart-define=JEEB_ENV_INDEX_KEY="${JEEB_ENV_INDEX_KEY}")
fi

exec "${flutter_bin}" run \
  --device-id "${device}" \
  --debug \
  --flavor dev \
  --dart-define=JEEB_MOCK_BASE_URL="${base_url}" \
  --dart-define=JEEB_USE_MOCK_PREFIXES="${mock_prefixes}" \
  --dart-define=JEEB_DEVTOOL_ENABLED=true \
  --dart-define=JEEB_OBS_OVERLAY=true \
  --dart-define=JEEB_REALTIME_TRACKING=true \
  --dart-define=JEEB_REALTIME_SOCKET_URL="${realtime_socket_url}" \
  ${extra_defines[@]+"${extra_defines[@]}"} \
  --route=/devtool
