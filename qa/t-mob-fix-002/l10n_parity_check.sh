#!/usr/bin/env bash
# qa/t-mob-fix-002/l10n_parity_check.sh
#
# 4-set localization parity gate for T-MOB-FIX-002 (JEB-2).
# Authoritative spec: JEB-2 comment 14782 (Tech Lead) §1 + §2.
#
# Sets:
#   S1 = { l10n.<key> call sites in lib/**/*.dart }
#   S2 = { _get('<key>') getters in lib/l10n/app_localizations.dart }
#   S3 = { non-@ keys in lib/l10n/app_en.arb }
#   S4 = { non-@ keys in lib/l10n/app_ar.arb }
#
# Pass criteria (LEAD §2, all strict):
#   (a) S1 \ S2 == ∅           — every call site has a getter
#   (b) S2 == S3               — every getter has an EN string
#   (c) S2 == S3 == S4         — full EN/AR parity at the getter set
#   (d) ∀ k ∈ S3 : value(en,k) != k  — no value equals its key
#   (e) ∀ k ∈ S4 : value(ar,k) != k  — no AR fallback to key name
#   (f) flutter analyze lib/   reports 0 errors  [optional, controlled by --analyze]
#
# Exit codes:
#   0   — all checks pass
#   1   — at least one strict check failed
#   2   — script invocation / environment error (jq missing, files missing, etc.)
#
# Artifacts written to ${OUT_DIR:-/tmp}:
#   s1_callsites.txt, s2_getters.txt, s3_en.txt, s4_ar.txt
#   missing_getters.txt   (S1 \ S2)            — should be 156 before ENG, 0 after
#   orphan_getters.txt    (S2 \ S1)            — non-blocking warning
#   missing_en.txt        (S2 \ S3)            — strict
#   missing_ar.txt        (S2 \ S4)            — strict
#   en_value_equals_key.txt, ar_value_equals_key.txt — strict
#
# Usage:
#   bash qa/t-mob-fix-002/l10n_parity_check.sh                  # static checks only
#   bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze        # + flutter analyze
#   OUT_DIR=./_artifacts bash qa/t-mob-fix-002/l10n_parity_check.sh
#
set -u
set -o pipefail

# --- locate repo root (so script works from any cwd) ---------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

OUT_DIR="${OUT_DIR:-/tmp}"
mkdir -p "${OUT_DIR}"

RUN_ANALYZE=0
for arg in "$@"; do
  case "$arg" in
    --analyze) RUN_ANALYZE=1 ;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# --- dependency checks ---------------------------------------------------------
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (brew install jq)" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep is required" >&2; exit 2; }

EN_ARB="lib/l10n/app_en.arb"
AR_ARB="lib/l10n/app_ar.arb"
LOC_DART="lib/l10n/app_localizations.dart"

for f in "${EN_ARB}" "${AR_ARB}" "${LOC_DART}"; do
  [[ -f "$f" ]] || { echo "ERROR: required file missing: $f" >&2; exit 2; }
done

# --- compute S1: l10n.<key> call sites ----------------------------------------
# Match `l10n.<identifier>` anywhere in lib/**/*.dart EXCEPT inside l10n/ itself
# (so we don't accidentally pick up _get('key') tokens or class definitions).
S1="${OUT_DIR}/s1_callsites.txt"
grep -rohE '\bl10n\.([a-zA-Z_][a-zA-Z0-9_]*)' lib/ \
  --include='*.dart' \
  --exclude-dir='l10n' \
  2>/dev/null \
  | sed -E 's/^l10n\.//' \
  | sort -u > "${S1}"

# --- compute S2: getter names in app_localizations.dart -----------------------
# Source of truth is _get('key') invocations, NOT `String get foo => ...` names,
# because the latter can drift from the ARB key (theoretically).
S2="${OUT_DIR}/s2_getters.txt"
grep -oE "_get\('[^']+'\)" "${LOC_DART}" \
  | sed -E "s/_get\('([^']+)'\)/\1/" \
  | sort -u > "${S2}"

