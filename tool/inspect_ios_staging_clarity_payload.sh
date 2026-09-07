#!/usr/bin/env bash
set -euo pipefail

# These actual application markers complement reviewed build provenance; they
# do not attest that a tester consented or that the service received a session.
app_binary="${1:-}"
[[ -f "${app_binary}" && ! -L "${app_binary}" && -s "${app_binary}" ]] || {
  printf '%s\n' 'Staging iOS capture payload is missing.' >&2
  exit 1
}
for marker in y6laxxj143 jeeb-clarity-sdk; do
  LC_ALL=C grep -aFq "${marker}" "${app_binary}" || {
    printf '%s\n' 'Staging iOS capture project or SDK application marker is missing.' >&2
    exit 1
  }
done
