#!/usr/bin/env bash
# qa/t-mob-fix-002/ar_plurals_check.sh
#
# Arabic CLDR plural-form audit for T-MOB-FIX-002 (JEB-2).
# Authoritative spec: JEB-2 comment 14782 (Tech Lead) §4 and UX comment 14779 §3.
#
# Arabic CLDR requires six plural forms: zero, one, two, few, many, other.
# This repo encodes plurals via key-suffix convention (NOT inline ICU):
#   <base>Zero, <base>One, <base>Two, <base>Few, <base>Many, <base>Other
# (compatible with Intl.plural at the loader layer per LEAD §4.)
#
# What this audit does
# --------------------
# 1. Detect every "plural set" — a group of keys sharing the same base name
#    whose suffix is one of {Zero, One, Two, Few, Many, Other}, OR
#    a single key with a `{count, plural, ...}` ICU expression.
# 2. For each plural set, verify the AR ARB declares ALL SIX CLDR forms.
# 3. Additionally flag any key whose value contains a numeric placeholder
#    (`{count}`, `{minutes}`, `{amount}`, `{n}`) and that lives OUTSIDE a
#    plural set — that's a candidate for promotion to a plural set per LEAD §4.
#
# Exit codes:
#   0  — all AR plural sets have the six required forms
#   1  — at least one plural set is missing AR forms
#   2  — script/environment error
#
# Artifacts in ${OUT_DIR:-/tmp}:
#   plural_sets.txt           — base names of detected plural sets
#   ar_plural_missing.txt     — base + list of missing AR forms (one line per set)
#   numeric_no_plural.txt     — keys with {count}/{minutes}/{amount} but no plural set
#
# Usage:
#   bash qa/t-mob-fix-002/ar_plurals_check.sh
#   OUT_DIR=./_artifacts bash qa/t-mob-fix-002/ar_plurals_check.sh
#
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

OUT_DIR="${OUT_DIR:-/tmp}"
mkdir -p "${OUT_DIR}"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }
EN_ARB="lib/l10n/app_en.arb"
AR_ARB="lib/l10n/app_ar.arb"
for f in "${EN_ARB}" "${AR_ARB}"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 2; }
done

# The six CLDR forms required for Arabic (LEAD §4).
REQUIRED_FORMS=(Zero One Two Few Many Other)

# --- Step 1: enumerate plural-set bases ---------------------------------------
# A "plural set base" is the shared prefix of two or more keys whose suffix
# matches one of REQUIRED_FORMS. Detection scans the UNION of EN+AR keys so a
# set is recognised even if one locale only declares some forms.
ALL_KEYS_FILE="${OUT_DIR}/_all_keys.txt"
jq -r 'keys[] | select(startswith("@") | not)' "${EN_ARB}" "${AR_ARB}" \
  | sort -u > "${ALL_KEYS_FILE}"

# Extract base names: strip the suffix if it matches one of the six forms.
BASES_FILE="${OUT_DIR}/plural_sets.txt"
grep -E '(Zero|One|Two|Few|Many|Other)$' "${ALL_KEYS_FILE}" \
  | sed -E 's/(Zero|One|Two|Few|Many|Other)$//' \
  | sort -u > "${BASES_FILE}"

# Filter to bases with ≥2 distinct suffix-form variants — a true plural set,
# not just a key that coincidentally ends in "One"/"Few" as English (e.g.
# `composerHintNoOne` would otherwise be flagged).
true_bases=()
while IFS= read -r base; do
  [[ -z "$base" ]] && continue
  count=0
  for f in "${REQUIRED_FORMS[@]}"; do
    if grep -qx "${base}${f}" "${ALL_KEYS_FILE}"; then
      count=$((count + 1))
    fi
  done
  if [[ "${count}" -ge 2 ]]; then
    true_bases+=("${base}")
  fi
done < "${BASES_FILE}"
printf '%s\n' "${true_bases[@]}" | sort -u > "${BASES_FILE}"

n_sets=$(wc -l < "${BASES_FILE}" | tr -d ' ')

# --- Step 2: for each base, check AR has all six forms ------------------------
MISSING_REPORT="${OUT_DIR}/ar_plural_missing.txt"
: > "${MISSING_REPORT}"

ar_keys_file="${OUT_DIR}/_ar_keys.txt"
jq -r 'keys[] | select(startswith("@") | not)' "${AR_ARB}" | sort -u > "${ar_keys_file}"