# --- compute S3, S4: ARB key sets (excluding @-metadata) ----------------------
S3="${OUT_DIR}/s3_en.txt"
S4="${OUT_DIR}/s4_ar.txt"
jq -r 'keys[] | select(startswith("@") | not)' "${EN_ARB}" | sort -u > "${S3}"
jq -r 'keys[] | select(startswith("@") | not)' "${AR_ARB}" | sort -u > "${S4}"

# --- diffs --------------------------------------------------------------------
MISSING_GETTERS="${OUT_DIR}/missing_getters.txt"   # S1 \ S2  [strict]
ORPHAN_GETTERS="${OUT_DIR}/orphan_getters.txt"     # S2 \ S1  [warn]
MISSING_EN="${OUT_DIR}/missing_en.txt"             # S2 \ S3  [strict]
MISSING_AR="${OUT_DIR}/missing_ar.txt"             # S2 \ S4  [strict]
EXTRA_EN="${OUT_DIR}/extra_en.txt"                 # S3 \ S2  [strict]
EXTRA_AR="${OUT_DIR}/extra_ar.txt"                 # S4 \ S2  [strict]
EN_VAL_EQ_KEY="${OUT_DIR}/en_value_equals_key.txt" # value == key in EN [strict]
AR_VAL_EQ_KEY="${OUT_DIR}/ar_value_equals_key.txt" # value == key in AR [strict]

comm -23 "${S1}" "${S2}" > "${MISSING_GETTERS}"
comm -23 "${S2}" "${S1}" > "${ORPHAN_GETTERS}"
comm -23 "${S2}" "${S3}" > "${MISSING_EN}"
comm -23 "${S2}" "${S4}" > "${MISSING_AR}"
comm -23 "${S3}" "${S2}" > "${EXTRA_EN}"
comm -23 "${S4}" "${S2}" > "${EXTRA_AR}"

# --- value-equals-key check (entries where the AR/EN value is the key string) -
jq -r 'to_entries[]
       | select(.key | startswith("@") | not)
       | select(.value | type == "string")
       | select(.value == .key)
       | .key' "${EN_ARB}" | sort -u > "${EN_VAL_EQ_KEY}"
jq -r 'to_entries[]
       | select(.key | startswith("@") | not)
       | select(.value | type == "string")
       | select(.value == .key)
       | .key' "${AR_ARB}" | sort -u > "${AR_VAL_EQ_KEY}"

# --- counts -------------------------------------------------------------------
s1_n=$(wc -l < "${S1}" | tr -d ' ')
s2_n=$(wc -l < "${S2}" | tr -d ' ')
s3_n=$(wc -l < "${S3}" | tr -d ' ')
s4_n=$(wc -l < "${S4}" | tr -d ' ')
mg_n=$(wc -l < "${MISSING_GETTERS}" | tr -d ' ')
og_n=$(wc -l < "${ORPHAN_GETTERS}" | tr -d ' ')
me_n=$(wc -l < "${MISSING_EN}" | tr -d ' ')
ma_n=$(wc -l < "${MISSING_AR}" | tr -d ' ')
ee_n=$(wc -l < "${EXTRA_EN}" | tr -d ' ')
ea_n=$(wc -l < "${EXTRA_AR}" | tr -d ' ')
evk_n=$(wc -l < "${EN_VAL_EQ_KEY}" | tr -d ' ')
avk_n=$(wc -l < "${AR_VAL_EQ_KEY}" | tr -d ' ')

