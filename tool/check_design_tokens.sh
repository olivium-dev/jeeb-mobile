#!/usr/bin/env bash
# Design token compliance gate for lib/features/
#
# Greps lib/features/**/*.dart for forbidden raw Material widgets, literal
# colors, and literal dimensions. Exits non-zero on any violation so it can
# be wired into CI to prevent design system regression.
#
# Run locally:
#   bash tool/check_design_tokens.sh
#
# Wire into CI (.github/workflows/<workflow>.yml):
#   - name: Design token compliance gate
#     run: bash tool/check_design_tokens.sh
#
# Exemptions (intentional, documented):
#   - lib/app/branded_splash.dart                  -> dependency-free splash
#   - lib/app/app_theme.dart                       -> defines the seed colors
#   - lib/features/auth/social/social_sign_in_button.dart
#                                                  -> Apple/Google brand reqs
#   - lib/features/registration/presentation/registration_screen.dart
#     -> JEEB-55/JEEB-57: raw TextField in _PhoneField for +961 prefix;
#        OmdsTextField lacks prefixIconConstraints support (upstream PR pending)
#
# Portability:
#   Uses POSIX ERE (-E) with [[:space:]] instead of \s and avoids PCRE
#   features (no lookbehind / -P) so it runs on both BSD grep (macOS) and
#   GNU grep (Linux CI).

set -euo pipefail

FEATURES_DIR="lib/features"
EXIT_CODE=0
VIOLATION_COUNT=0

if [[ ! -d "$FEATURES_DIR" ]]; then
  echo "Error: $FEATURES_DIR not found. Run this script from the jeeb-mobile repo root." >&2
  exit 2
fi

# check_pattern <label> <regex> [exclude_regex]
#
# Greps recursively under $FEATURES_DIR for files matching <regex>, then
# strips any line matching <exclude_regex> (line-level filter). Prints
# matches and bumps the violation counter.
check_pattern() {
  local label="$1"
  local pattern="$2"
  local exclude_pattern="${3:-}"

  local matches
  if [[ -n "$exclude_pattern" ]]; then
    matches=$(grep -rn --include="*.dart" -E "$pattern" "$FEATURES_DIR" \
      | grep -v -E '^\s*//' \
      | grep -v -E '///|//' \
      | grep -v -E "$exclude_pattern" \
      || true)
  else
    matches=$(grep -rn --include="*.dart" -E "$pattern" "$FEATURES_DIR" \
      | grep -v -E '///|//' \
      || true)
  fi

  if [[ -n "$matches" ]]; then
    echo ""
    echo "FAIL: $label"
    echo "$matches"
    VIOLATION_COUNT=$(( VIOLATION_COUNT + $(printf '%s\n' "$matches" | wc -l | tr -d ' ') ))
    EXIT_CODE=1
  fi
}

echo "Checking design token compliance in $FEATURES_DIR..."

# --- Color violations ------------------------------------------------------
# Apple/Google brand colors in social_sign_in_button.dart are exempt.
check_pattern \
  "Color(0xFF...) literals  ->  use OmdsColorTokens or Theme.of(context).colorScheme.<role>" \
  'Color\(0x[0-9A-Fa-f]{6,8}\)' \
  'social_sign_in_button\.dart'

# Colors.transparent is allowed (used legitimately for ripples / overlays).
# \b prevents matching custom getters like `semanticColors.availableNow`.
check_pattern \
  "Colors.<name>            ->  use ColorScheme roles (primary, surface, error, ...)" \
  '\bColors\.[a-zA-Z]+' \
  'Colors\.transparent'

# --- Dimension violations --------------------------------------------------
check_pattern \
  "SizedBox literal number  ->  use Spacing.<token> / Sizes.<token>" \
  'SizedBox\([[:space:]]*(width|height):[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]*\)'

check_pattern \
  "EdgeInsets literal       ->  use Spacing.<token>" \
  'EdgeInsets\.[a-zA-Z]+\([[:space:]]*[0-9]'

check_pattern \
  "BorderRadius.circular()  ->  use OmdsBorderRadius.<token>" \
  'BorderRadius\.circular\([[:space:]]*[0-9]'

check_pattern \
  "fontSize literal         ->  use Theme.of(context).textTheme.<role>" \
  'fontSize:[[:space:]]*[0-9]'

# --- Widget violations -----------------------------------------------------
# \b on each widget name prevents substring false positives like
# OMDSAppBar(, OMDSOutlinedButton(, OmdsTextField(, etc. The exclude_patterns
# remain as defense-in-depth.
check_pattern \
  "Raw AppBar               ->  use OMDSAppBar" \
  '\bAppBar\(' \
  'OMDSAppBar|AppBarTheme'

check_pattern \
  "Raw ElevatedButton       ->  use OmdsPrimaryButton" \
  '\bElevatedButton\('

check_pattern \
  "Raw OutlinedButton       ->  use OmdsOutlinedButton" \
  '\bOutlinedButton\('

check_pattern \
  "Raw TextField            ->  use OmdsTextField or OmdsValidatedTextField" \
  '\bTextField\(' \
  'OmdsTextField|OmdsValidatedTextField|registration_screen\.dart'

check_pattern \
  "Raw TextFormField        ->  use OmdsValidatedTextField" \
  '\bTextFormField\('

check_pattern \
  "Raw RefreshIndicator     ->  use OmdsPullToRefresh" \
  '\bRefreshIndicator\('

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "OK: all design token checks passed."
else
  echo "FAIL: found $VIOLATION_COUNT violation(s) in $FEATURES_DIR. Fix before merging."
fi

exit $EXIT_CODE
