#!/usr/bin/env bash
# Design token compliance gate for lib/features/
#
# Greps Dart sources under lib/features/ for forbidden raw Material widgets,
# literal colors, literal dimensions and the banned failure surfaces. Exits
# non-zero on any violation so it can be wired into CI.
#
# SCOPE: this branch's changed lib/features files vs $DESIGN_TOKENS_BASE plus
# dirty ones (on a push to main that scope is empty); --all is audit-only.
#
# Run locally:
#   bash tool/check_design_tokens.sh          # this branch's changes
#   bash tool/check_design_tokens.sh --all    # the whole tree (audit mode)
#
# Wire into CI with fetch-depth: 0 so the base ref resolves:
#   - name: Design token compliance gate (diff-scoped)
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
# Per-line exemptions:
#   A line carrying the repo's documented marker
#   `EXEMPT(flutter-omds-design-system-usage)` (the same marker the Dart-side
#   rule honors) is skipped by every check. Prefer it over the file list above:
#   it is line-precise, greppable and reviewed in the diff that adds it.
#
# Portability:
#   Uses POSIX ERE (-E) with [[:space:]] instead of \s and avoids PCRE
#   features (no lookbehind / -P) so it runs on both BSD grep (macOS) and
#   GNU grep (Linux CI).

set -euo pipefail

FEATURES_DIR="lib/features"
BASE_REF="${DESIGN_TOKENS_BASE:-origin/main}"
MODE="diff"
EXIT_CODE=0
VIOLATION_COUNT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) MODE="all" ;;
    --diff) MODE="diff" ;;
    --base) BASE_REF="${2:?--base needs a ref}"; shift ;;
    -h|--help)
      sed -n '2,35p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1 (expected --all, --diff or --base <ref>)" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -d "$FEATURES_DIR" ]]; then
  echo "Error: $FEATURES_DIR not found. Run this script from the jeeb-mobile repo root." >&2
  exit 2
fi

# --- Scope resolution ------------------------------------------------------
# Emits the newline-separated list of files to check on stdout.
resolve_scope() {
  if [[ "$MODE" == "all" ]]; then
    find "$FEATURES_DIR" -name '*.dart' -type f | sort
    return
  fi

  local diff_base=""
  if git rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    diff_base=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo "$BASE_REF")
  else
    echo "WARN: base ref '$BASE_REF' not found — checking working-tree changes only." >&2
  fi

  {
    if [[ -n "$diff_base" ]]; then
      git diff --name-only --diff-filter=ACMR "$diff_base" -- "$FEATURES_DIR" || true
    fi
    git diff --name-only --diff-filter=ACMR HEAD -- "$FEATURES_DIR" || true
    git ls-files --others --exclude-standard -- "$FEATURES_DIR" || true
  } | { grep -E '\.dart$' || true; } | sort -u | while read -r f; do
    [[ -f "$f" ]] && echo "$f"
  done
  return 0
}

SCOPE_FILE=$(mktemp)
trap 'rm -f "$SCOPE_FILE"' EXIT
resolve_scope > "$SCOPE_FILE"
FILE_COUNT=$(wc -l < "$SCOPE_FILE" | tr -d ' ')

if [[ "$FILE_COUNT" -eq 0 ]]; then
  echo "OK: no changed Dart files under $FEATURES_DIR — nothing to check."
  exit 0
fi

# Marker that exempts the line it sits on from every check below.
EXEMPT_MARKER='EXEMPT(flutter-omds-design-system-usage)'

# check_pattern <label> <regex> [exclude_regex]
#
# Greps the in-scope files for <regex>, then strips any line matching
# <exclude_regex> (line-level filter). Lines carrying $EXEMPT_MARKER are
# dropped first, before comments are stripped, so the marker stays visible.
# Prints matches and bumps the counter.
check_pattern() {
  local label="$1"
  local pattern="$2"
  local exclude_pattern="${3:-}"

  local matches
  if [[ -n "$exclude_pattern" ]]; then
    matches=$(grep -nE "" -- $(cat "$SCOPE_FILE") /dev/null \
      | grep -v -F "$EXEMPT_MARKER" \
      | sed -E 's#//.*$##' \
      | grep -E "$pattern" \
      | grep -v -E "$exclude_pattern" \
      || true)
  else
    matches=$(grep -nE "" -- $(cat "$SCOPE_FILE") /dev/null \
      | grep -v -F "$EXEMPT_MARKER" \
      | sed -E 's#//.*$##' \
      | grep -E "$pattern" \
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

if [[ "$MODE" == "all" ]]; then
  echo "Checking design token compliance across all of $FEATURES_DIR ($FILE_COUNT files)..."
else
  echo "Checking design token compliance in $FILE_COUNT changed file(s) under $FEATURES_DIR..."
fi

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
  "Raw RefreshIndicator     ->  use JeebPullToRefresh" \
  '\bRefreshIndicator\('

# --- Failure-surface violations (WP-0B kit) --------------------------------
check_pattern \
  "Bare OmdsPullToRefresh   ->  use JeebPullToRefresh (bakes the LR-20 spinner ink)" \
  '\bOmdsPullToRefresh\('

check_pattern \
  "showOmdsErrorSnackbar    ->  use showJeebErrorSnack (2.79:1 ink, no identifier)" \
  '\bshowOmdsErrorSnackbar\('

check_pattern \
  "Raw showSnackBar         ->  use showJeebSnack / showJeebErrorSnack" \
  '\.showSnackBar\('

check_pattern \
  "OmdsErrorState/LoadingState -> use JeebFailureBlock / JeebEmptyState" \
  '\bOmds(ErrorState|LoadingState)\('

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "OK: all design token checks passed."
else
  echo "FAIL: found $VIOLATION_COUNT violation(s). Fix before merging."
fi

exit $EXIT_CODE
