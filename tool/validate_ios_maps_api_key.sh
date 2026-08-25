#!/usr/bin/env bash

set -euo pipefail

KEY_PATH="${1:-}"

fail() {
  printf 'Protected iOS Maps validation failed: %s\n' "$1" >&2
  exit 1
}

[[ -n "${KEY_PATH}" ]] || fail 'a protected key file is required'
[[ -f "${KEY_PATH}" && ! -L "${KEY_PATH}" ]] ||
  fail 'the protected key input must be a regular file'

if [[ "$(uname -s)" == Darwin ]]; then
  key_mode="$(stat -f '%Lp' "${KEY_PATH}")"
else
  key_mode="$(stat -c '%a' "${KEY_PATH}")"
fi
[[ "${key_mode}" == 600 ]] || fail 'the protected key file must have mode 0600'

key_size="$(wc -c <"${KEY_PATH}" | tr -d '[:space:]')"
[[ "${key_size}" -le 40 ]] || fail 'the protected key has an invalid length'

maps_api_key="$(tr -d '\n' <"${KEY_PATH}")"
[[ "${maps_api_key}" != *$'\r'* ]] || fail 'the protected key contains CR bytes'
[[ "${maps_api_key}" =~ ^AIza[A-Za-z0-9_-]{35}$ ]] ||
  fail 'the protected key has an invalid format'

line_count="$({ grep -c '^' "${KEY_PATH}" || true; } | tr -d '[:space:]')"
[[ "${line_count}" == 1 ]] || fail 'the protected key must contain one line'

unset maps_api_key key_mode key_size line_count
printf '%s\n' 'Protected iOS Maps key validation passed.'