echo "================ l10n parity report (T-MOB-FIX-002) ================"
echo "S1 (l10n.<key> call sites)           : ${s1_n}"
echo "S2 (_get('<key>') getters)           : ${s2_n}"
echo "S3 (EN ARB keys, non-@)              : ${s3_n}"
echo "S4 (AR ARB keys, non-@)              : ${s4_n}"
echo "----"
echo "(a) S1 \\ S2  missing getters         : ${mg_n}   [strict, must be 0]"
echo "(b) S2 \\ S3  getters missing EN      : ${me_n}   [strict, must be 0]"
echo "    S3 \\ S2  EN keys w/ no getter    : ${ee_n}   [strict, must be 0]"
echo "(c) S2 \\ S4  getters missing AR      : ${ma_n}   [strict, must be 0]"
echo "    S4 \\ S2  AR keys w/ no getter    : ${ea_n}   [strict, must be 0]"
echo "(d) EN value == key                  : ${evk_n}  [strict, must be 0]"
echo "(e) AR value == key                  : ${avk_n}  [strict, must be 0]"
echo "    S2 \\ S1  orphan getters          : ${og_n}   [warn only]"
echo "===================================================================="

fail=0

if [[ "${mg_n}" -gt 0 ]]; then
  echo "FAIL (a): ${mg_n} call sites have no getter — see ${MISSING_GETTERS}" >&2
  head -20 "${MISSING_GETTERS}" | sed 's/^/  /' >&2
  [[ "${mg_n}" -gt 20 ]] && echo "  ... (+$((mg_n - 20)) more)" >&2
  fail=1
fi
if [[ "${me_n}" -gt 0 || "${ee_n}" -gt 0 ]]; then
  echo "FAIL (b): EN ARB / getter set mismatch — S2\\S3=${me_n}, S3\\S2=${ee_n}" >&2
  [[ "${me_n}" -gt 0 ]] && { echo "  missing EN strings:" >&2; head -10 "${MISSING_EN}" | sed 's/^/    /' >&2; }
  [[ "${ee_n}" -gt 0 ]] && { echo "  orphan EN keys:"   >&2; head -10 "${EXTRA_EN}"   | sed 's/^/    /' >&2; }
  fail=1
fi
if [[ "${ma_n}" -gt 0 || "${ea_n}" -gt 0 ]]; then
  echo "FAIL (c): AR ARB / getter set mismatch — S2\\S4=${ma_n}, S4\\S2=${ea_n}" >&2
  [[ "${ma_n}" -gt 0 ]] && { echo "  missing AR strings:" >&2; head -10 "${MISSING_AR}" | sed 's/^/    /' >&2; }
  [[ "${ea_n}" -gt 0 ]] && { echo "  orphan AR keys:"   >&2; head -10 "${EXTRA_AR}"   | sed 's/^/    /' >&2; }
  fail=1
fi
if [[ "${evk_n}" -gt 0 ]]; then
  echo "FAIL (d): ${evk_n} EN entries whose value equals their key — see ${EN_VAL_EQ_KEY}" >&2
  head -10 "${EN_VAL_EQ_KEY}" | sed 's/^/  /' >&2
  fail=1
fi
if [[ "${avk_n}" -gt 0 ]]; then
  echo "FAIL (e): ${avk_n} AR entries whose value equals their key — see ${AR_VAL_EQ_KEY}" >&2
  head -10 "${AR_VAL_EQ_KEY}" | sed 's/^/  /' >&2
  fail=1
fi
if [[ "${og_n}" -gt 0 ]]; then
  echo "WARN: ${og_n} orphan getters (declared but unused) — see ${ORPHAN_GETTERS}" >&2
fi

# --- optional flutter analyze gate --------------------------------------------
if [[ "${RUN_ANALYZE}" -eq 1 ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "FAIL (f): --analyze requested but flutter not on PATH" >&2
    fail=1
  else
    ANALYZE_LOG="${OUT_DIR}/flutter_analyze.log"
    echo "Running: flutter analyze lib/ (log: ${ANALYZE_LOG})"
    if ! flutter analyze lib/ > "${ANALYZE_LOG}" 2>&1; then
      echo "FAIL (f): flutter analyze reported errors — see ${ANALYZE_LOG}" >&2
      tail -20 "${ANALYZE_LOG}" | sed 's/^/  /' >&2
      fail=1
    fi
  fi
fi

if [[ "${fail}" -eq 0 ]]; then
  echo "PASS — l10n parity gate green"
  exit 0
fi
echo "FAILED — l10n parity gate red" >&2
exit 1
