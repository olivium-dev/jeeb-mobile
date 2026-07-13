#!/usr/bin/env bash
# otp.sh — request + read the REAL 4-digit OTP for the Jeeb phone-auth flow.
#
# The literal 1234 NEVER works. The gateway generates a per-request code stored
# in Postgres jeeb-otpdb."Phones"."OTP". This helper (1) optionally asks the
# gateway to send a fresh OTP, then (2) reads the newest code for the number.
#
# Proven contract (map 2026-07-13):
#   POST http://192.168.2.39:10090/v1/auth/otp/request  {"phone":"+96171888123"}
#     -> {"ttlSeconds":300}   (field is `phone`, E.164 with +961; NOT phoneNumber)
#   SELECT "OTP" FROM "Phones" WHERE "PhoneNumber"='+9617...' ORDER BY "ID" DESC LIMIT 1;
#     -> e.g. 9049
#
# IMPORTANT: run from a host that can reach the LAN (e.g. the Mac wired to
# 192.168.2.0/24). The phone RZCT505K7WF itself is offline and cannot do this.
# Never `docker run` a psql client here — use the native psql on PATH.
#
# Usage:
#   helpers/otp.sh +96171888123                 # request + read
#   REQUEST=0 helpers/otp.sh +96171888123       # read only (skip the request)
#   helpers/otp.sh +96171888123 | tr -d '\n'    # bare code for `-e OTP=...`
#
# Env knobs (all overridable):
#   GATEWAY   default http://192.168.2.39:10090
#   PGHOST    default 192.168.2.20
#   PGPORT    default 5432
#   PGDATABASE default jeeb-otpdb
#   PGUSER / PGPASSWORD  — REQUIRED for the DB read (no default; export them or
#                          set them in ~/.pgpass). Not committed here.
#   REQUEST   default 1 (set 0 to skip asking the gateway for a fresh code)
#   TABLE/PHONE_COL/OTP_COL/ID_COL — schema names, defaults match jeeb-otpdb.
set -euo pipefail

PHONE="${1:-${PHONE:-}}"
if [[ -z "${PHONE}" ]]; then
  echo "usage: otp.sh <phone-E164, e.g. +96171888123>" >&2
  exit 2
fi

GATEWAY="${GATEWAY:-http://192.168.2.39:10090}"
export PGHOST="${PGHOST:-192.168.2.20}"
export PGPORT="${PGPORT:-5432}"
export PGDATABASE="${PGDATABASE:-jeeb-otpdb}"
REQUEST="${REQUEST:-1}"
TABLE="${TABLE:-Phones}"
PHONE_COL="${PHONE_COL:-PhoneNumber}"
OTP_COL="${OTP_COL:-OTP}"
ID_COL="${ID_COL:-ID}"

if ! command -v psql >/dev/null 2>&1; then
  echo "error: psql not found on PATH (install native postgresql client; do NOT docker run one)" >&2
  exit 3
fi

# (1) request a fresh OTP from the gateway
if [[ "${REQUEST}" == "1" ]]; then
  resp="$(curl -fsS -X POST "${GATEWAY}/v1/auth/otp/request" \
    -H 'Content-Type: application/json' \
    -d "{\"phone\":\"${PHONE}\"}" 2>&1)" || {
      echo "error: OTP request to ${GATEWAY} failed (is the host on the LAN?): ${resp}" >&2
      exit 4
    }
  echo "otp requested: ${resp}" >&2
  sleep 2   # let the row land
fi

# (2) read the newest OTP for this number
otp="$(psql -tAc \
  "SELECT \"${OTP_COL}\" FROM \"${TABLE}\" WHERE \"${PHONE_COL}\"='${PHONE}' ORDER BY \"${ID_COL}\" DESC LIMIT 1;")"
otp="$(echo "${otp}" | tr -d '[:space:]')"

if [[ -z "${otp}" ]]; then
  echo "error: no OTP row found for ${PHONE} in ${PGDATABASE}.\"${TABLE}\"" >&2
  exit 5
fi

echo "${otp}"
