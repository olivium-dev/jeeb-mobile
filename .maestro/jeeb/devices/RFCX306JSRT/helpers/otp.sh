#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# otp.sh — read the latest real OTP for a phone from the live jeeb-otpdb.
# ─────────────────────────────────────────────────────────────────────────────
# The prod build's "Enter the code" screen is fed by POST /v1/auth/otp/request,
# which writes a fresh 4-digit code into jeeb-otpdb."Phones"."OTP". The dev code
# 1234 NEVER works and codes expire after 5 minutes — so an automated verify step
# MUST read the just-generated code from the DB.
#
# Usage:
#   helpers/otp.sh [PHONE]        # PHONE defaults to 71963130 (8-digit, no +961)
#   OTP=$(helpers/otp.sh 71963130)
#
# Prints ONLY the 4-digit code to stdout (nothing else) so it can be captured
# into a Maestro -e OTP=... injection. Exits non-zero if no code is found.
#
# Requires psql on PATH and network line-of-sight to the DB host.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PHONE="${1:-71963130}"

PGHOST="${PGHOST:-192.168.2.20}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-oudaykhaled}"
PGDATABASE="${PGDATABASE:-jeeb-otpdb}"

CONN="host=${PGHOST} port=${PGPORT} user=${PGUSER} dbname=${PGDATABASE} connect_timeout=8"

# Quoted identifiers because the columns are PascalCase. Newest row for the phone.
OTP="$(psql "${CONN}" -tAc \
  "SELECT \"OTP\" FROM \"Phones\" WHERE \"PhoneNumber\" LIKE '%${PHONE}%' ORDER BY \"ID\" DESC LIMIT 1" \
  2>/dev/null | tr -d '[:space:]')"

if [[ -z "${OTP}" ]]; then
  echo "otp.sh: no OTP row found for phone matching '%${PHONE}%' in ${PGDATABASE}.\"Phones\"" >&2
  exit 1
fi

printf '%s' "${OTP}"
