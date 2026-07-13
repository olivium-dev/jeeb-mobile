#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# otp.sh — read the REAL 4-digit OTP for a phone from the jeeb-otpdb Postgres.
# ─────────────────────────────────────────────────────────────────────────────
# Why this exists: on the physical device R5CT71TVVAJ this suite drives REAL
# phone-OTP auth against the MSI backend. The dev-only "1234" NEVER works. After
# the register page fires POST /v1/auth/otp/request (200), the backend writes the
# code to jeeb-otpdb."Phones"; read it here, then feed it to the otp-entry page
# (the 4-box field AUTO-SUBMITS on the 4th digit — no Verify tap).
#
# OTP auth is inherently TWO-PHASE (you cannot know the code before send-code):
#   Phase 1: run flows/journeys/auth-request-otp.yaml   (sends the code)
#   Phase 2: OTP="$(helpers/otp.sh 76543201)"           (reads the code)
#            run flows/journeys/after-otp.yaml -e OTP="$OTP"
#
# Usage:   helpers/otp.sh <phone-fragment>        # e.g. 76543201
# Output:  the 4-digit OTP on stdout (nothing else), or exits non-zero.
#
# Env (override as needed; defaults target the MSI dev/staging box):
#   PGHOST=192.168.2.20  PGPORT=5432  PGUSER=oudaykhaled  PGDATABASE=jeeb-otpdb
# Requires a NATIVE psql client (per house rule: never docker for dev tooling).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PHONE_FRAGMENT="${1:?usage: otp.sh <phone-fragment>  e.g. 76543201}"

export PGHOST="${PGHOST:-192.168.2.20}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-oudaykhaled}"
export PGDATABASE="${PGDATABASE:-jeeb-otpdb}"

if ! command -v psql >/dev/null 2>&1; then
  echo "otp.sh: psql not found on PATH (install a native postgres client)" >&2
  exit 3
fi

# -A -t = unaligned, tuples-only -> bare value. Newest OTP for the phone wins.
OTP="$(psql -A -t -v ON_ERROR_STOP=1 -c \
  "SELECT \"OTP\" FROM \"Phones\" \
     WHERE \"PhoneNumber\" LIKE '%${PHONE_FRAGMENT}%' \
     ORDER BY \"OTPSentDate\" DESC LIMIT 1;" | tr -d '[:space:]')"

if [[ -z "${OTP}" ]]; then
  echo "otp.sh: no OTP row for phone fragment '${PHONE_FRAGMENT}' in ${PGDATABASE}.Phones" >&2
  exit 4
fi

if [[ ! "${OTP}" =~ ^[0-9]{4}$ ]]; then
  echo "otp.sh: got '${OTP}' which is not a 4-digit code — check the schema/row" >&2
  exit 5
fi

printf '%s' "${OTP}"