fail_sets=0
while IFS= read -r base; do
  [[ -z "$base" ]] && continue
  missing=()
  for f in "${REQUIRED_FORMS[@]}"; do
    if ! grep -qx "${base}${f}" "${ar_keys_file}"; then
      missing+=("${f}")
    fi
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    fail_sets=$((fail_sets + 1))
    printf '%s\tmissing AR forms: %s\n' "${base}" "$(IFS=,; echo "${missing[*]}")" >> "${MISSING_REPORT}"
  fi
done < "${BASES_FILE}"

# --- Step 3: inline ICU plural check (any `{count, plural, ...}` in AR) -------
# If an AR value uses inline ICU, all six form-clauses must appear within it.
ICU_REPORT="${OUT_DIR}/ar_icu_plural_missing.txt"
: > "${ICU_REPORT}"
icu_fail=0
while IFS=$'\t' read -r key value; do
  for form in zero one two few many other; do
    # Each form must appear as a clause: ` <form>{` (after a separator).
    if ! printf '%s' "${value}" | grep -qE "[[:space:],]${form}\\{"; then
      icu_fail=$((icu_fail + 1))
      printf '%s\tmissing ICU clause: %s\n' "${key}" "${form}" >> "${ICU_REPORT}"
    fi
  done
done < <(jq -r '
  to_entries[]
  | select(.key | startswith("@") | not)
  | select(.value | type == "string")
  | select(.value | test("\\{[^}]*,\\s*plural\\s*,"))
  | [.key, .value] | @tsv
' "${AR_ARB}")

# --- Step 4: numeric-placeholder keys outside any plural set ------------------
NUMERIC_REPORT="${OUT_DIR}/numeric_no_plural.txt"
: > "${NUMERIC_REPORT}"
en_numeric_file="${OUT_DIR}/_en_numeric_keys.txt"
jq -r '
  to_entries[]
  | select(.key | startswith("@") | not)
  | select(.value | type == "string")
  | select(.value | test("\\{(count|minutes|amount|n|total|remaining)\\}"))
  | .key
' "${EN_ARB}" | sort -u > "${en_numeric_file}"

while IFS= read -r k; do
  [[ -z "$k" ]] && continue
  base="$(printf '%s' "$k" | sed -E 's/(Zero|One|Two|Few|Many|Other)$//')"
  if ! grep -qx "${base}" "${BASES_FILE}"; then
    printf '%s\n' "$k" >> "${NUMERIC_REPORT}"
  fi
done < "${en_numeric_file}"

# --- summary ------------------------------------------------------------------
n_numeric_no_plural=$(wc -l < "${NUMERIC_REPORT}" | tr -d ' ')

echo "================ AR plurals audit (T-MOB-FIX-002) ================"
echo "Detected plural sets             : ${n_sets}"
echo "Sets missing AR forms (strict)   : ${fail_sets}"
echo "Inline-ICU missing clauses       : ${icu_fail}"
echo "Numeric keys outside plural sets : ${n_numeric_no_plural}   [warn — review with LEAD §4]"
echo "=================================================================="

fail=0

if [[ "${fail_sets}" -gt 0 ]]; then
  echo "FAIL: ${fail_sets} plural set(s) missing AR CLDR forms — see ${MISSING_REPORT}" >&2
  head -20 "${MISSING_REPORT}" | sed 's/^/  /' >&2
  [[ "${fail_sets}" -gt 20 ]] && echo "  ... (+$((fail_sets - 20)) more)" >&2
  fail=1
fi
if [[ "${icu_fail}" -gt 0 ]]; then
  echo "FAIL: ${icu_fail} inline-ICU plural value(s) missing CLDR clauses — see ${ICU_REPORT}" >&2
  head -20 "${ICU_REPORT}" | sed 's/^/  /' >&2
  fail=1
fi
if [[ "${n_numeric_no_plural}" -gt 0 ]]; then
  echo "WARN: ${n_numeric_no_plural} numeric-placeholder key(s) declared without a plural set." >&2
  echo "      LEAD §4 requires plural-set promotion for restored countable getters." >&2
  echo "      Review list: ${NUMERIC_REPORT}" >&2
  # WARN, not FAIL — pre-existing repo state may have legitimate single-form keys
  # (e.g. error messages with numbers). QA-POST will visually verify these.
fi

if [[ "${fail}" -eq 0 ]]; then
  echo "PASS — AR plural CLDR audit green"
  exit 0
fi
echo "FAILED — AR plural CLDR audit red" >&2
exit 1
